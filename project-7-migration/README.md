# Project 7: On-Premises to AWS Migration — MedCore Health (Simulation)

## Scenario
**MedCore Health** — a simulated healthcare provider — needed to migrate three core systems off on-premises infrastructure onto AWS while maintaining HIPAA-appropriate security posture throughout. This migration is the second phase of a two-part engagement, following the HIPAA/FedRAMP gap assessment in Project 6 that scoped the compliance requirements before any workloads moved.

## Overview
Designed and executed a full simulated migration of a healthcare organization's on-premises infrastructure to AWS, following the **6R migration framework**. Both the legacy on-prem and target AWS environments were run simultaneously to validate a real-world cutover, not just a lift-and-shift on paper.

## Migration Approach (6R Framework)
| System | Strategy | Target |
|---|---|---|
| Web server | **Rehost** | Auto Scaling Group behind an Application Load Balancer |
| MySQL database | **Replatform** | RDS, encrypted at rest, deployed in private subnets |
| File server | **Refactor** | S3 with versioning enabled and AES-256 encryption |

## Design Decisions & Trade-offs

**Problem:** MedCore Health needed to move off on-premises infrastructure without a "big bang" cutover that risks downtime or data loss for a healthcare system where availability and data integrity both matter.

**Trade-off — Rehost vs. replatform vs. refactor, per system:** Not every system deserved the same migration strategy. The web server was rehosted (lift-and-shift into an Auto Scaling Group) because it needed minimal architectural change to benefit from AWS's elasticity. The database was replatformed to RDS — same MySQL engine, but now AWS manages patching and failover, a middle-ground choice that improves operations without a full rewrite. File storage was refactored to S3 with versioning and encryption because the old file server's architecture didn't map cleanly to any AWS service — this one required an actual redesign, not just a lift-and-shift, to get real benefit.

**Trade-off — Big-bang cutover vs. parallel run:** Switching everything over in one event is faster to execute but means any problem is discovered *after* the business depends on the new environment. I ran both the on-prem and AWS environments simultaneously before cutover — more operational overhead maintaining two environments temporarily, but it let me validate the new environment behaved identically before any real dependency shifted, which matters enormously for a healthcare system.

**Trade-off — Cost savings vs. migration risk:** The 6R approach chosen here optimizes for a ~95% projected cost reduction, but the more aggressive the re-architecture (refactor > replatform > rehost), the more testing and risk it introduces. I matched the migration strategy to each system's actual risk tolerance rather than refactoring everything for maximum savings — the file server could absorb refactor risk since it wasn't the core patient-data system; the database took the more conservative replatform path given its sensitivity.

## Tools Used
Terraform, Ansible, AWS (EC2, ASG, ALB, RDS, S3), DNS

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| HIPAA | Encrypted data at rest and in transit throughout migration, private subnet isolation for the database tier |
| SOC 2 | Documented, auditable migration and cutover process |

## Impact
Achieved a projected **95% cost reduction** versus maintaining on-premises infrastructure, with a complete migration evidence package (discovery, cutover plan, migration report) suitable for stakeholder and audit review.

## How to Reproduce
```bash
cd project-7-migration
terraform init
terraform plan -var-file="aws_target.tfvars"
terraform apply
```
See `discovery.md` for the full source environment inventory and `onprem.tf` for the simulated legacy environment definition.

## Notes
This project ties together every prior project's skills — Terraform provisioning (Project 1), automation patterns (Project 3), and compliance mapping (Projects 5 & 6) — into a single end-to-end migration narrative, which is the strongest single artifact for interviews.
