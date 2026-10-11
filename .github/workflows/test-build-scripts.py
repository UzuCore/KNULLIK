#!/usr/bin/env python3
"""빌드 없이 실행하는 사전 점검/공통 실행기의 회귀 테스트 (표준 라이브러리만 사용)."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import textwrap
import tempfile
import types
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("preflight", HERE / "preflight-check.py")
pf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pf)


class PreflightTests(unittest.TestCase):
    def test_boards_all_and_selected(self):
        boards = json.loads((HERE.parent / "ci-boards.json").read_text())
        self.assertEqual(boards, ["h700", "a133", "rk3128", "rk3326"])
        self.assertEqual(pf.select_boards(boards, {}), boards)
        self.assertEqual(pf.select_boards(boards, {b: False for b in boards}), boards)
        self.assertEqual(pf.select_boards(boards, {"rk3326": True}), ["rk3326"])
        self.assertEqual(pf.select_boards(boards, {"h700": "true", "rk3326": True}), ["h700", "rk3326"])
        for bad in ([], ["h700", "h700"], ["../oops"]):
            with self.assertRaises(ValueError):
                pf.select_boards(bad, {})

    def test_kconfig_graph_and_help(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            (p / "buildroot").mkdir()
            (p / "output").mkdir()
            (p / "buildroot/Config.in").write_text('source "$BR2_BASE_DIR/.br2-external.in.menus"\n')
            (p / "output/.br2-external.in.menus").write_text('source "/build/Config.in"\n')
            (p / "Config.in").write_text('config BR2_PACKAGE_OK\n  bool "ok"\n  help\n    config BR2_FAKE\n    select BR2_HELP_ONLY\n\nconfig BR2_OTHER\n  select BR2_TYPO\n')
            kc = pf.Kconfig(tmp, p / "output", "/build")
            self.assertEqual(kc.defined, {"BR2_PACKAGE_OK", "BR2_OTHER"})
            self.assertEqual([r[0] for r in kc.refs], ["BR2_TYPO"])

    def test_new_config_assignment_last_wins(self):
        args = types.SimpleNamespace(board="test")
        requested = [("BR2_PACKAGE_OK", "y", "configs/test.board", "BR2_PACKAGE_OK=y"),
                     ("BR2_PACKAGE_OK", "n", "configs/test.board", "BR2_PACKAGE_OK=n")]
        added = {"configs/test.board": {1: "BR2_PACKAGE_OK=y", 2: "BR2_PACKAGE_OK=n"}}
        with contextlib.redirect_stdout(io.StringIO()), patch.dict(os.environ, {}, clear=True):
            self.assertEqual(pf.check_new_config_lines(args, requested, {"BR2_PACKAGE_OK": "n"}, added), 0)
            self.assertEqual(pf.check_new_config_lines(args, requested[:1], {"BR2_PACKAGE_OK": "n"}, added), 1)

    def test_new_kconfig_ref_is_fatal_legacy_ref_is_not(self):
        args = types.SimpleNamespace(board="test")
        kc = types.SimpleNamespace(defined=set(), refs=[("BR2_TYPO", "/project/Config.in", 3)], owned=lambda _: True)
        with contextlib.redirect_stdout(io.StringIO()), patch.dict(os.environ, {}, clear=True):
            self.assertEqual(pf.check_new_kconfig_refs(args, kc, "/project", {}), 0)
            self.assertEqual(pf.check_new_kconfig_refs(args, kc, "/project", {"Config.in": {3: "select BR2_TYPO"}}), 1)

    def test_missing_sources_deduplicates_and_skips_local(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            info = {
                "existing": {"downloads": [{"source": "exists.tar.gz", "uris": ["https+https://example.org"]}]},
                "pkg": {"dl_dir": "pkg", "downloads": [{"source": "missing.tar.gz", "uris": ["git+https://example.org"]}]},
                "host-pkg": {"dl_dir": "pkg", "downloads": [{"source": "missing.tar.gz", "uris": ["git+https://example.org"]}]},
                "local": {"downloads": [{"source": "local.tar.gz", "uris": []}]},
                "bad-name": {"downloads": [{"source": "bad+name.tar.gz", "uris": ["https+https://example.org"]}]},
                "virtual": {"virtual": True, "downloads": [{"source": "virtual.tar.gz", "uris": ["https+https://example.org"]}]}}
            (p / "info").write_text("make preamble\n" + json.dumps(info) + "\nmake trailer\n")
            (p / "assets").write_text("exists.tar.gz\n")
            args = types.SimpleNamespace(show_info=p / "info", assets=p / "assets", out=p / "out")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(pf.cmd_sources(args), 0)
            rows = (p / "out").read_text().splitlines()
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0].split("\t")[1:], ["pkg", "missing.tar.gz"])

    def test_upstream_repo_skips_mirror(self):
        pkg = {"downloads": [{"uris": ["https+https://github.com/mirror/releases/download/sources|urlencode", "https+https://github.com/example/repo/archive/v1"]}]}
        self.assertEqual(pf.upstream_repo(pkg), "https://github.com/example/repo")
        pkg["downloads"][0]["uris"][1] = "git+https://github.com/example/repo.git"
        self.assertEqual(pf.upstream_repo(pkg), "https://github.com/example/repo.git")

    def test_annotation_escaping(self):
        self.assertEqual(pf.esc_prop("a:b,c%\n"), "a%3Ab%2Cc%25%0A")
        self.assertEqual(pf.value_of('y # note'), 'y')
        self.assertEqual(pf.value_of('"value # literal" # note'), '"value # literal"')


class RetryTests(unittest.TestCase):
    def run_retry(self, jobs, messages, status="failure", attempt=1):
        workflow = (HERE / "retry-workflow.yml").read_text()
        script = textwrap.dedent(workflow.split("      - name: Rerun failed jobs", 1)[1].split("        run: |\n", 1)[1])
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            (p / "bin").mkdir()
            (p / "meta").write_text(f"{status}\t{attempt}\n")
            (p / "jobs").write_text("".join(f"{job}\thttps://api.github.com/repos/UzuCore/KNULLIK/check-runs/{check}\n" for job, check in jobs))
            for check, msg in messages.items():
                (p / f"annotation-{check}").write_text(msg)
            gh = p / "bin/gh"
            gh.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> calls\nif [ "$1" = run ]; then echo rerun >> reruns; exit 0; fi\n[ "$2" != --paginate ] || shift\ncase "$2" in\n  */jobs?*) cat jobs ;;\n  */annotations?*) id=${2%/annotations?*}; id=${id##*/}; cat "annotation-$id" ;;\n  *) cat meta ;;\nesac\n')
            gh.chmod(0o755)
            env = {**os.environ, "PATH": str(p / "bin") + os.pathsep + os.environ["PATH"], "GH_REPO": "UzuCore/KNULLIK", "RUN_ID": "123"}
            r = subprocess.run(["bash", "-eo", "pipefail", "-c", script], cwd=p, env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(r.returncode, 0, r.stderr)
            return (p / "reruns").exists(), (p / "calls").read_text(), r.stdout

    def test_check_run_id_and_pagination(self):
        retried, calls, _ = self.run_retry([(100, 900)], {900: "The runner lost communication"})
        self.assertTrue(retried)
        self.assertIn("check-runs/900/annotations?per_page=100", calls)
        self.assertNotIn("check-runs/100/", calls)
        self.assertIn("--paginate", calls)

    def test_build_failure_alone_or_mixed_not_retried(self):
        for jobs in ([(100, 900)], [(100, 900), (101, 901)]):
            retried, _, _ = self.run_retry(jobs, {900: "fatal error: missing.h", 901: "lost communication"})
            self.assertFalse(retried)

    def test_attempt_limit_success_and_cancelled(self):
        for status, attempt in (("failure", 3), ("success", 1), ("cancelled", 1)):
            retried, _, _ = self.run_retry([(100, 900)], {900: "lost communication"}, status, attempt)
            self.assertFalse(retried)

    def test_board_and_stage_list_consistency(self):
        boards = json.loads((HERE.parent / "ci-boards.json").read_text())
        workflow = (HERE / "build.yml").read_text()
        boolean_inputs = re.findall(r"^      ([a-z0-9_-]+):\n        description: [^\n]*\n        type: boolean$", workflow, re.M)
        self.assertEqual(boolean_inputs, boards)
        text = (HERE / "build-board.yml").read_text()
        lists = re.findall(r"^  (?:HEAVY_LIBRETRO|STANDALONE|STANDALONE_HEAVY)_PACKAGES: >-\n((?:    [^\n]+\n)+)", text, re.M)
        self.assertEqual(len(lists), 3)
        names = [p for stage in lists for p in stage.split()]
        self.assertEqual(len(names), len(set(names)))
        available = pf.package_names(str(HERE.parent.parent))
        self.assertFalse(set(names) - available)


class RunnerTests(unittest.TestCase):
    def run_fake(self, logs, codes):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)
            (p / "bin").mkdir()
            for i, log in enumerate(logs, 1):
                (p / f"log{i}").write_text(log)
                (p / f"rc{i}").write_text(str(codes[i-1]))
            make = p / "bin/make"
            make.write_text('#!/bin/bash\nn=$(cat count 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > count\nprintf "%s\\n" "$@" >> args\ncat "log$n"; exit "$(cat rc$n)"\n')
            make.chmod(0o755)
            sleep = p / "bin/sleep"
            sleep.write_text('#!/bin/bash\n[ "$1" != 300 ]\n')
            sleep.chmod(0o755)
            env = {**os.environ, "PATH": str(p / "bin") + os.pathsep + os.environ["PATH"], "BOARD": "rk3326", "GITHUB_STEP_SUMMARY": str(p / "summary")}
            result = subprocess.run(["bash", str(HERE / "run-build.sh"), "test", "pkg"], cwd=p, env=env, text=True, capture_output=True, timeout=10)
            return result.returncode, int((p / "count").read_text()), result.stdout, (p / "summary").read_text() if (p / "summary").exists() else "", (p / "args").read_text()

    def test_success_without_filtered_output(self):
        rc, count, out, summary, args = self.run_fake(["quiet success\n"], [0])
        self.assertEqual((rc, count), (0, 1))
        self.assertIn("CMD=pkg", args)
        self.assertIn("--name=knulli-rk3326-test-", args)

    def test_compile_failure_no_retry(self):
        log = '>>> pkg 1 Building\n\x1b[31mfatal error: GLES2/gl2.h: No such file or directory\x1b[0m\nmake: *** [/rk3326/build/pkg-1/.stamp_built] Error 2\n'
        rc, count, out, summary, _ = self.run_fake([log], [2])
        self.assertEqual((rc, count), (2, 1))
        self.assertIn("pkg-1", summary)
        self.assertIn("GLES2/gl2.h", summary)
        self.assertIn("_DEPENDENCIES", summary)
        self.assertNotIn("\x1b", summary)

    def test_transient_download_retries(self):
        log = '>>> pkg 1 Downloading\nERROR 502: Bad Gateway.\nmake: *** [/rk3326/build/pkg-1/.stamp_downloaded] Error 1\n'
        rc, count, _, _, _ = self.run_fake([log, ">>> pkg 1 Building\n"], [2, 0])
        self.assertEqual((rc, count), (0, 2))

    def test_memory_failure_retries(self):
        log = '>>> pkg 1 Building\ngcc: fatal error: Killed signal terminated program cc1\nmake: *** [/rk3326/build/pkg-1/.stamp_built] Error 2\n'
        rc, count, _, _, _ = self.run_fake([log, "success\n"], [2, 0])
        self.assertEqual((rc, count), (0, 2))

    def test_hash_and_disk_failure_no_retry(self):
        for log, cause in [
            ('>>> pkg 1 Downloading\nERROR: pkg.tar.gz has wrong sha256 hash:\nmake: *** [/rk3326/build/pkg-1/.stamp_downloaded] Error 1\n', "소스 해시 불일치"),
            ('>>> pkg 1 Building\nNo space left on device\nmake: *** [/rk3326/build/pkg-1/.stamp_built] Error 2\n', "디스크 공간 부족")]:
            with self.subTest(cause=cause):
                rc, count, _, summary, _ = self.run_fake([log], [2])
                self.assertEqual((rc, count), (2, 1))
                self.assertIn(cause, summary)

    def test_final_download_failure_reported(self):
        log = '>>> pkg 1 Downloading\nERROR 404: Not Found.\nmake: *** [/rk3326/build/pkg-1/.stamp_downloaded] Error 1\n'
        rc, count, out, summary, _ = self.run_fake([log, log], [2, 2])
        self.assertEqual((rc, count), (2, 2))
        self.assertIn("::error title=rk3326", out)
        self.assertIn("소스 다운로드 실패", summary)


if __name__ == "__main__":
    unittest.main()
