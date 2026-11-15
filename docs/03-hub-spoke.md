# Lesson 3 — Hub-spoke architecture

## Concepts
**Hub**: one VNet owning *shared* services — firewall, DNS, (VPN/ExpressRoute gateway, Bastion).
**Spokes**: one VNet per workload, peered only to the hub.

Why: central egress/inspection, shared services paid once, blast-radius isolation per workload,
and spokes never need to know about each other.

```
            Internet / on-prem
                   │
            ┌──────▼───────┐
            │  HUB 10.0/22 │  Azure Firewall · Private DNS · (gateway)
            └──┬────────┬──┘
     peering   │        │   peering
     ┌─────────▼─┐    ┌─▼─────────┐
     │ app1 10.10│    │ app2 10.20│     spoke ↔ spoke is NOT automatic:
     └───────────┘    └───────────┘     peering is non-transitive
```

Key facts:
- **Peering is non-transitive and two-sided.** Both `spoke_to_hub` and `hub_to_spoke` are created in `spoke-network`.
- `allow_forwarded_traffic = true` lets traffic that the firewall forwards arrive from another spoke.
- `use_remote_gateways` / `allow_gateway_transit` are for hub VPN/ExpressRoute gateways (off here).
- Address spaces **must not overlap**, now or with on-prem. Plan IPAM early (this lab: hub 10.0/22, spokes 10.10/22, 10.20/24).
- **Private DNS zones** (`privatelink.*`) sit in the hub and are linked to every VNet so Private Endpoints resolve the same everywhere.

## Do it
1. Apply with `deploy_firewall = false` — free. Inspect peering state: both sides must say `Connected`.
   ```bash
   az network vnet peering list -g rg-lz-lab-hub --vnet-name vnet-lz-lab-hub -o table
   ```
2. Set `deploy_firewall = true`, apply (~10 min). The spoke module now adds a route table with `0.0.0.0/0 → firewall`.
3. See effective routes (needs a VM/NIC; deploy a tiny one in `snet-workload` if you want): 
   `az network nic show-effective-route-table`.

⚠️ **Destroy the firewall when done** (`deploy_firewall = false` + apply).

## Exercise
Add a third spoke `app3` in `variables.tf` defaults. Confirm: new RG, VNet, NSGs, two peerings, DNS links — with no module changes.
