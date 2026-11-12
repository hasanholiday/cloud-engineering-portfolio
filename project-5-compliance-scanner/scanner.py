import boto3
import json
from datetime import datetime, timezone, timedelta

import os

HOME_REGION = 'us-east-1'


def build_session():
    """Use the default credentials, or assume a read-only audit role if ASSUME_ROLE_ARN is set.

    Env vars: ASSUME_ROLE_ARN (cross-account role), EXTERNAL_ID (optional, for client roles).
    """
    role_arn = os.environ.get('ASSUME_ROLE_ARN')
    if not role_arn:
        return boto3.Session()
    params = {'RoleArn': role_arn, 'RoleSessionName': 'compliance-scan', 'DurationSeconds': 3600}
    if os.environ.get('EXTERNAL_ID'):
        params['ExternalId'] = os.environ['EXTERNAL_ID']
    creds = boto3.client('sts').assume_role(**params)['Credentials']
    print(f"Assumed role: {role_arn}")
    return boto3.Session(
        aws_access_key_id=creds['AccessKeyId'],
        aws_secret_access_key=creds['SecretAccessKey'],
        aws_session_token=creds['SessionToken'],
    )


session = build_session()

# Global services (not region-specific)
s3_client = session.client('s3', region_name=HOME_REGION)
iam_client = session.client('iam')
cloudtrail_client = session.client('cloudtrail', region_name=HOME_REGION)  # returns trails from all regions

# Regional clients are set per region in main loop
ec2_client = rds_client = cw_client = None
current_region = HOME_REGION


def get_regions():
    """REGIONS env var (comma list) or every region enabled for the account."""
    if os.environ.get('REGIONS'):
        return [r.strip() for r in os.environ['REGIONS'].split(',') if r.strip()]
    ec2 = session.client('ec2', region_name=HOME_REGION)
    return sorted(r['RegionName'] for r in ec2.describe_regions()['Regions'])


def set_region(region):
    global ec2_client, rds_client, cw_client, current_region
    current_region = region
    ec2_client = session.client('ec2', region_name=region)
    rds_client = session.client('rds', region_name=region)
    cw_client = session.client('cloudwatch', region_name=region)


findings = []
passed = 0
failed = 0

def add_finding(resource, check, status, framework, severity, remediation=""):
    global passed, failed
    findings.append({
        'resource': resource,
        'check': check,
        'status': status,
        'framework': framework,
        'severity': severity,
        'remediation': remediation
    })
    if status == 'PASS':
        passed += 1
    else:
        failed += 1

# ============================================
# S3 CHECKS
# ============================================
def check_s3():
    print("Scanning S3 buckets...")
    try:
        buckets = s3_client.list_buckets()['Buckets']
        if not buckets:
            print("  No S3 buckets found")
            return

        for bucket in buckets:
            name = bucket['Name']

            # Check encryption
            try:
                s3_client.get_bucket_encryption(Bucket=name)
                add_finding(name, 'S3 Encryption at Rest', 'PASS',
                           'HIPAA 164.312(a)(2)(iv)', 'LOW')
            except:
                add_finding(name, 'S3 Encryption at Rest', 'FAIL',
                           'HIPAA 164.312(a)(2)(iv)', 'HIGH',
                           'Enable S3 default encryption with AES-256 or KMS')

            # Check public access
            try:
                public_access = s3_client.get_public_access_block(Bucket=name)
                config = public_access['PublicAccessBlockConfiguration']
                if all([
                    config.get('BlockPublicAcls', False),
                    config.get('BlockPublicPolicy', False),
                    config.get('IgnorePublicAcls', False),
                    config.get('RestrictPublicBuckets', False)
                ]):
                    add_finding(name, 'S3 Public Access Blocked', 'PASS',
                               'PCI-DSS 1.3', 'LOW')
                else:
                    add_finding(name, 'S3 Public Access Blocked', 'FAIL',
                               'PCI-DSS 1.3', 'CRITICAL',
                               'Enable all public access block settings on S3 bucket')
            except:
                add_finding(name, 'S3 Public Access Blocked', 'FAIL',
                           'PCI-DSS 1.3', 'CRITICAL',
                           'Enable S3 public access block settings')

    except Exception as e:
        print(f"  S3 scan error: {e}")

