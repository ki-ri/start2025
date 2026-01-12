# Terraform でAWS Fargateインフラストラクチャを管理

このディレクトリには、Spring BootアプリケーションをAWS Fargateにデプロイするための完全なインフラストラクチャをTerraformで管理する設定が含まれています。

## インフラストラクチャ構成

```
┌─────────────────────────────────────────────────────────┐
│                      Internet                            │
└─────────────────┬───────────────────────────────────────┘
                  │
          ┌───────▼────────┐
          │ Application    │
          │ Load Balancer  │
          │ (Public)       │
          └───────┬────────┘
                  │
    ┌─────────────┴─────────────┐
    │         VPC                │
    │  ┌────────────────────┐   │
    │  │  Public Subnets    │   │
    │  │  (2 AZs)           │   │
    │  └────────────────────┘   │
    │           │                │
    │  ┌────────▼───────────┐   │
    │  │  Private Subnets   │   │
    │  │  (2 AZs)           │   │
    │  │                    │   │
    │  │  ┌──────────────┐  │   │
    │  │  │ ECS Fargate  │  │   │
    │  │  │ Tasks        │  │   │
    │  │  └──────┬───────┘  │   │
    │  │         │          │   │
    │  │  ┌──────▼───────┐  │   │
    │  │  │ RDS          │  │   │
    │  │  │ PostgreSQL   │  │   │
    │  │  └──────────────┘  │   │
    │  └────────────────────┘   │
    └───────────────────────────┘
```

## 作成されるリソース

### ネットワーク
- **VPC**: 10.0.0.0/16
- **Public Subnets**: 2つのAvailability Zoneに配置（ALB用）
- **Private Subnets**: 2つのAvailability Zoneに配置（ECS Tasks、RDS用）
- **Internet Gateway**: パブリックサブネットのインターネット接続
- **NAT Gateway**: プライベートサブネットからの外部通信（ECRイメージ取得用）

### コンピューティング
- **ECR Repository**: Dockerイメージの保存
- **ECS Cluster**: Fargateクラスター
- **ECS Task Definition**: アプリケーションコンテナの定義
- **ECS Service**: 高可用性のためのタスク管理（2つのタスク）
- **Application Load Balancer**: トラフィックの分散

### データベース
- **RDS PostgreSQL**: フルマネージドデータベース（db.t4g.micro）
- **Secrets Manager**: データベースパスワードの安全な保管

### セキュリティ
- **Security Groups**: ALB、ECS Tasks、RDSの通信制御
- **IAM Roles**: ECSタスク実行用の権限管理

### モニタリング
- **CloudWatch Logs**: アプリケーションログの集約
- **Container Insights**: ECSクラスターのメトリクス収集

## 前提条件

1. **Terraformのインストール（バージョン1.0以上）**
   ```bash
   # tfenvでバージョン管理（推奨）
   brew install tfenv
   tfenv install latest
   tfenv use latest

   # バージョン確認
   terraform version
   ```

2. **AWS CLIの設定**
   ```bash
   # AWS認証情報の設定（studyプロファイル）
   aws configure --profile study

   # 認証確認
   aws sts get-caller-identity --profile study
   ```

3. **Dockerイメージの準備**
   ```bash
   # ECRにイメージをプッシュ
   ./scripts/deploy-to-ecr.sh
   ```

4. **必要な権限**
   - ECR: CreateRepository, DescribeRepositories, GetAuthorizationToken
   - VPC: CreateVpc, CreateSubnet, CreateInternetGateway, CreateNatGateway
   - ECS: CreateCluster, CreateService, RegisterTaskDefinition
   - RDS: CreateDBInstance, CreateDBSubnetGroup
   - ELB: CreateLoadBalancer, CreateTargetGroup
   - IAM: CreateRole, AttachRolePolicy
   - Secrets Manager: CreateSecret, PutSecretValue
   - CloudWatch Logs: CreateLogGroup

