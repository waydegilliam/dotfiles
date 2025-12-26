# Code Style & Conventions

## Python

- Assign return values to a variable with blank line before return
- Use modern Python type hints: `list[str]`, `dict[str, int]`, `int | None` instead of `typing.List`, `typing.Dict`, `typing.Optional` (Python 3.9+)
- Run type checkers (`uv run pyright/mypy`) after code changes

## Inline Documentation

- Minimize inline documentation - prefer self-documenting code
- Avoid verbose docstrings unless necessary
- No proactive README creation unless requested
