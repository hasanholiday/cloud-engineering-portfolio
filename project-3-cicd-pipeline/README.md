# Project 3: CI/CD Pipeline with Jenkins, Terraform & Ansible

## Scenario
**Fielding Systems** — an internal engineering team needing to eliminate manual deployment errors and establish a repeatable, auditable change process aligned with FedRAMP-style change management expectations.

## Overview
Built an automated deployment pipeline that provisions infrastructure, configures servers, and verifies the deployment on every code push — replacing manual, error-prone deployment steps with an eight-stage pipeline that runs the same way every time, with a full audit trail of every change.

## Architecture / Pipeline Stages
1. **Checkout** — `checkout scm` pulls the exact commit that triggered the build and logs it
2. **Terraform Init** — initializes providers
3. **Terraform Validate** — catches syntax and config errors before planning
4. **Terraform Plan** — saves the change plan to a file (`tfplan`)
5. **Approval** — a human must click Apply in Jenkins (30-minute timeout)
6. **Terraform Apply** — applies exactly the saved, reviewed plan
7. **Ansible Configure** — installs and configures the web server (idempotent)
8. **Verify** — `curl --fail` with retries; a non-200 response fails the build

Any failing stage stops the pipeline and marks the build failed.

## Design Decisions & Trade-offs

**Problem:** Manual deployments at Fielding Systems were slow, inconsistent across engineers, and left no clear record of what changed, when, or why — a real risk under any change-management-driven compliance framework.

**Trade-off — Manual deploy vs. full pipeline automation:** A manual deployment process is faster to set up initially but every deploy is a new opportunity for human error, and there's no consistent record of what happened. I built a mostly automated 8-stage pipeline (one deliberate human approval) instead — more upfront setup work, but every deployment now runs identically and is logged automatically in Jenkins' build history, which is exactly the kind of auditable trail FedRAMP-style change management expects.

**Trade-off — All-at-once deploy vs. staged verification:** Deploying everything at once and hoping it works is faster but riskier — a bad deploy can go live with nothing catching it. I structured the pipeline so Terraform Plan runs before Apply (a preview step before any real change happens) added a manual approval gate between Plan and Apply, and a final verification stage that fails the build on a bad response — catching failures before they're considered "done" rather than after a customer notices.

**Trade-off — Workspace paths vs. parameterized environments:** The pipeline now runs from the checked-out repo (`terraform-project/`, `ansible-project/`) instead of hardcoded home-directory paths. It still targets a single environment; a production version would add `dev`/`prod` variables and separate state per environment.

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
4. Create a Pipeline job using "Pipeline script from SCM" pointing at this repo and `project-3-cicd-pipeline/Jenkinsfile`
5. Point Jenkins at the repository and configure a build trigger (poll SCM or webhook)
6. Ensure the Jenkins user has AWS credentials configured for Terraform to assume

## Notes
Jenkins must be manually restarted after an EC2 reboot: `sudo systemctl start jenkins`. Instance public IP changes on restart unless an Elastic IP is attached — check the AWS console for the current IP before accessing the Jenkins UI. The earlier version of this Jenkinsfile ran on a live Jenkins instance; this revised version (real checkout, validate, approval gate, strict verify) needs a re-run on Jenkins to confirm before you describe it as tested. Note: the Verify stage curls localhost, so it checks the Jenkins host itself, which is what the Ansible inventory configures.
