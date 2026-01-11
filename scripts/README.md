# デプロイスクリプト

## deploy-to-ecr.sh

Spring BootアプリケーションをDockerイメージとしてビルドし、AWS ECRにプッシュするスクリプトです。

### 前提条件

1. AWS CLIがインストールされていること
2. AWS認証情報が設定されていること
   - プロファイル `study` を推奨（Terraform設定と一致）
   - `aws configure --profile study`
3. Dockerが起動していること
4. 適切なAWS権限があること：
   - `ecr:CreateRepository`
   - `ecr:DescribeRepositories`
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:PutImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`

### Terraform統合

このスクリプトはTerraformで管理されたECRリポジトリと統合されています。

- `terraform/` ディレクトリに設定がある場合、自動的に検出
- Terraformのoutputからリポジトリ情報を取得
- リポジトリが存在しない場合、Terraformでの作成を推奨

### 使い方

#### 基本的な使い方

```bash
# デフォルト設定で実行
# - AWS Profile: study
# - リージョン: ap-northeast-1
# - リポジトリ名: potato-app
./scripts/deploy-to-ecr.sh
```

#### Terraformでリポジトリを事前作成（推奨）

```bash
# Terraformでインフラを構築
cd terraform
terraform init
terraform apply

# デプロイスクリプトを実行（Terraformのoutputを自動利用）
cd ..
./scripts/deploy-to-ecr.sh
```

#### 環境変数でカスタマイズ

利用可能な環境変数（すべてTerraform `variables.tf` のデフォルト値に準拠）:

| 環境変数 | デフォルト値 | 説明 |
|---------|------------|------|
| `AWS_PROFILE` | `study` | AWS CLIプロファイル名 |
| `AWS_REGION` | `ap-northeast-1` | AWSリージョン |
| `ECR_REPOSITORY` | `potato-app` | ECRリポジトリ名 |
| `IMAGE_TAG` | `latest` | Dockerイメージタグ |

```bash
# 異なるプロファイルを使用
AWS_PROFILE=default ./scripts/deploy-to-ecr.sh

# リージョンを変更
AWS_REGION=us-west-2 ./scripts/deploy-to-ecr.sh

# リポジトリ名を変更
ECR_REPOSITORY=my-app ./scripts/deploy-to-ecr.sh

# イメージタグを変更
IMAGE_TAG=v1.0.0 ./scripts/deploy-to-ecr.sh

# すべてをカスタマイズ
AWS_PROFILE=production AWS_REGION=ap-northeast-1 ECR_REPOSITORY=potato-app IMAGE_TAG=production ./scripts/deploy-to-ecr.sh
```

### スクリプトの動作

1. AWS認証情報を確認（指定されたプロファイルで）
2. Terraformのoutputから情報を取得（存在する場合）
3. ECRリポジトリの存在確認
   - 存在する場合: 次のステップへ
   - 存在しない場合: Terraformでの作成を推奨
     - ユーザーがスクリプトでの作成を選択した場合、リポジトリを作成
4. ECRにログイン
5. Dockerイメージをビルド
6. イメージにタグを付与（`latest` と GitコミットSHA）
7. ECRにプッシュ

### トラブルシューティング

#### AWS認証エラー（プロファイル関連）

```bash
# studyプロファイルを設定
aws configure --profile study

# プロファイルの認証情報を確認
aws sts get-caller-identity --profile study

# または、デフォルトプロファイルを使用
AWS_PROFILE=default ./scripts/deploy-to-ecr.sh
```

#### Docker未起動エラー

Dockerデスクトップを起動してください。

#### 権限エラー

IAMユーザーまたはロールにECR関連の権限を付与してください。

#### Terraform統合の問題

```bash
# Terraformの状態を確認
cd terraform
terraform output

# 状態がない場合は、まず apply を実行
terraform init
terraform apply

# 既存のECRリポジトリをTerraformにインポート（スクリプトで作成した場合）
terraform import aws_ecr_repository.potato_app potato-app
```

### 出力例

#### Terraformと統合した場合

```
=== ECRへのデプロイスクリプト ===
AWS Profile: study
AWS Region: ap-northeast-1

[1/6] AWSアカウント情報を取得中...
✓ AWSアカウントID: 123456789012
Terraform設定を検出しました
Terraformのoutputから情報を取得中...
✓ Terraformで管理されているリポジトリを使用します
  Repository URL: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app
[2/6] ECRリポジトリの存在確認中...
✓ ECRリポジトリが存在します
[3/6] ECRにログイン中...
✓ ECRにログインしました
[4/6] Dockerイメージをビルド中...
✓ Dockerイメージをビルドしました
[5/6] イメージにタグを付与中...
✓ タグを付与しました:
  - 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app:latest
  - 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app:860a545
[6/6] ECRにプッシュ中...
✓ ECRにプッシュしました

=== デプロイ完了 ===
イメージURI: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app:latest
Git SHA: 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app:860a545

次のステップ:
  1. ECSタスク定義でイメージURIを指定
  2. AWS Fargateでサービスを起動

AWS コンソールで確認:
  https://console.aws.amazon.com/ecr/repositories/potato-app?region=ap-northeast-1
```
