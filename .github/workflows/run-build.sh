#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# build-board.yml 의 빌드 스텝 공통 실행기
#
#   bash .github/workflows/run-build.sh <stage> [package ...]
#   패키지를 주지 않으면 전체 빌드(최종 이미지)를 한다.
#
# - 빌드 컨테이너 메모리를 제한해, 메모리가 모자라면 러너 대신 컨테이너가 종료되게 한다.
# - 5분마다 메모리/디스크를 출력한다. DROP_OBJECTS=1 이면 설치가 끝난 패키지의 *.o 를 지운다.
# - 메모리/다운로드 오류만 한 번 더 시도한다. 컴파일·해시·디스크 오류는 즉시 멈춘다.
# - 취소/시간 초과 시 이 스텝의 컨테이너만 종료해 백그라운드 빌드가 남지 않게 한다.
# - 실패한 패키지·원인·첫 오류를 annotation 과 잡 요약에 남기고,
#   이 스텝에서 오래 걸린 패키지를 잡 요약에 적는다 (4단계로 옮길 무거운 패키지 찾기용).
#
# 환경변수: BOARD (필수), DROP_OBJECTS (선택)
# ─────────────────────────────────────────────────────────────────────────────

set -u

STAGE="${1:?stage required}"
shift
PKGS="$*"
: "${BOARD:?BOARD env required}"

ROOT="output/${BOARD}"
TIMELOG="$ROOT/build/build-time.log"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
[[ "$BOARD" =~ ^[a-z0-9_-]+$ && "$STAGE" =~ ^[a-z0-9_-]+$ ]] || { echo "잘못된 보드/단계 이름"; exit 2; }
CONTAINER_NAME="knulli-${BOARD}-${STAGE}-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-1}"
DOCKER_MEM="--memory=12g --memory-swap=20g --name=$CONTAINER_NAME"

TIMELOG_START=0
[ -f "$TIMELOG" ] && TIMELOG_START=$(wc -l < "$TIMELOG")

monitor() {
  while sleep 300; do
    echo "[monitor] $(date -u +%H:%M:%S) $(free -m | awk '/^Mem:/{printf "mem used=%sM avail=%sM", $3, $7} /^Swap:/{printf " swap used=%sM", $3}') $(df -h . | awk 'NR==2{printf "disk avail=%s", $4}') $(df -h / | awk 'NR==2{printf "root avail=%s", $4}')"
    [ "${DROP_OBJECTS:-0}" = 1 ] || continue
    find "$ROOT/build" -mindepth 2 -maxdepth 2 -name .stamp_installed -printf '%h\n' 2>/dev/null \
      | grep -v -E '/(linux|uboot)[^/]*$' \
      | while read -r D; do
          [ -e "$D/.objects_dropped" ] && continue
          find "$D" -type f -name '*.o' -delete 2>/dev/null
          touch "$D/.objects_dropped"
        done
  done
}

# annotation 값 이스케이프 (https://github.com/actions/toolkit/blob/main/packages/core/src/command.ts)
esc_data() { local s="$1"; s="${s//'%'/%25}"; s="${s//$'\r'/%0D}"; s="${s//$'\n'/%0A}"; printf '%s' "$s"; }
esc_prop() { local s; s="$(esc_data "$1")"; s="${s//:/%3A}"; s="${s//,/%2C}"; printf '%s' "$s"; }

