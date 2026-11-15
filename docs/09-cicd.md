# Lesson 9 — CI/CD with GitHub Actions

Infrastructure changes should be **reviewed, planned, approved, applied** — never run from a laptop.

```
feature branch ─PR─▶ plan workflow (fmt · validate · Checkov · plan → PR comment)
                         │ review + approve
                         ▼
        merge to main ─▶ apply workflow ─▶ environment "production" (required reviewer) ─▶ apply
```

## Why it's secure
- `permissions: id-token: write` lets the job request an OIDC token. No `AZURE_CLIENT_SECRET` exists.
- Credentials are **scoped by subject**: PRs get the `pull_request` credential; apply only runs in `environment: production`.
- `concurrency` group prevents two applies fighting over state (blob lease also locks).
- Only non-secret IDs are stored as GitHub **variables** (not secrets).

## Set up
1. `terraform output -raw github_setup_commands | bash` (from `bootstrap/`).
2. Repo → Settings → **Environments** → create `production` → add yourself as *Required reviewer*.
3. Branch protection on `main`: require PR + passing `terraform-plan`.
4. Open a PR that flips `enforce_policy` default. Read the plan comment. Merge. Approve the deployment.

## Hardening ideas
- Pin actions by commit SHA; enable Dependabot for actions and Terraform providers.
- Make Checkov blocking (`soft_fail: false`) after triaging baseline findings; add `tflint` and `terraform-docs`.
- Separate pipelines/identities: *platform* (MGs, policy, hub) vs *workload* (spokes), each least-privileged.
- Add drift detection: scheduled `terraform plan -detailed-exitcode` that opens an issue on changes.
- Store the plan artifact and apply that exact plan (avoid plan/apply skew).
