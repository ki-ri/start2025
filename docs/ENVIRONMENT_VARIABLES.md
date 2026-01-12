# 環境変数設定ガイド

## 概要

このアプリケーションは環境変数を使用して設定を管理します。これにより、環境ごとに異なる設定を柔軟に適用できます。

## 環境変数一覧

### 必須の環境変数

| 環境変数名 | 説明 | デフォルト値 | 本番環境での例 |
|-----------|------|------------|--------------|
| `DATABASE_URL` | PostgreSQL接続URL | `jdbc:postgresql://localhost:55432/demo` | `jdbc:postgresql://your-rds.amazonaws.com:5432/production_db` |
| `DATABASE_USERNAME` | データベースユーザー名 | `postgres` | `app_user` |
| `DATABASE_PASSWORD` | データベースパスワード | `password` | （セキュアなパスワード） |

### オプションの環境変数

#### データベース接続プール設定

| 環境変数名 | 説明 | デフォルト値（dev） | デフォルト値（prod） |
|-----------|------|------------------|-------------------|
| `DATABASE_POOL_SIZE` | 最大コネクション数 | `10` | `20` |
| `DATABASE_POOL_MIN_IDLE` | 最小アイドルコネクション数 | `2` | `5` |

#### サーバー設定

| 環境変数名 | 説明 | デフォルト値（dev） | デフォルト値（prod） |
|-----------|------|------------------|-------------------|
| `SERVER_PORT` | アプリケーションポート | `8089` | `8080` |
| `TOMCAT_MAX_THREADS` | Tomcat最大スレッド数 | - | `200` |
| `TOMCAT_MIN_SPARE_THREADS` | Tomcat最小スペアスレッド数 | - | `10` |
| `TOMCAT_ACCEPT_COUNT` | Tomcat受付キュー数 | - | `100` |
| `TOMCAT_MAX_CONNECTIONS` | Tomcat最大接続数 | - | `8192` |

#### ログ設定

| 環境変数名 | 説明 | デフォルト値（dev） | デフォルト値（prod） |
|-----------|------|------------------|-------------------|
| `LOG_LEVEL` | ルートログレベル | `INFO` | `WARN` |
| `APP_LOG_LEVEL` | アプリケーションログレベル | `DEBUG` | `INFO` |

#### Spring Profile

| 環境変数名 | 説明 | 使用可能な値 |
|-----------|------|------------|
| `SPRING_PROFILES_ACTIVE` | アクティブなSpring Profile | `dev`, `prod` |

## 環境別の設定例

### ローカル開発環境

`.env` ファイルを作成：

```bash
# .env
DATABASE_URL=jdbc:postgresql://localhost:55432/demo
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=password
SERVER_PORT=8089
LOG_LEVEL=INFO
APP_LOG_LEVEL=DEBUG
SPRING_PROFILES_ACTIVE=dev
```

実行：
```bash
# .envファイルを読み込んでアプリケーションを起動
./gradlew bootRun
```

### Docker Compose環境

`docker-compose.yml` がすでに設定済みです：

```bash
# データベースとアプリケーションを起動
docker-compose up -d

# ログを確認
docker-compose logs -f app

# 停止
docker-compose down
```

### AWS Fargate環境

#### ECS タスク定義での設定方法

タスク定義のJSON例：

```json
{
  "family": "potato-app",
  "containerDefinitions": [
    {
      "name": "potato-app",
      "image": "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/potato-app:latest",
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "prod"
        },
        {
          "name": "DATABASE_URL",
          "value": "jdbc:postgresql://your-rds-endpoint.rds.amazonaws.com:5432/production_db"
        },
        {
          "name": "DATABASE_USERNAME",
          "value": "app_user"
        },
        {
          "name": "DATABASE_POOL_SIZE",
          "value": "20"
        },
        {
          "name": "SERVER_PORT",
          "value": "8080"
        },
        {
          "name": "LOG_LEVEL",
          "value": "WARN"
        },
        {
          "name": "APP_LOG_LEVEL",
          "value": "INFO"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:prod/db/password"
        }
      ]
    }
  ]
}
```

#### AWS Secrets Manager を使用した機密情報の管理（推奨）

1. **シークレットの作成**

```bash
# データベースパスワードをSecrets Managerに保存
aws secretsmanager create-secret \
    --name prod/db/password \
    --description "Production database password" \
    --secret-string "your-secure-password-here" \
    --region ap-northeast-1
```

2. **タスク定義で参照**

タスク定義の `secrets` セクションで参照します（上記JSON例参照）。

#### Systems Manager Parameter Store を使用する方法

```bash
# パラメータの作成
aws ssm put-parameter \
    --name /potato-app/prod/database-password \
    --value "your-secure-password" \
    --type SecureString \
    --region ap-northeast-1
```

タスク定義：
```json
{
  "secrets": [
    {
      "name": "DATABASE_PASSWORD",
      "valueFrom": "arn:aws:ssm:ap-northeast-1:123456789012:parameter/potato-app/prod/database-password"
    }
  ]
}
```

## セキュリティのベストプラクティス

1. **機密情報は環境変数に直接書かない**
   - AWS Secrets Manager または Systems Manager Parameter Store を使用
   - `.env` ファイルは `.gitignore` に追加（既に設定済み）

2. **本番環境では必ず `prod` プロファイルを使用**
   ```bash
   SPRING_PROFILES_ACTIVE=prod
   ```

3. **データベースパスワードは強力なものを使用**
   - 最低16文字以上
   - 大文字・小文字・数字・記号を含む

4. **ログレベルを適切に設定**
   - 本番環境: `LOG_LEVEL=WARN`, `APP_LOG_LEVEL=INFO`
   - 開発環境: `LOG_LEVEL=INFO`, `APP_LOG_LEVEL=DEBUG`

## トラブルシューティング

### データベース接続エラー

```
Unable to acquire JDBC Connection
```

**確認項目：**
1. `DATABASE_URL` が正しいか確認
2. データベースが起動しているか確認
3. ネットワーク接続が可能か確認（セキュリティグループ設定など）

### 環境変数が反映されない

**確認項目：**
1. 環境変数名のスペルミスがないか確認
2. タスク定義を更新した後、サービスを再デプロイしたか確認
3. `SPRING_PROFILES_ACTIVE` が正しく設定されているか確認

### ヘルスチェックが失敗する

**確認項目：**
1. アプリケーションが起動完了したか確認（起動に60秒程度かかります）
2. `SERVER_PORT` とヘルスチェックのポートが一致しているか確認
3. `/actuator/health` エンドポイントにアクセスできるか確認

## 参考リンク

- [Spring Boot Externalized Configuration](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
