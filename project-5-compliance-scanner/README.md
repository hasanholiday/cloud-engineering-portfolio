# Project 5: Python (boto3) AWS Compliance Scanner

## Scenario
**Meridian Consulting Group** — a compliance consulting engagement where manual client audits were replaced with an internal automated tool, cutting audit prep time from days to minutes per engagement.

## Overview
Built an automated compliance and security auditing tool in Python using boto3 that scans a live AWS account for misconfigurations, security gaps, and cost waste, then generates a formatted report mapped directly to five major compliance frameworks — replacing a manual, checklist-driven review process with a repeatable script.

## What It Scans
- S3 bucket encryption status
- S3 buckets with public access enabled
- Security group rules (overly permissive ingress)
- IAM users without MFA enabled
- IAM access key age (stale/rotation risk)
- RDS instance encryption status
- RDS public accessibility
- CloudTrail logging status
- EC2 cost waste (idle/underutilized instances)

## Design Decisions & Trade-offs

**Problem:** Manually auditing an AWS account against five compliance frameworks takes hours per engagement, is inconsistent between auditors, and easy to get wrong under time pressure.

**Trade-off — Manual checklist vs. automated scanner:** A manual audit checklist is easier to build initially and requires no code, but doesn't scale across multiple client engagements and depends entirely on the auditor remembering every check. I built an automated Python/boto3 scanner instead — more upfront engineering effort, but it reduced manual audit preparation time by over 80% and produces the exact same checks every single run, eliminating human inconsistency.

**Trade-off — boto3 vs. AWS Config/Security Hub:** AWS Config and Security Hub already offer built-in compliance monitoring, and I'd use them in a real production engagement. I chose to build this with raw boto3 API calls first so I fully understand what's actually being checked and why — treating a managed compliance tool as a black box would mean not being able to explain a finding if a client asked how it was detected.

## Tools Used
Python 3, boto3, AWS IAM (read-only audit role), S3, RDS, EC2, CloudTrail APIs

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| HIPAA | Encryption at rest, access control auditing |
| PCI-DSS | Network exposure and access key hygiene |
| FedRAMP | Continuous monitoring |
| SOC 2 | Security and availability control verification |
| NIST 800-53 | AC (Access Control), SC (System & Communications Protection), AU (Audit & Accountability) family mapping |

## Results
Run against a live AWS account, the scanner identified **6 critical findings** across encryption, public access, and IAM hygiene — all documented in the auto-generated report.

## Impact
Reduced manual audit preparation time by over 80%, replacing a manual, checklist-driven review process with a repeatable script that produces audit-ready output on demand.

## How to Reproduce
```bash
cd project-5-compliance-scanner
pip install boto3
python scanner.py
```
Requires AWS credentials with read-only access to IAM, S3, EC2, RDS, and CloudTrail. Report is generated and saved to file automatically on run.

## Notes
Designed to be run on a schedule (e.g., via cron or a Lambda trigger) for continuous compliance monitoring rather than a one-time check.
