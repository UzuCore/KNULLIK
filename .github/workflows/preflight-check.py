#!/usr/bin/env python3
"""build-board.yml 의 0-check 잡: 몇 시간짜리 빌드 전에 몇 분 안에 잡을 수 있는 문제를 찾는다.

  boards   .github/ci-boards.json 에서 빌드 매트릭스와 미러 보드 목록을 만든다.
  config   보드 설정과 Config.in 점검. 오류가 있으면 종료 코드 1.
           - 보드 설정에 적었지만 빌드가 읽는 어떤 Config.in 에도 없는 옵션
             (예: uboot-a133 의 Config.in 을 불러오지 않아 BR2_PACKAGE_UBOOT_A133=y 가 무시됨)
           - --base-ref 이후 추가한 설정 줄이 .config 에 반영되지 않음 (의존성 미충족 등)
           - --base-ref 이후 추가한 Config.in 줄의 select/depends 가 없는 옵션을 가리킴 (오타 등)
           - 4단계 잡 패키지 목록에 없는 패키지 이름 (경고)
  sources  미러 릴리즈에 없는 소스 파일 목록을 TSV(패키지, dl 하위 폴더, 파일 이름)로 쓴다.
  floating git 브랜치를 따라가는 패키지를 경고한다 (upstream 이 바뀌면 빌드가 갑자기 깨질 수 있음).
"""
import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys

STAGE_LIST_VARS = ("HEAVY_LIBRETRO_PACKAGES", "STANDALONE_PACKAGES", "STANDALONE_HEAVY_PACKAGES")
# update-mirror-sources.yml 과 같은 규칙: GitHub 가 이름을 바꾸는 파일과 2 GiB 이상 파일은 미러에 올릴 수 없다.
MIRROR_NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")
ASSIGN_RE = re.compile(r"^(BR2_\w+)=(.*)$")
KCONFIG_REF_RE = re.compile(r"^(select|imply|depends\s+on|default|if|visible\s+if|range)\b(.*)$")
MAX_ITEMS = 30


def esc_data(s):
    return s.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def esc_prop(s):
    return esc_data(s).replace(":", "%3A").replace(",", "%2C")


def annotate(level, title, lines):
    shown = lines[:MAX_ITEMS]
    if len(lines) > MAX_ITEMS:
        shown.append(f"... 외 {len(lines) - MAX_ITEMS}개")
    print(f"::{level} title={esc_prop(title)}::{esc_data(chr(10).join(shown))}")


def summary(text):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as f:
            f.write(text.rstrip("\n") + "\n\n")


def summary_list(title, lines):
    body = "\n".join(f"- {l}" for l in lines[:MAX_ITEMS])
    if len(lines) > MAX_ITEMS:
        body += f"\n- ... 외 {len(lines) - MAX_ITEMS}개"
    summary(f"#### {title}\n\n{body}")


def value_of(raw):
    """defconfig 값에서 따옴표 밖의 '# 주석'을 뗀다."""
    raw = raw.strip()
    if raw.startswith('"'):
        m = re.match(r'"(?:[^"\\]|\\.)*"', raw)
        return m.group(0) if m else raw
    return re.sub(r"\s+#.*$", "", raw)


def strip_kconfig_expr(s):
    return re.sub(r'"(?:[^"\\]|\\.)*"', '""', s.split("#", 1)[0])


def indent_width(line):
    expanded = line.expandtabs(8)
    return len(expanded) - len(expanded.lstrip())


