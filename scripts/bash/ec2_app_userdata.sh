#!/bin/bash

# Node.js와 npm 설치 (Amazon Linux 2023 기준)
dnf -y install nodejs npm mariadb105   # mariadb105 = MySQL 클라이언트

# 앱 디렉터리
mkdir -p /opt/app
cd /opt/app

# 의존성 설치
npm init -y
npm install express mysql2

# 앱 코드 작성 (server.js)
cat > /opt/app/server.js << 'JS'
const express = require('express');
const mysql = require('mysql2/promise');

const app = express();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0
});

app.get('/health', (_, res) => res.status(200).send('OK'));

app.get('/app', (_, res) => {
  res.send('<h1>App Tier (Node.js) OK</h1><a href="/app/db">/app/db</a>');
});

app.get('/app/db', async (_, res) => {
  try {
    const [[alice]] = await pool.query(
      'SELECT id, name, email, created_at FROM users WHERE email = ? LIMIT 1',
      ['alice@example.com']
    );
    res.json({ status: 'ok', user: alice || null });
  } catch (err) {
    console.error(err);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, '0.0.0.0', () => console.log(`App listening on ${port}`));
JS

# 1) 파라미터 스토어에서 DB 접속 정보 조회
DB_HOST=$(aws ssm get-parameter --name "/dev/app/dbhost" --region "ap-northeast-2" --query "Parameter.Value" --output text)
DB_USER=$(aws ssm get-parameter --name "/dev/app/dbuser" --region "ap-northeast-2" --query "Parameter.Value" --output text)
DB_PASS=$(aws ssm get-parameter --name "/dev/app/dbpass" --with-decryption --region "ap-northeast-2" --query "Parameter.Value" --output text)
DB_NAME=$(aws ssm get-parameter --name "/dev/app/dbname" --region "ap-northeast-2" --query "Parameter.Value" --output text)

# 2) 환경변수에 저장 (systemd 서비스에서 로드)
echo "DB_HOST=$DB_HOST" >> /etc/environment
echo "DB_USER=$DB_USER" >> /etc/environment
echo "DB_PASS=$DB_PASS" >> /etc/environment
echo "DB_NAME=$DB_NAME" >> /etc/environment

# 3) DB 없으면 생성 (문자셋 권장)
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e \
"CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 4) users 테이블 없을 때만 생성 + 시드
TABLE_EXISTS=$(mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -Nse \
"SELECT COUNT(*) FROM information_schema.tables
 WHERE table_schema='$DB_NAME' AND table_name='users';")

if [ "${TABLE_EXISTS:-0}" -eq 0 ]; then
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
SQL
fi

# 5) systemd 유닛 작성
cat > /etc/systemd/system/app.service << 'UNIT'
[Unit]
Description=Node.js App Service (App Tier)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node /opt/app/server.js
Restart=always
RestartSec=3
Environment=PORT=8080
EnvironmentFile=-/etc/environment
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

# 6) 서비스 기동
systemctl daemon-reload
systemctl enable app
systemctl restart app
