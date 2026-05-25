#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# clean-changed-packages.sh
#
# 마지막 release 태그(YYYYMMDD) 이후 변경된 buildroot 패키지의 .stamp_built 를
# 제거해서 다음 make 실행 시 재빌드되도록 한다.
#
# B 패턴: 폰트/리소스 파일만 바꾸고 .mk의 _VERSION을 안 올렸을 때도
#         buildroot가 못 잡는 변경을 git diff로 잡아준다.
#
# 환경변수:
#   BOARD          (필수) — 보드 이름
#   SCOPE_PATTERNS (필수) — 이 잡이 책임지는 패키지 glob 패턴 (공백 구분)
#                          예) "linux* uboot*"
#                              "libretro-mame*"
#                              "libretro-*"          (mame 포함이면 제외 처리는 EXCLUDE_PATTERNS)
#                              "*"                   (모든 패키지)
#   EXCLUDE_PATTERNS (선택) — SCOPE에서 빼고 싶은 패턴
#                            예) heavy-libretro 잡에서 mame은 mame-lr 잡이 처리하니 제외
#                                EXCLUDE_PATTERNS="libretro-mame*"
#   DIFF_PATHS     (선택) — git diff 대상 경로. 기본값:
#                          'package/' 'batocera/package/' 'buildroot/package/' 'board/'
# ─────────────────────────────────────────────────────────────────────────────

set -e

: "${BOARD:?BOARD env required}"
: "${SCOPE_PATTERNS:?SCOPE_PATTERNS env required}"

EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-}"
DIFF_PATHS="${DIFF_PATHS:-package/ batocera/package/ buildroot/package/ board/}"

echo "════════════════════════════════════════════════════════════"
echo " Auto-detect changed packages (board=$BOARD)"
echo "   scope:   $SCOPE_PATTERNS"
echo "   exclude: ${EXCLUDE_PATTERNS:-(none)}"
echo "════════════════════════════════════════════════════════════"

# 태그 가져오기
git fetch --tags --depth=50 origin 2>/dev/null || true

# 가장 최근 YYYYMMDD 태그
LAST_TAG=$(git tag --sort=-creatordate | grep -E '^[0-9]{8}$' | head -n1 || true)

if [ -z "$LAST_TAG" ]; then
  echo "이전 release 태그 없음 — 첫 빌드로 간주, 변경분 감지 스킵"
  exit 0
fi

# 현재 빌드 커밋과 같으면 의미 없음
if git merge-base --is-ancestor HEAD "$LAST_TAG" 2>/dev/null; then
  echo "HEAD가 마지막 태그($LAST_TAG)에 포함됨 — 새 변경분 없음"
  exit 0
fi

echo "Diff 기준: $LAST_TAG..HEAD"
echo

# 패키지 디렉토리 이름만 추출 (예: package/foo/bar.mk → foo)
# - package/{NAME}/...  : NAME 추출
# - batocera/package/{CAT}/{NAME}/... : NAME 추출
# - buildroot/package/{NAME}/... : NAME 추출
# - board/{BOARD}/... : BOARD 자체는 패키지 아님, 별도 처리
#
# 또한 .gitmodules의 batocera/buildroot 서브모듈 자체가 바뀌었을 가능성도 있어
# `git diff` 결과에서 디렉토리 한 단계 더 들어가서 추출

CHANGED=$(git diff --name-only "$LAST_TAG..HEAD" -- $DIFF_PATHS 2>/dev/null | \
  awk '
    /^package\// { split($0, a, "/"); print a[2]; next }
    /^batocera\/package\// {
      split($0, a, "/")
      # batocera/package/CAT/NAME/... 형태가 많음 (예: emulators/retroarch/libretro/libretro-mame/)
      # NAME만 뽑기 위해 .mk가 있는 마지막 디렉토리를 찾기보다는 단순화:
      # 위치 4가 패키지 디렉토리인 경우가 가장 흔함
      if (a[5] != "") print a[5]  # batocera/package/CAT/SUBCAT/NAME/...
      else print a[4]              # batocera/package/CAT/NAME/...
      next
    }
    /^buildroot\/package\// { split($0, a, "/"); print a[3]; next }
    /^board\// { print "_BOARD_OVERLAY_"; next }
  ' | sort -u || true)