class Kconfig:
    """빌드가 실제로 읽는 Config.in 파일(source 로 이어진 것)과 정의된 옵션, 옵션 참조를 모은다."""

    def __init__(self, project, base_dir, docker_root):
        self.project = os.path.realpath(project)
        self.br = os.path.join(self.project, "buildroot")
        self.env = {"BR2_BASE_DIR": os.path.realpath(base_dir), "BR2_EXTERNAL_KNULLI_PATH": self.project}
        self.docker_root = docker_root.rstrip("/")
        self.files = set()
        self.defined = set()
        self.refs = []  # (symbol, realpath, line number)
        self._walk(os.path.join(self.br, "Config.in"))

    def _expand(self, path):
        path = re.sub(r"\$\{?(\w+)\}?", lambda m: self.env.get(m.group(1), m.group(0)), path)
        # .br2-external.in.* 에는 Docker 안의 경로(/build/...)가 적혀 있다.
        if self.docker_root and path.startswith(self.docker_root + "/") and not os.path.exists(path):
            path = self.project + path[len(self.docker_root):]
        return path if os.path.isabs(path) else os.path.join(self.br, path)

    def _walk(self, path):
        real = os.path.realpath(path)
        if real in self.files:
            return
        try:
            with open(real, errors="replace") as f:
                lines = f.read().splitlines()
        except OSError:
            return
        self.files.add(real)
        in_help, help_indent = False, None
        for no, line in enumerate(lines, 1):
            s = line.strip()
            if in_help:
                if not s:
                    continue
                if help_indent is None:
                    help_indent = indent_width(line)
                if indent_width(line) >= help_indent:
                    continue
                in_help = False
            if not s or s.startswith("#"):
                continue
            if s in ("help", "---help---"):
                in_help, help_indent = True, None
                continue
            # Kconfig 는 닫는 따옴표가 없어도 경고만 내고 불러온다 (Config.in 의 silkyrgb 줄).
            m = re.match(r'^source\s+"?([^"\s]+)"?', s)
            if m:
                self._walk(self._expand(m.group(1)))
                continue
            m = re.match(r"^(?:menu)?config\s+(\w+)", s)
            if m:
                self.defined.add(m.group(1))
                continue
            m = KCONFIG_REF_RE.match(s)
            if m:
                for sym in re.findall(r"\bBR2_\w+", strip_kconfig_expr(m.group(2))):
                    self.refs.append((sym, real, no))

    def owned(self, real):
        """KNULLIK 저장소 자체의 Config.in 인지 (batocera/buildroot 서브모듈 제외)."""
        return real == os.path.join(self.project, "Config.in") or real.startswith(os.path.join(self.project, "package") + os.sep)


def read_defconfig(path, board):
    """createDefconfig.sh 가 만든 defconfig 를 읽어 [(옵션, 값, 원본 파일, 줄)] 을 돌려준다."""
    origin = f"configs/knulli-{board}.board"
    out = []
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = re.match(r"^# from file (\S+)", line)
            if m:
                origin = f"configs/{m.group(1)}"
                continue
            if line.startswith("### from board file ###"):
                origin = f"configs/knulli-{board}.board"
                continue
            m = ASSIGN_RE.match(line.strip())
            if m:
                out.append((m.group(1), value_of(m.group(2)), origin, line.strip()))
    return out


def read_dotconfig(path):
    values = {}
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = ASSIGN_RE.match(line)
            if m:
                values[m.group(1)] = m.group(2)
                continue
            m = re.match(r"^# (BR2_\w+) is not set$", line)
            if m:
                values[m.group(1)] = "n"
    return values


def added_lines(project, base_ref, pathspecs):
    """base_ref..HEAD 에서 추가된 줄: {상대 경로: {줄 번호: 내용}}"""
    try:
        diff = subprocess.run(
            ["git", "-C", project, "diff", "-U0", "--no-color", "--no-ext-diff", base_ref, "HEAD", "--", *pathspecs],
            check=True, capture_output=True, text=True, errors="replace").stdout
    except subprocess.CalledProcessError as e:
        print(f"::notice::{base_ref} 와 비교하지 못해 새로 추가한 줄 점검을 건너뜁니다: {e.stderr.strip()[:200]}")
        return None
    result, path, new_no = {}, None, 0
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
            continue
        m = re.match(r"^@@ -\S+ \+(\d+)(?:,\d+)? @@", line)
        if m:
            new_no = int(m.group(1))
            continue
        if path and line.startswith("+"):
            result.setdefault(path, {})[new_no] = line[1:]
            new_no += 1
    return result


def package_names(project):
    names = set()
    roots = [os.path.join(project, "package"), os.path.join(project, "batocera", "package"),
             os.path.join(project, "buildroot", "package")]
    for root in roots:
        for _, _, files in os.walk(root):
            names.update(f[:-3] for f in files if f.endswith(".mk"))
    return names


def select_boards(boards, inputs):
    if not boards or len(boards) != len(set(boards)) or any(not re.fullmatch(r"[a-z0-9_-]+", b) for b in boards):
        raise ValueError("CI 보드 목록이 비었거나, 중복/잘못된 이름이 있습니다")
    selected = [b for b in boards if inputs.get(b) in (True, "true")]
    return selected or boards


def cmd_boards(args):
    with open(args.file) as f:
        boards = json.load(f)
    inputs = json.loads(os.environ.get(args.inputs_env, "{}")) if args.inputs_env else {}
    selected = select_boards(boards, inputs)
    print("matrix=" + json.dumps([{"board": b} for b in selected], separators=(",", ":")))
    print("BOARDS=" + " ".join(selected))
    return 0


