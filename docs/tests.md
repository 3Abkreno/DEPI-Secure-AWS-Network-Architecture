# Acceptance tests: control → test → proof

| # | Control | Test | Expected | Result | Evidence file | Owner | Date |
|---|---|---|---|---|---|---|---|
| 1 | Centralized egress with SNAT | Prod → internet | Firewall EIP seen | | | 2 | |
| 2 | Segmentation (TGW blackhole + firewall) | Dev → Prod | Blocked twice | | | 1, 2 | |
| 3 | Hybrid connectivity | On-prem → Prod via VPN | Succeeds | | | 3 | |
| 4 | Non-transitive peering | Partner → Dev | Fails | | | 3 | |
| 5 | Origin protection | Direct S3 / ALB | Refused | | | 4 | |
| 6 | WAF | SQLi / exploit | 403, logged | | | 2, 4 | |
| 7 | VPN redundancy | One tunnel down | No outage | | | 3 | |
| 8 | Inbound independent of firewall | Firewall stopped | Site stays up | | | 2 | |