# 실패 원인 분석: FAIL_PKG, FAIL_STEP, CAUSE, FIRST_ERR, HINT 를 채운다.
diagnose() {
  local log="$1" clean line fail_ln from
  clean="$(mktemp)"
  sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g; s/\r$//' "$log" > "$clean"

  FAIL_PKG=""; FAIL_STEP=""; CAUSE="build"; FIRST_ERR=""; HINT=""
  line=$(grep -a -n -m1 -E '/build/[^/ ]+/\.stamp_[a-z_]+\] Error' "$clean")
  if [ -n "$line" ]; then
    FAIL_PKG=$(sed -E 's#.*/build/([^/ ]+)/\.stamp_.*#\1#' <<< "$line")
    FAIL_STEP=$(sed -E 's#.*/\.stamp_([a-z_]+)\].*#\1#' <<< "$line")
  else
    # 패키지 밖에서 실패한 경우 (예: target-post-image 의 genimage)
    line=$(grep -a -n -E '\*\*\* \[[^]]*: [^] ]+\] Error' "$clean" \
      | grep -v -E ': (_all|all|world|[a-z0-9_]+-build)\] Error' | head -n1)
    FAIL_PKG=$(sed -E 's#.*: ([^] ]+)\] Error.*#\1#' <<< "$line")
  fi
  fail_ln=${line%%:*}
  [ -n "$fail_ln" ] || fail_ln=$(wc -l < "$clean")

  if grep -a -q 'No space left on device' "$clean"; then
    CAUSE="disk"
  elif grep -a -q -E 'Killed signal terminated program|virtual memory exhausted|[Cc]annot allocate memory|[Oo]ut of memory' "$clean" \
       || [ "$RC" -eq 137 ]; then
    CAUSE="memory"
  elif [ "$FAIL_STEP" = downloaded ] && grep -a -q -E 'wrong (sha[0-9]+|md5) hash|HASH MISMATCH|No hash found' "$clean"; then
    CAUSE="hash"
  elif [ "$FAIL_STEP" = downloaded ] || grep -a -q -E '^go: .*(502 Bad Gateway|503 Service Unavailable|i/o timeout|TLS handshake timeout|connection reset)' "$clean"; then
    CAUSE="download"
  fi

  # 컴파일 오류: 실패한 패키지가 마지막으로 시작된 줄(>>> 이름 버전 ...) 이후의 첫 오류
  # 다운로드: 실패한 make 줄 바로 앞의 다운로드 도구 오류
  # 패키지 밖(post-image 등): 마지막 >>> 줄 이후의 첫 오류
  # gcc 가 보여 주는 소스 줄("  145 |  ...")은 오류 문구가 들어 있어도 건너뛴다.
  local err_re='(fatal )?error:|undefined reference to|cannot find -l|No rule to make target|No space left on device|Killed signal|^ERROR'
  local dl_re='^ERROR|^fatal:|^go: |wget: |curl: \([0-9]+\)|ERROR [0-9]{3}:|[0-9]{3} (Not Found|Forbidden|Bad Gateway|Service Unavailable)'
  if [ "$CAUSE" = download ] || [ "$CAUSE" = hash ]; then
    FIRST_ERR=$(head -n "$fail_ln" "$clean" | grep -a -E "$dl_re" | tail -n1 || true)
  else
    if [ -n "$FAIL_STEP" ]; then
      from=$(head -n "$fail_ln" "$clean" | awk -v d="$FAIL_PKG" '$1 == ">>>" && ($2 "-" $3) == d { n = NR } END { print (n ? n : 1) }')
    else
      from=$(head -n "$fail_ln" "$clean" | awk '$1 == ">>>" { n = NR } END { print (n ? n : 1) }')
    fi
    FIRST_ERR=$(sed -n "${from},${fail_ln}p" "$clean" | grep -a -v -E '^[[:space:]]*[0-9]+ \|' \
      | grep -a -m1 -E "$err_re" || true)
  fi
  FIRST_ERR="$(sed -E 's/^[[:space:]]+//' <<< "$FIRST_ERR" | cut -c1-400)"

  if grep -q -E 'fatal error: .*: No such file or directory' <<< "$FIRST_ERR"; then
    HINT="패키지별 디렉토리 빌드(PARALLEL_BUILD)에서는 .mk 의 _DEPENDENCIES 에 적은 패키지의 헤더만 보입니다. 이 헤더를 설치하는 패키지를 의존성에 추가하세요."
  elif grep -q 'undefined reference to' <<< "$FIRST_ERR"; then
    HINT="링크할 라이브러리를 설치하는 패키지가 의존성에 있는지, 이 보드의 GPU(GLES 버전)가 지원하는 기능인지 확인하세요."
  fi
  rm -f "$clean"
}

cause_text() {
  case "$1" in
    download) echo "소스 다운로드 실패" ;;
    hash)     echo "소스 해시 불일치" ;;
    disk)     echo "디스크 공간 부족" ;;
    memory)   echo "메모리 부족" ;;
    *)        echo "빌드 오류" ;;
  esac
}

