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
class HookData:
    cwd: Path
    tool_name: Literal["Edit", "MultiEdit", "Write"]
    tool_response_file_path: Path


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    hook_data = HookData(
        cwd=Path(data["cwd"]),
        tool_name=data["tool_name"],
        tool_response_file_path=Path(data["tool_response"]["filePath"]),
    )

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
