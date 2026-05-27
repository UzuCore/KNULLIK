#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# clean-changed-packages.sh  (v5-verified)
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
#  - package 경로가 중첩되어 있어도 .mk 파일이 있는 디렉토리를 패키지명으로 추출
#    (예: package/audio/m8c/... → m8c, package/batocera/.../libretro-mame/... → libretro-mame)
#  - find pattern 을 `${P}-[0-9]*` 로 좁혀 `linux-headers` 같은 over-match 방지
#  - fetch-depth 부족 시 자동으로 unshallow / 추가 fetch 시도
#
# v4 변경사항:
#  - buildroot/batocera/main repo 의 전역 infra/config 변경 감지 시 _GLOBAL_REBUILD_ 마커 추가
#    (pkg-*.mk, Makefile, Config.in, support/scripts 등)
#  - _GLOBAL_REBUILD_ 는 모든 scope 에서 감지/로그한다.
#  - 단, 이 GitHub Actions 구조는 output/ 을 cross-run cache 하지 않고,
#    모든 artifact 가 같은 SHA의 현재 run에서 생성된다. 따라서 downstream stage에서
#    upstream toolchain/base/frontend stamp 를 다시 지우면 불필요한 대형 재빌드가 발생한다.
#  - 그래서 전역 변경은 destructive clean 대신 final image stamp 만 제거한다.
#  - dl/ 와 ccache 는 건드리지 않는다.
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


# package/<...>/<PKG>/<file> 형태에서 실제 패키지명 추출
# 기준: 경로를 위로 올라가며 *.mk 파일이 있는 디렉토리명을 패키지명으로 본다.
# 이유: Knulli/Batocera/Buildroot package 트리는 package/audio/m8c 처럼 중첩될 수 있어
#       package/ 바로 아래 디렉토리(a[2])나 마지막에서 두 번째 디렉토리(a[n-1])를
#       고정으로 쓰면 오탐한다.
extract_pkg_from_path() {
  local root="$1"
  local path="$2"
  local d

  [[ "$path" == package/* ]] || return 1

  d="$(dirname "$path")"
  while [[ "$d" == package/* && "$d" != "package" && "$d" != "." ]]; do
    if ( cd "$root" 2>/dev/null && compgen -G "$d/*.mk" >/dev/null ); then
      basename "$d"
      return 0
    fi
    d="$(dirname "$d")"
  done

  # package/pkg-generic.mk 같은 전역 infra 파일은 여기서 패키지명으로 오인하지 않는다.
  return 1
}

# 전역 build infra/config 변경 감지
# 이 파일들이 바뀌면 특정 패키지만 stamp 제거하는 방식은 stale artifact 위험이 크다.
# 단순/안전 정책: _GLOBAL_REBUILD_ 마커를 모든 stage 에 전달한다.
is_global_infra_path() {
  local path="$1"

  case "$path" in
    # top-level orchestration / config
    Makefile|Config.in|Config.in.*|*/Makefile|*/Config.in|*/Config.in.*)
      return 0
      ;;

    # Buildroot/Batocera package infrastructure
    package/pkg-*.mk|*/package/pkg-*.mk)
      return 0
      ;;

    # Config.in graph changes can alter selected packages/dependencies.
    package/Config.in|package/Config.in.*|package/*/Config.in|package/*/Config.in.*|*/package/Config.in|*/package/Config.in.*|*/package/*/Config.in|*/package/*/Config.in.*)
      return 0
      ;;

    # common helper scripts/support files used by build/package infra
    support/*|scripts/*|utils/*|*/support/*|*/scripts/*|*/utils/*)
      return 0
      ;;
  esac

  return 1
}

emit_global_marker_if_needed() {
  local path="$1"
  if is_global_infra_path "$path"; then
    echo "_GLOBAL_REBUILD_"
  fi
}

# ─── 1) 메인 레포의 변경 ──────────────────────────────────────────────
# package/  : knulli 고유 패키지 (중첩 구조 가능: package/audio/m8c/...)
# board/    : 보드 오버레이 (별도 마커로 처리)
# Makefile/Config.in/support/scripts/pkg-*.mk 등은 전역 rebuild 마커로 처리
MAIN_DIFF=$(git diff --name-only "$LAST_TAG..HEAD" 2>/dev/null || true)

echo "$MAIN_DIFF" | while IFS= read -r F; do
  [ -n "$F" ] || continue

  emit_global_marker_if_needed "$F" || true

  case "$F" in
    board/*)
      echo "_BOARD_OVERLAY_"
      ;;
    package/*)
      extract_pkg_from_path "." "$F" || true
      ;;
  esac
done >> "$TMP_CHANGED" || true

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
      git cat-file -e "${SHA}^{commit}" 2>/dev/null ||         git fetch --depth=200 origin "$SHA" 2>/dev/null ||         git fetch --unshallow origin 2>/dev/null || true
    done
    git diff --name-only "$PREV_SHA..$CUR_SHA" 2>/dev/null || true
  )

  # 서브모듈 안의 package 경로에서도 .mk 파일이 있는 디렉토리를 패키지명으로 추출
  # 전역 infra/config 변경은 _GLOBAL_REBUILD_ 로 처리
  echo "$SM_DIFF" | while IFS= read -r F; do
    [ -n "$F" ] || continue
    emit_global_marker_if_needed "$SM/$F" || true
    extract_pkg_from_path "$SM" "$F" || true
  done >> "$TMP_CHANGED" || true
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
  # 전역 infra/config 변경은 모든 stage 에서 처리한다.
  # scope/exclude 로 걸러버리면 일부 stage 가 stale output 을 들고 갈 수 있다.
  if [ "$P" = "_GLOBAL_REBUILD_" ]; then
    FILTERED="$FILTERED $P"
    continue
  fi

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
  if [ "$P" = "_GLOBAL_REBUILD_" ]; then
    echo "  global infra/config 변경 감지"
    echo "    - 이 workflow는 output/을 cross-run cache 하지 않음"
    echo "    - upstream artifact는 같은 SHA/current run에서 생성된 것이므로 toolchain/base/frontend stamp는 보존"
    echo "    - 최종 image/finalize stamp만 제거해 이미지 재생성은 보장"

    rm -rf "output/${BOARD}/images" 2>/dev/null || true
    rm -f "output/${BOARD}/build/.stamp_target_finalized" 2>/dev/null || true
    rm -f "output/${BOARD}/.stamp_target_finalized" 2>/dev/null || true
    rm -f "output/${BOARD}/.stamp_images_built" 2>/dev/null || true
    continue
  fi

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
  for D in $(find output/${BOARD}/build -maxdepth 1 -type d \( \
              -name "${P}" \
           -o -name "${P}-[0-9]*" \
           -o -name "${P}-v[0-9]*" \
           -o -name "${P}-custom" \
           -o -name "${P}-git*" \
           -o -name "${P}-master*" \
           -o -name "${P}-[a-f0-9][a-f0-9]*" \
         \) 2>/dev/null); do
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
