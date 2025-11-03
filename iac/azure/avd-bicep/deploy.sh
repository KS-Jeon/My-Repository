set -e

echo "=============================="
echo "Azure Bicep 배포 자동화 스크립트"
echo "=============================="
# -------------------------------------------------------------------------
# Azure CLI 로그인 및 구독 설정 (이미 로그인되어 있다면 생략 가능)
# -------------------------------------------------------------------------
if ! az account show > /dev/null 2>&1; then
  echo "Azure에 로그인합니다..."
  az login
fi

echo ""
echo "[*] 사용 가능한 구독 목록:"
az account list --output table

echo ""
read -rp "설정할 구독 이름(Subscription name)을 입력하세요: " SUB_NAME

if [ -z "$SUB_NAME" ]; then
  echo "[!] 구독 이름이 입력되지 않아 작업을 중단합니다."
  exit 1
fi
# 구독 지정 
echo ""
echo "[*] 구독을 '$SUB_NAME'으로 설정합니다..."
az account set --subscription "$SUB_NAME"
  
# 설정 결과 확인
echo "[*] 현재 설정된 구독:"
az account show --output table

# -------------------------------------------------------------------------
# Azure 리소스 그룹 지정
# -------------------------------------------------------------------------
echo ""
read -rp "지정할 리소스그룹 이름(ResourceGroup name)을 입력하세요: " resourceGroupName
echo ""
# -------------------------------------------------------------------------
# 사용자 입력 받기 (관리자 비밀번호와 생성할 VM 개수)
# -------------------------------------------------------------------------
# 관리자 비밀번호 (비밀 입력)
read -s -p "관리자 비밀번호를 입력하세요: " adminPassword
echo ""
# 시작할 VM 숫자 입력력
read -p "시작할 VM 번호를 입력하세요( 최소값 0 ): " vmNum
echo ""
# 생성할 VM 개수 입력
read -p "생성할 VM 개수를 입력하세요( 최소값 1 ): " vmCount
echo ""
# 지정할 호스트풀 이름 입력
read -p "호스트풀 이름을 입력하세요: " hostPoolName
echo ""
# Domain Join 유형 선택
while true; do
  read -p "Domain Join 유형을 선택하세요 (true : EntraID / false : WindowAD ) : " aadJoin
  if [[ $aadJoin == "true" || $aadJoin == "false" ]]; then
    break
  else
    echo "올바른 값을 입력하세요  (true : EntraID / false : WindowAD ) : "
  fi
done   
echo "$aadJoin 을 선택하셨습니다"
# -------------------------------------------------------------------------
# main.bicep 템플릿 배포 ( wr_sample.bicepparam 이름을 환경에 맞게 변경 )
# -------------------------------------------------------------------------
echo "main.bicep 배포를 시작합니다..."

az deployment group create \
  --resource-group "$resourceGroupName" \
  --template-file ./main.bicep \
  --parameters wr_sample.bicepparam \
  --parameters adminPassword="$adminPassword" vmCount="$vmCount" hostPoolName="$hostPoolName" aadJoin="$aadJoin" vmNameNum="$vmNum"

echo "배포 명령이 실행되었습니다."
echo "배포 상태를 확인하려면 Azure Portal에서 리소스 그룹 '$resourceGroupName'을 확인하세요."
