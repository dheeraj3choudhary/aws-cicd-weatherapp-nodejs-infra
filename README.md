# weather-app-infra

Infrastructure as Code for the Weather App CI/CD pipeline on AWS. This repository manages all AWS infrastructure using CloudFormation and contains the bootstrap pipeline that provisions everything from scratch.

---

## Repository Structure

```
weather-app-infra/
├── bootstrap/
│   └── pipeline.yml          ← deploy once from AWS console
├── infra/
│   ├── buildspec-validate.yml
│   └── cfn/
│       ├── 01-iam.yml
│       ├── 02-networking.yml
│       ├── 03-compute.yml
│       ├── 04-ecr-s3.yml
│       └── 05-monitoring.yml
└── README.md
```

---

## Prerequisites

Before you begin make sure you have the following ready:

- An AWS account with admin access
- AWS CLI installed and configured (`aws configure`)
- Two CodeCommit repositories created manually in your AWS account:
  - `weather-app-infra` — this repository
  - `weather-application` — the application code repository

### Create CodeCommit Repositories

Go to AWS Console → CodeCommit → Create repository and create both repositories:

**Repo 1:**
- Name: `weather-app-infra`

**Repo 2:**
- Name: `weather-application`

> These must be created manually before deploying the bootstrap stack. The bootstrap pipeline will reference both repos.

---

## How It Works

This repo uses a two-pipeline pattern:

```
Bootstrap (one time)
        ↓
Creates Infra Pipeline + App Pipeline
        ↓
Push to weather-app-infra → Infra pipeline triggers → provisions all AWS resources
        ↓
Push to weather-application → App pipeline triggers → builds and deploys app to EC2
```

---

## Step 1 — Create SSM Parameter for API Key

Before deploying anything, create the OpenWeatherMap API key in Parameter Store manually.

Go to AWS Console → Systems Manager → Parameter Store → Create parameter:

- Name: `/weather-app/api-key`
- Type: `SecureString`
- KMS key: `aws/ssm` (default)
- Value: your OpenWeatherMap API key

> Never put API keys in code or CloudFormation templates.

---

## Step 2 — Deploy Bootstrap Stack

Go to AWS Console → CloudFormation → Create Stack → With new resources:

1. Upload `bootstrap/pipeline.yml`
2. Fill in parameters:
   - `InfraRepoName`: `weather-app-infra`
   - `AppRepoName`: `weather-application`
   - `BranchName`: `main`
3. Stack name: `weather-app-bootstrap`
4. Check `I acknowledge that AWS CloudFormation might create IAM resources`
5. Click Create Stack

This creates both pipelines. You will never need to touch AWS console again after this.

---

## Step 3 — Push Infra Code

Push this repository to your `weather-app-infra` CodeCommit repo:

```bash
git remote add origin https://git-codecommit.<region>.amazonaws.com/v1/repos/weather-app-infra
git add .
git commit -m "initial infra setup"
git push origin main
```

The infra pipeline will trigger automatically and deploy all CloudFormation stacks in order:

| Stack | What it creates |
|-------|----------------|
| `weather-app-iam` | EC2 role, instance profile, CodeDeploy role |
| `weather-app-networking` | VPC, subnet, internet gateway, security group |
| `weather-app-compute` | EC2 instance, CodeDeploy app and deployment group |
| `weather-app-ecr` | ECR repository for Docker images |
| `weather-app-monitoring` | CloudWatch log groups and CPU alarm |

---

## Step 4 — Push App Code

Once infra pipeline completes successfully, push the application code to `weather-application` repo. See the [weather-application](https://github.com/your-username/weather-application) repository for instructions.

---

## Tearing Down

Run the teardown script — it deletes all stacks in correct reverse order automatically:

```bash
chmod +x teardown.sh
./teardown.sh
```

The script will:
- Ask for confirmation before proceeding
- Delete all stacks in correct reverse order
- Wait for each stack to fully delete before moving to next
- Skip stacks that don't exist

> The SSM parameter `/weather-app/api-key` is **not** deleted by the script — delete it manually from AWS Console → Parameter Store if needed.

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| AWS CodeCommit | Source control |
| AWS CodePipeline | Pipeline orchestration |
| AWS CodeBuild | CFN template validation |
| AWS CloudFormation | Infrastructure provisioning |
| AWS EC2 | Application hosting |
| AWS ECR | Docker image registry |
| AWS SSM Parameter Store | Secrets management |
| AWS CloudWatch | Monitoring and logging |