## ファイル構成

```
terraform/
├── main.tf                 # プロバイダー設定、ECRリポジトリ
├── variables.tf            # 変数定義
├── outputs.tf              # 出力定義
├── vpc.tf                  # VPC、サブネット、ルーティング
├── security_groups.tf      # セキュリティグループ
├── rds.tf                  # RDS PostgreSQL、Secrets Manager
├── alb.tf                  # Application Load Balancer
├── ecs.tf                  # ECS、Fargate、IAMロール
├── terraform.tfvars        # 変数の値（Git管理外）
└── README.md               # このファイル
```

## 使用方法

### 1. 初回セットアップ

```bash
# terraformディレクトリに移動
cd terraform

# Terraformの初期化（プロバイダーのダウンロード）
terraform init
```

### 2. 実行計画の確認

```bash
# 作成されるリソースを確認
terraform plan

# プロファイルを指定する場合
AWS_PROFILE=study terraform plan
```

### 3. インフラストラクチャの作成

```bash
# リソースを作成（約10-15分かかります）
terraform apply

# 自動承認する場合
terraform apply -auto-approve
```

**注意**: RDSインスタンスの作成には5-10分程度かかります。

### 4. デプロイ後の確認

```bash
# 出力値を確認
terraform output

# アプリケーションURLを取得
terraform output -raw application_url

# ALB DNS名を取得
terraform output -raw alb_dns_name
```

### 5. アプリケーションへのアクセス

```bash
# 出力されたURLにアクセス
curl http://$(terraform output -raw alb_dns_name)/api/users

# ブラウザでアクセス
open http://$(terraform output -raw alb_dns_name)
```

### 6. リソースの削除

```bash
# すべてのリソースを削除
terraform destroy

# 確認メッセージで "yes" を入力
```

**警告**: RDSデータベースのデータも削除されます。本番環境では `skip_final_snapshot = false` に設定してください。

## 設定のカスタマイズ

`variables.tf` で定義されている変数をカスタマイズできます。

### 主要な変数

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `aws_region` | `ap-northeast-1` | AWSリージョン |
| `aws_profile` | `study` | AWS CLIプロファイル |
| `vpc_cidr` | `10.0.0.0/16` | VPCのCIDRブロック |
| `db_instance_class` | `db.t4g.micro` | RDSインスタンスタイプ |
| `container_cpu` | `512` | コンテナCPU（1024 = 1 vCPU） |
| `container_memory` | `1024` | コンテナメモリ（MB） |
| `desired_count` | `2` | ECSタスク数 |

### カスタマイズ例

`terraform.tfvars` ファイルを作成して変数を上書きできます：

```hcl
# リージョンの変更
aws_region = "us-west-2"

# RDSインスタンスのスケールアップ
db_instance_class = "db.t4g.small"

# コンテナリソースの増加
container_cpu    = 1024
container_memory = 2048

# タスク数の変更
desired_count = 3

# NAT Gatewayを無効化（コスト削減、開発環境用）
enable_nat_gateway = false
```

## 出力値

`terraform apply` 実行後、以下の情報が出力されます：

### ECR
- `repository_url`: ECRリポジトリURL
- `repository_name`: リポジトリ名

### ネットワーク
- `vpc_id`: VPC ID
- `public_subnet_ids`: パブリックサブネットID一覧
- `private_subnet_ids`: プライベートサブネットID一覧

### データベース
- `db_endpoint`: RDSエンドポイント
- `db_address`: RDSアドレス
- `db_name`: データベース名
- `db_secret_arn`: パスワードのSecrets Manager ARN

### ロードバランサー
- `alb_dns_name`: ALB DNS名（アプリケーションアクセス用）
- `alb_arn`: ALB ARN
- `target_group_arn`: ターゲットグループARN

### ECS
- `ecs_cluster_name`: ECSクラスター名
- `ecs_service_name`: ECSサービス名
- `ecs_task_definition_arn`: タスク定義ARN

