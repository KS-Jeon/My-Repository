#!/bin/bash

# 0) 헬스체크 파일을 먼저 만들어두기 (설치가 길어져도 빨리 200 응답 가능)
mkdir -p /var/www/html
echo OK > /var/www/html/healthz
chmod 644 /var/www/html/healthz

# 1) httpd 설치
dnf -y install httpd

# 2) Parameter Store에서 App 엔드포인트 조회
APP_ENDPOINT=$(aws ssm get-parameter \
  --name "/dev/web/app_endpoint" \
  --query "Parameter.Value" \
  --output text \
  --region "ap-northeast-2")

echo "APP_ENDPOINT=${APP_ENDPOINT}" >> /etc/environment

# 3) 기본 페이지
cat > /var/www/html/index.html <<'HTML'
<h1>Web Tier OK</h1>
<ul>
  <li><a href="/app">/app (proxy → App)</a></li>
  <li><a href="/app/db">/app/db (App → RDS)</a></li>
</ul>
HTML

# 4) 리버스 프록시
cat > /etc/httpd/conf.d/revproxy.conf <<CONF
ProxyRequests Off
ProxyPreserveHost On

RedirectMatch 301 ^/app$ /app/

ProxyPass        /app/ http://${APP_ENDPOINT}/app/
ProxyPassReverse /app/ http://${APP_ENDPOINT}/app/
CONF

# 6) 기동
apachectl configtest
systemctl enable httpd
systemctl restart httpd