#!/usr/bin/env bash
# One-time setup (run in AWS CloudShell or with admin credentials):
# state bucket + lock table, ECR repo, GitHub OIDC provider and deploy role.
# Usage: GH_REPO=hasanholiday/cloud-engineering-portfolio ./bootstrap.sh
set -euo pipefail
REGION="${REGION:-us-east-1}"
GH_REPO="${GH_REPO:?set GH_REPO=owner/repo}"
ACCT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="ptp-tfstate-${ACCT}"
TABLE="ptp-tf-lock"
ECR="ptp-app"
ROLE="ptp-github-deploy"

aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null || {
  if [ "$REGION" = "us-east-1" ]; then aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"; fi
}
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" >/dev/null 2>&1 || \
  aws dynamodb create-table --table-name "$TABLE" --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region "$REGION" >/dev/null
aws ecr describe-repositories --repository-names "$ECR" --region "$REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR" --image-scanning-configuration scanOnPush=true --region "$REGION" >/dev/null

OIDC="arn:aws:iam::${ACCT}:oidc-provider/token.actions.githubusercontent.com"
aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC" >/dev/null 2>&1 || \
  aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null

cat > /tmp/trust.json <<JSON
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"${OIDC}"},
"Action":"sts:AssumeRoleWithWebIdentity",
"Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},
"StringLike":{"token.actions.githubusercontent.com:sub":["repo:${GH_REPO}:environment:production","repo:${GH_REPO}:ref:refs/heads/main","repo:${GH_REPO}:pull_request"]}}}]}
JSON
aws iam get-role --role-name "$ROLE" >/dev/null 2>&1 || aws iam create-role --role-name "$ROLE" --assume-role-policy-document file:///tmp/trust.json >/dev/null
# Lab shortcut: AdministratorAccess because Terraform creates IAM + VPC + ALB. In a real job, scope this down.
aws iam attach-role-policy --role-name "$ROLE" --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo
echo "Add these GitHub repo variables (Settings > Secrets and variables > Actions > Variables):"
echo "  AWS_REGION=$REGION"
echo "  AWS_ROLE_ARN=arn:aws:iam::${ACCT}:role/${ROLE}"
echo "  TF_STATE_BUCKET=$BUCKET"
echo "  TF_LOCK_TABLE=$TABLE"
echo "  ECR_REPO_URL=${ACCT}.dkr.ecr.${REGION}.amazonaws.com/${ECR}"
