#########################################
# PIPELINE: GitHub → CodeBuild → ECS
#########################################


# Variables for GitHub integration
variable "github_owner" {
  description = "GitHub username or org"
  type        = string
  default     = "YOUR_GITHUB_USERNAME"
}

variable "github_repo" {
  description = "GitHub repo name"
  type        = string
  default     = "exercise-hello"
}

variable "github_branch" {
  description = "Branch to track"
  type        = string
  default     = "main"
}

variable "github_token" {
  description = "GitHub Personal Access Token (repo + admin:repo_hook + workflow)"
  type        = string
}

#########################################
# S3 bucket for artifacts
#########################################
resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "exercise-artifacts-${random_id.suffix.hex}"
}

#########################################
# IAM for CodeBuild
#########################################
data "aws_iam_policy_document" "codebuild_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild_role" {
  name               = "exercise-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust.json
}

resource "aws_iam_role_policy_attachment" "codebuild_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ])
  role       = aws_iam_role.codebuild_role.name
  policy_arn = each.value
}

#########################################
# CodeBuild project (Docker build + push)
#########################################
resource "aws_codebuild_project" "build" {
  name         = "exercise-build"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type      = "S3"
    location  = aws_s3_bucket.artifacts.bucket
    packaging = "ZIP"
    name      = "build-output.zip"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = "app"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
    buildspec       = file("${path.module}/buildspec.yml")
    git_clone_depth = 1
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/exercise"
      stream_name = "build"
    }
  }
}

#########################################
# IAM for CodePipeline
#########################################
data "aws_iam_policy_document" "codepipeline_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = "exercise-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_trust.json
}

resource "aws_iam_role_policy_attachment" "codepipeline_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/AWSCodeBuildDeveloperAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
  ])
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = each.value
}

#########################################
# CodePipeline definition
#########################################
resource "aws_codepipeline" "pipeline" {
  name     = "exercise-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_token
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "DeployToECS"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.app.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}

#########################################
# Outputs
#########################################
output "pipeline_name" {
  value = aws_codepipeline.pipeline.name
}

