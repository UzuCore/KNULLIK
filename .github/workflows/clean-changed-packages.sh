#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# clean-changed-packages.sh  (v2)
#
# 마지막 release 태그(YYYYMMDD) 이후 변경된 buildroot 패키지의 .stamp_built 를
# 제거해서 다음 make 실행 시 재빌드되도록 한다.
#
# B 패턴: 폰트/리소스 파일만 바꾸고 .mk의 _VERSION을 안 올렸을 때도
#         buildroot가 못 잡는 변경을 git diff로 잡아준다.
#
# v2 변경사항:
#  - batocera, buildroot 두 서브모듈 내부의 diff까지 추출
#    (이전 버전은 메인 레포의 diff만 봐서, batocera 본체 변경을 전혀 감지 못함.
#     batocera/ 가 서브모듈이라 메인 git diff에는 "batocera" 한 줄로만 나옴)
#  - batocera/package, buildroot/package 의 awk 추출을 .mk 디렉토리 기준으로 수정
#    (이전 a[5] 하드코딩은 batocera/package/CAT/SUBCAT/NAME/ 형태에서 카테고리명을
#     패키지명으로 오해함)
#  - find pattern 을 `${P}-[0-9]*` 로 좁혀 `linux-headers` 같은 over-match 방지
#  - fetch-depth 부족 시 자동으로 unshallow / 추가 fetch 시도
#
# 환경변수:
#   BOARD          (필수) — 보드 이름
#   SCOPE_PATTERNS (필수) — 이 잡이 책임지는 패키지 glob 패턴 (공백 구분)
#                          예) "linux* uboot*"
#                              "libretro-mame*"
#                              "libretro-*"
#                              "*"   (모든 패키지)
#   EXCLUDE_PATTERNS (선택) — SCOPE 에서 빼고 싶은 패턴
# ─────────────────────────────────────────────────────────────────────────────

set -e

: "${BOARD:?BOARD env required}"
: "${SCOPE_PATTERNS:?SCOPE_PATTERNS env required}"

EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-}"

echo "════════════════════════════════════════════════════════════"
echo " Auto-detect changed packages (board=$BOARD)"
echo "   scope:   $SCOPE_PATTERNS"
echo "   exclude: ${EXCLUDE_PATTERNS:-(none)}"
echo "════════════════════════════════════════════════════════════"

# 태그/커밋 충분히 가져오기
git fetch --tags --depth=200 origin 2>/dev/null || true

# 가장 최근 YYYYMMDD 태그
LAST_TAG=$(git tag --sort=-creatordate | grep -E '^[0-9]{8}$' | head -n1 || true)

if [ -z "$LAST_TAG" ]; then
  echo "이전 release 태그 없음 — 첫 빌드로 간주, 변경분 감지 스킵"
  exit 0
fi

# LAST_TAG 커밋이 현재 fetch된 히스토리에 없으면 더 받아오기
if ! git rev-parse "$LAST_TAG^{commit}" >/dev/null 2>&1; then
  echo "Tag $LAST_TAG 의 커밋이 아직 fetch 안 됨 → 추가 fetch 시도"
  git fetch --unshallow origin 2>/dev/null \
    || git fetch --depth=500 origin 2>/dev/null \
    || true
fi

# 현재 빌드 커밋과 같으면 의미 없음
if git merge-base --is-ancestor HEAD "$LAST_TAG" 2>/dev/null; then
  echo "HEAD가 마지막 태그($LAST_TAG)에 포함됨 — 새 변경분 없음"
  exit 0
fi

echo "Diff 기준: $LAST_TAG..HEAD"
echo

# 변경 패키지 모음 임시 파일
TMP_CHANGED=$(mktemp)
trap 'rm -f "$TMP_CHANGED"' EXIT

# ─── 1) 메인 레포의 변경 ──────────────────────────────────────────────
# package/  : knulli 고유 패키지 (package/NAME/...)
# board/    : 보드 오버레이 (별도 마커로 처리)
git diff --name-only "$LAST_TAG..HEAD" -- 'package/' 'board/' 2>/dev/null | \
  awk '
    /^package\// { split($0, a, "/"); print a[2]; next }
    /^board\//   { print "_BOARD_OVERLAY_"; next }
  ' >> "$TMP_CHANGED" || true

# ─── 2) 서브모듈 변경 처리 ────────────────────────────────────────────
# batocera, buildroot 둘 다 서브모듈. 메인 레포의 diff 출력에는
# 변경된 서브모듈이 "batocera" 또는 "buildroot" 한 줄로 나옴.
# 그 안에서 실제 변경된 파일 목록을 얻으려면 서브모듈 디렉토리로 들어가서
# 별도 diff 를 떠야 한다.
SUBMODULES_CHANGED=$(git diff --name-only "$LAST_TAG..HEAD" 2>/dev/null | \
  grep -xE 'batocera|buildroot' || true)

