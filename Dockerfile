# ビルドステージ
FROM gradle:8.5-jdk21 AS builder

WORKDIR /app

# Gradleのキャッシュを活用するため、依存関係を先にダウンロード
COPY build.gradle.kts settings.gradle.kts ./
COPY gradle gradle
COPY gradlew ./
RUN gradle dependencies --no-daemon || true

# ソースコードをコピー
COPY src ./src

# アプリケーションをビルド（テストはスキップ）
RUN gradle bootJar --no-daemon -x test

# ランタイムステージ
FROM eclipse-temurin:21-jre-jammy

WORKDIR /app

# 非rootユーザーを作成
RUN groupadd -r spring && useradd -r -g spring spring

# ビルドしたJARファイルをコピー
COPY --from=builder /app/build/libs/*.jar app.jar

# ユーザーを切り替え
RUN chown -R spring:spring /app
USER spring

# アプリケーションのポート
EXPOSE 8089

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8089/actuator/health || exit 1

# JVMオプションとアプリケーション起動
ENTRYPOINT ["java", \
            "-XX:+UseContainerSupport", \
            "-XX:MaxRAMPercentage=75.0", \
            "-Djava.security.egd=file:/dev/./urandom", \
            "-jar", \
            "app.jar"]
