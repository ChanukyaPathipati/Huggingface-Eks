# TestTony

# Hugging Face Model Serving Infrastructure

A fully automated, production-ready cloud infrastructure to deploy, monitor, and manage a Hugging Face model-serving FastAPI application using AWS, Terraform, Docker, Kubernetes (EKS), Helm, and GitHub Actions.

---

## 📦 Project Structure
project-root/
├── iac/                        # Terraform files for infra + Helm app
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tf
│   ├── monitoring/
│   │   └── prometheus-values.yaml
│   └── my-webapp/              # Helm chart to deploy FastAPI app
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── nginx-nlb-values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── _helpers.tpl
├── serving/                    # FastAPI application source
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
├── tests/                      # Unit tests for FastAPI endpoints
│   └── test_api.py
├── .github/                    # GitHub Actions CI/CD workflow
│   └── workflows/
│       └── ci-cd.yml
└── README.md                   # Project documentation

---

## Features Completed

### 1. FastAPI ML Serving App

* `/model` POST: Dynamically loads Hugging Face model (e.g., `gpt2`)
* `/status` GET: Deployment status (`NOT_DEPLOYED`, `PENDING`, `RUNNING`)
* `/completion` POST: Accepts messages and returns model output
* `/metrics` GET: Prometheus-compatible metrics

### 2. Dockerized & Tested Locally

* Built custom Docker image
* Ran and validated via `curl` and `pytest`

### 3. Helm Chart for Kubernetes

* Helm chart for FastAPI app (`my-webapp`)
* Deployable to Minikube or AWS EKS
* Supports NGINX ingress, resource configs, and autoscaling-ready

### 4. EKS Infrastructure with Terraform

* VPC module using `terraform-aws-modules/vpc`
* EKS cluster with managed ARM64 nodes (`t4g.small`)
* Key pair auto-generated and uploaded to S3
* NGINX ingress controller deployed with NLB

### 5. Monitoring Stack (Prometheus + Grafana)

* Installed via Helm
* `/metrics` endpoint scraped using `ServiceMonitor`
* Exposed via AWS LoadBalancer

### 6. CI/CD Pipeline (WIP)

* GitHub Actions configured:

  * Run tests
  * Build and push image to ECR
  * Deploy updated image to EKS via Helm
* IAM user for GitHub CI/CD being provisioned

---

##  How to Run Tests

```bash
pip install -r serving/requirements.txt
pytest tests/
```

---

## How to Build & Push to ECR

```bash
docker build -t huggingface-fastapi .
docker tag huggingface-fastapi:latest <aws_account>.dkr.ecr.<region>.amazonaws.com/huggingface-fastapi:latest
aws ecr get-login-password | docker login ...
docker push ...
```

---

##  Monitoring Access

* **Grafana**: Exposed via NLB on port 80 (check `kubectl get svc -n monitoring`)
* **Prometheus**: Same via `kube-prometheus-stack`
* Default Grafana login: `admin / admin`

---



Required GitHub Secrets (set these in your repo)

| Secret Name             | Value Example              |
| ----------------------- | -------------------------- |
| `AWS_ACCESS_KEY_ID`     | Your CI/CD IAM user key    |
| `AWS_SECRET_ACCESS_KEY` | Your CI/CD IAM user secret |
| `AWS_REGION`            | `eu-west-2`                |
| `AWS_ACCOUNT_ID`        | `123456789012`             |
| `ECR_REPOSITORY`        | `huggingface-fastapi`      |
| `EKS_CLUSTER_NAME`      | `huggingface-eks`          |




for testing

Your FastAPI app likely has these routes:

/model
/completion
/status
/metrics
But not / — so when NGINX or a browser hits /, FastAPI replies:
"404 Not Found".

Example = http://abcfb9de7459f46ad9ce61827d73cde4-bad609e46ad5cec2.elb.us-east-1.amazonaws.com/status

![Alt text](<Screenshot 2025-05-22 at 4.06.59 PM.png>)
