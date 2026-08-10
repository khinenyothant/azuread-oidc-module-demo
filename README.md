# azuread-oidc-app

This module automates Azure AD app registration →  creating the app, service principal, role assignments, and client secret, then publishing the credentials to Key Vault. No more manual Portal clicks or secrets pasted into config files.

---

## Before you start

You'll need these tools installed:

- Terraform >= 1.5 →  https://developer.hashicorp.com/terraform/install
- Azure CLI →  https://learn.microsoft.com/cli/azure/install-azure-cli
- kubectl →  https://kubernetes.io/docs/tasks/tools/
- Docker →  https://docs.docker.com/get-docker/
- minikube (local testing only) →  https://minikube.sigs.k8s.io/docs/start/

Log in to Azure:
```bash
az login
az account set --subscription "<your-subscription-id>"
```

A few things need to exist in Azure before Terraform can run. Create them once:

```bash
# Resource group + Key Vault
az group create --name rg-oidc-demo --location japaneast
az keyvault create --name kv-oidc-demo --resource-group rg-oidc-demo --location japaneast

# Grant yourself permission to write secrets (Terraform needs this)
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --scope $(az keyvault show --name kv-oidc-demo --query id -o tsv)

# AAD groups →  one for admins, one for regular users
az ad group create --display-name "demo-admins" --mail-nickname "demo-admins"
az ad group create --display-name "demo-users"  --mail-nickname "demo-users"
```

One permission you can't grant yourself: `Application.ReadWrite.All` on Entra ID. Ask your tenant admin if you don't have it.

---

## What gets created

![Resource dependency graph](docs/resource-dependency-graph.svg)

After `terraform apply`, you'll have:

- An Entra ID app registration with your custom roles on it
- A service principal (the live tenant instance users actually sign in to)
- Role assignments binding your AAD groups to roles
- A client secret that auto-rotates every 30 days
- Three secrets in Key Vault:

| Secret name | What's in it |
|---|---|
| `<prefix>-client-id` | The app's client ID |
| `<prefix>-client-secret` | The app's client secret |
| `<prefix>-allowed-principals` | Object IDs of everyone with a role |

The secrets never go into git or container images →  Key Vault is the only place they live.

---

## How sign-in works

![Authentication and authorization flow](docs/auth-flow.svg)

```
1. User hits your app → redirected to Entra ID login
2. User logs in → Entra ID returns a JWT token with a "roles" claim
3. Browser sends the token to your app
4. App exchanges it with Entra ID using client-id + client-secret (from Key Vault)
5. App reads the roles claim
6. Admin sees the admin panel, User sees standard access, no role = denied
```

If you set `require_role_to_signin = true`, Entra ID handles step 6 for you →  users without a role can't even get a token.

---

## Repo layout

```
modules/azuread-oidc-app/       the module itself
usecase/provision/               step 1: register the app in Entra ID
usecase/consuming-secrets/       step 2: get credentials into a running pod
  ├── fetch-secrets.sh           quick script, good for local testing
  ├── secret-provider-class.yaml production path using CSI driver
  ├── deployment.yaml            Kubernetes Deployment wired to the secrets
  └── flask-app/                 small Flask app that does the OIDC login + role check
docs/                            architecture diagrams
```

---

## Calling the module

```hcl
module "my_app" {
  source = "./modules/azuread-oidc-app"

  app_display_name = "app-my-tool"
  owners           = ["<your-object-id>"]
  redirect_uris    = ["https://my-tool.example.com/auth/callback"]

  roles = [
    { name = "Admin", description = "Can manage settings" },
    { name = "User",  description = "Can use the tool" },
  ]

  role_assignments = {
    Admin = ["<admin-group-object-id>"]
    User  = ["<user-group-object-id>"]
  }

  require_role_to_signin = true
  keyvault_id            = var.keyvault_id
  secret_name_prefix     = "my-tool"
}
```

Key inputs:

