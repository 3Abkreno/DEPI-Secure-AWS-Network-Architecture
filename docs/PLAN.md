# Execution plan

Seven phases, in order. A phase starts only when the previous phase's exit criteria are met. Build spending stops at 72 USD; 28 USD is reserved for rehearsal and presentation. Prices are approximate.

## People and targets

| Person | Responsibility | Stacks | Target |
|---|---|---|---|
| 1 | Network core, tech lead, repo and CI | 10-network, 30-transit | Whole environment builds with `up.sh` and tears down with `down.sh` with no manual step; Dev → Prod blocked at the TGW |
| 2 | Firewall and WAF | 70-inspection, WAF rules | All inter-VPC and internet-bound traffic passes through the firewall and is logged; SQLi gets 403 |
| 3 | Hybrid connectivity, account security, budget | 00-bootstrap, 40-hybrid | On-prem reaches Prod over a two-tunnel VPN, one tunnel down causes no outage; spending never passes 72 USD |
| 4 | Edge and application | 20-prod-app, 50-edge | Site opens through CloudFront only; direct ALB and S3 access refused |
| 5 | Monitoring, IR, documentation | 60-monitoring, RDS | Saved evidence for each of the 8 tests; IR drill done; final report delivered |

Reviewers: 1←5, 2←4, 3←1, 4←2, 5←3.

## Budget per phase

| Phase | Running | ~USD/hour | Hours | Cap (USD) |
|---|---|---|---|---|
| 0 Setup | short service checks | <0.10 | few | 2 |
| 1 Prod core | ALB, 2 EC2, RDS, SSM endpoints | 0.12 | 50 | 7 |
| 2 TGW + hybrid | + TGW (4 attachments), VPN, on-prem; Client VPN 1 h | 0.40 | 55 | 24 |
| 3 Edge | app stack only; edge on Free plan | 0.12 | 45 | 6 |
| 4 Monitoring | app stack + sensor; TGW for some sessions | 0.15–0.45 | 40 | 12 |
| 5 Firewall | everything, 5 attachments | 0.50 | 25 | 13 |
| 6 Final test | everything + Client VPN | 0.60 | 13 | 8 |
| 7 Presentation | 2 rehearsals + presentation day + buffer | 0.60 | 12 | 28 |

Cumulative checkpoints: after phase 1 < 9, phase 2 < 33, phase 3 < 39, phase 4 < 51, phase 5 < 64, phase 6 ≤ 72.

## Steps

`[n]` is the step number, followed by the owner.

### Phase 0: Setup

- [1] all: install Git, VS Code, AWS CLI v2, Terraform (same version for everyone).
- [2] all: VS Code extensions: HashiCorp Terraform, AWS Toolkit, GitHub Pull Requests; format on save.
- [3] P3: root MFA; AWS Budgets cost budget of 72 USD with alerts at 20/40/60/72 USD to all five emails; record credit balance and Free plan end date in `docs/hours.md`.
- [4] P3: complete the "Explore AWS" credit activities (20 USD each, max 100); delete what they create.
- [5] P3: IAM group `engineers`, users `person1..5`; each person sets their own MFA and CLI access key.
- [6] all: `aws configure --profile secure-net`; verify with `aws sts get-caller-identity`.
- [7] P3: confirm TGW, Client VPN, Site-to-Site VPN and Traffic Mirroring are usable on the Free plan (create and delete immediately); record the result in the README.
- [8] P1: create the private GitHub repo, collaborators, branch protection on `main`, secret scanning.
- [9] P1: repo skeleton, `.gitignore`, `CODEOWNERS` (this starter kit).
- [10] P3: apply `00-bootstrap` (state bucket).
- [11] P1: provider/backend template per stack with `default_tags`.
- [12] P1: CI workflow.
- [13] all: learn the daily loop: branch → code → fmt/validate/plan → PR → merge → owner applies from `main`.
- [14] P1: supervisor approval for Linux firewall instead of FortiGate.
- [15] P2: draft nftables + Suricata config on a local VM; `docs/firewall-design.md`.
- [16] P4: decide domain vs default CloudFront name; try the CloudFront flat-rate Free plan.
- [17] P5: templates: `docs/tests.md`, `docs/hours.md`, `docs/report.md`.

Exit: all five ran `terraform plan` successfully; first PR merged through CI; supervisor approved; service check recorded.

### Phase 1: Prod core

