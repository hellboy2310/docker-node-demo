# CI/CD with GitHub Actions — Design Spec

**Date:** 2026-05-13
**Project:** docker-node-demo

## Overview

Two independent GitHub Actions pipelines:

1. **Docker pipeline** — builds, tests, and pushes the Node.js Docker image to Docker Hub
2. **Lambda pipeline** — packages and deploys the Lambda function to AWS

Both pipelines are separate workflow files that trigger on push to `main`, with path filtering so each only runs when its relevant files change.

---

## File Structure

```
.github/
  workflows/
    docker.yml    ← Docker build, test, push pipeline
    lambda.yml    ← Lambda package and deploy pipeline
```

---

## Pipeline 1: Docker (`docker.yml`)

### Trigger

Push to `main`, watching paths:
- `index.js`
- `Dockerfile`
- `package.json`
- `package-lock.json`

### Job: `build-and-push`

| Step | Action |
|---|---|
| 1 | Checkout code |
| 2 | Set up Docker Buildx |
| 3 | Log in to Docker Hub (via secrets) |
| 4 | Build production image (`--target production`) |
| 5 | Start container, hit `/health`, assert HTTP 200 |
| 6 | Stop container |
| 7 | Push image to Docker Hub (tags: `latest` + git SHA) |

Step 7 only runs if step 5 passes — a broken image is never pushed.

### GitHub Secrets Required

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not password) |

---

## Pipeline 2: Lambda (`lambda.yml`)

### Trigger

Push to `main`, watching paths:
- `lambda/**`

### Job: `deploy`

| Step | Action |
|---|---|
| 1 | Checkout code |
| 2 | Configure AWS credentials (via secrets) |
| 3 | Zip `lambda/handler.js` |
| 4 | Run `aws lambda update-function-code` |

### GitHub Secrets Required

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key with Lambda deploy permissions |
| `AWS_SECRET_ACCESS_KEY` | Paired secret key |
| `AWS_REGION` | `ap-south-1` |

### Pre-requisite

The Lambda function must already exist in AWS before `update-function-code` can run. The Terraform `main.tf` needs an `aws_lambda_function` resource added as part of implementation. The function will be named `docker-node-demo`.

---

## Key Concepts Covered

| Concept | Where it appears |
|---|---|
| Workflow triggers | Both pipelines |
| Path filtering | Both pipelines |
| Jobs and steps | Both pipelines |
| GitHub secrets | Both pipelines |
| Docker Buildx | Docker pipeline |
| Health-check testing in CI | Docker pipeline |
| Image tagging (latest + SHA) | Docker pipeline |
| AWS credential configuration | Lambda pipeline |
| Serverless deployment via CLI | Lambda pipeline |