# ============================================
# SECURITY GROUP CHECKS
# ============================================
def check_security_groups():
    print("Scanning security groups...")
    try:
        sgs = ec2_client.describe_security_groups()['SecurityGroups']
        dangerous_ports = [22, 3389, 3306, 5432, 6379, 27017]

        for sg in sgs:
            sg_id = sg['GroupId']
            sg_name = sg.get('GroupName', 'unnamed')

            for rule in sg.get('IpPermissions', []):
                all_traffic = rule.get('IpProtocol') == '-1'
                from_port = rule.get('FromPort', 0)
                to_port = rule.get('ToPort', 65535 if all_traffic else 0)

                for ip_range in rule.get('IpRanges', []):
                    if ip_range.get('CidrIp') != '0.0.0.0/0':
                        continue
                    label = f"{current_region}:{sg_id} ({sg_name})"
                    # Which dangerous ports fall inside this rule's range (handles 0-65535 and all-traffic)?
                    exposed = [p for p in dangerous_ports if from_port <= p <= to_port]
                    if exposed:
                        add_finding(
                            label,
                            f"Ports {', '.join(str(p) for p in exposed)} Open to World",
                            'FAIL',
                            'PCI-DSS 1.2 | HIPAA 164.312(a)(1)',
                            'CRITICAL',
                            f"Restrict ports {', '.join(str(p) for p in exposed)} to specific IP addresses only"
                        )
                    else:
                        add_finding(label, f'Port {from_port}-{to_port} Open to World', 'PASS',
                                    'PCI-DSS 1.2', 'LOW')

    except Exception as e:
        print(f"  Security group scan error: {e}")

# ============================================
# IAM CHECKS
# ============================================
def check_iam():
    print("Scanning IAM users...")
    try:
        users = iam_client.list_users()['Users']

        if not users:
            print("  No IAM users found")
            return

        for user in users:
            username = user['UserName']

            # Check MFA
            try:
                mfa_devices = iam_client.list_mfa_devices(UserName=username)['MFADevices']
                if mfa_devices:
                    add_finding(username, 'MFA Enabled', 'PASS',
                               'HIPAA 164.312(d) | FedRAMP IA-2', 'LOW')
                else:
                    add_finding(username, 'MFA Enabled', 'FAIL',
                               'HIPAA 164.312(d) | FedRAMP IA-2', 'HIGH',
                               f'Enable MFA for IAM user {username} immediately')
            except Exception as e:
                print(f"  MFA check error for {username}: {e}")

            # Check access key age
            try:
                keys = iam_client.list_access_keys(UserName=username)['AccessKeyMetadata']
                for key in keys:
                    if key['Status'] == 'Active':
                        created = key['CreateDate']
                        age_days = (datetime.now(timezone.utc) - created).days
                        if age_days > 90:
                            add_finding(
                                username,
                                f'Access Key Age {age_days} days',
                                'FAIL',
                                'NIST 800-53 IA-5 | SOC2 CC6.1',
                                'HIGH',
                                f'Rotate access key for {username} — key is {age_days} days old'
                            )
                        else:
                            add_finding(
                                username,
                                f'Access Key Age {age_days} days',
                                'PASS',
                                'NIST 800-53 IA-5 | SOC2 CC6.1',
                                'LOW'
                            )
            except Exception as e:
                print(f"  Access key check error for {username}: {e}")

    except Exception as e:
        print(f"  IAM scan error: {e}")

