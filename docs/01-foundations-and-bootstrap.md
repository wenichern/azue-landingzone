# Lesson 1 — Foundations, remote state & OIDC bootstrap

## Concepts
A **landing zone** is a pre-governed environment: networking, identity, policy, logging and
cost controls exist *before* workloads arrive. Azure's reference is the Cloud Adoption
Framework "Azure Landing Zones" (ALZ). Eight design areas: billing/tenant, identity,
network, resource organization, security, management, governance, platform automation.
This lab covers the technical core of each.

Two problems to solve before any infrastructure:

1. **Where does Terraform keep state?** In an Azure Storage blob container (versioned, private,
   AAD-authenticated) so teams and pipelines share one source of truth, with blob-lease locking.
2. **How does the pipeline authenticate?** With **workload identity federation**. GitHub issues a
   short-lived OIDC token per job; Entra ID trusts it because of a *federated credential*
   whose `subject` matches `repo:ORG/REPO:environment:production`. No client secret to leak or rotate.

```
GitHub job ──OIDC JWT──▶ Entra ID ──checks issuer+subject+audience──▶ access token ──▶ ARM / Graph
```

## What `bootstrap/` builds
- Resource group + GRS storage account (TLS1.2, versioning, 14-day soft delete) + `tfstate` container.
- Entra **application + service principal** for the pipeline.
- Two **federated credentials**: one for the `production` environment (apply), one for pull requests (plan).
- RBAC: Contributor on the subscription, Blob Data Contributor on state, and (toggle) three roles
  at the **tenant root management group** so the pipeline can create MGs, policy and role assignments.
- Microsoft Graph application permissions so the pipeline can manage groups/Conditional Access.

> ⚠️ **Trade-off:** `Role Based Access Control Administrator` at the tenant root is very powerful.
> In production, split pipelines (platform vs workload), scope to your own root MG after creating
> it, and use ABAC conditions to limit which roles can be assigned.

## Do it
Follow *Quick start* in the README. Then inspect:
```bash
az ad app federated-credential list --id <pipeline_client_id> -o table
az role assignment list --assignee <pipeline_client_id> --all -o table
```

## Check yourself
- Why does the PR credential exist separately from the environment credential? (Hint: PRs from forks/branches
  shouldn't be able to *apply*; only the protected environment can.)
- What happens if someone changes the `subject` to `repo:ORG/*`? (Entra doesn't allow wildcards — and you wouldn't want them.)

## Exercise
Add a second environment `staging` to `github_environments`, re-apply, and find the new credential in the portal.