def cmd_config(args):
    project = os.path.realpath(args.project)
    output = args.output or os.path.join(project, "output", args.board)
    kc = Kconfig(project, output, args.docker_root)
    requested = read_defconfig(os.path.join(project, "configs", f"knulli-{args.board}_defconfig"), args.board)
    actual = read_dotconfig(os.path.join(output, ".config"))
    print(f"Config.in {len(kc.files)}개, 옵션 {len(kc.defined)}개, 보드 설정 줄 {len(requested)}개")
    errors = 0

    final = {entry[0]: entry for entry in requested}
    unknown = [f"{origin}: {line}" for sym, val, origin, line in final.values() if sym not in kc.defined and val != "n"]
    if unknown:
        errors += 1
        title = f"{args.board} · 어떤 Config.in 에도 없는 옵션 {len(unknown)}개"
        hint = "옵션 이름이 틀렸거나, 패키지의 Config.in 을 최상위 Config.in 에서 source 하지 않았거나, 삭제된 옵션입니다."
        annotate("error", title, unknown + [hint])
        summary_list(title, unknown + [hint])

    if args.base_ref:
        added = added_lines(project, args.base_ref, ["configs", "Config.in", "package"])
        if added is not None:
            errors += check_new_config_lines(args, requested, actual, added)
            errors += check_new_kconfig_refs(args, kc, project, added)

    names = package_names(project)
    seen = {}
    stage_warn = []
    for var in STAGE_LIST_VARS:
        for name in os.environ.get(var, "").split():
            if name not in names:
                stage_warn.append(f"{var}: {name} 패키지가 없습니다 (이름이 바뀌었거나 삭제됨)")
            if name in seen:
                stage_warn.append(f"{name} 가 {seen[name]} 와 {var} 에 모두 있습니다")
            seen.setdefault(name, var)
    if stage_warn:
        title = f"{args.board} · 4단계 잡 패키지 목록 확인 필요"
        annotate("warning", title, stage_warn)
        summary_list(title, stage_warn)

    if not errors:
        summary(f"#### {args.board} · 설정 점검 통과")
    return 1 if errors else 0


def check_new_config_lines(args, requested, actual, added):
    added_text = {path: {t.strip() for t in lines.values()} for path, lines in added.items()}
    final = {}
    for entry in requested:
        final[entry[0]] = entry
    bad = []
    for sym, val, origin, line in final.values():
        if line not in added_text.get(origin, set()) or val == "n":
            continue
        got = actual.get(sym)
        if val == "y" and got == "y":
            continue
        if val != "y" and got == val:
            continue
        shown = got if got is not None else "없음 (의존성이 맞지 않아 숨겨짐)"
        bad.append(f"{origin}: {line} → 실제 .config: {shown}")
    if bad:
        title = f"{args.board} · 새로 추가한 설정 {len(bad)}줄이 적용되지 않음"
        hint = "Config.in 의 depends on 조건(아키텍처, GPU 등)이 이 보드에서 맞지 않는지 확인하세요."
        annotate("error", title, bad + [hint])
        summary_list(title, bad + [hint])
        return 1
    return 0


def check_new_kconfig_refs(args, kc, project, added):
    bad = []
    for sym, real, no in kc.refs:
        if sym in kc.defined or not kc.owned(real):
            continue
        rel = os.path.relpath(real, project)
        if no in added.get(rel, {}):
            bad.append(f"{rel}:{no}: {added[rel][no].strip()} → {sym} 는 정의되지 않은 옵션")
    if bad:
        title = f"{args.board} · 새로 추가한 Config.in 줄이 없는 옵션을 가리킴 {len(bad)}개"
        hint = "없는 옵션을 select 하거나 depends on 하면 Kconfig 가 경고 없이 무시합니다. 오타나 source 누락을 확인하세요."
        annotate("error", title, bad + [hint])
        summary_list(title, bad + [hint])
        return 1
    return 0


def load_show_info(path):
    """`make <board>-build CMD=show-info` 출력에서 JSON 부분만 읽는다 (앞뒤에 make 출력이 섞여 있음)."""
    with open(path, errors="replace") as f:
        text = f.read()
    m = re.search(r"^\{", text, re.M)
    if not m:
        sys.exit("show-info 출력에서 JSON 을 찾지 못했습니다")
    info, _ = json.JSONDecoder().raw_decode(text[m.start():])
    return info


