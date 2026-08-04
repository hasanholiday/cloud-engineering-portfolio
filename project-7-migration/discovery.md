MEDCORE HEALTH — CLOUD MIGRATION DISCOVERY DOCUMENT
Assessor: Hasan Holiday
Date: 2026-08-03

================================================================
CURRENT STATE — ON PREMISES INVENTORY
================================================================

SERVER 1 — Web Server
Name: medcore-web-01
OS: Amazon Linux 2023
CPU: 2 vCPU
RAM: 4GB
Storage: 50GB
Application: Apache HTTP Server
Purpose: Patient portal web application
Uptime Requirement: 99.9% — critical system
Dependencies: MySQL database on medcore-db-01
Compliance: HIPAA — handles PHI

SERVER 2 — Database Server
Name: medcore-db-01
OS: Amazon Linux 2023
CPU: 4 vCPU
RAM: 8GB
Storage: 200GB
Application: MySQL 8.0
Purpose: Patient records database
Uptime Requirement: 99.99% — critical system
Dependencies: None
Compliance: HIPAA — stores PHI directly

SERVER 3 — File Server
Name: medcore-files-01
OS: Amazon Linux 2023
CPU: 2 vCPU
RAM: 4GB
Storage: 500GB
Application: File storage
Purpose: Medical documents and reports
Uptime Requirement: 99.5%
Dependencies: None
Compliance: HIPAA — stores PHI directly

================================================================
6R MIGRATION DECISIONS
================================================================

Web Server — REPLATFORM
Reason: Move to EC2 with Auto Scaling Group and Load Balancer
for improved availability and automatic scaling
Benefit: Zero downtime, auto healing, cost optimization

Database — REPLATFORM
Reason: Move from self-managed MySQL to AWS RDS MySQL
Benefit: Automated backups, Multi-AZ, managed patches,
encryption at rest, automated failover

File Server — REFACTOR
Reason: Replace file server with S3
Benefit: 99.999999999% durability, versioning, encryption,
lifecycle policies, massive cost reduction

================================================================
MIGRATION RISK ASSESSMENT
================================================================

Risk 1 — Data loss during migration
Likelihood: Low
Impact: Critical
Mitigation: Full backup before migration, parallel run period

Risk 2 — Application downtime
Likelihood: Medium
Impact: High
Mitigation: Blue-green deployment, DNS cutover strategy

Risk 3 — Compliance gap post-migration
Likelihood: Low
Impact: Critical
Mitigation: Run compliance scanner before go-live

Risk 4 — Performance degradation
Likelihood: Low
Impact: Medium
Mitigation: Load testing in new environment before cutover

================================================================
SUCCESS CRITERIA
================================================================

All patient data migrated with zero data loss
Application available 99.9% measured over 30 days
All HIPAA controls validated before go-live
RTO less than 4 hours if rollback required
RPO less than 1 hour — backup within 1 hour of cutover