if [ -z "$CHANGED" ]; then
  echo "변경된 패키지 없음"
  exit 0
fi

echo "─── git diff에서 감지된 패키지 ───"
echo "$CHANGED" | sed 's/^/  - /'
echo

# scope/exclude 필터링
# ✅ 글로빙 방지: 호출 직전/직후에 noglob 토글
matches_pattern() {
  local name="$1"; shift
  local pat
  for pat in "$@"; do
    # shellcheck disable=SC2053
    case "$name" in $pat) return 0 ;; esac
  done
  return 1
}

# 문자열을 배열로 분할 (글로빙 방지)
split_patterns() {
  local s="$1"
  set -f                   # 글로빙 비활성
  # shellcheck disable=SC2206
  local arr=( $s )
  set +f                   # 글로빙 복원
  printf '%s\n' "${arr[@]}"
}

# 배열 형태로 변환
mapfile -t SCOPE_ARR < <(split_patterns "$SCOPE_PATTERNS")
mapfile -t EXCLUDE_ARR < <(split_patterns "$EXCLUDE_PATTERNS")

FILTERED=""
for P in $CHANGED; do
  # board overlay 변경은 image 잡에서만 처리 (별도 처리)
  if [ "$P" = "_BOARD_OVERLAY_" ]; then
    if matches_pattern "$P" "${SCOPE_ARR[@]}"; then
      FILTERED="$FILTERED $P"
    fi
    continue
  fi

  if ! matches_pattern "$P" "${SCOPE_ARR[@]}"; then
    continue
  fi
  if [ ${#EXCLUDE_ARR[@]} -gt 0 ] && matches_pattern "$P" "${EXCLUDE_ARR[@]}"; then
    continue
  fi
  FILTERED="$FILTERED $P"
done

if [ -z "$FILTERED" ]; then
  echo "이 잡 scope에 해당하는 변경 패키지 없음"
  exit 0
fi

echo "─── 이 잡에서 clean할 패키지 ───"
echo "$FILTERED" | tr ' ' '\n' | grep -v '^$' | sed 's/^/  - /'
echo

# stamp 제거 + per-package 디렉토리 제거
# .stamp_built / .stamp_target_installed / .stamp_staging_installed 셋만 지우면
# buildroot가 해당 단계부터 다시 시작함 (다운로드/패치 단계 stamp는 유지 → 빠름)
for P in $FILTERED; do
  if [ "$P" = "_BOARD_OVERLAY_" ]; then
    # board overlay는 final image 단계에서 다시 복사되도록
    # target/.stamp_target_finalized 만 제거
    rm -f output/${BOARD}/build/.stamp_target_finalized 2>/dev/null || true
    rm -f output/${BOARD}/.stamp_target_finalized 2>/dev/null || true
    rm -f output/${BOARD}/.stamp_images_built 2>/dev/null || true
    echo "  board overlay → final image 재생성 트리거"
    continue
  fi

  # 패키지 stamp는 buildroot 표준 위치
  for D in $(find output/${BOARD}/build -maxdepth 1 -type d -name "${P}-*" 2>/dev/null) \
           $(find output/${BOARD}/build -maxdepth 1 -type d -name "${P}" 2>/dev/null); do
    if [ -d "$D" ]; then
      echo "  clean: $D"
      rm -f "$D"/.stamp_built \
            "$D"/.stamp_target_installed \
            "$D"/.stamp_staging_installed \
            "$D"/.stamp_host_installed \
            "$D"/.stamp_images_installed
    fi
  done

  # per-package 디렉토리도 통째로 제거 (per-package mode에서만 존재)
  for D in $(find output/${BOARD}/per-package -maxdepth 1 -type d -name "${P}" 2>/dev/null); do
    if [ -d "$D" ]; then
      echo "  remove per-package: $D"
      rm -rf "$D"
    fi
  done
done

echo
echo "════════════════════════════════════════════════════════════"
echo " Clean 완료 — 다음 make 실행 시 위 패키지들이 재빌드됨"
echo "════════════════════════════════════════════════════════════"
