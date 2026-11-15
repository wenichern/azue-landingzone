# Lesson 10 — Next steps & production gaps

This lab deliberately simplifies. A production Azure Landing Zone adds:

| Area | Lab | Production |
|------|-----|-----------|
| Subscriptions | one | connectivity, identity, management, + 1 per app/env (**subscription vending** via `azurerm_subscription` / EA/MCA alias) |
| Hub | VNet + optional firewall | + VPN/ExpressRoute gateway, Bastion, DNS Private Resolver, Firewall Premium (IDPS/TLS), or **Virtual WAN** |
| Regions | one | paired hub per region, global peering / vWAN |
| Policy | small baseline | full ALZ policy set (MCSB, DINE for diagnostics, Defender for Cloud plans, backup, tagging) |
| Identity | groups + CA + PIM | access reviews, entitlement management, break-glass monitoring, Entra-joined admin workstations (PAW) |
| Security | – | Defender for Cloud, Sentinel, Key Vault + CMK, Private Link everywhere, DDoS Protection |
| IaC | one stack | layered state files, private module registry, versioned modules, Azure Verified Modules (AVM) |
| Ops | email alerts | ITSM integration, runbooks, SLOs, DR/backup policy |

## Recommended reading / tooling
- Microsoft **Azure Landing Zones** docs & the **ALZ Terraform accelerator** / `Azure/avm-ptn-alz` module — compare their design with yours.
- **Azure Verified Modules (AVM)** for Terraform — reuse instead of writing modules from scratch.
- Cloud Adoption Framework → *Ready* and *Govern* methodologies.
- Azure Well-Architected Framework (cost, security, reliability, ops, performance).

## Capstone ideas
1. Split the repo into `platform` and `workloads` stacks with separate state and pipeline identities.
2. Add subscription vending: a module taking `{name, mg, budget, owners}` and creating a subscription + budget + RBAC + spoke.
3. Add a VPN gateway with a point-to-site config and `use_remote_gateways` on spokes.
4. Write a policy initiative mapping to a compliance framework you care about, and report on compliance in a workbook.
5. Add Defender for Cloud plans and Sentinel with analytics rules for risky role-assignment changes.

## Final cleanup checklist
- [ ] `deploy_firewall = false` and applied (or full `terraform destroy`)
- [ ] Management groups removed (subscription moved out first)
- [ ] `bootstrap` destroyed, GitHub variables removed
- [ ] Root-scope elevated access removed:
  `az role assignment delete --assignee <you> --role "User Access Administrator" --scope "/"`
