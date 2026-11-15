# Lesson 7 — Logging & monitoring

## Concepts
Azure emits three telemetry planes:
| Plane | What | Where it goes |
|-------|------|---------------|
| **Activity log** | control-plane ops (who created/deleted/changed) per subscription | diagnostic setting → LAW |
| **Resource logs** | data-plane events (firewall rules hit, NSG events, Key Vault reads) | diagnostic setting on **each resource** → LAW |
| **Metrics** | numeric time-series (CPU, throughput) | Azure Monitor metrics store |
| **Entra logs** | sign-ins, audits | Entra diagnostic setting → LAW |

Resources send **nothing** by default — you must configure *diagnostic settings*. That's why the modules wire them:
- `logging`: Activity Log → central LAW (+ optional Entra logs); 30-day retention; **daily cap 1 GB** as a cost guard.
- `hub-network`: firewall `allLogs` → LAW (resource-specific tables like `AZFWNetworkRule`).
- `spoke-network`: every NSG `allLogs` → LAW.

> Scale tip: enforce diagnostic settings with `DeployIfNotExists` policy (built-in "Configure … to send logs to Log Analytics") so new resources are covered automatically.

## Alerts (`modules/monitoring`)
- Action group → email (extend with Teams/webhook/ITSM).
- **Activity-log alerts**: role assignment written; NSG rule written; Service Health incidents. These catch *drift and privilege changes*.
- **Log-query alert**: >100 firewall denies in 5 minutes (only when firewall is deployed).

## Do it
In Log Analytics → Logs, run the files in `kql/`. Then provoke events:
```bash
az role assignment create --assignee <some group id> --role Reader --scope /subscriptions/<id>/resourceGroups/rg-app1-spoke
# → email within minutes, and:
```
```kusto
AzureActivity | where OperationNameValue =~ "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE" | top 5 by TimeGenerated
```

## Exercises
- Check ingestion cost: `Usage | where TimeGenerated > ago(7d) | summarize GB=sum(Quantity)/1024 by DataType | order by GB desc`.
- Add a Basic Logs / lower-retention table plan for chatty firewall data.
- Add Microsoft Sentinel on the workspace (`azurerm_sentinel_log_analytics_workspace_onboarding`) and enable the Azure Activity connector.
- Add an Azure Workbook for "network health".
