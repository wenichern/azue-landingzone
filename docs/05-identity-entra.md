# Lesson 5 — Identity & Entra ID federation

"Federation" appears three different ways in a landing zone. Know which one you mean:

1. **Workload federation (machine → Azure).** GitHub/Kubernetes/other clouds exchange their OIDC token for an
   Entra token. *Built in lesson 1* (`azuread_application_federated_identity_credential`). Kills secrets.
2. **Workforce federation (human → Entra).** Your corporate IdP (AD FS, Okta, Ping, or on-prem AD via Entra Connect /
   Cloud Sync) authenticates users into Entra ID, which is the *only* IdP Azure trusts. Mostly tenant configuration
   (domain federation, SAML/WS-Fed, cross-tenant access). Prefer **Entra-native auth** (password-hash sync + SSO)
   over AD FS where possible. Terraform can manage parts (`azuread_*` resources), but the sync setup itself is not Terraform.
3. **Authorization (what can they do in Azure).** Entra identity → **group** → **Azure RBAC role at a management group**.

## The pattern in `modules/identity`
```
user ──member of──▶ Entra security group ──Azure RBAC role──▶ MG scope
```
- Never assign roles to individuals. Joiners/leavers are handled by group membership.
- **Active** assignments only for read/operate roles (Reader, Security Reader, Network Contributor on `platform`).
- **PIM eligible** assignments for privileged roles: the user *activates* for a few hours with MFA + justification,
  and activation is audited. (`enable_pim = true`, needs Entra ID P2.)
- **Conditional Access** requires MFA for admin groups. Starts as `enabledForReportingButNotEnforced` (report-only);
  review impact in Entra → Sign-in logs → *Conditional Access* tab, then set `enabled`.
- Exclude **break-glass** emergency accounts (cloud-only, long password, FIDO2, monitored) from every CA policy.

## Managed identities > service principals > secrets
Workloads should use **managed identities**; pipelines use **federated credentials**; client secrets are the last resort.

## Do it
1. `enable_identity = true` (default). Add yourself to a group:
   `members = ["<your object id>"]` — get it with `az ad signed-in-user show --query id -o tsv`.
2. `az role assignment list --assignee <group objectId> --all -o table`.
3. If you have P1: `enable_conditional_access = true`, apply, then examine report-only results.
4. If you have P2: `enable_pim = true`; activate the role in portal → *Privileged Identity Management → My roles*.

## Exercises
- Why must the Graph permissions in `bootstrap` need admin consent? 
- Create a `lz-online-contributors` group with Contributor on the `online` MG.
- Turn on `enable_entra_logs` and write a KQL query for failed sign-ins (`SigninLogs | where ResultType != 0`).
