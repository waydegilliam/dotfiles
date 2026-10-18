#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.15.0"
# dependencies = ["pydantic==2.14.1"]
# ///

import json
import os
import shlex
import signal
import subprocess
import sys
import tempfile
import time
import tomllib
from collections.abc import Iterator
from dataclasses import dataclass
from functools import cache
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, ValidationError

TIMEOUT_SECONDS = 270
OUTPUT_LIMIT = 12000
EXCLUDED_DIRECTORIES = set(
    """
    .git node_modules .pnpm-store .venv venv __pycache__ .cache .uv-cache
    .ruff_cache .pytest_cache .mypy_cache .parcel-cache .next .nuxt .turbo
    .tanstack .source .nitro .output build dist release coverage storybook-static
    """.split()
)
PYTHON_EXTENSIONS = {".py", ".pyi"}
JAVASCRIPT_EXTENSIONS = {".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts"}
FORMAT_EXTENSIONS = JAVASCRIPT_EXTENSIONS | set(
    """
    .json .jsonc .json5 .css .scss .less .pcss .postcss .graphql .gql .graphqls
    .toml .yml .yaml .html .htm .xhtml .vue .md .markdown .mdx .hbs .handlebars .mjml
    """.split()
)
FORMAT_NAMES = {".babelrc", ".swcrc", ".prettierrc", ".eslintrc"}
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
TOOLS = {
    "oxlint": "npx --yes --package=oxlint --package=oxlint-tsgolint oxlint --format stylish",
    "oxfmt": "npx --yes oxfmt",
    "pyrefly": "uvx pyrefly check --min-severity warn --summary=none",
}


@dataclass
class QualityCommand:
    args: list[str]
    paths: list[Path]


class InputModel(BaseModel):
    model_config = ConfigDict(strict=True, extra="ignore")


class HookInput(InputModel):
    cwd: Path | None = None
    transcript_path: Path | None = None
    turn_id: str | None = None
    stop_hook_active: bool = False
    permission_mode: str | None = None


class FileChange(InputModel):
    move_path: Path | None = None


class TranscriptEvent(InputModel):
    type: str | None = None
    cwd: Path | None = None
    turn_id: str | None = None
    status: str | None = None
    success: bool = False
    item: "TranscriptEvent | None" = None
    changes: dict[str, FileChange] = Field(default_factory=dict)


class TranscriptRecord(InputModel):
    type: str | None = None
    payload: TranscriptEvent


def is_in_scope(path: Path, root: Path) -> bool:
    if not path.is_relative_to(root):
        return False
    return not any(
        part in EXCLUDED_DIRECTORIES or part.endswith(".egg-info") for part in path.relative_to(root).parts[:-1]
    )


def read_session_edits(transcript: Path, cwd: Path, turn_id: str) -> set[Path]:
    paths: set[Path] = set()
    changed = False
    active_turn = None
    active_cwd = cwd
    with transcript.open() as stream:
        for line in stream:
            try:
                record = TranscriptRecord.model_validate_json(line)
            except ValidationError:
                continue
            payload = record.payload
            if record.type in ("session_meta", "turn_context"):
                if payload.cwd is not None:
                    active_cwd = payload.cwd
                if payload.turn_id is not None:
                    active_turn = payload.turn_id
            if payload.type == "task_started":
                active_turn = payload.turn_id

            match payload:
                case TranscriptEvent(
                    type="item_completed", item=TranscriptEvent(type="FileChange", status="completed") as item
                ):
                    pass
                case TranscriptEvent(type="patch_apply_end", success=True) as item:
                    pass
                case _:
                    continue
            for name, change in item.changes.items():
                path = Path(os.path.abspath(active_cwd / (change.move_path or name)))
                if is_in_scope(path, cwd):
                    paths.add(path)
                    event_turn = payload.turn_id if "turn_id" in payload.model_fields_set else active_turn
                    changed |= event_turn == turn_id
    return paths if changed else set()


def run_git(cwd: Path, *args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(cwd), *args], input=input_text, capture_output=True, text=True, timeout=15, check=False
    )


