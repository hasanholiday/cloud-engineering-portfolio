# Project 9: Push to production, no clicking

A `git push` builds, tests and deploys a small app to AWS with no manual steps except one approval click.

```
push -> unit tests -> terraform plan -> [approval] -> docker build + push to ECR
     -> terraform apply (new launch template, rolling instance refresh)
     -> health check on /health must return the new git SHA
     -> pass: save SHA as last-good   |   fail: re-apply the previous SHA (rollback)
```

## What is in here
| Path | What it does |
|---|---|
| `app/` | Tiny Python web app, `/health` returns status and version. Dockerfile runs it as a non-root user. |
| `terraform/` | VPC, 2 public subnets, ALB, target group with `/health` check, launch template, auto scaling group (2 to 4, CPU target tracking), instance role (ECR read + SSM), IMDSv2 only, no SSH. State in S3 with DynamoDB lock. |
| `scripts/bootstrap.sh` | One-time: state bucket, lock table, ECR repo, GitHub OIDC provider and deploy role. Prints the GitHub variables to set. |
| `../.github/workflows/project-9-deploy.yml` | The pipeline. |

## Run it (about 7 hours the first time)
1. In AWS CloudShell: `GH_REPO=hasanholiday/cloud-engineering-portfolio ./scripts/bootstrap.sh`
2. Add the five printed values as GitHub repo **variables**.
3. GitHub, Settings, Environments: create `production`, add yourself as required reviewer.
4. Merge to `main`. Watch the run, approve, open the `alb_url`.
5. Break it: make `/health` return 500 in `app.py`, push, approve, and watch the rollback.
6. **Clean up:** `terraform destroy` (init with the same backend config), then delete the ECR repo, state bucket and lock table if you are done.

## Design choices (interview talking points)
- No long-lived AWS keys: GitHub assumes the role through OIDC, and the trust policy names this repo.
- Public subnets and no NAT gateway to save about $1 a day. Instances accept traffic only from the ALB. Production would use private subnets and a NAT or VPC endpoints.
- Rolling refresh keeps at least 50% healthy, so a bad image never takes the whole site down.
- The deploy role has AdministratorAccess for the lab. A real team would scope it down.
- Rollback is a second `terraform apply` with the previous tag, so state and reality stay in sync.

## Status
Written and syntax-checked (HCL parses, YAML parses, unit test passes). **Not yet applied to a live AWS account.** Record your real run times, screenshots and the break-and-fix log here once you have run it.
