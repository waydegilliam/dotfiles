import json
import subprocess
import sys
import builtins


def _copy_to_clipboard(text: str) -> None:
    if sys.platform == "darwin":
        cmds = [["pbcopy"]]
    elif sys.platform == "linux":
        cmds = [["xclip", "-selection", "clipboard"], ["xsel", "-b"]]
    else:
        raise RuntimeError("Unsupported platform")

    for cmd in cmds:
        try:
            subprocess.run(cmd, check=True, text=True, input=text)
            return
        except FileNotFoundError:
            continue
    raise RuntimeError("No clipboard utility found (install xclip or xsel on Linux)")


def cp(obj, *, indent: int = 2):
    try:
        payload = json.dumps(obj, indent=indent, default=str, ensure_ascii=False)
    except (TypeError, ValueError):
        payload = repr(obj)
    _copy_to_clipboard(payload)
    print("✔ copied to clipboard")


builtins.cp = cp