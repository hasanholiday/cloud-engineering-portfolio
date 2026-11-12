# Project 1: Multi-Tier AWS Infrastructure with Terraform

## Scenario
**NorthPoint Retail** — a mid-size e-commerce company needing a highly available backend capable of handling seasonal traffic spikes without downtime, while maintaining PCI-DSS-aware network security for payment-adjacent systems.

## Overview
Architected a highly available, multi-tier AWS infrastructure using Infrastructure as Code, spanning two Availability Zones and provisioning 29 resources automatically — reducing manual deployment time from a multi-hour manual build to minutes, while enforcing compliance-aware network segmentation from the ground up.

## Architecture
- **Compute:** Auto Scaling Group behind an Application Load Balancer, spanning 2 AZs
- **Database:** RDS MySQL, encrypted at rest, Multi-AZ enabled for automatic failover, deployed in private subnets (no public access); master password generated and held in AWS Secrets Manager, never written in code
- **Networking:** Custom VPC with public/private subnet tiers, web servers in private subnets with outbound-only access through a single NAT gateway, security groups chained by tier (ALB → App → DB, no SSH from the internet, no direct public-to-DB path)
- **Monitoring:** CloudWatch alarms on key infrastructure metrics, catching issues before customers experience them
- **Cost Governance:** Consistent cost allocation tags applied across the provisioned resources

## Design Decisions & Trade-offs

**Problem:** NorthPoint Retail needed infrastructure that stays up during a single Availability Zone outage and automatically absorbs seasonal traffic spikes without manual intervention.

**Trade-off — Single-AZ vs. Multi-AZ:** A single-AZ deployment is simpler and cheaper to run, but a single data center outage takes the whole application down. I chose Multi-AZ for both the compute layer (Auto Scaling Group across 2 AZs) and the database layer (RDS Multi-AZ with automatic failover), accepting the added cost and complexity in exchange for fault tolerance — the system survives a full AZ failure without anyone manually intervening.

**Trade-off — Fixed capacity vs. Auto Scaling:** Running a fixed number of servers at all times is predictable but wastes money during low-traffic periods and risks being overwhelmed during spikes. I configured Auto Scaling to scale out at 70% CPU utilization and scale in at 40% (min 2, max 4 servers), so capacity follows load instead of sitting at peak. I have not measured the dollar savings; the saving depends on real traffic.

**Trade-off — One NAT gateway vs. one per AZ:** A single NAT gateway costs roughly a third of a two-NAT setup, but if its AZ fails, private servers lose outbound internet until it recovers (inbound traffic through the load balancer is unaffected). I chose one for lab cost; production should use one per AZ.

**Trade-off — Public vs. private database placement:** Placing the database in a public subnet would simplify initial setup and debugging, but exposes it directly to the internet. I placed RDS in a private subnet reachable only from the application tier — the extra networking complexity buys real security: there is no network path from the public internet directly to the data layer, satisfying HIPAA-style network segmentation expectations even though this specific engagement was PCI-DSS focused.

## Tools Used
Terraform, AWS EC2, Auto Scaling Groups, Application Load Balancer, RDS MySQL, VPC, Security Groups, CloudWatch, IAM

## Compliance Controls Demonstrated
| Framework | Control Area |
|---|---|
| HIPAA | Network segmentation — database tier isolated in private subnets, unreachable from the public internet |
| SOC 2 | Availability — Auto Scaling Group + multi-AZ deployment for fault tolerance |
| PCI-DSS | Security group chaining — least-privilege network access enforced tier-to-tier |

## Impact
- Environment builds from code with `terraform apply` instead of a manual console build (record your own apply time and put it here)
- Capacity follows load: scale out at 70% CPU, scale in at 40% CPU (min 2, max 4 servers)
- Enforced consistent security posture and cost tagging across every resource by default

## How to Reproduce
```bash
cd project-1-multitier
terraform init
terraform plan
terraform apply
```
Requires AWS credentials configured (`aws configure`) with sufficient IAM permissions to provision VPC, EC2, RDS, and Secrets Manager resources.

**Cost warning:** the NAT gateway (about $0.045/hour plus data) and Multi-AZ RDS are not free-tier. Run `terraform destroy` when you finish.

## Notes
- `.terraform/` provider binaries and `*.tfstate` files are intentionally excluded from version control (see `.gitignore`) — state should be managed via remote backend (e.g., S3 + DynamoDB lock table) in a real production setup, not committed to git.
