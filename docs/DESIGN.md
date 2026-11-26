# Design reference

Source: the team's project deck "Secure AWS Network Architecture & Hybrid Connectivity", adapted to the Free plan (Linux firewall instead of FortiGate, CloudFront flat-rate Free plan for the edge).

## Networks

| VPC | CIDR | Subnets |
|---|---|---|
| Prod | 10.10.0.0/16 | public 10.10.0.0/24, 10.10.1.0/24 · app 10.10.10.0/24, 10.10.11.0/24 · db 10.10.20.0/24, 10.10.21.0/24 · tgw 10.10.255.0/28, 10.10.255.16/28 |
| Dev | 10.20.0.0/16 | one private subnet + tgw subnets |
| Shared services | 10.0.0.0/16 | one private subnet + tgw subnets |
| Inspection (phase 5) | 10.200.0.0/16 | tgw 10.200.0.0/28, 10.200.0.16/28 · internal 10.200.1.0/24 · external 10.200.2.0/24 |
| Simulated on-prem | 172.16.0.0/16 | one public subnet |
| Partner (peering proof) | 192.168.0.0/16 | one subnet |
| Client VPN pool | 10.250.0.0/22 | n/a |

AZs: us-east-1a and us-east-1b. No NAT gateways anywhere. Private instances reach AWS APIs through endpoints (S3 gateway endpoint is free; SSM needs `ssm`, `ssmmessages`, `ec2messages` interface endpoints).

## Prod tiers

- ALB in public subnets → ASG of 2 × t3.micro (Amazon Linux 2023, nginx) in app subnets → RDS MySQL db.t3.micro in db subnets.
- SG chain: `alb-sg` → `app-sg` (80 from alb-sg only) → `db-sg` (3306 from app-sg only). SG rules reference SGs, not CIDRs. No SSH rule anywhere.
- NACL on db subnets: 3306 in from the two app subnets, ephemeral ports out to them, db↔db allowed, everything else denied.
- Admin access is SSM Session Manager only (`AmazonSSMManagedInstanceCore` on the instance role).

## Transit Gateway

`default_route_table_association = "disable"`, `default_route_table_propagation = "disable"`, ASN 64512.

Phase 2 (no firewall yet, spokes route directly):

| TGW route table | Associated with | Routes |
|---|---|---|
| rt-prod | att-prod | propagate Shared + VPN; blackhole 10.20.0.0/16 |
| rt-dev | att-dev | propagate Shared; blackhole 10.10.0.0/16 |
| rt-shared | att-shared, VPN attachment | propagate Prod, Dev, VPN |
| rt-inspection | (empty until phase 5) | n/a |

Phase 5 (inspection inserted), controlled by `var.inspection_enabled` in `30-transit`:

- Spoke tables (rt-prod, rt-dev, rt-shared): static `0.0.0.0/0` → att-inspection; direct spoke-to-spoke propagations removed; blackholes stay.
- rt-inspection: associated with att-inspection; propagations from Prod, Dev, Shared, VPN.
- att-inspection has `appliance_mode_support = "enable"`.
- App subnets in the spoke VPCs get `0.0.0.0/0` → TGW so internet egress goes through the firewall.

Dev → Prod must be blocked twice: by the TGW blackhole, and by the firewall when the blackhole is temporarily removed.

## Hybrid

- On-prem: t3.micro with an EIP, `source_dest_check = false`, strongSwan (IPsec) + FRR (BGP, ASN 65000).
- `aws_customer_gateway` + `aws_vpn_connection` to the TGW, `static_routes_only = false`, two tunnels.
- Tunnel values come from the console's "Download configuration" (strongSwan). That file holds pre-shared keys: never commit it.
- Client VPN: mutual-auth certificates (easy-rsa → ACM import), associated with a Shared subnet, behind `var.enable_client_vpn`.
- Partner VPC peers with Prod only. Proof: Partner reaches Prod, cannot reach Dev (peering is non-transitive).

## Edge

Path: user → CloudFront (+ WAF) → ALB → app. The firewall is not in the inbound path.

