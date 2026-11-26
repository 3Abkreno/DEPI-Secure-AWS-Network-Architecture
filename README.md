# Secure AWS Network Architecture & Hybrid Connectivity

Hub-and-spoke AWS network with centralized inspection, hybrid VPN connectivity, a CloudFront/WAF edge and full logging, built with Terraform by a team of five on the AWS Free plan (100 USD credit).

- Plan and ownership: [docs/PLAN.md](docs/PLAN.md)
- Design reference: [docs/DESIGN.md](docs/DESIGN.md)
- Rules for working with Claude Code: [CLAUDE.md](CLAUDE.md)

## First-time setup

1. Account ID `091109216641` is already set in `stacks/*/versions.tf`.
2. Replace `@person1..5` in `CODEOWNERS` with GitHub usernames.
3. Person 3: `terraform -chdir=stacks/00-bootstrap init && terraform -chdir=stacks/00-bootstrap apply`

## Daily use

```bash
export AWS_PROFILE=secure-net
scripts/up.sh 20-prod-app          # start what you need
# ... work ...
scripts/down.sh                    # ALWAYS, before you stop
scripts/check-running.sh           # nothing should be listed
```

Log every session in [docs/hours.md](docs/hours.md).

## Free-plan service check (phase 0, step 7)

| Service | Available on Free plan? |
|---|---|
| Transit Gateway | |
| Site-to-Site VPN | |
| Client VPN | |
| Traffic Mirroring | |

## Manual steps (not in Terraform)

- Root MFA, AWS Budgets alerts, IAM users
- strongSwan/FRR tunnel values from the downloaded VPN configuration
- CloudFront flat-rate Free plan, if the provider cannot set it
