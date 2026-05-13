# CI/CD with GitHub Actions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build two independent GitHub Actions pipelines — one that builds, tests, and pushes the Docker image to Docker Hub, and one that packages and deploys the Lambda function to AWS.

**Architecture:** Two separate workflow files under `.github/workflows/`. The Docker pipeline triggers on changes to app files and pushes to Docker Hub. The Lambda pipeline triggers on changes to `lambda/` and deploys to AWS using `update-function-code`. Terraform manages the Lambda function resource so it exists before the pipeline first runs.

**Tech Stack:** GitHub Actions, Docker Buildx, Docker Hub, AWS Lambda, AWS IAM, Terraform (AWS provider)

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `.github/workflows/docker.yml` | Create | Docker build → health-check → push pipeline |
| `.github/workflows/lambda.yml` | Create | Lambda zip → deploy pipeline |
| `terraform/main.tf` | Modify | Add IAM role + `aws_lambda_function` resource |

---

## Task 1: Add Lambda resource to Terraform

The Lambda function must exist in AWS before `aws lambda update-function-code` can run. This task adds it via Terraform.

**Files:**
- Modify: `terraform/main.tf`

- [ ] **Step 1: Add IAM role and Lambda function to `terraform/main.tf`**

Replace the full contents of `terraform/main.tf` with:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "demo_server" {
  ami           = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-demo"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "docker-node-demo-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "demo" {
  filename         = "../lambda/function.zip"
  function_name    = "docker-node-demo"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.handler"
  runtime          = "nodejs20.x"
  source_code_hash = filebase64sha256("../lambda/function.zip")
}
```

- [ ] **Step 2: Apply Terraform**

Run from the `terraform/` directory:

```bash
cd terraform
terraform init
terraform apply
```

When prompted `Do you want to perform these actions?` type `yes`.

Expected output includes:
```
aws_iam_role.lambda_role: Creating...
aws_iam_role_policy_attachment.lambda_basic: Creating...
aws_lambda_function.demo: Creating...
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

- [ ] **Step 3: Verify Lambda exists in AWS**

```bash
aws lambda get-function --function-name docker-node-demo --region ap-south-1
```

Expected: JSON response with `"FunctionName": "docker-node-demo"` and `"State": "Active"`.

- [ ] **Step 4: Commit**

```bash
cd ..
git add terraform/main.tf
git commit -m "feat: add Lambda function and IAM role to Terraform"
```

---

## Task 2: Set up Docker Hub credentials as GitHub secrets

GitHub Actions needs your Docker Hub credentials to push images. These are stored as encrypted secrets in your GitHub repo — never in code.

**Files:** None (manual GitHub UI steps)

- [ ] **Step 1: Create a Docker Hub access token**

1. Go to [hub.docker.com](https://hub.docker.com) → Account Settings → Security → New Access Token
2. Name it `github-actions`
3. Set permissions to **Read, Write, Delete**
4. Copy the token — you won't see it again

- [ ] **Step 2: Add secrets to your GitHub repository**

1. Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret
2. Add `DOCKERHUB_USERNAME` — your Docker Hub username (e.g. `hellboy2310`)
3. Add `DOCKERHUB_TOKEN` — the token you just created

---

## Task 3: Create the Docker workflow

**Files:**
- Create: `.github/workflows/docker.yml`

- [ ] **Step 1: Create the workflows directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Create `.github/workflows/docker.yml`**

```yaml
name: Docker Build and Push

on:
  push:
    branches:
      - main
    paths:
      - 'index.js'
      - 'Dockerfile'
      - 'package.json'
      - 'package-lock.json'

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build production image
        run: docker build --target production -t docker-node-demo:test .

      - name: Run health-check test
        run: |
          docker run -d --name test-container -p 3000:3000 docker-node-demo:test
          sleep 5
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
          docker stop test-container
          docker rm test-container
          if [ "$STATUS" != "200" ]; then
            echo "Health check failed — got HTTP $STATUS, expected 200"
            exit 1
          fi
          echo "Health check passed — HTTP $STATUS"

      - name: Push image to Docker Hub
        run: |
          docker tag docker-node-demo:test ${{ secrets.DOCKERHUB_USERNAME }}/docker-node-demo:latest
          docker tag docker-node-demo:test ${{ secrets.DOCKERHUB_USERNAME }}/docker-node-demo:${{ github.sha }}
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/docker-node-demo:latest
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/docker-node-demo:${{ github.sha }}
```

- [ ] **Step 3: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/docker.yml')); print('YAML valid')"
```

Expected: `YAML valid`

- [ ] **Step 4: Commit and push to trigger the pipeline**

```bash
git add .github/workflows/docker.yml
git commit -m "feat: add Docker build and push GitHub Actions workflow"
git push origin main
```

- [ ] **Step 5: Verify the pipeline runs**

1. Go to your GitHub repo → Actions tab
2. You should see a workflow run called **Docker Build and Push** triggered by your push
3. Click it and watch the steps — all should show green checkmarks
4. After it completes, go to [hub.docker.com](https://hub.docker.com) → your repositories — you should see `docker-node-demo` with tags `latest` and the git SHA

If it fails at the health-check step, click the step to read the logs — it will show the HTTP status returned.

---

## Task 4: Create an IAM user for GitHub Actions Lambda deployments

GitHub Actions needs AWS credentials with permission to update the Lambda function code.

**Files:** None (AWS Console steps)

- [ ] **Step 1: Create an IAM user in AWS**

1. Go to AWS Console → IAM → Users → Create user
2. Name: `github-actions-lambda-deploy`
3. Select **Attach policies directly**
4. Attach the policy `AWSLambda_FullAccess`
5. Click Create user

- [ ] **Step 2: Create an access key for the IAM user**

1. Click the user → Security credentials → Create access key
2. Use case: **Application running outside AWS**
3. Copy the **Access key ID** and **Secret access key** — you won't see the secret again

- [ ] **Step 3: Add AWS secrets to your GitHub repository**

1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Add `AWS_ACCESS_KEY_ID` — the access key ID from above
3. Add `AWS_SECRET_ACCESS_KEY` — the secret access key from above
4. Add `AWS_REGION` — `ap-south-1`

---

## Task 5: Create the Lambda workflow

**Files:**
- Create: `.github/workflows/lambda.yml`

- [ ] **Step 1: Create `.github/workflows/lambda.yml`**

```yaml
name: Lambda Deploy

on:
  push:
    branches:
      - main
    paths:
      - 'lambda/**'

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Zip Lambda function
        run: |
          cd lambda
          zip -r function.zip handler.js

      - name: Deploy to AWS Lambda
        run: |
          aws lambda update-function-code \
            --function-name docker-node-demo \
            --zip-file fileb://lambda/function.zip
```

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/lambda.yml')); print('YAML valid')"
```

Expected: `YAML valid`

- [ ] **Step 3: Commit and push to trigger the pipeline**

```bash
git add .github/workflows/lambda.yml
git commit -m "feat: add Lambda deploy GitHub Actions workflow"
git push origin main
```

Expected: This push does NOT trigger the Lambda pipeline — the changed file is `lambda.yml`, not anything under `lambda/`. This is the path filter working correctly.

- [ ] **Step 4: Trigger the Lambda pipeline by touching the function**

Add a comment to `lambda/handler.js` to trigger the path filter:

```js
// updated via CI/CD
exports.handler = async (event) => {
```

Then commit and push:

```bash
git add lambda/handler.js
git commit -m "test: trigger Lambda CI/CD pipeline"
git push origin main
```

- [ ] **Step 5: Verify the pipeline runs**

1. Go to GitHub repo → Actions tab
2. You should see **Lambda Deploy** triggered
3. All steps should show green checkmarks
4. Verify in AWS Console → Lambda → `docker-node-demo` → the **Last modified** timestamp updated

---

## What you've learned

| Concept | Where you saw it |
|---|---|
| Workflow triggers (`on: push`) | Both pipelines |
| Path filtering (`paths:`) | Both pipelines — Docker pipeline didn't run when `lambda.yml` changed |
| Jobs and steps | Both pipelines |
| GitHub secrets (`${{ secrets.X }}`) | Docker Hub credentials, AWS credentials |
| Docker Buildx | Docker pipeline |
| Health-check testing in CI | Docker pipeline — push blocked if container is broken |
| Image tagging (`latest` + SHA) | Docker pipeline |
| AWS credential configuration | Lambda pipeline |
| `update-function-code` | Lambda pipeline |
