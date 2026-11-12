# Hasan Holiday — Cloud Engineering Portfolio

**AWS Cloud Engineer | DevOps & Infrastructure Automation | Cloud Security & Compliance**

Atlanta, GA · [Hasanholiday55@gmail.com](mailto:Hasanholiday55@gmail.com) · +1 (470) 437-1840
[LinkedIn](#) · [Live Portfolio Site](http://hasan-cloud-pro-resume.s3-website-us-east-1.amazonaws.com) · [Resume](#)

---

## About This Portfolio

This repository contains production-style AWS projects demonstrating hands-on cloud engineering, DevOps automation, and compliance work across realistic business scenarios. Each project was built using Infrastructure as Code, with intentional real-world failure scenarios included and debugged — not just clean, scripted demos. Every project README includes a **Design Decisions & Trade-offs** section explaining not just what was built, but why that approach was chosen over the alternatives.

The projects are tied together through simulated company scenarios spanning e-commerce, internal engineering operations, compliance consulting, and healthcare — the same sectors (healthcare, finance, and government) this portfolio is built to target.

**A note on the scenarios:** Company names like NorthPoint Retail, Fielding Systems, Meridian Consulting Group, and MedCore Health are simulated engagements built to practice against realistic business context — not real clients or employers. Everything else — the infrastructure, the code, the compliance findings, the debugging, the trade-off decisions — is real, self-directed work.

---

## Projects

| # | Project | Scenario | Tech Stack | Status |
|---|---|---|---|---|
| 1 | [Multi-Tier AWS Infrastructure](./project-1-multitier) | NorthPoint Retail (e-commerce) | Terraform, EC2, ALB, Auto Scaling, RDS, IAM, CloudWatch | ✅ Complete |
| 2 | [Serverless Portfolio Site](./project-2-resume-site) | Personal project | S3, CloudFront, Lambda, API Gateway, DynamoDB | ✅ Complete |
| 3 | [CI/CD Pipeline](./project-3-cicd-pipeline) | Fielding Systems (internal engineering) | Jenkins, Terraform, Ansible, GitHub | ✅ Complete |
| 4 | [EKS + Prometheus/Grafana Monitoring](./project-4-eks-monitoring) | — | EKS, Prometheus, Grafana, Helm | ✅ Complete |
| 5 | [AWS Compliance Scanner](./project-5-compliance-scanner) | Meridian Consulting Group | Python, boto3, IAM, CloudTrail, RDS, S3 | ✅ Complete |
| 6 | [HIPAA/FedRAMP Gap Assessment](./project-6-hipaa-fedramp) | MedCore Health (Part 1) | IAM, CloudTrail, Security Hub | ✅ Complete |
| 7 | [On-Prem to AWS Migration](./project-7-migration) | MedCore Health (Part 2) | Terraform, Ansible, EC2, RDS, S3 | ✅ Complete |
| 8 | [HIPAA-Compliant Document Pipeline](./project-8-medcore-pipeline) | MedCore Health | S3, Lambda, Textract, DynamoDB, EventBridge, SNS, WAF | ✅ Complete |

Projects 6 and 7 form a single continuous engagement for MedCore Health — a compliance gap assessment followed by the actual migration it scoped. Project 8 extends that same MedCore Health engagement into an automated document processing pipeline.

---

## Highlights

- **Architected highly available AWS infrastructure** using Auto Scaling and Load Balancing, with demand-based scaling (scale out at 70% CPU, scale in at 40%)
- **Automated infrastructure deployment** with Terraform, cutting build time from a multi-hour manual process to an 8-minute automated deployment
- **Identified and remediated 11 security and compliance gaps**, including 6 critical findings, across a live AWS environment
- **Achieved a 95% projected cost reduction** through a full on-prem to AWS migration using the 6R framework
- **Built and debugged a real EKS cluster** under genuine Free Tier resource constraints — diagnosed pod scheduling limits and storage provisioning issues directly from Kubernetes error output
- **Designed a serverless HIPAA-compliant document pipeline** with automated failure handling, verified under a real account-level service restriction encountered during testing
- **8 production-style projects** spanning infrastructure, automation, security, compliance, container orchestration, and serverless architecture — each documented with the trade-offs behind every decision

---

## Core Technologies

**Cloud:** AWS (EC2, S3, VPC, IAM, RDS, Lambda, API Gateway, DynamoDB, CloudFront, ALB, Auto Scaling, CloudWatch, CloudTrail, Security Hub, EventBridge, SNS, WAF, Textract, EKS)
**Infrastructure as Code:** Terraform, Ansible
**DevOps:** Jenkins, Git, GitHub, Docker, Kubernetes, Helm
**Monitoring:** Prometheus, Grafana
**Languages:** Python (boto3), SQL, Bash
**Compliance:** HIPAA, PCI-DSS, SOC 2, FedRAMP, NIST 800-53

---

## Background

Former educator turned cloud engineer, with a background independently owning and operating two businesses (HVAC services and a restaurant) — bringing real-world accountability, regulatory compliance experience, and operational discipline into cloud infrastructure and security work.

---

## Contact

Open to entry-to-mid level Cloud Engineer, DevOps Engineer, and Cloud Support Engineer roles. Reach out via [email](mailto:Hasanholiday55@gmail.com) or [LinkedIn](#).
