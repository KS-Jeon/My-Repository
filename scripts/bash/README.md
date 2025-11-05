## Script: `ec2_web_userdata.sh`

**용도**  
EC2 인스턴스를 **Web Tier**로 구성하기 위한 초기 설정 스크립트입니다.  
Apache(httpd)를 설치하고, **Application Tier(ALB 또는 EC2)로 리버스 프록시 설정**,  
그리고 **헬스체크 엔드포인트 제공**까지 자동으로 수행합니다.

**주요 동작 흐름**
1. `/var/www/html/healthz` 파일 생성 → ALB / NLB / Target Group 헬스체크용 200 OK 응답 준비
2. `httpd` 설치 및 서비스 활성화
3. **AWS Systems Manager Parameter Store**에서 `app_endpoint` 값을 조회하여 App Tier 주소 자동 반영
4. 기본 웹 페이지 `/var/www/html/index.html` 생성
5. `/app` 경로 요청을 App Tier로 전달하는 **Reverse Proxy** 설정
6. Apache 설정 테스트 후 서비스 재시작

**사용되는 Parameter Store Key**
| Key | 예시 값 | 설명 |
|---|---|---|
| `/dev/web/app_endpoint` | `app.internal:8080` 또는 `app-alb-xxxx.amazonaws.com` | App Tier 엔드포인트 |

**이 스크립트가 유용한 상황**
- 3-Tier 아키텍처 (Web → App → DB) 데모 / PoC 환경 구성
- ASG + ALB 기반 EC2 Web Tier 자동부팅 환경
- Terraform / CDK / CloudFormation User Data에 그대로 포함 가능

**사전 조건**
- EC2 인스턴스는 SSM Agent가 활성화된 AMI 사용 권장
- `ssm:GetParameter` IAM 권한이 필요한 인스턴스 프로파일 부여

---

## Script: `ec2_app_userdata.sh`

**용도**  
EC2 인스턴스를 **App Tier (Node.js 기반 애플리케이션 서버)** 로 자동 구성하는 사용자 데이터 스크립트입니다.  
DB 접속 정보는 **SSM Parameter Store에서 자동 조회**하며,  
Node.js 앱을 **systemd 서비스로 등록**하여 인스턴스 재부팅 후에도 자동 실행되도록 합니다.

**주요 동작 흐름**
1. Node.js / npm 설치 (Amazon Linux 2023 기준)
2. `/opt/app` 디렉터리에 Express + MySQL2 기반 Node.js App 생성
3. **Parameter Store**에서 DB 접속 정보 조회 → `/etc/environment`에 저장
4. DB 존재 여부 확인 후 없으면 자동 생성 + `users` 테이블 시드 데이터 주입
5. Node.js 앱을 `systemd` 서비스(`app.service`)로 등록 및 기동

**App 엔드포인트 구조**
| 경로 | 설명 |
|---|---|
| `/health` | 헬스체크 (200 OK 반환) |
| `/app` | App Tier 정상동작 확인 페이지 |
| `/app/db` | DB 연결 테스트 + 사용자 정보 조회 반환(JSON) |

**사용되는 Parameter Store Key**
| Key | 예시 값 | 설명 |
|---|---|---|
| `/dev/app/dbhost` | `mydb.cluster-xxxx.ap-northeast-2.rds.amazonaws.com` | RDS 호스트 |
| `/dev/app/dbuser` | `appuser` | DB 계정 ID |
| `/dev/app/dbpass` | `*****` | DB 비밀번호 (**SecureString**) |
| `/dev/app/dbname` | `appdb` | 데이터베이스 이름 |

**DB 초기화 동작**
- DB가 없으면 자동 생성 (`utf8mb4`)
- users 테이블이 없으면 생성 + Alice 샘플 데이터 삽입

**systemd 서비스 정보**
| 항목 | 값 |
|---|---|
| 서비스명 | `app.service` |
| 포트 | `8080` (환경변수 변경 가능) |
| 실행 디렉터리 | `/opt/app` |
| 재시작 정책 | `always` |

**이 스크립트가 유용한 상황**
- Web → App → DB **3-Tier 아키텍처 데모 / PoC 환경 자동 구성**
- ASG + Launch Template 환경에서 **수평 확장 시 자동 초기화**
- Terraform / CDK / CloudFormation User Data에 그대로 적용 가능

**전제 조건**
- DB Security Group이 App Tier 인스턴스 CIDR or SG ID 허용하도록 구성되어 있어야 함

