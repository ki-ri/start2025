-- 初期データベーススキーマとデータ

-- usersテーブルの作成
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- テストデータの挿入
INSERT INTO users (name) VALUES
    ('Alice'),
    ('Bob'),
    ('Charlie')
ON CONFLICT DO NOTHING;
