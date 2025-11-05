## Script: `azure_vmInitScript.ps1`

**용도**  
Azure Virtual Desktop(AVD) Host Pool에 포함된 Session Host VM들에 대해  
**드라이브 리디렉션(Drive Redirection) 허용 / 차단 스크립트를 자동 실행**합니다.

**동작 요약**
1. Host Pool 내 Session Host VM 목록 조회
2. 사용자 입력(`allow` / `deny`)에 따라 실행할 설정 스크립트 선택
3. 스토리지 계정에서 해당 스크립트를 다운로드하기 위한 **SAS Token 자동 생성**
4. 각 VM에 대해 다음 작업 수행:
   - VM 자동 시작
   - Custom Script Extension을 통해 스크립트 실행
   - 적용 완료 확인
   - VM 자동 중지

**입력값**
| 항목 | 설명 |
|---|---|
| Host Pool Resource Group | Session Host VM이 포함된 리소스 그룹 |
| Host Pool Name | 드라이브 리디렉션 정책을 적용할 대상 Host Pool |
| allow / deny | 드라이브 리디렉션 허용 / 차단 |
| Storage Account 정보 | 스크립트가 저장된 Blob 컨테이너 위치 |

**전제 조건**
- `allowDriveRedirection.ps1` 또는 `denyDriveRedirection.ps1` 스크립트가 Blob 컨테이너에 업로드되어 있어야 함
- 스크립트를 실행하는 계정은 VM 및 Storage에 대한 권한을 보유해야 함

**전제 조건**
- Blob 컨테이너에 `allowDriveRedirection.ps1` 또는 `denyDriveRedirection.ps1` 업로드되어 있어야 함
- 실행 계정은 VM 및 Storage 관리 권한 필요

**특징**
- VM 상태에 관계없이 자동 처리 (Start → 실행 → Stop)
- 별도 관리 도구 없이 PowerShell + Azure 모듈로 수행 가능

---

## Script: `win_allowDriveRedirection.ps1`

**용도**  
원격 세션 환경에서 **클라이언트 드라이브 리디렉션(Drive Redirection)을 허용**하도록  
로컬 정책 레지스트리를 설정하는 스크립트입니다.  

**동작 요약**
1. 정책 레지스트리 경로 확인 및 없을 경우 자동 생성
2. `fDisableCdm` 값을 `0`으로 설정하여 드라이브 리디렉션 허용
3. `gpupdate /force` 명령으로 정책 즉시 반영

**설정 내용**
| 레지스트리 경로 | 값 이름 | 값 | 의미 |
|---|---|---|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services` | `fDisableCdm` | `0` | 드라이브 리디렉션 허용 |

**특징**
- 레지스트리 존재 여부를 자동 확인하고 필요 시 생성
- 정책 반영까지 한 번에 수행됨

---

## Script: `denyDriveRedirection.ps1`

**용도**  
원격 세션 환경에서 **클라이언트 드라이브 리디렉션(Drive Redirection)을 차단**하도록  
로컬 정책 레지스트리를 설정하는 스크립트입니다.  

**동작 요약**
1. 정책 레지스트리 경로 확인 및 필요 시 자동 생성
2. `fDisableCdm` 값을 `1`로 설정하여 드라이브 리디렉션 차단
3. `gpupdate /force` 명령을 통해 정책 즉시 반영

**설정 내용**
| 레지스트리 경로 | 값 이름 | 값 | 의미 |
|---|---|---|---|
| `HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services` | `fDisableCdm` | `1` | 드라이브 리디렉션 차단 |

**특징**
- 레지스트리 키가 없을 경우 자동 생성되므로 신규/초기 환경에서도 문제 없이 적용 가능
- 정책 적용 단계를 자동 처리하여 즉시 반영됨