# ============================================
# RDS CHECKS
# ============================================
def check_rds():
    print("Scanning RDS instances...")
    try:
        instances = rds_client.describe_db_instances()['DBInstances']

        if not instances:
            print("  No RDS instances found")
            return

        for db in instances:
            db_id = f"{current_region}:{db['DBInstanceIdentifier']}"

            # Check encryption
            if db.get('StorageEncrypted', False):
                add_finding(db_id, 'RDS Encryption at Rest', 'PASS',
                           'HIPAA 164.312(a)(2)(iv)', 'LOW')
            else:
                add_finding(db_id, 'RDS Encryption at Rest', 'FAIL',
                           'HIPAA 164.312(a)(2)(iv)', 'CRITICAL',
                           'Enable RDS encryption — requires creating new encrypted instance')

            # Check public accessibility
            if db.get('PubliclyAccessible', True):
                add_finding(db_id, 'RDS Not Publicly Accessible', 'FAIL',
                           'PCI-DSS 1.3 | HIPAA 164.312(a)(1)', 'CRITICAL',
                           'Disable public accessibility on RDS instance immediately')
            else:
                add_finding(db_id, 'RDS Not Publicly Accessible', 'PASS',
                           'PCI-DSS 1.3 | HIPAA 164.312(a)(1)', 'LOW')

            # Check Multi-AZ
            if db.get('MultiAZ', False):
                add_finding(db_id, 'RDS Multi-AZ Enabled', 'PASS',
                           'SOC2 A1.2', 'LOW')
            else:
                add_finding(db_id, 'RDS Multi-AZ Enabled', 'FAIL',
                           'SOC2 A1.2', 'MEDIUM',
                           'Enable Multi-AZ for high availability and disaster recovery')

    except Exception as e:
        print(f"  RDS scan error: {e}")

# ============================================
# CLOUDTRAIL CHECKS
# ============================================
def check_cloudtrail():
    print("Scanning CloudTrail...")
    try:
        trails = cloudtrail_client.describe_trails()['trailList']

        if not trails:
            add_finding('CloudTrail', 'CloudTrail Enabled', 'FAIL',
                       'FedRAMP AU-2 | HIPAA 164.312(b) | SOC2 CC7.2', 'CRITICAL',
                       'Enable CloudTrail immediately — required for all compliance frameworks')
            return

        for trail in trails:
            trail_name = trail['Name']
            add_finding(trail_name, 'CloudTrail Enabled', 'PASS',
                       'FedRAMP AU-2 | HIPAA 164.312(b) | SOC2 CC7.2', 'LOW')

            # Check if logging is active
            try:
                status = cloudtrail_client.get_trail_status(Name=trail['TrailARN'])
                if status.get('IsLogging', False):
                    add_finding(trail_name, 'CloudTrail Logging Active', 'PASS',
                               'FedRAMP AU-2', 'LOW')
                else:
                    add_finding(trail_name, 'CloudTrail Logging Active', 'FAIL',
                               'FedRAMP AU-2', 'HIGH',
                               'Start CloudTrail logging — currently paused')
            except Exception as e:
                print(f"  CloudTrail status error: {e}")

    except Exception as e:
        print(f"  CloudTrail scan error: {e}")

# ============================================
# EC2 COST WASTE CHECKS
# ============================================
def average_cpu(instance_id, days=7):
    """Average CPU % over the last N days, or None if CloudWatch has no data."""
    now = datetime.now(timezone.utc)
    points = cw_client.get_metric_statistics(
        Namespace='AWS/EC2', MetricName='CPUUtilization',
        Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
        StartTime=now - timedelta(days=days), EndTime=now,
        Period=3600, Statistics=['Average'],
    )['Datapoints']
    if not points:
        return None
    return sum(p['Average'] for p in points) / len(points)


def check_cost_waste():
    print(f"Scanning for cost waste in {current_region}...")
    try:
        paginator = ec2_client.get_paginator('describe_instances')
        for page in paginator.paginate():
            for reservation in page['Reservations']:
                for instance in reservation['Instances']:
                    state = instance['State']['Name']
                    instance_id = instance['InstanceId']
                    label = f"{current_region}:{instance_id} ({instance['InstanceType']})"

                    if state == 'stopped':
                        add_finding(label, 'Stopped EC2 Instance — EBS Still Billing', 'FAIL',
                                    'SOC2 CC9.1 Cost Management', 'MEDIUM',
                                    f'Terminate {instance_id} if no longer needed to stop EBS charges')
                    elif state == 'running':
                        cpu = average_cpu(instance_id)
                        if cpu is None:
                            continue  # new instance or no metrics yet; not enough evidence
                        if cpu < 5:
                            add_finding(label, f'Idle EC2 Instance (avg CPU {cpu:.1f}% over 7 days)', 'FAIL',
                                        'SOC2 CC9.1 Cost Management', 'MEDIUM',
                                        f'Review {instance_id}: stop, downsize, or terminate if unused')
                        else:
                            add_finding(label, f'EC2 Instance In Use (avg CPU {cpu:.1f}%)', 'PASS',
                                        'SOC2 CC9.1', 'LOW')
    except Exception as e:
        print(f"  Cost waste scan error in {current_region}: {e}")

