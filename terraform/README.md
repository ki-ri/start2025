# Terraform で ECR リポジトリを管理

このディレクトリには、AWS ECR（Elastic Container Registry）リポジトリをTerraformで管理するための設定が含まれています。

## 前提条件

1. **Terraformのインストール**
   ```bash
   # Homebrewでインストール（macOS）
   brew install terraform

   # バージョン確認
   terraform version
   ```

2. **AWS CLIの設定**
   ```bash
   # AWS認証情報の設定
   aws configure
   ```

3. **必要な権限**
   - `ecr:CreateRepository`
   - `ecr:DescribeRepositories`
   - `ecr:DeleteRepository`
   - `ecr:PutLifecyclePolicy`
   - `ecr:GetLifecyclePolicy`

## ファイル構成

```
terraform/
├── main.tf                    # メインの設定（ECRリポジトリ定義）
├── variables.tf               # 変数定義
├── outputs.tf                 # 出力定義
├── terraform.tfvars.example   # 変数の設定例
└── README.md                  # このファイル
```

## 使用方法

### 1. 初回セットアップ

```bash
# terraformディレクトリに移動
cd terraform

# 変数ファイルを作成（必要に応じてカスタマイズ）
cp terraform.tfvars.example terraform.tfvars

# Terraformの初期化
terraform init
```

### 2. 実行計画の確認

```bash
# 変更内容を確認
terraform plan
```

### 3. リソースの作成

```bash
# ECRリポジトリを作成
terraform apply

# 確認メッセージで "yes" を入力
```

### 4. リソースの確認

```bash
# 作成されたリソースの情報を表示
terraform show

# 出力値のみを表示
terraform output
```

### 5. リソースの削除（必要な場合）

```bash
# ECRリポジトリを削除
terraform destroy

# 確認メッセージで "yes" を入力
```

## 設定のカスタマイズ

`terraform.tfvars` ファイルを編集して、以下の設定をカスタマイズできます：

### リージョンの変更

```hcl
aws_region = "us-west-2"
```

### リポジトリ名の変更

```hcl
repository_name = "my-app"
```

### イメージタグの変更不可設定

本番環境では、イメージタグを変更不可にすることを推奨します：

```hcl
image_tag_mutability = "IMMUTABLE"
```

### ライフサイクルポリシーの調整

```hcl
max_image_count = 50   # 保持する最大イメージ数を増やす
untagged_days   = 3    # タグなしイメージの保持期間を短縮
```

## 出力値

Terraform applyの実行後、以下の情報が出力されます：

- **repository_url**: ECRリポジトリのURL（Dockerイメージのプッシュ先）
- **repository_arn**: ECRリポジトリのARN
- **repository_name**: ECRリポジトリ名
- **registry_id**: ECRレジストリID（AWSアカウントID）

### 出力値の使用例

```bash
# リポジトリURLを取得
export ECR_URL=$(terraform output -raw repository_url)
echo $ECR_URL

# Dockerイメージにタグ付け
docker tag potato-app:latest $ECR_URL:latest
```

## ライフサイクルポリシー

自動的に以下のライフサイクルポリシーが設定されます：

1. **タグ付きイメージ**: `v*` で始まるタグのイメージを最大30個保持（設定可能）
2. **タグなしイメージ**: 7日以上古いタグなしイメージを自動削除（設定可能）

これによりストレージコストを最適化できます。

## トラブルシューティング

### 認証エラー

```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**解決方法:**
```bash
# AWS認証情報を設定
aws configure

# または環境変数を設定
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

### リポジトリが既に存在するエラー

```
Error: creating ECR Repository: RepositoryAlreadyExistsException
```

**解決方法:**
```bash
# 既存のリポジトリをTerraformにインポート
terraform import aws_ecr_repository.potato_app potato-app
```

### 権限エラー

```
Error: AccessDeniedException: User is not authorized to perform: ecr:CreateRepository
```

**解決方法:**
IAMユーザーまたはロールに必要な権限を付与してください。

## ベストプラクティス

1. **バージョン管理**
   - `terraform.tfvars` は `.gitignore` に追加済み（機密情報保護）
   - Terraform stateファイルはリモートバックエンド（S3等）に保存することを推奨

2. **環境分離**
   - 開発・ステージング・本番で異なるリポジトリを使用
   - Terraform Workspacesを活用

3. **セキュリティ**
   - 本番環境では `image_tag_mutability = "IMMUTABLE"` を使用
   - イメージスキャンを有効化（`scan_on_push = true`）

4. **コスト最適化**
   - ライフサイクルポリシーで不要なイメージを自動削除
   - 定期的に使用状況を確認

## 参考リンク

- [Terraform AWS Provider - ECR Repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
