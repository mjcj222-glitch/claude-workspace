# 전송 차단 진단 · 2026-10-20 UTC

사용자가 전송 문제 해결을 우선하도록 요청해 구현을 체크포인트로 보존했다. 아래는 이미 발생한 실패와 변경 없는 환경 확인 결과다. 이 진단에서 다운로드를 재시도하거나 네트워크 설정을 바꾸지 않았다.

| 단계 | 실제 결과 |
|---|---|
| Library 파일 준비 | `prepare_materialize` 성공, `isError=false`, `unavailable_items=[]`, 경고 없음 |
| 로컬 연결 | `workspace_path=null`; 로컬 파일이 직접 제공되지 않아 서명된 다운로드 전송이 필요 |
| Python HTTPS 다운로드 | 프록시 터널 생성에서 `Tunnel connection failed: 403 Forbidden` |
| 파일 수신 | 기본 대기 PNG와 공격 준비 PNG 모두 미수신. 같은 호스트의 공격 PNG는 실패 반복을 피하고 요청하지 않음 |
| 별도 CC0 다운로드 | `kenney.nl` 공개 Particle Pack ZIP도 CONNECT 403. 미수신 |

실제 요청한 호스트명은 `sdmntprcentralus.oaiusercontent.com`, `sdmntprwestus3.oaiusercontent.com`, `kenney.nl`이다. 서명 URL·서명 파라미터·토큰·계정 정보는 이 보고서에 포함하지 않는다.

HTTP_PROXY/HTTPS_PROXY 및 소문자 변형은 모두 `http://proxy:8080`이고 내장 인증 정보는 없다. NO_PROXY는 localhost/127.0.0.1/::1뿐이다. 실행 환경 선언은 `network: enabled`이지만 도메인별 outbound 허용 목록은 노출되지 않았다. 읽을 수 있는 프로젝트/사용자 Codex 설정 파일에서도 해당 목록을 확인하지 못했다. 따라서 “특정 호스트가 허용 목록에서 빠졌다”는 것은 아직 확정할 수 없다.

CONNECT 단계에서 원본 파일 서버와의 TLS 연결 전에 실패했으므로, 관찰된 실패는 Library 조회/계정 권한 실패와 구분되는 **실행 환경 프록시 연결 거부**다. 원본 스토리지의 파일 접근 응답은 받지 못했고 URL 만료 여부도 검사하지 못했다. 이는 도구 자동 승인 심사 거부가 아니라 네트워크에서 관찰된 403이다.

## 최소 다음 작업 — 아직 실행하지 않음

1. 환경 소유자가 해당 클라우드 환경의 인터넷 접근 및 도메인 허용 목록을 읽어 위 두 `oaiusercontent.com` 호스트가 포함되는지 확인한다. 현재 도구에는 이 환경의 허용 목록 조회·수정 기능이 없다.
2. 누락된 경우 사용자에게 **두 정확한 호스트의 HTTPS 다운로드 접근만 추가**하는 변경안을 확인받는다. 모든 도메인 허용, 프록시 제거, 인증서 검증 해제, 다른 호스트 경유를 제안하지 않는다. Kenney는 캐릭터 전송과 분리해 나중에 판단할 수 있다.
3. 허용 설정이 이미 맞거나 UI에서 조정할 수 없다면 아래 공식 지원 경로로 프록시 CONNECT 403과 시각·호스트명을 제공한다. 설정 변경이 실제 적용됐다는 새 증거를 받은 뒤 새 전송 URL로 한 번만 재시도한다.

공식 근거(2026-10-20 열람): [Cloud 인터넷 접근 문서](https://developers.openai.com/codex/cloud/internet-access/)는 환경 인터넷 설정과 도메인/HTTP 메서드 제한을 구분하며, 명령 네트워크 정책과 환경 설정이 별도로 적용될 수 있다고 설명한다. 이 문서는 현재 환경의 실제 허용 목록을 보여 주는 증거는 아니다. [OpenAI 지원 안내](https://help.openai.com/en/articles/6614161-how-can-i-contact-support)는 Help Center의 채팅을 지원 접수 경로로 안내한다. 지원 문의는 아직 발송하지 않았다.
