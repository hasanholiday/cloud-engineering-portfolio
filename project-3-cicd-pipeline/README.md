# Project 3: CI/CD Pipeline with Jenkins, Terraform & Ansible

## Scenario
**Fielding Systems** — an internal engineering team needing to eliminate manual deployment errors and establish a repeatable, auditable change process aligned with FedRAMP-style change management expectations.

## Overview
Built an automated deployment pipeline that provisions infrastructure, configures servers, and verifies the deployment on every code push — replacing manual, error-prone deployment steps with a six-stage pipeline that runs the same way every time, with a full audit trail of every change.

## Architecture / Pipeline Stages
1. **Checkout** — pulls latest code from the repository
2. **Terraform Init** — initializes providers and backend
3. **Terraform Plan** — generates and displays the infrastructure change plan
4. **Terraform Apply** — provisions/updates infrastructure
5. **Ansible Playbook** — configures the provisioned servers (packages, users, services, idempotent state enforcement)
6. **Verification** — automated `curl` check confirming the deployed application responds as expected

All 6 stages run automatically and must pass for the pipeline to report success.

## Design Decisions & Trade-offs

**Problem:** Manual deployments at Fielding Systems were slow, inconsistent across engineers, and left no clear record of what changed, when, or why — a real risk under any change-management-driven compliance framework.

**Trade-off — Manual deploy vs. full pipeline automation:** A manual deployment process is faster to set up initially but every deploy is a new opportunity for human error, and there's no consistent record of what happened. I built a fully automated 6-stage pipeline instead — more upfront setup work, but every deployment now runs identically and is logged automatically in Jenkins' build history, which is exactly the kind of auditable trail FedRAMP-style change management expects.

**Trade-off — All-at-once deploy vs. staged verification:** Deploying everything at once and hoping it works is faster but riskier — a bad deploy can go live with nothing catching it. I structured the pipeline so Terraform Plan runs before Apply (a preview step before any real change happens) and added a final automated verification stage after Ansible configuration completes — catching failures before they're considered "done" rather than after a customer notices.

**Trade-off — Hardcoded paths vs. parameterized pipeline:** The pipeline currently hardcodes absolute paths (`/home/ec2-user/terraform-project`, `/home/ec2-user/ansible-project`) specific to this EC2 environment. This was the right call for a single-environment portfolio build, but a production version serving multiple environments would parameterize these as pipeline variables instead — a clear, honest next iteration rather than something I'd claim was already built.

**Trade-off — What I would still add:** The current pipeline stops and alerts on failure but doesn't yet have automated rollback if a later stage fails after infrastructure changes are partially applied. That's the next real improvement — automatic rollback to the last known-good state rather than requiring manual intervention.

## Tools Used
Jenkins (running on EC2, port 8080), Terraform, Ansible, Git, Java 21

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| FedRAMP | Change management — every infrastructure and configuration change is automated, logged, and reproducible via pipeline run history |
| SOC 2 | Change control audit trail — Jenkins build history provides a complete record of what changed, when, and via which commit |

## Impact
Automated infrastructure provisioning and server configuration end-to-end on every code push, replacing manual, error-prone deployment steps with a repeatable, auditable pipeline — the same underlying pattern that lets companies ship code dozens of times a day without each release being a manual, high-risk event.

## How to Reproduce
1. Stand up an EC2 instance, install Java 21 and Jenkins
2. `sudo systemctl start jenkins` and complete initial setup at `http://<instance-ip>:8080`
3. Install the required Jenkins plugins (Pipeline, Git, Ansible)
4. Create a `Jenkinsfile` defining the 6 stages above (see this folder's `Jenkinsfile` for the actual working pipeline definition)
5. Point Jenkins at the repository and configure a build trigger (poll SCM or webhook)
6. Ensure the Jenkins user has AWS credentials configured for Terraform to assume

## Notes
Jenkins must be manually restarted after an EC2 reboot: `sudo systemctl start jenkins`. Instance public IP changes on restart unless an Elastic IP is attached — check the AWS console for the current IP before accessing the Jenkins UI. The `Jenkinsfile` in this folder is the real, currently-running pipeline definition, pulled directly from the live Jenkins job configuration.