- [18] P1: Prod VPC and 8 subnets.
- [19] P1: IGW, route tables, S3 gateway endpoint. No NAT.
- [20] P1: SG chain alb → app → db.
- [21] P1: NACL on db subnets.
- [22] P3: SSM interface endpoints (one AZ) and instance role/profile.
- [23] P4: launch template, ASG (2 × t3.micro, nginx), ALB, target group, listener.
- [24] P5: RDS MySQL db.t3.micro, Single-AZ, `var.db_multi_az`; capture Multi-AZ failover evidence once.
- [25] P5: Flow Logs to S3.
- [26] P2: security review of SGs/NACLs; `scripts/connectivity-tests.sh`.
- [27] P1: `scripts/up.sh`, `scripts/down.sh`.
- [28] all: evidence in `docs/evidence/phase1/`; `down.sh`; P3 runs `check-running.sh` and logs hours.

Exit: site loads from the ALB; access is SSM only; DB reachable only from the app tier.

### Phase 2: TGW and hybrid

Write, review and pass CI on all code before turning the TGW on. Run it in short agreed sessions.

- [29] P1: Dev and Shared VPCs with a test instance each.
- [30] P1: TGW and VPC attachments.
- [31] P1: TGW route tables and blackholes.
- [32] P1: VPC routes to the TGW (in `30-transit`). Evidence: Dev → Prod blocked at TGW.
- [33] P3: simulated on-prem VPC, strongSwan + FRR instance.
- [34] P3: customer gateway, VPN connection to TGW, tunnel configuration (manual values).
- [35] P3: tests: on-prem → Prod; one tunnel down.
- [36] P3: Client VPN for one hour, then disable.
- [37] P3: Partner VPC peering; Partner → Dev fails.
- [38] P4: endpoints / PrivateLink in Shared.
- [39] P5: Flow Logs on Dev and Shared; record 4 tests in `docs/tests.md`.
- [40] P2: write `70-inspection` code and open the PR. No apply.
- [41] all: `down.sh`, check, log hours.

Exit: tests 2 (TGW half), 3, 4, 7 pass and are recorded; TGW and VPN destroyed.

### Phase 3: Edge

TGW stays off.

- [42] P4: static S3 bucket + OAC.
- [43] P4: CloudFront distribution (ALB + S3 origins, secret header).
- [44] P4: lock the ALB to CloudFront (prefix list + header rule, default 403). Evidence: test 5.
- [45] P2: WAF Count → Block; `docs/ddos-plan.md`. Evidence: test 6.
- [46] P1: origin-group failover to a static S3 page.
- [47] P3: IAM least-privilege review; fix or justify checkov findings; set `soft_fail: false`.
- [48] P5: WAF and CloudFront logs; evidence; `down.sh`.

Exit: site opens through CloudFront only; SQLi blocked and logged.

### Phase 4: Monitoring and detection

- [49] P5: Athena table and saved queries.
- [50] P5: SNS topic, CloudWatch alarms, dashboard.
- [51] P3: Suricata sensor and Traffic Mirroring session.
- [52] P2: `local.rules` (Dev→Prod, SQLi, DNS tunneling, C2 ports).
- [53] P1: `quarantine-sg` and `docs/runbooks/quarantine.md`.
- [54] P4: `scripts/attack-sim.sh` against the project's own site only.
- [55] P5: detection use-case table with owners; `down.sh`.

Exit: at least one alarm fired for real; Suricata logged an alert.

### Phase 5: Firewall (last build step)

- [56] P2: Inspection VPC, subnets, route tables.
- [57] P2: firewall instance, two ENIs, EIP.
- [58] P2: sysctl, static routes, nftables.
- [59] P2: Suricata on the firewall (IDS).
- [60] P1: inspection attachment (appliance mode), rt-inspection, spoke default routes, `inspection_enabled`.
- [61] P2 + P5: tests 1, 2 (firewall half), 8, and east-west with real source IP.
- [62] P3, P4: re-run VPN and edge tests; `down.sh` removes `70-inspection` cleanly.

Exit: all 8 tests have passed at least once.

### Phase 6: Final test, IR drill, report

- [63] P1: full build from scratch, timed.
- [64] all: screen-record all 8 tests; P5 updates `docs/tests.md`.
- [65] P5 leads: IR drill → `docs/ir-drill.md` (timeline, evidence, lessons). Delete the snapshot afterwards.
- [66] P2 `docs/ha-design.md`; P3 `docs/budget.md`; P4 updates the slides.
- [67] P5: final report.
- [68] P1: clean README, tag `v1.0`.

Exit: video recorded; report delivered; nothing billing; ≥ 28 USD of credit left.

### Phase 7: Rehearsal and presentation

- [69] all: rehearsal two days before, same order as the real day, including the fallback video.
- [70] all: presentation day: `up.sh` two hours before; live demo of tests 2, 5, 6; `down.sh` right after.
- [71] P3: clean-up: check nothing is billing, delete snapshots/log buckets, delete access keys.