@cache
def get_repository(cwd: Path) -> Path | None:
    try:
        result = run_git(cwd, "rev-parse", "--show-toplevel")
    except FileNotFoundError:
        return None
    return Path(result.stdout.strip()).resolve() if result.returncode == 0 else None


def get_check_files(repository: Path | None, cwd: Path, edited: set[Path]) -> list[Path]:
    paths = edited
    if repository:
        result = run_git(repository, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        paths = {repository / name for name in result.stdout.split("\0") if name}
    paths = {
        path
        for path in paths
        if is_in_scope(path, repository or cwd)
        and path.is_file()
        and path.resolve() == path
        and (path.suffix.lower() in PYTHON_EXTENSIONS | FORMAT_EXTENSIONS or path.name in FORMAT_NAMES)
    }
    if repository and paths:
        ignored = run_git(
            repository, "check-ignore", "--no-index", "-z", "--stdin", input_text="".join(f"{path}\0" for path in paths)
        )
        if ignored.returncode not in {0, 1}:
            raise RuntimeError(ignored.stderr.strip())
        paths -= {Path(name) for name in ignored.stdout.split("\0") if name}
    return sorted(paths)


@cache
def find_config(directory: Path, root: Path, tool: str) -> Path:
    if tool == "pyrefly":
        if override := os.environ.get("PYREFLY_CONFIG"):
            return (root / override).resolve()
        names = ["pyrefly.toml", "pyproject.toml"]
    else:
        names = [f".{tool}rc.json", f".{tool}rc.jsonc", f".config/{tool}/config.json", f".config/{tool}/config.jsonc"]
        names.extend(f"{tool}.config.{extension}" for extension in ("ts", "mts", "cts", "js", "mjs", "cjs"))
    for parent in (directory, *directory.parents):
        for name in names:
            config = parent / name
            if config.is_file() and (
                name != "pyproject.toml" or "pyrefly" in tomllib.loads(config.read_text()).get("tool", {})
            ):
                return config
        if tool != "pyrefly" and parent == root:
            break
    return CONFIG_HOME / tool / ("pyrefly.toml" if tool == "pyrefly" else "config.json")


def get_commands(paths: list[Path], cwd: Path, fix: bool) -> Iterator[QualityCommand]:
    python = [path for path in paths if path.suffix.lower() in PYTHON_EXTENSIONS]
    yield QualityCommand(["uvx", "ruff", "format", "--quiet", "--force-exclude", *([] if fix else ["--check"])], python)
    yield QualityCommand(["uvx", "ruff", "check", "--quiet", "--force-exclude", *(["--fix"] if fix else [])], python)
    for tool, extensions in {
        "oxlint": JAVASCRIPT_EXTENSIONS,
        "oxfmt": FORMAT_EXTENSIONS,
        "pyrefly": PYTHON_EXTENSIONS,
    }.items():
        if tool == "pyrefly" and fix:
            continue
        groups: dict[Path, list[Path]] = {}
        for path in paths:
            if path.suffix.lower() in extensions or (tool == "oxfmt" and path.name in FORMAT_NAMES):
                groups.setdefault(find_config(path.parent, cwd, tool), []).append(path)
        for config, files in groups.items():
            args = [*shlex.split(TOOLS[tool]), "--config", str(config)]
            global_config = config.parent == CONFIG_HOME / tool
            if tool == "pyrefly":
                settings = tomllib.loads(config.read_text())
                if config.name == "pyproject.toml":
                    settings = settings["tool"]["pyrefly"]
                if global_config:
                    args.extend(["--search-path", str(cwd)])
                for pattern in settings.get("project-excludes", []):
                    args.extend(["--project-excludes", str((cwd if global_config else config.parent) / pattern)])
            else:
                args.append("--no-error-on-unmatched-pattern")
                if tool == "oxlint":
                    args.append("--fix" if fix else "--deny-warnings")
                else:
                    args.append("--write" if fix else "--list-different")
                if global_config:
                    patterns: list[str] = json.loads(config.read_text()).get("ignorePatterns", [])
                    for pattern in patterns:
                        args.extend([f"!{pattern}"] if tool == "oxfmt" else ["--ignore-pattern", pattern])
            yield QualityCommand(args, files)


def run_command(command: QualityCommand, cwd: Path, deadline: float) -> str | None:
    if not command.paths:
        return None
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return "Quality hook execution deadline exceeded."
    label = f"$ {shlex.join(command.args)}"
    environment = dict(os.environ, NO_COLOR="1", FORCE_COLOR="0", LC_ALL="C", UV_NO_PROGRESS="1", PYREFLY_LOG="warn")
    if (cwd / ".venv/pyvenv.cfg").is_file():
        environment["VIRTUAL_ENV"] = str(cwd / ".venv")
    try:
        with (
            tempfile.TemporaryFile() as output,
            subprocess.Popen(
                ["xargs", "-0", "-s", "60000", "--", *command.args, "--"],
                cwd=cwd,
                stdin=subprocess.PIPE,
                stdout=output,
                stderr=subprocess.STDOUT,
                env=environment,
                start_new_session=True,
            ) as process,
        ):
            try:
                process.communicate(b"".join(os.fsencode(path) + b"\0" for path in command.paths), timeout=remaining)
                timed_out = False
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                timed_out = True
            if process.returncode == 0:
                return None
            output.seek(0)
            diagnostic = output.read(OUTPUT_LIMIT).decode(errors="replace")
            if output.read(1):
                diagnostic += "\n[output truncated]"
            if timed_out:
                diagnostic += "\nQuality hook execution deadline exceeded."
        return f"{label} ({len(command.paths)} files)\n{diagnostic.strip()}"
    except OSError as error:
        return f"{label}\n{error}"


def run_quality(payload: HookInput) -> dict[str, object]:
    if payload.stop_hook_active or payload.permission_mode == "plan":
        return {"continue": True}
    if payload.cwd is None or payload.transcript_path is None or payload.turn_id is None:
        return {"continue": True, "systemMessage": "Quality checks skipped: missing Codex session context."}
    cwd = payload.cwd.resolve()
    try:
        edits = read_session_edits(payload.transcript_path, cwd, payload.turn_id)
    except (OSError, UnicodeError) as error:
        return {"continue": True, "systemMessage": f"Quality checks skipped: cannot read Codex transcript: {error}"}
    if not edits:
        return {"continue": True}

    deadline = time.monotonic() + TIMEOUT_SECONDS
    repository = get_repository(cwd)
    groups: dict[Path, list[Path]] = {}
    for path in get_check_files(repository, cwd, edits):
        check_root = repository or get_repository(path.parent) or cwd
        groups.setdefault(check_root, []).append(path)
    commands = (
        (check_root, command)
        for check_root, paths in groups.items()
        for fix in (True, False)
        for command in get_commands([path for path in paths if not fix or path in edits], check_root, fix)
    )
    failures: list[str] = []
    for check_root, command in commands:
        failure = run_command(command, check_root, deadline)
        if failure:
            failures.append(failure)
        if time.monotonic() >= deadline:
            if not failure:
                failures.append("Quality hook execution deadline exceeded before all checks completed.")
            break
    if not failures:
        return {"continue": True}
    per_failure_limit = OUTPUT_LIMIT // len(failures)
    reason = "Code quality checks failed. Fix the reported issues and rerun the failing checks.\n\n"
    reason += "\n\n".join(
        failure if len(failure) <= per_failure_limit else failure[:per_failure_limit] + "\n[output truncated]"
        for failure in failures
    )
    return {"decision": "block", "reason": reason}


def main() -> None:
    try:
        payload = HookInput.model_validate_json(sys.stdin.read())
    except (ValidationError, UnicodeError) as error:
        response = {"continue": True, "systemMessage": f"Quality checks skipped: invalid hook input: {error}"}
    else:
        try:
            response = run_quality(payload)
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            response = {"decision": "block", "reason": f"Quality hook failed: {error}"}
    sys.stdout.write(json.dumps(response) + "\n")


if __name__ == "__main__":
    main()
