using 'main.bicep'

param vmCount = ' '                                                       // 생성할 VM 수
param vmNameNum = ' '                                                     // 시작할 VM 숫자       
param adminPassword = ' '                                                 // 관리자 암호     
param hostPoolName = ' '                                                  // AVD 호스트 풀 이름 (VM 등록용)  
param aadJoin = ' '                                                       // Domain Join 유형 선택
param location = 'East US'                                                // 호스트풀 배포 위치 
param vmOSName = 'User-'                                                  // VM 이름
param adminUsername = 'Azureadmin'                                        // VM 관리자 사용자 이름
param existingVnetName = 'AD-BICEP-VNET'                                  // 배포할 VNET 이름 
param existingSubnetName = 'Subnet01'                                     // 배포할 Subnet 이름
param domainJoinOptions = '3'                                             // Domain Join 방식 지정
param domainToJoin = 'avd-test.com'                                     // AD Domain 입력                 
param domainadminUser = 'avdadmin'                                      // Domain Admin 사용자 계정명 입력                  
param DomainPassword = 'tdg3000djr!'                                      // Domain Admin 사용자 비밀번호 입력                  
param ouPath = 'OU=VM,OU=BICEP,DC=avd-test,DC=com'                      // VM을 저장할 OU 경로 입력 
param hostPoolProperties = {
  friendlyName: hostPoolName                                              // 호스트 풀의 표시 이름
  description: 'AVD Personal Host Pool deployed via Bicep'                // 호스트 풀에 대한 설명
  hostPoolType: 'Personal'                                                // 호스트 풀 유형: Personal
  personalDesktopAssignmentType: 'Direct'                                 // 사용자 할당 방식: Direct (수동 할당)
  loadBalancerType: 'Persistent'                                          // 로드 밸런서 유형: Persistent (사용자 연결 유지)
  preferredAppGroupType: 'Desktop'                                        // 선호 앱 그룹 유형
  startVMOnConnect: false                                                 // 사용자가 연결 시 VM 자동 시작 기능 활성화
  validationEnvironment: false                                            // 유효성 검사 환경 기능 활성화
  customRdpProperty: 'targetisaadjoined:i:1'                              // 추가 RDP 속성 정의 (targetisadjoin : EntraID RDP 설정 )
}
param artifactsLocation = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02774.414.zip'     //변경 금지
