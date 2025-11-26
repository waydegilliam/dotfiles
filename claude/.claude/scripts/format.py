#!/usr/bin/env python3

import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

RUFF_EXTENSIONS = {"py"}
PRETTIER_EXTENSIONS = {
    "js",
    "jsx",
    "ts",
    "tsx",
    "json",
    "css",
    "scss",
    "less",
    "html",
    "vue",
    "yaml",
    "yml",
    "md",
    "mdx",
    "svg",
    "toml",
}


@dataclass
class StopHookInput:
    session_id: str
    transcript_path: Path
    hook_event_name: Literal["Stop", "SubagentStop"]
    stop_hook_active: bool


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    hook_data = StopHookInput(
        session_id=data["session_id"],
        transcript_path=data["transcript_path"],
        hook_event_name=data["hook_event_name"],
        stop_hook_active=data["stop_hook_active"],
    )

    # Get files created/modified in the transcript
    # For each file, run the appropriate formatter
    # If any errors, block stopage and show the errors

    file_suffix = hook_data.tool_response_file_path.suffix.lower().lstrip(".")

    if file_suffix in RUFF_EXTENSIONS:
        command = ["uvx", "ruff", "check", "--fix", str(hook_data.tool_response_file_path)]
    elif file_suffix in PRETTIER_EXTENSIONS:
        command = ["npx", "prettier", "--write", str(hook_data.tool_response_file_path)]
    else:
        return

    result = subprocess.run(command, cwd=hook_data.cwd, capture_output=True, text=True, check=True)

    print(result.stdout)


if __name__ == "__main__":
    main()
