#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
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
from dataclasses import dataclass, field
from functools import cache
from pathlib import Path

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
OXLINT = ["npx", "--yes", "--package=oxlint", "--package=oxlint-tsgolint", "oxlint", "--no-error-on-unmatched-pattern"]
OXFMT = ["npx", "--yes", "oxfmt", "--no-error-on-unmatched-pattern"]


@dataclass
class SessionEdits:
    paths: set[Path] = field(default_factory=set)
    changed_this_turn: bool = False


@dataclass
class QualityCommand:
    args: list[str]
    paths: list[Path]


def is_in_scope(path: Path, root: Path) -> bool:
    if not path.is_relative_to(root):
        return False
    return not any(
        part in EXCLUDED_DIRECTORIES or part.endswith(".egg-info") for part in path.relative_to(root).parts[:-1]
    )


def read_session_edits(transcript: Path, cwd: Path, turn_id: str) -> SessionEdits:
    edits = SessionEdits()
    active_turn = None
    active_cwd = cwd
    with transcript.open() as stream:
        for line in stream:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(record, dict) or not isinstance(record.get("payload"), dict):
                continue
            payload = record["payload"]
            if record.get("type") in {"session_meta", "turn_context"}:
                if isinstance(payload.get("cwd"), str):
                    active_cwd = Path(payload["cwd"])
                if isinstance(payload.get("turn_id"), str):
                    active_turn = payload["turn_id"]
            if payload.get("type") == "task_started":
                active_turn = payload.get("turn_id")

            if payload.get("type") == "item_completed":
                item = payload.get("item")
                if not isinstance(item, dict) or item.get("type") != "FileChange" or item.get("status") != "completed":
                    continue
            elif payload.get("type") == "patch_apply_end" and payload.get("success") is True:
                item = payload
            else:
                continue

            changes = item.get("changes")
            if not isinstance(changes, dict):
                continue
            for name, change in changes.items():
                if not isinstance(name, str) or not isinstance(change, dict):
                    continue
                destination = change.get("move_path")
                if isinstance(destination, str):
                    name = destination
                path = Path(os.path.abspath(active_cwd / name))
                if is_in_scope(path, cwd):
                    edits.paths.add(path)
                    if payload.get("turn_id", active_turn) == turn_id:
                        edits.changed_this_turn = True
    return edits


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


def select_files(paths: set[Path], root: Path) -> list[Path]:
    return sorted(
        path
        for path in paths
        if is_in_scope(path, root)
        and path.is_file()
        and path.resolve() == path
        and (path.suffix.lower() in PYTHON_EXTENSIONS | FORMAT_EXTENSIONS or path.name in FORMAT_NAMES)
    )


