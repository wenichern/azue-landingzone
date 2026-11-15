# Lesson 6 — Policy enforcement

**RBAC** answers *who can do what*. **Azure Policy** answers *what is allowed to exist* — regardless of who asks.

## Building blocks
- **Definition** — an `if / then` rule (built-in or custom) with an *effect*.
- **Initiative (policy set)** — a bundle of definitions managed as one unit.
- **Assignment** — applies a definition/initiative to a **scope** (MG, sub, RG).
- **Exemption** — a time-boxed, audited exception.
- **Effects:** `Audit`, `Deny`, `Modify`, `Append`, `DeployIfNotExists`, `AuditIfNotExists`, `Disabled`.

## What `modules/policy` does
| Policy | Scope | Effect |
|--------|-------|--------|
| *Landing Zone Baseline* initiative: allowed locations, require `costCenter` tag on RGs, secure transfer on storage, subnets must have NSG | root MG | Deny/Audit (`enforce_policy`) |
| Custom **deny public IPs** (`lz-deny-public-ip`) | `corp` MG | Deny/Audit |
| **Inherit `costCenter`** tag from RG | root MG | Modify (uses managed identity + Tag Contributor) |

The custom rule is only 8 lines — read `modules/policy/main.tf` to see how `effect` is parameterised so the
same definition can run in Audit first, then Deny.

## Safe rollout playbook
1. Assign with `enforce = false` (DoNotEnforce) or effect `Audit`.
2. Wait for compliance evaluation (≈30 min; trigger: `az policy state trigger-scan`).
3. Review non-compliant resources: portal → Policy → Compliance, or
   `az policy state list --filter "complianceState eq 'NonCompliant'" -o table`.
4. Remediate or exempt, then set `enforce = true`.

## Do it
```bash
terraform apply -var enforce_policy=false
az policy assignment list --scope /providers/Microsoft.Management/managementGroups/lz -o table
# now try to violate it:
az group create -n rg-test-bad -l westeurope --tags costCenter=x    # blocked once enforced: location
az group create -n rg-test-notag -l eastus2                         # blocked: missing tag
```
Then `-var enforce_policy=true` and retry. Look for the denial in Log Analytics (`PolicyDenies` saved search).

## Exercises
- Move the subscription to `corp` (`subscription_mg = "corp"`), enable the firewall — observe the public IP being denied. Fix with a Policy **exemption** for the firewall's PIP (`azurerm_management_group_policy_exemption`), not by weakening the rule.
- Add a built-in assignment: "Azure Backup should be enabled for Virtual Machines" (Audit).
- Research: use the **Microsoft Cloud Security Benchmark** initiative at the root MG in audit mode and read the findings.

## Pitfalls
- Policy denies hit *Terraform* too — roll out in audit mode, and create policy **after** the infrastructure it might block (see `depends_on` in `envs/lab/main.tf`).
- MG assignment names are limited to 24 characters.
- `DeployIfNotExists`/`Modify` need a managed identity **with roles** and an explicit remediation task for existing resources.
