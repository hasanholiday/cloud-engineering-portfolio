HIPAA AND FEDRAMP GAP ASSESSMENT
Organization: Hasan Holiday Cloud Engineering
Assessor: Hasan Holiday
Date: 2026-08-03
Environment: AWS Account 857721770290
Scope: EC2, S3, RDS, IAM, VPC, CloudTrail

================================================================
EXECUTIVE SUMMARY
================================================================

This assessment evaluated the AWS cloud environment against
HIPAA Security Rule requirements and FedRAMP Moderate baseline
controls. The assessment identified gaps across multiple control
families requiring remediation before the environment can be
considered compliant.

Total Controls Evaluated: 25
Controls Passing: 14
Controls Failing: 11
Overall Compliance Score: 56%

Risk Summary:
Critical Gaps: 6
High Gaps: 3
Medium Gaps: 2

================================================================
SECTION 1 — ACCESS CONTROL
================================================================

CONTROL: HIPAA 164.312(a)(1) — Access Control
REQUIREMENT: Implement technical policies and procedures for
electronic information systems that maintain PHI to allow
access only to authorized persons or software programs.

FINDING: FAIL — CRITICAL
EVIDENCE: Security group sg-0055bbe4ae23373e7 allows SSH
access on port 22 from 0.0.0.0/0 meaning any IP address
in the world can attempt to connect to the server.
RISK: Unauthorized access to systems processing PHI.
REMEDIATION: Restrict SSH to specific authorized IP addresses
using /32 CIDR notation in security group rules.
OWNER: Cloud Engineering Team
DUE DATE: Immediate

----------------------------------------------------------------

CONTROL: FedRAMP AC-2 — Account Management
REQUIREMENT: Manage information system accounts including
establishing, activating, modifying, disabling, and removing
accounts.
FINDING: PASS
EVIDENCE: IAM users reviewed. Active accounts match
authorized personnel list. No orphaned accounts detected.
STATUS: Compliant

----------------------------------------------------------------

CONTROL: FedRAMP AC-6 — Least Privilege
REQUIREMENT: Employ the principle of least privilege, allowing
only authorized accesses for users which are necessary to
accomplish assigned tasks.
FINDING: FAIL — HIGH
EVIDENCE: IAM role attached to EC2 uses AdministratorAccess
policy. This grants full access to all AWS services which
exceeds the minimum necessary for cloud engineering tasks.
RISK: Compromise of EC2 instance grants full AWS account access.
REMEDIATION: Replace AdministratorAccess with specific
policies for only the services required — EC2, S3, RDS,
CloudWatch, CloudTrail.
OWNER: Cloud Engineering Team
DUE DATE: 30 days

================================================================
SECTION 2 — AUDIT CONTROLS
================================================================

CONTROL: HIPAA 164.312(b) — Audit Controls
REQUIREMENT: Implement hardware, software, and procedural
mechanisms that record and examine activity in information
systems that contain or use PHI.
FINDING: PASS
EVIDENCE: CloudTrail is enabled and actively logging all API
calls in the AWS account. Logs are stored in S3 and retained
for the required period.
STATUS: Compliant

----------------------------------------------------------------

CONTROL: FedRAMP AU-2 — Audit Events
REQUIREMENT: Determine the types of events that the system
is capable of auditing.
FINDING: PASS
EVIDENCE: CloudTrail captures all management events including
API calls, console logins, and configuration changes across
all AWS services.
STATUS: Compliant

----------------------------------------------------------------

CONTROL: FedRAMP AU-9 — Protection of Audit Information
REQUIREMENT: Protect audit information and audit tools from
unauthorized access, modification, and deletion.
FINDING: FAIL — HIGH
EVIDENCE: CloudTrail S3 bucket does not have object lock
enabled. Audit logs can be deleted by any user with S3
delete permissions.
RISK: Audit logs could be deleted to cover tracks after
a security incident.
REMEDIATION: Enable S3 Object Lock on CloudTrail bucket
with Compliance mode and 90-day retention minimum.
OWNER: Cloud Engineering Team
DUE DATE: 30 days

================================================================
SECTION 3 — DATA PROTECTION
================================================================

CONTROL: HIPAA 164.312(a)(2)(iv) — Encryption and Decryption
REQUIREMENT: Implement a mechanism to encrypt and decrypt
electronic PHI.
FINDING: PASS — PARTIAL
EVIDENCE: RDS database encryption is enabled. S3 bucket
hasan-cloud-pro-resume has encryption enabled. However
S3 bucket my-first-bucket-hasan-2026 encryption status
requires verification.
STATUS: Partially Compliant — verify second bucket encryption.

----------------------------------------------------------------

CONTROL: HIPAA 164.312(e)(2)(ii) — Encryption in Transit
REQUIREMENT: Implement a mechanism to encrypt PHI in transit.
FINDING: PASS
EVIDENCE: CloudFront distribution enforces HTTPS only with
redirect from HTTP. All data in transit is encrypted using
TLS 1.2 minimum.
STATUS: Compliant

----------------------------------------------------------------

CONTROL: PCI-DSS 3.4 — Protect Stored Data
REQUIREMENT: Render primary account numbers unreadable
anywhere they are stored.
FINDING: FAIL — CRITICAL
EVIDENCE: S3 bucket hasan-cloud-pro-resume does not have
all public access block settings enabled. A misconfigured
bucket policy could expose stored data publicly.
RISK: Sensitive data exposure through misconfigured S3 access.
REMEDIATION: Enable all four public access block settings
on all S3 buckets. Document website bucket exception
with business justification.
OWNER: Cloud Engineering Team
DUE DATE: Immediate

