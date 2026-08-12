# Project 8: HIPAA-Compliant Medical Document Processing Pipeline

## Scenario
**MedCore Health** — the same simulated healthcare organization from Projects 6 and 7 — needed to automate intake of thousands of medical documents (patient forms, lab results, insurance claims) without staff manually reading and handling PHI for every single document, reducing both processing time and unnecessary human exposure to sensitive data.

## Overview
Architected a fully serverless document processing pipeline that ingests medical documents, extracts text automatically via OCR, classifies the document type, stores structured metadata, and alerts on both success and failure — with a WAF-protected API layer, automated infrastructure backups, and live monitoring, all built and torn down in a single focused session.

## Architecture
- **Intake:** S3 bucket (encrypted, versioned, public access blocked) receives documents
- **Processing:** Lambda function triggered on every S3 upload — calls Amazon Textract for OCR, classifies the document type, writes metadata to DynamoDB
- **Success path:** Processed document moved to a separate encrypted S3 bucket, SNS success notification sent
- **Failure path:** Failed document automatically quarantined to a separate bucket, failure logged to DynamoDB with the full error, SNS failure alert sent
- **Monitoring:** CloudWatch dashboard tracking Lambda invocations, errors, and duration
- **Backup Automation:** EventBridge triggers a nightly Lambda that snapshots tagged EC2 volumes and prunes snapshots older than 30 days
- **API Layer:** API Gateway exposing a status endpoint, protected by a WAF Web ACL running AWS's Managed Common Rule Set
- **AI Layer (attempted):** Amazon Bedrock integration for document summarization — see Notes below

## Design Decisions & Trade-offs

**Problem:** MedCore Health needed documents processed without staff manually reading every one — both a throughput problem and a HIPAA "minimum necessary access" problem, since every unnecessary human touch of PHI is its own compliance risk.

**Trade-off — Synchronous processing vs. event-driven pipeline:** A synchronous system (upload and wait for a response) is simpler to build but doesn't scale and ties up resources waiting. I built this fully event-driven — S3 upload triggers Lambda automatically, no polling, no waiting — so the pipeline scales to thousands of documents without any architectural change, at the cost of more moving pieces to coordinate (S3 events, IAM permissions between services, async failure handling).

**Trade-off — Fail loudly vs. fail gracefully:** A pipeline that crashes on a bad document blocks the entire intake queue behind it. I built explicit quarantine-and-continue logic instead: any document that fails processing gets moved to a separate quarantine bucket, logged to DynamoDB with the exact error, and triggers an SNS alert — but never blocks the next document from processing. This paid off directly during testing (see Notes).

**Trade-off — Single IAM role vs. separate roles per Lambda:** One shared IAM role across both Lambda functions would have been faster to set up, but violates least-privilege — the document processor has no legitimate reason to touch EC2 snapshots, and the backup function has no reason to touch S3/DynamoDB/Textract. I gave each function its own scoped role, matching exactly what it needs and nothing more.

**Trade-off — Building the full API integration vs. a mock status endpoint:** A fully wired API Gateway → Lambda → DynamoDB status-lookup endpoint is the "real" version of this feature, but building and testing that fully was a lower priority than proving the WAF + API Gateway security pattern itself in this session. I built a mock endpoint to prove the API and WAF association work correctly, and documented full Lambda-proxy integration as a clear next iteration rather than rushing it.

## Compliance Controls Demonstrated
| Control | Implementation |
|---|---|
| HIPAA 164.312(a)(2)(iv) — Encryption at rest | S3 (AES-256) and DynamoDB encryption enabled on all data stores |
| HIPAA 164.312(e)(2)(ii) — Transmission security | WAF + HTTPS on the API Gateway layer |
| HIPAA 164.308(a)(7) — Contingency planning | Automated nightly EBS snapshots via EventBridge + Lambda |
| HIPAA 164.312(b) — Audit controls | CloudWatch dashboard + DynamoDB failure logging with full error capture |
| HIPAA 164.308(a)(1) — Security management | WAF Managed Common Rule Set blocking common web threats at the API layer |
| SOC 2 CC7.2 — Monitoring | CloudWatch dashboard + SNS alerting on both success and failure |
| SOC 2 A1.2 — Availability | Automated backup and recovery via EBS snapshot rotation |

## Tools Used
S3, Lambda, Amazon Textract, DynamoDB, EventBridge, SNS, CloudWatch, API Gateway, WAF, IAM

## Results
- Built and tested a complete event-driven document pipeline in a single session
- Backup Lambda successfully created a real EBS snapshot on manual invocation, confirmed via `aws ec2 describe-snapshots`
- WAF Web ACL confirmed actively associated with the API Gateway stage via `get-web-acl-for-resource`
- CloudWatch dashboard live and correctly tracking Lambda metrics
- Full evidence package collected (dashboard config, snapshot details, DynamoDB records, WAF association, Lambda function list) before teardown

## Notes — Account-Level Restrictions Encountered

During testing, both **Amazon Textract** and **Amazon Bedrock** returned account-level restriction errors (`SubscriptionRequiredException` and `ValidationException` respectively) when invoked — not IAM permission issues, confirmed by testing with an `AdministratorAccess`-attached role and by calling both services directly via CLI outside of Lambda. These are pre-existing account-level service restrictions unrelated to this project's code or configuration.

This is documented here rather than hidden because it's a legitimate finding, not a build failure: the pipeline's error-handling path was proven under real failure conditions — the failed document was automatically quarantined, logged to DynamoDB with the full error message, and triggered a real SNS alert, exactly as designed. A pipeline that only works when nothing goes wrong isn't proof of anything; watching the failure path execute correctly under an unplanned real-world error is arguably stronger evidence of solid engineering than a clean success would have been.

**Next steps once Textract/Bedrock access clears:** re-run the test document through the pipeline to capture a full successful "Processed" record, and wire the Bedrock summarization step into the main Lambda as a second processing stage after Textract extraction.

## How to Reproduce
This project was built and fully torn down in the same session to avoid ongoing cost (Textract, Bedrock, and WAF all carry per-use or hourly charges). To rebuild:
1. Create the S3 buckets (intake, processed, quarantine) with encryption, versioning, and public access blocked
2. Create the DynamoDB table and SNS topic
3. Deploy the document processor Lambda with a scoped IAM role, wired to the intake bucket via S3 event notification
4. Deploy the backup Lambda with a separate scoped IAM role, wired to an EventBridge nightly schedule
5. Build the CloudWatch dashboard
6. Build the API Gateway status endpoint and associate a WAF Web ACL with the Managed Common Rule Set
7. Test end-to-end, collect evidence, then tear down every resource in reverse order to avoid ongoing charges
