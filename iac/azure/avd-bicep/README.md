# **AVD Bicep Scripts**<br>

### 구성
1. **deploy.sh**
2. **main.bicep**
3. **sample.bicepparam**

---

### 내용
1. **deploy.sh**<br>
    * Bicep 동작을 위한 Shell Scripts
    * 사용하거나 배포할 HostPool 이 있는 구독 , 리소스 그룹 을 지정합니다. (Azure 미 로그인 시 해당 과정도 포함)<br>
    * 관리자 비밀번호는 VM 배포 시 사용할 Admin 비밀번호 입니다.<br>
    * Domain Join 유형 입력에서 true 입력 시 EntraID Join 을 진행 , false 입력 시 WindowsAD Join 을 진행합니다.<br>
    * 생성할 VM 들의 시작 번호와 개수를 입력하세요 ( ex) 26, 3 입력 시 vm-26, vm-27, vm-28 생성 )<br>
    * 변경한 매개변수 파일의 이름에 맞춰서 `--parameters` 에서 선언하는 bicepparam 파일 이름을 변경해줍니다.
2. **main.bicep**<br>
    * Bicep 파일 
    * 해당 스크립트는 수정할 필요 없이 그대로 사용하셔도 무방합니다.
    * 만약 존재하는 이미지를 사용할 경우 주석 처리된 Image Resource 부분을 사용합니다.
3. **sample.bicepparam**<br>
    * 매개변수 파일
    * 여기서 주요 설정들을 적용할 환경에 맞게 설정합니다.

---

### 사용방법
* Bash Shell 을 사용해서 `deploy.sh` 를 실행시켜 배포를 시작합니다.

`Contributor : KS-Jeon, hittol`
