# KNULLIK EmulationStation 한국어 번역 관리

## 기준 파일과 적용

- **통합 번역(정본)**: `rocknixk/locales/ko_KR/emulationstation2.po`
- **게임·에뮬레이터 설정 옵션**: `locales/ko/knulli-es-system.po`
- `knulli-emulationstation.mk`의 한국어 오버레이가 `ko`, `ko_KR` 양쪽에 통합 PO를 배치하고, 컴파일된 `emulationstation2.mo`를 루트 파일시스템에 설치합니다.
- 영어 원문 키의 표기, 대소문자, 줄바꿈, 숫자·문자열 서식(예: `%s`, `%i`, `%d`)은 절대로 번역 과정에서 변경하지 않습니다.
- `msgctxt "game_options"`와 일반 UI 문맥이 같아 보여도 독립적으로 취급합니다. 중복 메시지를 함부로 제거하지 않습니다.

## 2026-10-16 정비 결과

- 기기 RG34XX-SP의 언어 설정 `ko_KR`, `LANG=ko_KR.UTF-8` 확인.
- 빌드 원문 `emulationstation2.pot` **4,426개 전체**를 통합 한국어 PO에 대응시킴. 그중 원문 대비 신규 누락 232개(일반 UI 185개, 게임 옵션 47개)를 영어 원문 및 일본어 참고 번역을 비교하여 추가.
- 기존 핵심 UI 문구 117개를 개별 검토하여 잘못된 의미와 용어를 바로잡음.
- 기존 옵션 PO 2,956개 항목은 통합 PO에 동일 `msgctxt` + `msgid`가 모두 존재함을 확인한 다음 그 **정확한 키의 검수된 한국어 번역**과 동기화. 기존 fuzzy 1,557개와 미번역 1,084개를 무분별하게 승인하거나 기계 번역한 것이 아님.
- 최종 통합 PO 4,443개, 옵션 PO 2,956개가 각각 `msgfmt --check --check-format` 통과, 두 PO의 `msgcat` 병합도 통과, 원문 POT 누락 0개.
- `msgcmp`에서 출력하는 현재 빌드 POT에 없는 **여분의 과거 메시지 경고**는 번역 누락이 아님. `msgcmp`의 종료 코드 0을 확인.

## 용어 기준

| 영어 문맥 | 표준 표기 |
| --- | --- |
| Settings | 설정 |
| Controller | 컨트롤러 |
| Gamepad | 게임패드 |
| Controller mapping | 컨트롤러 버튼 설정 |
| Hotkey | 단축키 |
| Save state / Restore state | 상태 저장 / 상태 불러오기 |
| Savestate manager | 상태 저장 관리자 |
| Scrape / Scraper | 게임 정보 수집 |
| Gamelist | 게임 목록 |
| Wi-Fi | Wi-Fi (WIFI 등 표기 통일) |
| Bluetooth | 블루투스 |
| BIOS | 바이오스 |
| Reboot / Restart system | 시스템 재부팅 |
| Shutdown | 전원 끄기 |
| Format | 포맷 |
| Cancel / Confirm | 취소 / 확인 |

엔진 이름(EmulationStation, RetroArch, libretro, GZDoom), 포맷, 게임기의 물리 버튼명, 기술 약어와 제품명은 필요한 경우 원문을 유지합니다. 뜻이 바뀌는 축약은 하지 않습니다.

## 번역 변경 시 검수

```sh
ES_PO=package/emulationstation/knulli-es-system/rocknixk/locales/ko_KR/emulationstation2.po
OPTS_PO=package/emulationstation/knulli-es-system/locales/ko/knulli-es-system.po
HOST_GETTEXT=output/h700/host/bin
BUILT_POT=output/h700/build/knulli-emulationstation-10834d004ec3de0808703b46220b6a8574d53218/locale/emulationstation2.pot

"$HOST_GETTEXT/msgfmt" --check --check-format "$ES_PO" -o /tmp/es-ko.mo
"$HOST_GETTEXT/msgfmt" --check --check-format "$OPTS_PO" -o /tmp/es-opt-ko.mo
"$HOST_GETTEXT/msgcmp" "$ES_PO" "$BUILT_POT"
"$HOST_GETTEXT/msgcat" "$ES_PO" "$OPTS_PO" -o /tmp/es-ko-merged.po
"$HOST_GETTEXT/msgfmt" --check --check-format /tmp/es-ko-merged.po -o /tmp/es-ko-merged.mo
```

`BUILT_POT` 경로는 해당 보드의 실제 빌드 해시로 갱신해야 합니다. 펌웨어에 탑재된 라이브 화면은 별도 검수가 필요합니다. **텍스트 키·컴파일 검수만으로 모든 UI에서 글자가 잘리지 않는다고 판단하지 마세요.** 실제 기기에서 작은 화면 및 툴 실행/취소/복귀 등의 검수 결과를 함께 기록합니다.

## 실기 적용/복구

- RG34XX-SP에서 `ko`, `ko_KR` `emulationstation2.mo`를 설치한 위치는 `/usr/share/locale/<언어>/LC_MESSAGES/`입니다.
- 사용자 맞춤 번역은 영구 overlay에도 반영돼 재부팅 후에도 유지됩니다.
- 이전 번역 백업: `/userdata/system/knullik/backups/es-korean-before-20261016/original-ko-emulationstation2.mo`.
- 비정상 출력 발생 시 원본 파일의 SHA-256을 확인한 뒤 복원해야 합니다. Wi-Fi, BIOS, ROM, 화면 회전·밝기 설정은 번역을 위해 변경하지 않습니다.
- 실제 EmulationStation 프로세스를 재시작해야 새 번역이 화면에 반영됩니다. 사용자가 앱/게임을 실행 중일 때 강제 종료하지 마세요.