def get_check_files(repository: Path | None, cwd: Path, edited: set[Path]) -> list[Path]:
    if repository is None:
        return select_files(edited, cwd)
    result = run_git(repository, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    paths = select_files({repository / name for name in result.stdout.split("\0") if name}, repository)
    if not paths:
        return []
    ignored = run_git(
        repository, "check-ignore", "--no-index", "-z", "--stdin", input_text="".join(f"{path}\0" for path in paths)
    )
    if ignored.returncode not in {0, 1}:
        raise RuntimeError(ignored.stderr.strip())
    excluded = set(ignored.stdout.split("\0"))
    return [path for path in paths if str(path) not in excluded]


@cache
def find_pyrefly_config(directory: Path) -> Path | None:
    for parent in (directory, *directory.parents):
        config = parent / "pyrefly.toml"
        if config.is_file():
            return config
        config = parent / "pyproject.toml"
        if config.is_file() and "pyrefly" in tomllib.loads(config.read_text()).get("tool", {}):
            return config
    return None


def get_pyrefly_commands(paths: list[Path], cwd: Path) -> Iterator[QualityCommand]:
    groups = {}
    override = os.environ.get("PYREFLY_CONFIG")
    for path in paths:
        config = (cwd / override).resolve() if override else find_pyrefly_config(path.parent)
        groups.setdefault(config, []).append(path)
    for config, files in groups.items():
        args = ["uvx", "pyrefly", "check", "--output-format", "min-text"]
        if config is not None:
            settings = tomllib.loads(config.read_text())
            if config.name == "pyproject.toml":
                settings = settings["tool"]["pyrefly"]
            args.extend(["--config", str(config)])
            for pattern in settings.get("project-excludes", []):
                args.extend(["--project-excludes", str(config.parent / pattern)])
        yield QualityCommand(args, files)


def get_commands(edited: list[Path], checked: list[Path], cwd: Path) -> list[QualityCommand]:
    python_edited = [path for path in edited if path.suffix.lower() in PYTHON_EXTENSIONS]
    javascript_edited = [path for path in edited if path.suffix.lower() in JAVASCRIPT_EXTENSIONS]
    format_edited = [path for path in edited if path.suffix.lower() in FORMAT_EXTENSIONS or path.name in FORMAT_NAMES]
    python_checked = [path for path in checked if path.suffix.lower() in PYTHON_EXTENSIONS]
    javascript_checked = [path for path in checked if path.suffix.lower() in JAVASCRIPT_EXTENSIONS]
    format_checked = [path for path in checked if path.suffix.lower() in FORMAT_EXTENSIONS or path.name in FORMAT_NAMES]
    return [
        QualityCommand(["uvx", "ruff", "check", "--fix", "--force-exclude"], python_edited),
        QualityCommand([*OXLINT, "--fix"], javascript_edited),
        QualityCommand(["uvx", "ruff", "format", "--force-exclude"], python_edited),
        QualityCommand([*OXFMT, "--write"], format_edited),
        QualityCommand(["uvx", "ruff", "check", "--force-exclude"], python_checked),
        QualityCommand(["uvx", "ruff", "format", "--check", "--force-exclude"], python_checked),
        QualityCommand(["uvx", "ty", "check", "--force-exclude", "--output-format", "concise"], python_checked),
        *get_pyrefly_commands(python_checked, cwd),
        QualityCommand([*OXLINT, "--type-aware", "--type-check"], javascript_checked),
        QualityCommand([*OXFMT, "--check"], format_checked),
    ]


def batch_commands(commands: list[QualityCommand]) -> Iterator[QualityCommand]:
    for command in commands:
        paths = []
        size = 0
        for path in command.paths:
            length = len(os.fsencode(path)) + 1
            if size + length > 60000 and paths:
                yield QualityCommand(command.args, paths)
                paths = []
                size = 0
            paths.append(path)
            size += length
        if paths:
            yield QualityCommand(command.args, paths)


def run_command(command: QualityCommand, cwd: Path, deadline: float) -> str | None:
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return "Quality hook execution deadline exceeded."
    args = [*command.args, "--", *(str(path) for path in command.paths)]
    label = f"$ {shlex.join(command.args)}"
    environment = {**os.environ, "NO_COLOR": "1", "UV_NO_PROGRESS": "1"}
    if (cwd / ".venv/pyvenv.cfg").is_file():
        environment["VIRTUAL_ENV"] = str(cwd / ".venv")
    try:
        with (
            tempfile.TemporaryFile() as output,
            subprocess.Popen(
                args,
                cwd=cwd,
                stdin=subprocess.DEVNULL,
                stdout=output,
                stderr=subprocess.STDOUT,
                env=environment,
                start_new_session=True,
            ) as process,
        ):
            try:
                process.wait(timeout=remaining)
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


def run_quality(payload: dict[str, object]) -> dict[str, object]:
    if payload.get("stop_hook_active") is True or payload.get("permission_mode") == "plan":
        return {"continue": True}
    cwd_value = payload.get("cwd")
    transcript_value = payload.get("transcript_path")
    turn_id = payload.get("turn_id")
    if not isinstance(cwd_value, str) or not isinstance(transcript_value, str) or not isinstance(turn_id, str):
        return {"continue": True, "systemMessage": "Quality checks skipped: missing Codex session context."}
    cwd = Path(cwd_value).resolve()
    try:
        edits = read_session_edits(Path(transcript_value), cwd, turn_id)
    except (OSError, UnicodeError) as error:
        return {"continue": True, "systemMessage": f"Quality checks skipped: cannot read Codex transcript: {error}"}
    if not edits.changed_this_turn:
        return {"continue": True}

    deadline = time.monotonic() + TIMEOUT_SECONDS
    repository = get_repository(cwd)
    checked = get_check_files(repository, cwd, edits.paths)
    groups = {}
    for path in checked:
        check_root = repository or get_repository(path.parent) or cwd
        groups.setdefault(check_root, []).append(path)
    commands = (
        (check_root, command)
        for check_root, paths in groups.items()
        for command in batch_commands(get_commands([path for path in paths if path in edits.paths], paths, check_root))
    )
    failures = []
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
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            raise ValueError("expected a JSON object")
    except (ValueError, UnicodeError) as error:
        response = {"continue": True, "systemMessage": f"Quality checks skipped: invalid hook input: {error}"}
    else:
        try:
            response = run_quality(payload)
        except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
            response = {"decision": "block", "reason": f"Quality hook failed: {error}"}
    sys.stdout.write(json.dumps(response) + "\n")


if __name__ == "__main__":
    main()
