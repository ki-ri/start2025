#!/bin/bash
set -e

# 色付き出力用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定（Terraform variables.tfのデフォルト値に合わせる）
AWS_REGION=${AWS_REGION:-ap-northeast-1}
AWS_PROFILE=${AWS_PROFILE:-study}
ECR_REPOSITORY=${ECR_REPOSITORY:-potato-app}
IMAGE_TAG=${IMAGE_TAG:-latest}
LOCAL_IMAGE_NAME="potato-app"
TERRAFORM_DIR="terraform"

echo -e "${BLUE}=== ECRへのデプロイスクリプト ===${NC}"
echo -e "${BLUE}AWS Profile: ${AWS_PROFILE}${NC}"
echo -e "${BLUE}AWS Region: ${AWS_REGION}${NC}"
echo ""

# AWSアカウントIDを取得
echo -e "${BLUE}[1/6] AWSアカウント情報を取得中...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text 2>&1)
if [ $? -ne 0 ]; then
    echo -e "${RED}エラー: AWS認証情報が設定されていません${NC}"
    echo "プロファイル '${AWS_PROFILE}' が存在しません"
    echo ""
    echo "以下のいずれかを実行してください:"
    echo "  1. aws configure --profile ${AWS_PROFILE}"
    echo "  2. 環境変数でプロファイルを指定: AWS_PROFILE=default ./scripts/deploy-to-ecr.sh"
    exit 1
fi
echo -e "${GREEN}✓ AWSアカウントID: ${AWS_ACCOUNT_ID}${NC}"

# Terraformのoutput値を取得（存在する場合）
if [ -d "${TERRAFORM_DIR}" ] && [ -f "${TERRAFORM_DIR}/outputs.tf" ]; then
    echo -e "${BLUE}Terraform設定を検出しました${NC}"
    if [ -f "${TERRAFORM_DIR}/terraform.tfstate" ]; then
        echo -e "${BLUE}Terraformのoutputから情報を取得中...${NC}"
        TF_REPO_URL=$(cd ${TERRAFORM_DIR} && terraform output -raw repository_url 2>/dev/null || echo "")
        if [ -n "$TF_REPO_URL" ]; then
            echo -e "${GREEN}✓ Terraformで管理されているリポジトリを使用します${NC}"
            echo -e "  Repository URL: ${TF_REPO_URL}"
            ECR_URI="${TF_REPO_URL}"
        fi
    fi
fi

# ECRリポジトリURLを構築（Terraformから取得できなかった場合）
if [ -z "$ECR_URI" ]; then
    ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"
fi

# ECRリポジトリの存在確認
echo -e "${BLUE}[2/6] ECRリポジトリの存在確認中...${NC}"
if ! aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} --profile ${AWS_PROFILE} > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ リポジトリが存在しません${NC}"
    echo ""
    echo -e "${YELLOW}推奨: Terraformでリポジトリを管理することを推奨します${NC}"
    echo "  cd ${TERRAFORM_DIR}"
    echo "  terraform init"
    echo "  terraform apply"
    echo ""
    read -p "スクリプトでリポジトリを作成しますか? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}リポジトリを作成しています...${NC}"
        aws ecr create-repository \
            --repository-name ${ECR_REPOSITORY} \
            --region ${AWS_REGION} \
            --profile ${AWS_PROFILE} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --tags Key=ManagedBy,Value=Script Key=Project,Value=potato-app
        echo -e "${GREEN}✓ ECRリポジトリを作成しました${NC}"
        echo -e "${YELLOW}注意: Terraformで管理する場合は、既存リソースをインポートしてください${NC}"
        echo "  terraform import aws_ecr_repository.potato_app ${ECR_REPOSITORY}"
    else
        echo -e "${RED}リポジトリの作成をキャンセルしました${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ ECRリポジトリが存在します${NC}"
fi

# ECRにログイン
echo -e "${BLUE}[3/6] ECRにログイン中...${NC}"
aws ecr get-login-password --region ${AWS_REGION} --profile ${AWS_PROFILE} | \
    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
echo -e "${GREEN}✓ ECRにログインしました${NC}"

# Dockerイメージのビルド
echo -e "${BLUE}[4/6] Dockerイメージをビルド中...${NC}"
docker build -t ${LOCAL_IMAGE_NAME}:${IMAGE_TAG} .
echo -e "${GREEN}✓ Dockerイメージをビルドしました${NC}"

# イメージにタグ付け
echo -e "${BLUE}[5/6] イメージにタグを付与中...${NC}"
docker tag ${LOCAL_IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:${IMAGE_TAG}
docker tag ${LOCAL_IMAGE_NAME}:${IMAGE_TAG} ${ECR_URI}:$(git rev-parse --short HEAD)
echo -e "${GREEN}✓ タグを付与しました:${NC}"
echo "  - ${ECR_URI}:${IMAGE_TAG}"
echo "  - ${ECR_URI}:$(git rev-parse --short HEAD)"

# ECRにプッシュ
echo -e "${BLUE}[6/6] ECRにプッシュ中...${NC}"
docker push ${ECR_URI}:${IMAGE_TAG}
docker push ${ECR_URI}:$(git rev-parse --short HEAD)
echo -e "${GREEN}✓ ECRにプッシュしました${NC}"

echo ""
echo -e "${GREEN}=== デプロイ完了 ===${NC}"
echo -e "イメージURI: ${BLUE}${ECR_URI}:${IMAGE_TAG}${NC}"
echo -e "Git SHA: ${BLUE}${ECR_URI}:$(git rev-parse --short HEAD)${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "  1. ECSタスク定義でイメージURIを指定"
echo "  2. AWS Fargateでサービスを起動"
echo ""
echo -e "${BLUE}AWS コンソールで確認:${NC}"
echo "  https://console.aws.amazon.com/ecr/repositories/${ECR_REPOSITORY}?region=${AWS_REGION}"
