# Lesson 2 — Management groups & subscriptions

## Concepts
Scope hierarchy: **Tenant root → Management groups → Subscriptions → Resource groups → Resources.**
Policy and RBAC assigned at a scope **inherit downward**. So design the tree around *what
governance different workloads need*, not your org chart.

```
lz (root)                    ← baseline policy, global RBAC readers
├─ platform                  ← network/identity/mgmt teams
│  ├─ connectivity           ← hub VNet, firewall, DNS (own subscription in prod)
│  ├─ identity               ← domain controllers etc.
│  └─ management             ← logging, automation, monitoring
├─ landing-zones
│  ├─ corp                   ← private workloads: no public IPs
│  └─ online                 ← internet-facing workloads
├─ sandbox                   ← experimentation, relaxed policy
└─ decommissioned            ← parked subs, deny-all
```

Rules of thumb: ≤ 3–4 levels deep; **subscriptions are the unit of scale and isolation**
(quota, RBAC boundary, billing); one environment tier per subscription in real life.

**This lab uses one subscription** to keep costs/complexity low, so hub, logging and spokes share it.
In production put connectivity, management, identity and each app in separate subscriptions
(see lesson 10).

## Code tour
`modules/management-groups` creates the tree and `azurerm_management_group_subscription_association`
places the subscription. `var.subscription_mg` chooses where (default `sandbox`).

## Do it
```bash
terraform apply -target=module.management_groups   # first time only
az account management-group list -o table
az account management-group show -n lz-corp --expand --recurse
```

## Exercise
Set `subscription_mg = "corp"` — don't apply yet. Read lesson 6, predict what breaks when the firewall
(needs a public IP) is deployed, then apply and confirm.