for SM in $SUBMODULES_CHANGED; do
  # 서브모듈이 체크아웃 안 되어 있으면 스킵
  if [ ! -e "$SM/.git" ]; then
    echo "서브모듈 $SM/ 이 초기화 안 됨 — 스킵 (변경분 감지 불가)"
    continue
  fi

  # LAST_TAG 시점 vs 현재 시점의 서브모듈 commit SHA
  CUR_SHA=$(git ls-tree HEAD "$SM" | awk '{print $3}')
  PREV_SHA=$(git ls-tree "$LAST_TAG" "$SM" | awk '{print $3}')

  if [ -z "$CUR_SHA" ] || [ -z "$PREV_SHA" ]; then
    echo "서브모듈 $SM 의 SHA 추출 실패 — 스킵"
    continue
  fi

  if [ "$CUR_SHA" = "$PREV_SHA" ]; then
    continue
  fi

  echo "서브모듈 $SM diff: $PREV_SHA..$CUR_SHA"

  # 서브모듈 안에서 두 commit 모두 reachable 해야 diff 가능
  SM_DIFF=$(
    cd "$SM" 2>/dev/null || exit 0
    for SHA in "$PREV_SHA" "$CUR_SHA"; do
      git cat-file -e "${SHA}^{commit}" 2>/dev/null || \
        git fetch --depth=200 origin "$SHA" 2>/dev/null || \
        git fetch --unshallow origin 2>/dev/null || true
    done
    git diff --name-only "$PREV_SHA..$CUR_SHA" -- 'package/' 2>/dev/null || true
  )

  # 서브모듈 안의 package/<...>/<NAME>/<file> 형태에서 NAME 추출
  # NAME 은 항상 .mk 파일이 있는 디렉토리 (=경로 마지막에서 두 번째 세그먼트)
  # 예) package/batocera/emulators/libretro/libretro-mame/libretro-mame.mk
  #     → 마지막 디렉토리 = "libretro-mame"
  echo "$SM_DIFF" | awk '
    NF > 0 {
      n = split($0, a, "/")
      if (n >= 2) print a[n-1]
    }
  ' >> "$TMP_CHANGED" || true
done

CHANGED=$(sort -u "$TMP_CHANGED")

if [ -z "$CHANGED" ]; then
  echo "변경된 패키지 없음"
  exit 0
fi

echo "─── git diff에서 감지된 패키지 ───"
echo "$CHANGED" | sed 's/^/  - /'
echo

# ─── 3) scope/exclude 필터링 ─────────────────────────────────────────
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

mapfile -t SCOPE_ARR   < <(split_patterns "$SCOPE_PATTERNS")
mapfile -t EXCLUDE_ARR < <(split_patterns "$EXCLUDE_PATTERNS")

FILTERED=""
for P in $CHANGED; do
  # board overlay 변경은 image 잡에서만 처리
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

# ─── 4) stamp 제거 + per-package 디렉토리 제거 ───────────────────────
# .stamp_built / .stamp_target_installed / .stamp_staging_installed 셋만 지우면
# buildroot가 해당 단계부터 다시 시작함 (다운로드/패치 단계 stamp는 유지 → 빠름)
for P in $FILTERED; do
  if [ "$P" = "_BOARD_OVERLAY_" ]; then
    # board overlay는 final image 단계에서 다시 복사되도록
    rm -f output/${BOARD}/build/.stamp_target_finalized 2>/dev/null || true
    rm -f output/${BOARD}/.stamp_target_finalized 2>/dev/null || true
    rm -f output/${BOARD}/.stamp_images_built 2>/dev/null || true
    echo "  board overlay → final image 재생성 트리거"
    continue
  fi

  # 버전 붙은 디렉토리: ${P}-1.2.3 (숫자 시작)으로 제한해서 over-match 방지
  # 예) P=linux 일 때 linux-headers, linux-pam 같은 것은 잡지 않음
  # 추가로 버전 없는 정확 매치 (per-package 모드의 일부 케이스)
  for D in $(find output/${BOARD}/build -maxdepth 1 -type d -name "${P}-[0-9]*" 2>/dev/null) \
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

  # per-package 디렉토리도 통째로 제거 (per-package mode 에서만 존재)
  # per-package 디렉토리는 버전 없이 패키지명 그대로
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