# 이 스텝에서 빌드한 패키지 중 오래 걸린 10개를 잡 요약에 적는다.
report_times() {
  [ -f "$TIMELOG" ] || return 0
  local rows
  rows=$(tail -n +"$((TIMELOG_START + 1))" "$TIMELOG" | awk -F: '
    NF >= 4 {
      ts = $1; ev = $2; gsub(/ /, "", ev); step = $3; gsub(/ /, "", step)
      pkg = $4; for (i = 5; i <= NF; i++) pkg = pkg ":" $i; gsub(/^ +| +$/, "", pkg)
      k = pkg SUBSEP step
      if (ev == "start") s[k] = ts
      else if (ev == "end" && (k in s)) { d[pkg] += ts - s[k]; delete s[k] }
    }
    END { for (p in d) printf "%d\t%s\n", d[p], p }' | sort -rn)
  [ -n "$rows" ] || return 0
  {
    echo "### ${BOARD} · ${STAGE}: 오래 걸린 패키지 (이 스텝에서 빌드한 $(wc -l <<< "$rows")개 중)"
    echo
    echo "| 패키지 | 시간 |"
    echo "|---|---|"
    head -n 10 <<< "$rows" | awk -F'\t' '{ printf "| %s | %d분 %d초 |\n", $2, $1 / 60, $1 % 60 }'
    echo
  } >> "$SUMMARY"
}

monitor &
MON_PID=$!
trap 'kill "$MON_PID" 2>/dev/null || true' EXIT
stop_build() {
  if command -v docker >/dev/null 2>&1; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
  exit 143
}
trap stop_build TERM INT

ARGS=(BATCH_MODE=1 PARALLEL_BUILD=1 "DOCKER_OPTS=$DOCKER_MEM")
[ -n "$PKGS" ] && ARGS+=("CMD=$PKGS")

RC=0
for i in 1 2; do
  # 재시도는 동시 빌드 패키지 수를 줄여 메모리 사용량을 낮춘다.
  JLEVEL=$(nproc); [ "$i" -gt 1 ] && [ "$JLEVEL" -gt 2 ] && JLEVEL=2
  echo "::group::Attempt $i (MAKE_JLEVEL=$JLEVEL)"
  make "${BOARD}-build" "${ARGS[@]}" "MAKE_JLEVEL=$JLEVEL" \
    2>&1 | tee build.log | grep -E --color=never --line-buffered '>>>|error:|Error:|FAILED'
  PIPE_RC=("${PIPESTATUS[@]}")
  RC=${PIPE_RC[0]}
  # grep 가 출력할 줄을 못 찾은 것은 실패가 아니다. make/로그 저장 오류는 실패다.
  [ "$RC" -ne 0 ] || RC=${PIPE_RC[1]}
  echo "::endgroup::"
  [ "$RC" -eq 0 ] && break

  diagnose build.log
  echo "Attempt $i failed (RC=$RC)"
  echo "실패: ${FAIL_PKG:-알 수 없음}${FAIL_STEP:+ (${FAIL_STEP} 단계)} · 원인: $(cause_text "$CAUSE")"
  [ -n "$FIRST_ERR" ] && echo "첫 오류: $FIRST_ERR"
  echo "----- build.log error summary -----"
  grep -a -n -E 'No space left on device|rsync error|rsync: |make(\[[0-9]+\])?: \*\*\*|[Ee]rror:|Error [0-9]+|fatal error|Killed signal|ERROR' build.log \
    | head -n 120 || true
  echo "----- last started packages -----"
  grep -a -E '>>> ' build.log | tail -n 30 || true
  echo "----- disk usage -----"
  df -h . / || true
  du -sh "$ROOT/build" "$ROOT/per-package" "$ROOT/host" "$ROOT/target" "$ROOT/images" 2>/dev/null || true
  echo "----- build.log tail -----"
  tail -n 160 build.log || true
  echo "--------------------------"
  cp -f build.log "build-attempt${i}.log" || true
  if [ "$i" -lt 2 ]; then
    case "$CAUSE" in
      download) WAIT=120 ;;
      memory) WAIT=10 ;;
      *) echo "재시도로 해결되지 않는 오류 — 즉시 중단"; break ;;
    esac
    echo "sleeping ${WAIT}s before retry..."
    sleep "$WAIT"
  fi
done

report_times

if [ "$RC" -ne 0 ]; then
  MSG="$(cause_text "$CAUSE")${FAIL_STEP:+ (${FAIL_STEP} 단계)}${FIRST_ERR:+: $FIRST_ERR}${HINT:+ — $HINT}"
  echo "::error title=$(esc_prop "${BOARD} · ${STAGE} · ${FAIL_PKG:-알 수 없음}")::$(esc_data "$MSG")"
  {
    echo "### ${BOARD} · ${STAGE} 실패"
    echo
    echo "- 패키지: \`${FAIL_PKG:-알 수 없음}\`${FAIL_STEP:+ (${FAIL_STEP} 단계)}"
    echo "- 원인: $(cause_text "$CAUSE")"
    [ -n "$FIRST_ERR" ] && echo "- 첫 오류: \`${FIRST_ERR//\`/\'}\`"
    [ -n "$HINT" ] && echo "- 참고: $HINT"
    echo
  } >> "$SUMMARY"
fi
exit "$RC"
