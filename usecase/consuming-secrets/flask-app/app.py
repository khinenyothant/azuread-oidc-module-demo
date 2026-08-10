import os
import msal
from flask import Flask, redirect, render_template_string, request, session, url_for

app = Flask(__name__)
app.secret_key = os.environ["SESSION_SECRET"]

CLIENT_ID    = os.environ["OIDC_CLIENT_ID"]
CLIENT_SECRET = os.environ["OIDC_CLIENT_SECRET"]
TENANT_ID    = os.environ["AZURE_TENANT_ID"]
AUTHORITY    = f"https://login.microsoftonline.com/{TENANT_ID}"
REDIRECT_URI = os.environ.get("REDIRECT_URI", "http://localhost:5000/auth/callback")
SCOPE        = []  # MSAL adds openid/profile/offline_access automatically

_PAGE = """
<h2>Hello, {{ name }}</h2>
<p>Roles from token: <b>{{ roles }}</b></p>
{% if "Admin" in roles %}
  <p style="color:green">✓ Admin panel access granted.</p>
{% elif "User" in roles %}
  <p>Standard user access.</p>
{% else %}
  <p style="color:red">✗ No role assigned — contact your administrator.</p>
{% endif %}
<a href="/logout">Logout</a>
"""


def _msal():
    return msal.ConfidentialClientApplication(
        CLIENT_ID, authority=AUTHORITY, client_credential=CLIENT_SECRET
    )


@app.route("/")
def index():
    if "user" not in session:
        return redirect(url_for("login"))
    user = session["user"]
    return render_template_string(
        _PAGE,
        name=user.get("name") or user.get("preferred_username", "unknown"),
        roles=user.get("roles", []),
    )


@app.route("/login")
def login():
    flow = _msal().initiate_auth_code_flow(SCOPE, redirect_uri=REDIRECT_URI)
    session["flow"] = flow
    return redirect(flow["auth_uri"])


@app.route("/auth/callback")
def auth_callback():
    result = _msal().acquire_token_by_auth_code_flow(
        session.get("flow", {}), request.args
    )
    if "error" in result:
        return f"Login error: {result.get('error_description', result['error'])}", 400
    # id_token_claims contains the roles claim injected by Entra ID
    session["user"] = result["id_token_claims"]
    return redirect(url_for("index"))


@app.route("/logout")
def logout():
    session.clear()
    post_logout = url_for("index", _external=True)
    return redirect(f"{AUTHORITY}/oauth2/v2.0/logout?post_logout_redirect_uri={post_logout}")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
