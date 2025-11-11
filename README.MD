# 🚀 AWS ECS CI/CD Pipeline — Exercise Hello

This project demonstrates a **complete AWS DevOps pipeline** built with **Terraform**, **CodePipeline**, **CodeBuild**, **ECR**, and **ECS**, deploying a Dockerized web app to AWS automatically on every push to GitHub.

---

## 🧱 Architecture Overview

**Main AWS Components:**
- **VPC** with public & private subnets  
- **ECR** – stores container images  
- **ECS Fargate Cluster** – runs the app containers  
- **ALB (Application Load Balancer)** – routes traffic to ECS services  
- **CodeBuild** – builds Docker images & pushes to ECR  
- **CodePipeline** – automates CI/CD from GitHub to ECS  

The entire infrastructure is defined in **Terraform**, ensuring full reproducibility and easy cleanup.

---

## ⚙️ How the Pipeline Works

1. **Push to GitHub** → triggers CodePipeline.  
2. **CodeBuild** runs using `buildspec.yml`:  
   - Logs in to ECR  
   - Builds Docker image from `/app/Dockerfile`  
   - Tags the image dynamically with commit hash or timestamp  
   - Pushes the image to ECR  
   - Generates `imagedefinitions.json` for ECS deploy  
3. **ECS Service** automatically updates to the new image.  
4. The app becomes available via the **ALB DNS** output from Terraform.


---

## 🧩 Main Terraform Files

| File | Purpose |
|------|----------|
| `main.tf` | Providers, backend, base setup |
| `ecs.tf` | ECS cluster, service, and task definition |
| `pipeline.tf` | CI/CD pipeline (CodePipeline + CodeBuild) |
| `variables.tf` | Configurable parameters (region, repo, etc.) |
| `outputs.tf` | Outputs like ALB DNS and ECR URL |
| `buildspec.yml` | Build instructions for CodeBuild |
| `app/Dockerfile` | Docker image definition for the sample app |

---

## 🧠 Key Learnings

- ✅ How to automate infrastructure and CI/CD using Terraform  
- ✅ Build and deploy Docker images to AWS ECS  
- ✅ Integrate GitHub → CodePipeline → CodeBuild → ECR → ECS  
- ✅ Troubleshoot buildspec and dynamic tagging issues  
- ✅ Apply and destroy resources safely using Terraform  

---

## 💻 Commands Used

```bash
# Initialize and apply Terraform
terraform init
terraform apply -auto-approve

# Destroy all AWS resources
terraform destroy -auto-approve