### アプリケーション
- `application_url`: アプリケーションURL（http://ALB-DNS）

## コスト概算（東京リージョン）

| サービス | スペック | 月額概算 |
|---------|---------|---------|
| RDS PostgreSQL | db.t4g.micro | $15-20 |
| ECS Fargate | 0.5 vCPU, 1GB x 2 | $25-30 |
| ALB | - | $20-25 |
| NAT Gateway | - | $35-40 |
| データ転送 | 軽微 | $5-10 |
| **合計** | | **$100-125/月** |

**コスト削減のヒント:**
- 開発環境では `enable_nat_gateway = false` を設定
- `desired_count = 1` でタスク数を削減
- 使用しない時間帯は `terraform destroy` でリソースを削除

## データベース初期設定

RDSインスタンスは空の状態で作成されます。初期データを投入する場合：

### 方法1: ECSタスクから初期化スクリプトを実行

```bash
# ECSタスクに接続
aws ecs execute-command \
  --cluster potato-app-cluster \
  --task <task-id> \
  --container potato-app \
  --interactive \
  --command "/bin/bash"

# データベースに接続して初期化
psql -h <db-endpoint> -U postgres -d demo < init.sql
```

### 方法2: RDS Data API（推奨）

Secrets Managerに保存されたパスワードを使用してスクリプトから初期化できます。

## トラブルシューティング

### ECSタスクが起動しない

**症状**: タスクが `PENDING` 状態のまま、または即座に終了する

**確認項目**:
```bash
# ECSタスクのログを確認
aws logs tail /ecs/potato-app --follow --profile study

# タスクの詳細を確認
aws ecs describe-tasks \
  --cluster potato-app-cluster \
  --tasks <task-arn> \
  --profile study
```

**よくある原因**:
1. ECRイメージが存在しない → `./scripts/deploy-to-ecr.sh` を実行
2. NAT Gatewayがない → `enable_nat_gateway = true` に設定
3. データベース接続エラー → RDSのセキュリティグループ確認

### ALB経由でアクセスできない

**確認項目**:
```bash
# ターゲットグループのヘルスチェック状態を確認
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --profile study
```

**よくある原因**:
1. ヘルスチェックパス `/actuator/health` にアクセスできない
2. セキュリティグループの設定ミス
3. タスクが起動していない

### データベース接続エラー

**確認項目**:
```bash
# Secrets Managerからパスワードを取得
aws secretsmanager get-secret-value \
  --secret-id potato-app-db-password \
  --profile study

# RDSエンドポイントを確認
terraform output db_endpoint
```

### コスト超過

**対策**:
```bash
# 開発時はNAT Gatewayを削除
terraform apply -var="enable_nat_gateway=false"

# タスク数を削減
terraform apply -var="desired_count=1"

# 完全に停止
terraform destroy
```

## セキュリティベストプラクティス

1. **データベースパスワード**
   - Secrets Managerで自動生成
   - 手動設定する場合は `db_password` 変数を使用（機密情報として扱う）

2. **ネットワークセキュリティ**
   - ECSタスクとRDSはプライベートサブネットに配置
   - セキュリティグループで最小権限の原則を適用

3. **暗号化**
   - RDS: ストレージ暗号化有効
   - ECR: AES256暗号化

4. **モニタリング**
   - CloudWatch Logsでアプリケーションログを収集
   - Container Insightsでメトリクスを監視

## CI/CD統合

GitHub ActionsなどのCI/CDパイプラインとの統合例：

```yaml
- name: Deploy to ECR
  run: ./scripts/deploy-to-ecr.sh

- name: Update ECS Service
  run: |
    aws ecs update-service \
      --cluster potato-app-cluster \
      --service potato-app-service \
      --force-new-deployment \
      --profile study
```

## 参考リンク

- [Terraform AWS Provider - ECS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/fargate/)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [RDS PostgreSQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