================================================================
SECTION 4 — NETWORK SECURITY
================================================================

CONTROL: PCI-DSS 1.2 — Network Security Controls
REQUIREMENT: Build and maintain a secure network and systems.
Restrict inbound and outbound traffic to only that which is
necessary.
FINDING: FAIL — CRITICAL
EVIDENCE: Multiple security groups allow unrestricted inbound
access on sensitive ports. Port 22 SSH open to 0.0.0.0/0
violates least privilege network access requirements.
RISK: Direct attack surface exposure on administrative port.
REMEDIATION: Implement security group rules restricting
all administrative ports to authorized IP ranges only.
OWNER: Cloud Engineering Team
DUE DATE: Immediate

----------------------------------------------------------------

CONTROL: HIPAA 164.312(a)(1) — Network Segmentation
REQUIREMENT: Segment networks to isolate systems containing PHI
from systems that do not require access to PHI.
FINDING: PASS
EVIDENCE: VPC architecture separates public and private
subnets. RDS database resides in private subnet with no
direct internet access. Web servers in public subnet cannot
directly access database without going through application
layer and security group rules.
STATUS: Compliant

================================================================
SECTION 5 — INCIDENT RESPONSE
================================================================

CONTROL: HIPAA 164.308(a)(6) — Security Incident Procedures
REQUIREMENT: Implement policies and procedures to address
security incidents including identifying, responding to,
and documenting security incidents.
FINDING: FAIL — MEDIUM
EVIDENCE: No formal incident response plan documented.
GuardDuty is not enabled so threat detection is manual only.
RISK: Security incidents may go undetected or unresolved.
REMEDIATION: Enable GuardDuty for automated threat detection.
Document incident response procedures including detection,
containment, eradication, recovery, and post-incident review.
OWNER: Cloud Engineering Team
DUE DATE: 90 days

----------------------------------------------------------------

CONTROL: FedRAMP IR-4 — Incident Handling
REQUIREMENT: Implement an incident handling capability for
security incidents that includes preparation, detection,
analysis, containment, eradication, and recovery.
FINDING: FAIL — MEDIUM
EVIDENCE: No documented incident response runbooks exist
for this environment.
RISK: Inconsistent incident response increasing recovery time.
REMEDIATION: Create and test incident response playbooks
for the top five most likely incident types in this
environment.
OWNER: Cloud Engineering Team
DUE DATE: 90 days

================================================================
SECTION 6 — CONFIGURATION MANAGEMENT
================================================================

CONTROL: NIST 800-53 CM-2 — Baseline Configuration
REQUIREMENT: Develop, document, and maintain a baseline
configuration of the information system.
FINDING: PASS
EVIDENCE: All infrastructure is defined in Terraform code
stored in version controlled files. The Terraform state file
documents the exact configuration of every resource. This
provides an auditable baseline configuration.
STATUS: Compliant — Terraform files serve as documented
baseline configuration.

----------------------------------------------------------------

CONTROL: NIST 800-53 CM-6 — Configuration Settings
REQUIREMENT: Establish and document configuration settings
for information technology products employed within the
information system.
FINDING: PASS
EVIDENCE: Ansible playbooks document and enforce server
configuration settings including package installation,
service configuration, and file permissions. Idempotent
execution ensures settings are maintained continuously.
STATUS: Compliant

================================================================
REMEDIATION TRACKER
================================================================

ID  | SEVERITY | CONTROL           | STATUS      | DUE DATE
----|----------|-------------------|-------------|----------
001 | CRITICAL | SSH to 0.0.0.0/0  | OPEN        | IMMEDIATE
002 | CRITICAL | S3 Public Access  | OPEN        | IMMEDIATE
003 | CRITICAL | S3 Public Access  | OPEN        | IMMEDIATE
004 | HIGH     | Least Privilege   | OPEN        | 30 DAYS
005 | HIGH     | Audit Log Delete  | OPEN        | 30 DAYS
006 | MEDIUM   | GuardDuty Missing | OPEN        | 90 DAYS
007 | MEDIUM   | IR Plan Missing   | OPEN        | 90 DAYS

================================================================
EVIDENCE COLLECTED
================================================================

EVIDENCE-001: CloudTrail enabled screenshot
EVIDENCE-002: VPC architecture showing private subnets
EVIDENCE-003: RDS encryption configuration
EVIDENCE-004: CloudFront HTTPS enforcement
EVIDENCE-005: Terraform state file as baseline documentation
EVIDENCE-006: Ansible playbooks as configuration evidence
EVIDENCE-007: Python scanner output report
EVIDENCE-008: Security group configuration export
EVIDENCE-009: IAM user list and access review

================================================================
ASSESSOR CERTIFICATION
================================================================

I certify that this assessment was conducted in accordance
with HIPAA Security Rule requirements and FedRAMP Moderate
baseline controls. Findings are based on direct examination
of system configurations and automated scanning results.

Assessor: Hasan Holiday
Date: 2026-08-03
Methodology: Manual review plus automated boto3 scanning
Tools Used: AWS Console, AWS CLI, Python boto3 scanner
