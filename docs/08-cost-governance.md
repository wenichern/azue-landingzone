# Lesson 8 — Cost governance

Cost control = **visibility** (who spends what) + **guardrails** (what may be built) + **alerts** (when to react) + **optimisation**.

## 1. Visibility: tags
Require `costCenter` on every resource group (policy, lesson 6) and **inherit** it to resources (Modify policy).
Then Cost Management can group/split by tag. Tags only apply from the moment they're set — they aren't retroactive.

## 2. Guardrails
- **Allowed locations** (also a data-residency control).
- Restrict expensive SKUs with a built-in "Allowed virtual machine size SKUs" policy.
- Daily ingestion cap on Log Analytics (`daily_quota_gb`).
- Keep firewall / gateways as toggles in non-prod.

## 3. Alerts (`modules/cost`)
`azurerm_consumption_budget_subscription` with:
- Actual spend at 50 %, 80 %, 100 %
- **Forecasted** spend at 100 % (an early warning, days before you breach)

> A budget **notifies**; it doesn't stop spend. To act, point the budget at an **action group** that triggers an
> automation (Logic App / Function / runbook) that deallocates VMs or removes the firewall. Gate this carefully.

## 4. Optimisation habits
Right-size (Azure Advisor), auto-shutdown dev VMs, reservations/savings plans for steady workloads,
delete orphaned disks/IPs, review Azure Hybrid Benefit, and review the **FinOps** monthly.

## Do it
1. Set `monthly_budget = 20` and apply. Portal → Cost Management → Budgets.
2. Cost analysis → *Group by tag: costCenter*.
3. Estimate the firewall's share: Standard ≈ hourly fee + data processing. Compare with a $20 budget. What would you do?

## Exercises
- Add a **resource-group-level** budget for each spoke (`azurerm_consumption_budget_resource_group`).
- Export cost data to storage on a schedule (`azurerm_subscription_cost_management_export`).
- Add an Advisor alert for cost recommendations (activity-log alert category `Recommendation`).