# ============================================
# GENERATE REPORT
# ============================================
def generate_report():
    print("\n")
    print("=" * 60)
    print("   COMPLIANCE AND SECURITY SCAN REPORT")
    print("   Hasan Holiday — Cloud Engineering Portfolio")
    print(f"   Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    print(f"\nSUMMARY")
    print(f"Total Checks: {passed + failed}")
    print(f"Passed:       {passed}")
    print(f"Failed:       {failed}")
    if passed + failed > 0:
        score = int((passed / (passed + failed)) * 100)
        print(f"Score:        {score}%")

    print(f"\nFRAMEWORKS COVERED")
    print("  HIPAA 164.312 — PHI Protection Controls")
    print("  PCI-DSS 1.x   — Network Security Controls")
    print("  FedRAMP AU-2  — Audit and Accountability")
    print("  SOC 2 CC/A    — Security and Availability")
    print("  NIST 800-53   — Identity and Access Controls")

    critical = [f for f in findings if f['status'] == 'FAIL' and f['severity'] == 'CRITICAL']
    high = [f for f in findings if f['status'] == 'FAIL' and f['severity'] == 'HIGH']
    medium = [f for f in findings if f['status'] == 'FAIL' and f['severity'] == 'MEDIUM']

    if critical:
        print(f"\nCRITICAL FINDINGS ({len(critical)}) — Fix Immediately")
        print("-" * 60)
        for f in critical:
            print(f"CRITICAL | {f['check']}")
            print(f"Resource:    {f['resource']}")
            print(f"Framework:   {f['framework']}")
            print(f"Remediation: {f['remediation']}")
            print()

    if high:
        print(f"\nHIGH FINDINGS ({len(high)}) — Fix Within 30 Days")
        print("-" * 60)
        for f in high:
            print(f"HIGH     | {f['check']}")
            print(f"Resource:    {f['resource']}")
            print(f"Framework:   {f['framework']}")
            print(f"Remediation: {f['remediation']}")
            print()

    if medium:
        print(f"\nMEDIUM FINDINGS ({len(medium)}) — Fix Within 90 Days")
        print("-" * 60)
        for f in medium:
            print(f"MEDIUM   | {f['check']}")
            print(f"Resource:    {f['resource']}")
            print(f"Framework:   {f['framework']}")
            print(f"Remediation: {f['remediation']}")
            print()

    passed_findings = [f for f in findings if f['status'] == 'PASS']
    if passed_findings:
        print(f"\nPASSED CHECKS ({len(passed_findings)})")
        print("-" * 60)
        for f in passed_findings:
            print(f"PASS | {f['check']} | {f['resource']}")

    print("\n" + "=" * 60)
    print("END OF REPORT")
    print("=" * 60)

    # Save report to file
    report_file = f"compliance_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, 'w') as f:
        f.write("COMPLIANCE AND SECURITY SCAN REPORT\n")
        f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total Checks: {passed + failed}\n")
        f.write(f"Passed: {passed}\n")
        f.write(f"Failed: {failed}\n\n")
        for finding in findings:
            f.write(f"{finding['status']} | {finding['severity']} | {finding['check']} | {finding['resource']}\n")
            if finding['status'] == 'FAIL':
                f.write(f"  Framework: {finding['framework']}\n")
                f.write(f"  Fix: {finding['remediation']}\n")
            f.write("\n")

    print(f"\nReport saved to: {report_file}")

# ============================================
# RUN ALL SCANS
# ============================================
print("Starting AWS Compliance and Security Scan...")
print("=" * 60)

check_s3()
check_iam()
check_cloudtrail()

for region in get_regions():
    print(f"\n--- Region: {region} ---")
    set_region(region)
    check_security_groups()
    check_rds()
    check_cost_waste()

generate_report()
