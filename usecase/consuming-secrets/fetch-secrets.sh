#!/usr/bin/env bash
# The simplest way to use the secrets: pull them from Key Vault with the
# Azure CLI and drop them straight into a Kubernetes Secret. No extra
# cluster components required — good for testing, or if you don't have
# the CSI driver installed. See secret-provider-class.yaml for the
# production-grade version that stays in sync automatically.

set -euo pipefail

KEYVAULT_NAME="kv-oidc-demo"
SECRET_PREFIX="app-oidc-demo"  # must match secret_name_prefix (= app_display_name) in your Terraform call
NAMESPACE="demo"
K8S_SECRET_NAME="oidc-app-credentials"

CLIENT_ID=$(az keyvault secret show \
  --vault-name "$KEYVAULT_NAME" \
  --name "${SECRET_PREFIX}-client-id" \
  --query value -o tsv)

CLIENT_SECRET=$(az keyvault secret show \
  --vault-name "$KEYVAULT_NAME" \
  --name "${SECRET_PREFIX}-client-secret" \
  --query value -o tsv)

kubectl create secret generic "$K8S_SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-literal=client-id="$CLIENT_ID" \
  --from-literal=client-secret="$CLIENT_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret '$K8S_SECRET_NAME' created/updated in namespace '$NAMESPACE'."