- CloudFront distribution: origin `alb` (custom header `X-Origin-Verify` = `random_password`), origin `s3` (OAC, bucket fully private), `/static/*` → s3, default → origin group `alb` with failover to `s3` on 502/503/504.
- ALB lock-down: SG ingress only from managed prefix list `com.amazonaws.global.cloudfront.origin-facing`; listener rule forwards only when `X-Origin-Verify` matches; default action is fixed-response 403.
- WAF (`scope = "CLOUDFRONT"`): AWS managed SQLi, Common and KnownBadInputs rule groups + a rate-based rule. Start in Count, then switch to Block.
- Pricing: use the CloudFront flat-rate Free plan (bundles WAF, DDoS protection, DNS, TLS). It limits the number of WAF rules. If the Terraform provider cannot set the plan, it is set in the console and noted in the README.
- No custom domain is required: the default `*.cloudfront.net` name and certificate are enough. With a domain, add ACM (us-east-1) and switch the ALB origin to HTTPS.
- Shield Standard only. The DDoS plan is a document (`docs/ddos-plan.md`).

## Monitoring

- VPC Flow Logs (ALL traffic) to S3 for every VPC; Athena table over them; saved queries in `stacks/60-monitoring/queries/`.
- CloudWatch alarms → SNS email: WAF BlockedRequests spike, ALB target 5xx, UnHealthyHostCount, VPN TunnelState, RDS CPU. One dashboard.
- Suricata sensor (t3.small) receiving Traffic Mirroring (VXLAN, UDP 4789) from an app ENI. Custom rules in `stacks/60-monitoring/rules/local.rules`, reused on the firewall.
- IR: `quarantine-sg` (no rules at all) + `docs/runbooks/quarantine.md` (swap SG, detach from ASG, snapshot, timeline).

## Linux firewall (phase 5, last build step)

One t3.small, Amazon Linux 2023, two ENIs, `source_dest_check = false` on both, EIP on the external ENI. Managed through SSM only.

Inspection VPC route tables:

| Subnet | Route |
|---|---|
| tgw-a, tgw-b | 0.0.0.0/0 → firewall internal ENI |
| internal | 10.0.0.0/8 and 172.16.0.0/16 → TGW |
| external | 0.0.0.0/0 → Internet gateway |

Host config (in `user_data`):

- sysctl: `net.ipv4.ip_forward = 1`, `net.ipv4.conf.all.send_redirects = 0`, `net.ipv4.conf.all.rp_filter = 2`.
- Static routes: 10.0.0.0/8 and 172.16.0.0/16 via the internal subnet gateway (10.200.1.1) on the internal interface; must survive reboot.
- nftables, `forward` chain policy **drop**:
  - accept established/related
  - drop + log `FW-DENY dev-to-prod` (10.20.0.0/16 → 10.10.0.0/16) and the reverse
  - accept + log `FW-EW` for internal → internal (east-west, **no NAT**, real source IP preserved)
  - accept + log `FW-EGRESS` for internal → external on tcp 80/443
  - log `FW-DENY default`
- nftables nat: `masquerade` only on traffic leaving the external interface from 10.0.0.0/8 or 172.16.0.0/16 (SNAT for egress).
- Suricata in IDS mode (af-packet) on the internal interface with `local.rules`. IPS via NFQUEUE is optional, only if time and credit remain.

HA for the firewall is a design document only (`docs/ha-design.md`); a second firewall is over budget.

## The 8 acceptance tests

| # | Test | Expected | Owner |
|---|---|---|---|
| 1 | Prod → internet | `curl https://checkip.amazonaws.com` returns the firewall EIP (SNAT) | 2 |
| 2 | Dev → Prod | blocked by TGW blackhole; blocked again by firewall when blackhole removed | 1, 2 |
| 3 | On-prem → Prod over VPN | succeeds | 3 |
| 4 | Partner → Dev | fails | 3 |
| 5 | Direct to S3 / ALB | 403 / refused | 4 |
| 6 | SQLi / exploit | 403 from WAF, visible in WAF logs | 2, 4 |
| 7 | One VPN tunnel down | no outage | 3 |
| 8 | Firewall stopped | site still loads through CloudFront (east-west and egress stop; say so in the report) | 2 |
