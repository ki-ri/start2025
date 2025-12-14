#!/bin/bash
set -e

# 色付き出力用
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 設定
AWS_REGION=${AWS_REGION:-ap-northeast-1}
ECR_REPOSITORY=${ECR_REPOSITORY:-potato-app}
IMAGE_TAG=${IMAGE_TAG:-latest}
LOCAL_IMAGE_NAME="potato-app"

echo -e "${BLUE}=== ECRへのデプロイスクリプト ===${NC}"

# AWSアカウントIDを取得
echo -e "${BLUE}[1/6] AWSアカウント情報を取得中...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}エラー: AWS認証情報が設定されていません${NC}"
    echo "aws configure を実行してください"
    exit 1
fi
echo -e "${GREEN}✓ AWSアカウントID: ${AWS_ACCOUNT_ID}${NC}"

# ECRリポジトリURLを構築
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

# ECRリポジトリの存在確認
echo -e "${BLUE}[2/6] ECRリポジトリの存在確認中...${NC}"
if ! aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} > /dev/null 2>&1; then
    echo -e "${BLUE}リポジトリが存在しないため作成します...${NC}"
    aws ecr create-repository \
        --repository-name ${ECR_REPOSITORY} \
        --region ${AWS_REGION} \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
    echo -e "${GREEN}✓ ECRリポジトリを作成しました${NC}"
else
    echo -e "${GREEN}✓ ECRリポジトリが存在します${NC}"
fi

# ECRにログイン
echo -e "${BLUE}[3/6] ECRにログイン中...${NC}"
aws ecr get-login-password --region ${AWS_REGION} | \
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
