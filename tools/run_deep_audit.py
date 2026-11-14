#!/usr/bin/env python3
"""Bounded audit driver. Requires Python 3 stdlib and Godot 4.5.1.

Run from any directory; logs go to --out, never the normal save directory.
Exit 1 means desired-behaviour regressions remain; exit 2 is setup/CLI failure.
Known ObjectDB teardown warnings are retained and counted, never hidden.
"""
import argparse
import json
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SAVE_CASES = ["valid", "broken_json", "root_array", "missing_schema", "unsupported_schema",
              "wrong_players_container", "negative_budget", "missing_player", "duplicate_fixture",
              "round_high", "round_negative", "round_string", "season_zero", "season_over_type",
              "lineup_duplicate", "lineup_empty", "lineup_no_keeper", "squad_type", "club_null",
              "player_null", "attrs_type", "attr_missing", "attr_range", "age_missing",
              "fixture_score_negative", "fixture_season_missing", "fixture_played_type", "fixture_self_match",
              "transfer_list_type", "history_type", "both_invalid", "missing_backup"]
EDGE_CASES = ["determinism", "career_stress", "substitution_state", "backpass_feet", "pause_shot", "pass_handoff", "keeper_only_lineup", "match_lifetime", "camera_input", "pause_policy"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--out", type=pathlib.Path, required=True)
    parser.add_argument("--group", choices=["all", "save", "edge"], default="all")
    args = parser.parse_args()
    binary = shutil.which(args.godot)
    if not binary:
        parser.error("Godot executable not found")
    version = subprocess.run([binary, "--version"], capture_output=True, text=True, timeout=15).stdout.strip()
    if not version.startswith("4.5.1."):
        parser.error("Use the project engine 4.5.1; found " + version)
    args.out.mkdir(parents=True, exist_ok=True)
    cases = []
    if args.group in ("all", "save"):
        cases += [("save/" + name, "tools/audit_save_case.gd", name, "SAVE_CASE_DONE") for name in SAVE_CASES]
    if args.group in ("all", "edge"):
        cases += [("edge/" + name, "tools/deep_audit.gd", name, "DEEP_AUDIT_DONE") for name in EDGE_CASES]
    results = []
    for name, script, case, sentinel in cases:
        command = [binary, "--headless", "-s", script, "--", "--case=" + case]
        timeout = False
        try:
            process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=60)
            output = process.stdout + process.stderr
            code = process.returncode
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or b"").decode(errors="replace") + (exc.stderr or b"").decode(errors="replace")
            code, timeout = -1, True
        log = args.out / (name.replace("/", "_") + ".log")
        log.write_text(output, encoding="utf-8")
        script_error = "SCRIPT ERROR:" in output or "Parse Error:" in output or "Failed to load script" in output
        ok = code == 0 and sentinel in output and not script_error and not timeout
        result = {"name": name, "ok": ok, "exit": code, "script_error": script_error,
                  "completed": sentinel in output, "timeout": timeout,
                  "lifetime_warning": "ObjectDB instances leaked" in output,
                  "command": command, "log": log.name}
        results.append(result)
        print(("PASS " if ok else "FAIL ") + name + " exit=" + str(code) + (" SCRIPT_ERROR" if script_error else ""), flush=True)
    report = {"engine": version, "cases": len(results), "passed": sum(r["ok"] for r in results), "results": results}
    (args.out / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("AUDIT: %d/%d subprocess cases passed" % (report["passed"], report["cases"]))
    return 0 if report["passed"] == report["cases"] else 1


if __name__ == "__main__":
    sys.exit(main())
