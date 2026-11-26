# Secure AWS Network Architecture & Hybrid Connectivity

Graduation-style lab project built by a team of 5 with Terraform, driven from VS Code and the AWS CLI, in this GitHub repo.

**Talk to the team in Egyptian Arabic.** Keep code, comments, file names and commit messages in English.

Read `docs/PLAN.md` (who does what, in what order) and `docs/DESIGN.md` (CIDRs, route tables, firewall config) before writing code.

## Hard constraints: never break these

1. **Budget is 100 USD of AWS credit, total, on the AWS Free account plan.** There is no payment method to fall back on. If credit reaches zero the account is suspended and the project is lost.
   - Build spending stops at 72 USD. The last 28 USD is reserved for the rehearsal and the final presentation.
   - Each phase has its own cap (see `docs/PLAN.md`).
2. **Never run `terraform apply` or `terraform destroy`, or any AWS CLI command that creates, changes or deletes resources, without the user explicitly asking for it in that message.** Writing code, `terraform fmt`, `terraform validate` and `terraform plan` are fine. Read-only `aws ... describe-*` / `list-*` commands are fine.
3. **Before any apply, state the hourly cost of what is about to start** and remind the user to log the session in `docs/hours.md` and to run `scripts/down.sh` afterwards.
4. **No AWS Marketplace products.** The Free plan blocks Marketplace, so no FortiGate, Sophos, Palo Alto, pfSense AMIs. The firewall is a plain Linux EC2 with nftables + Suricata.
5. **Never create these:** NAT gateways, Shield Advanced subscription, AWS Organizations / Control Tower (joining an Organization cancels the credits), Reserved Instances, Savings Plans, Network Firewall, anything bigger than t3.small / db.t3.micro.
6. **Never upgrade the account to the Paid plan** and never suggest it as a fix.
7. **No secrets in the repo.** No access keys, VPN pre-shared keys, `.pem`, `.ovpn`, `.tfvars` with secrets, or downloaded VPN config files. Passwords come from `manage_master_user_password` or `random_password`.
8. **Everything is Terraform.** Nothing is created by hand in the console except the few manual steps listed in `docs/PLAN.md` (root MFA, Budgets, IAM users, strongSwan tunnel values, CloudFront flat-rate plan if the provider cannot set it).
9. Region is **us-east-1** for everything.

## Cost-saving rules for the code

- RDS runs Single-AZ by default; `var.db_multi_az` flips it only for the failover evidence.
- Client VPN sits behind `var.enable_client_vpn` (default `false`); it is turned on for one hour only.
- SSM interface endpoints go in one AZ, and live in `20-prod-app` (destroyed nightly), not in `10-network`.
- Every `aws_db_instance` has `skip_final_snapshot = true`; every log bucket has `force_destroy = true`, so `destroy` always completes.
- `10-network` must contain only free resources (VPCs, subnets, route tables, IGW, SGs, NACLs, gateway endpoints). Anything billed per hour goes in a stack that `scripts/down.sh` destroys.
- Every stack uses `default_tags` (Project, Stack, ManagedBy).

## Repo layout

```
stacks/00-bootstrap    state bucket (local state, never destroyed)      owner: person 3
stacks/10-network      VPCs, subnets, routes, SGs, NACLs (free)          owner: person 1
stacks/20-prod-app     ALB, ASG, RDS, SSM endpoints                      owner: person 4 (+5 RDS, +3 endpoints)
stacks/30-transit      TGW, attachments, TGW route tables, blackhole     owner: person 1
stacks/40-hybrid       simulated on-prem, S2S VPN, Client VPN, peering   owner: person 3
stacks/50-edge         CloudFront, WAF, S3 OAC, ALB lock-down            owner: person 4 (+2 WAF)
stacks/60-monitoring   Flow Logs, Athena, CloudWatch, Suricata sensor    owner: person 5 (+3 mirroring)
stacks/70-inspection   Inspection VPC, Linux firewall, route flip (LAST) owner: person 2
modules/vpc            shared VPC module
scripts/up.sh          apply the stacks named on the command line
scripts/down.sh        destroy every paid stack, in reverse order
scripts/check-running.sh  list anything still billing
docs/                  plan, design, evidence, hours log, tests, report
```

Stack number = apply order. Destroy order is the reverse. Stacks read each other through `terraform_remote_state` (S3 backend). `70-inspection` is built last, in phase 5.

## Workflow

- Branch per task: `feat/<stack>-<short-name>`. No direct pushes to `main`.
- Before a PR: `terraform fmt -recursive`, then `terraform -chdir=stacks/<stack> validate` and `plan`.
- CI (`.github/workflows/terraform-ci.yml`) runs fmt, validate with `-backend=false`, and checkov. It has no AWS credentials, on purpose.
- Only the stack owner applies, only from `main`, after the PR is merged.
- Reviewers: 1←5, 2←4, 3←1, 4←2, 5←3.
- AWS CLI profile is `secure-net` (`export AWS_PROFILE=secure-net`).

## First-time setup of this repo

1. Account ID 091109216641 is already set in every `stacks/*/versions.tf`.
2. Replace `@person1..5` in `CODEOWNERS` with real GitHub usernames.
3. Person 3 applies `stacks/00-bootstrap` once.

## How to help

- When asked for a step, find it in `docs/PLAN.md`, check which person owns it and which phase it is in, and say so.
- Do not start a later phase's work while an earlier phase's exit criteria are unmet, unless the user says to.
- Explain each resource briefly in Arabic as you add it; the team is learning and must defend every line at the presentation.
- Prefer small, reviewable PR-sized changes over one large drop.
- If something in the design cannot work on the Free plan (a service is blocked), stop and say so instead of working around it with a paid alternative.
- Prices in the docs are approximate; do not present them as exact.