def cmd_sources(args):
    info = load_show_info(args.show_info)
    with open(args.assets) as f:
        assets = {l.strip() for l in f if l.strip()}
    needed, missing, unmirrorable = set(), [], set()
    for name, pkg in sorted(info.items()):
        if pkg.get("virtual"):
            continue
        for dl in pkg.get("downloads", []):
            src = dl.get("source")
            if not src or not dl.get("uris"):
                continue
            needed.add(src)
            if src in assets:
                continue
            if not MIRROR_NAME_RE.fullmatch(src):
                unmirrorable.add(src)
                continue
            missing.append((name, pkg.get("dl_dir") or name, src))
    seen, rows = set(), []
    for row in missing:
        if row[2] not in seen:
            seen.add(row[2])
            rows.append(row)
    with open(args.out, "w") as f:
        f.writelines("\t".join(r) + "\n" for r in rows)
    print(f"필요한 소스 {len(needed)}개, 미러에 없음 {len(rows)}개, 미러에 올릴 수 없는 이름 {len(unmirrorable)}개")
    for r in rows:
        print(f"  미러에 없음: {r[2]} ({r[0]})")
    for n in sorted(unmirrorable):
        print(f"  미러에 올릴 수 없는 이름 (원래 주소에서 받음): {n}")
    return 0


def upstream_repo(pkg):
    """패키지의 git 저장소 주소 (git 방식이거나 GitHub 아카이브일 때만)."""
    for dl in pkg.get("downloads", []):
        for uri in dl.get("uris", []):
            if "|urlencode" in uri:  # BR2_PRIMARY_SITE / BR2_BACKUP_SITE
                continue
            if uri.startswith("git+"):
                return uri[4:]
            m = re.match(r"^https?\+(https://github\.com/[^/]+/[^/]+?)(?:\.git)?/archive/", uri)
            if m:
                return m.group(1)
            return None
    return None


def is_branch(repo, version):
    try:
        out = subprocess.run(["git", "ls-remote", "--heads", repo, f"refs/heads/{version}"],
                             capture_output=True, text=True, timeout=30,
                             env={**os.environ, "GIT_TERMINAL_PROMPT": "0"}).stdout
    except (subprocess.TimeoutExpired, OSError):
        return False
    return bool(out.strip())


def cmd_floating(args):
    info = load_show_info(args.show_info)
    cands = []
    for name, pkg in sorted(info.items()):
        version = pkg.get("version") or ""
        if pkg.get("virtual") or not version or re.fullmatch(r"[0-9a-f]{40}", version):
            continue
        repo = upstream_repo(pkg)
        if repo:
            cands.append((name, version, repo))
    with concurrent.futures.ThreadPoolExecutor(16) as ex:
        flags = list(ex.map(lambda c: is_branch(c[2], c[1]), cands))
    floating = [f"{n}: {v} ({r})" for (n, v, r), f in zip(cands, flags) if f]
    print(f"git/GitHub 패키지 중 커밋으로 고정하지 않은 것 {len(cands)}개, 그중 브랜치 {len(floating)}개")
    for l in floating:
        print(f"  {l}")
    if floating:
        title = f"{args.board} · 브랜치를 따라가는 패키지 {len(floating)}개"
        hint = "upstream 이 바뀌면 다음 미러 갱신 뒤 빌드가 깨질 수 있습니다. 버전을 커밋 해시로 고정하는 것을 권장합니다."
        annotate("warning", title, floating + [hint])
        summary_list(title, floating + [hint])
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("boards")
    b.add_argument("--file", default=".github/ci-boards.json")
    b.add_argument("--inputs-env", default="")
    c = sub.add_parser("config")
    c.add_argument("--board", required=True)
    c.add_argument("--project", default=".")
    c.add_argument("--output", help="buildroot 출력 폴더 (기본: output/<board>)")
    c.add_argument("--base-ref", default="", help="새로 추가한 줄을 가릴 기준 커밋/태그")
    c.add_argument("--docker-root", default="/build", help="Docker 안에서 프로젝트가 보이는 경로")
    s = sub.add_parser("sources")
    s.add_argument("--show-info", required=True)
    s.add_argument("--assets", required=True)
    s.add_argument("--out", required=True)
    fl = sub.add_parser("floating")
    fl.add_argument("--board", required=True)
    fl.add_argument("--show-info", required=True)
    args = p.parse_args()
    return {"boards": cmd_boards, "config": cmd_config, "sources": cmd_sources, "floating": cmd_floating}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
