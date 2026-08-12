# Project 6: HIPAA & FedRAMP Gap Assessment

## Scenario
**MedCore Health** — a simulated healthcare organization requiring a pre-migration compliance assessment before moving any workloads to AWS. This assessment is the first phase of a two-part engagement; see Project 7 for the migration that followed.

## Overview
Led a full compliance gap assessment against a live AWS environment, evaluating controls against HIPAA and FedRAMP requirements, identifying gaps, implementing remediations, and producing a complete audit-ready evidence package — the kind of deliverable a compliance-focused engagement would expect on day one.

## Process
1. **Scoping** — defined assessment boundary and applicable control set
2. **Control Evaluation** — assessed **25 controls** across identity, network, data, and logging domains
3. **Gap Identification** — found **11 gaps**, including **6 critical findings**
4. **Remediation** — implemented fixes for identified gaps directly in the live environment
5. **Evidence Collection** — produced a 9-piece evidence package for external audit review

## Design Decisions & Trade-offs

**Problem:** MedCore Health needed to know, before any migration work began, exactly where their environment fell short of HIPAA and FedRAMP requirements — moving workloads first and assessing compliance afterward would risk migrating sensitive data into a non-compliant environment.

**Trade-off — Assess-then-fix vs. fix-as-you-go:** Fixing issues as they're discovered feels faster in the moment, but without a full scoped assessment first, it's easy to miss systemic gaps that only show up when controls are evaluated together. I ran the full 25-control evaluation before starting remediation — slower up front, but it surfaced the complete picture (11 gaps, 6 critical) rather than a partial one, and produced a real baseline to measure remediation against.

**Trade-off — Remediate everything vs. prioritize by severity:** With 11 gaps found, fixing them all with equal urgency wastes effort on low-risk items while critical ones wait. I prioritized the 6 critical findings for immediate remediation and documented the remaining lower-severity gaps with recommended timelines — a real audit engagement almost never has unlimited time to fix everything at once, so prioritization itself is part of the deliverable.

## Evidence Package Contents
- `gap_assessment.md` — full gap analysis with control-by-control findings
- `final_report.md` — executive summary and remediation summary
- `evidence_security_groups.json` — security group configuration evidence
- `evidence_iam_users.json` — IAM user and MFA status evidence
- `evidence_cloudtrail.json` — audit logging configuration evidence
- `evidence_rds.json` — database encryption and access evidence
- `evidence_scanner_report.txt` — supporting output from the Project 5 compliance scanner

## Tools Used
AWS Console/CLI, boto3 (via Project 5 scanner), IAM, CloudTrail, RDS, Security Groups

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| HIPAA | Full technical safeguard assessment (access control, audit controls, encryption) |
| FedRAMP | Control-by-control evaluation aligned to FedRAMP baseline requirements |

## Impact
Delivered a complete, audit-ready evidence package from a live environment — scoped, assessed, remediated, and documented — demonstrating the full lifecycle of a compliance engagement rather than just a point-in-time scan.

## Notes
This project pairs directly with Project 5 (the scanner supplies evidence) and Project 7 (the migration project this assessment gated before go-live in a simulated healthcare environment).
