# Lesson 4 — Network segmentation

Defence in depth: segment at several layers, deny by default at each.

| Layer | Tool | Scope | Implemented in |
|-------|------|-------|----------------|
| Macro | VNet per workload (hub-spoke) | spoke ↔ spoke | `spoke-network` |
| Perimeter/East-west | Azure Firewall policy | between spokes, to Internet | `hub-network` |
| Micro | NSG per subnet | tier ↔ tier | `spoke-network` |
| Paths | UDR 0.0.0.0/0 → firewall | forces inspection | `spoke-network` |
| PaaS | Private Endpoints + private DNS | no public data-plane | hub zones |

## NSGs: the default-allow trap
Azure NSG defaults include `AllowVnetInBound` (priority 65000) — *everything inside a VNet can talk*.
So `spoke-network` appends `deny-vnet-inbound-by-default` at **priority 4000** and
`deny-internet-inbound` at 4050. Your explicit allows (100–3999) win because **lower number = evaluated first**.

The default `app1` spoke implements a 3-tier pattern:
```
hub (10.0/22) ──443──▶ web 10.10.0.0/24 ──8080──▶ app 10.10.1.0/24 ──1433──▶ data 10.10.2.0/24
```
web cannot reach data directly; nothing else gets in.

## Firewall: spoke-to-spoke is denied
Azure Firewall is default-deny. Until you add a rule, app1 cannot reach app2 even though both peer to the hub.
`firewall_network_rules` (commented example in `envs/lab/main.tf`) opens exactly one flow.

## Do it
1. With the firewall on, apply. Check NSG rules: 
   `az network nsg rule list -g rg-app1-spoke --nsg-name nsg-app1-data -o table --include-default`
2. Uncomment the `app1-web-to-app2` rule; plan and read the diff; apply.
3. Query denials after generating some traffic: `kql/firewall-denies.kql`.

## Exercises
- Tighten `allowed_egress_fqdns`; which package repos does your workload really need?
- Add `Microsoft.Storage` Private Endpoint in `snet-data` using the hub's `privatelink.blob...` zone.
- Why is an NSG alone not enough? (No FQDN filtering, no threat intel, no central logging of flows, rules are per-subnet sprawl.)
- Why is a firewall alone not enough? (Intra-subnet and intra-tier east-west still needs NSGs; defence in depth.)

> Note: NSG **flow logs** are being retired in favour of **VNet flow logs**. Here NSGs send rule-event logs via
> diagnostic settings; add `azurerm_network_watcher_flow_log` targeting a VNet as an extension.