| Input | Required | Notes |
|---|---|---|
| `app_display_name` | yes | Shows up in the Entra ID portal |
| `owners` | yes | Who can manage the app registration |
| `redirect_uris` | yes | Must match exactly what your app sends |
| `roles` | yes | Names your app will check in the token |
| `role_assignments` | no | Which AAD groups get which role |
| `require_role_to_signin` | no | Blocks users with no role at Entra ID level |
| `keyvault_id` | yes | Where to write the credentials |
| `secret_name_prefix` | no | Defaults to `app_display_name` |

---

## Usage →  step by step

### Step 1 →  Provision the app in Entra ID

```bash
cd usecase/provision
cp terraform.tfvars.example terraform.tfvars
# fill in your Key Vault ID and AAD group object IDs

terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

After apply, verify in the portal:

<img width="861" height="426" alt="image" src="https://github.com/user-attachments/assets/76328192-1b1c-4f2e-90fa-70f0f120ef66" />
<img width="1102" height="629" alt="image" src="https://github.com/user-attachments/assets/aa426645-06d7-48ea-a05c-41dbf9f977d3" />
<img width="1250" height="373" alt="image" src="https://github.com/user-attachments/assets/0de51f20-ccf2-43c2-8e58-b81f60c9879a" />
<img width="1553" height="426" alt="image" src="https://github.com/user-attachments/assets/390c4862-a153-44f9-a20b-802ee29adbdc" />
<img width="1391" height="284" alt="image" src="https://github.com/user-attachments/assets/5847debf-d689-49c7-b058-60f23f635b0b" />
<img width="1109" height="112" alt="image" src="https://github.com/user-attachments/assets/c9da1834-2058-4c28-921c-b3eea9c6e84f" />

---

### Step 2 →  Get secrets into the cluster

The module only writes to Key Vault →  this step reads them back out into a Kubernetes Secret.

**For local testing (minikube):** run `fetch-secrets.sh`. It calls `az keyvault secret show` and creates the k8s Secret directly. No cluster components needed.

```bash
minikube start
cd usecase/consuming-secrets
./fetch-secrets.sh

# verify:
kubectl get secret oidc-app-credentials -n demo
kubectl get secret oidc-app-credentials -n demo -o json | jq -r '.data | map_values(@base64d)'
```
<img width="1197" height="405" alt="image" src="https://github.com/user-attachments/assets/4fb92458-eb07-4a3e-a6c3-c4423ef6d553" />

**For production (AKS):** use `secret-provider-class.yaml` instead. The CSI driver pulls secrets automatically and keeps them in sync when they rotate. Fill in `keyvaultName`, `tenantId`, and `userAssignedIdentityID`, then apply it.

Both paths produce the same Kubernetes Secret (`oidc-app-credentials`) that the deployment reads.

---

### Step 3 →  Run the demo app

`usecase/consuming-secrets/flask-app/` is a small Flask app that does the full OIDC login and shows what role the user has.

```bash
# build into minikube (no external registry needed)
eval $(minikube docker-env)
docker build -t oidc-demo-app:latest ./flask-app

# session secret for Flask cookie signing
kubectl create secret generic oidc-session \
  --from-literal=session-secret=$(openssl rand -hex 32) -n demo

# fill in AZURE_TENANT_ID and REDIRECT_URI in deployment.yaml, then:
kubectl apply -f deployment.yaml
kubectl port-forward deploy/my-oidc-app 5000:5000 -n demo
```

Open http://localhost:5000. You'll get redirected to the Microsoft login page. After signing in, the app shows your name and role.
<img width="533" height="640" alt="image" src="https://github.com/user-attachments/assets/55e60d18-16cf-4976-a630-7fb37cdccb35" />

Signed in as Admin:

<img width="575" height="251" alt="image" src="https://github.com/user-attachments/assets/64f272de-d397-4c01-92de-c2b7a75e523f" />


Signed in as User:

<img width="603" height="261" alt="image" src="https://github.com/user-attachments/assets/e558b7cc-14d4-4bb5-b7ba-9d6d9af9db0a" />


