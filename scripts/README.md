# デプロイスクリプト

## deploy-to-ecr.sh

Spring BootアプリケーションをDockerイメージとしてビルドし、AWS ECRにプッシュするスクリプトです。

### 前提条件

1. AWS CLIがインストールされていること
2. AWS認証情報が設定されていること（`aws configure`）
3. Dockerが起動していること
4. 適切なAWS権限があること：
   - `ecr:CreateRepository`
   - `ecr:GetAuthorizationToken`
   - `ecr:BatchCheckLayerAvailability`
   - `ecr:PutImage`
   - `ecr:InitiateLayerUpload`
   - `ecr:UploadLayerPart`
   - `ecr:CompleteLayerUpload`

### 使い方

#### 基本的な使い方

```bash
# デフォルト設定で実行（リージョン: ap-northeast-1、リポジトリ名: potato-app）
./scripts/deploy-to-ecr.sh
```

#### 環境変数でカスタマイズ

```bash
# リージョンを変更
AWS_REGION=us-west-2 ./scripts/deploy-to-ecr.sh

# リポジトリ名を変更
ECR_REPOSITORY=my-app ./scripts/deploy-to-ecr.sh

# イメージタグを変更
IMAGE_TAG=v1.0.0 ./scripts/deploy-to-ecr.sh

# すべてをカスタマイズ
AWS_REGION=ap-northeast-1 ECR_REPOSITORY=potato-app IMAGE_TAG=production ./scripts/deploy-to-ecr.sh
```

### スクリプトの動作

1. AWS認証情報を確認
2. ECRリポジトリの存在確認（なければ自動作成）
3. ECRにログイン
4. Dockerイメージをビルド
5. イメージにタグを付与（`latest` と GitコミットSHA）
6. ECRにプッシュ

### トラブルシューティング

#### AWS認証エラー

```bash
# AWS認証情報を設定
aws configure

# 認証情報を確認
aws sts get-caller-identity
```

#### Docker未起動エラー

Dockerデスクトップを起動してください。

#### 権限エラー

IAMユーザーまたはロールにECR関連の権限を付与してください。

### 出力例

```
=== ECRへのデプロイスクリプト ===
[1/6] AWSアカウント情報を取得中...
✓ AWSアカウントID: 123456789012
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
```
