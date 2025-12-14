# Terraformを使用したECRリポジトリ作成の例
# このファイルは参考用です（実行しないでください）

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_ecr_repository" "potato_app" {
  name                 = "potato-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "potato-app"
    Environment = "production"
  }
}

output "repository_url" {
  value = aws_ecr_repository.potato_app.repository_url
}
