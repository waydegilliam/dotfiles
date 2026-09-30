# Python Standards

Use the supported Python version and existing formatter, line length, linter, and type checker settings. For standalone
code, use the intended Python version and follow nearby style, or standard Python style if there is none.

- Use modern type hints supported by the target runtime, such as `list[str]` and `int | None`.
- Prefer `StrEnum` for string enums when supported by the target Python version.
- If imports used only in type hints would cause a circular import, put them in an `if TYPE_CHECKING:` block and use
  postponed annotations when needed. Prefer this over moving imports to the bottom of the file or inside functions.
- Keep runtime imports at the top of the file. Use `TYPE_CHECKING` blocks only for names used in type hints.
- Prefer dataclasses or the project's existing model library over plain dictionaries for structured values.
- When using Pydantic, prefer field types such as `EmailStr` and `HttpUrl` when they match the field's requirements.
- Do not add local variable type annotations or casts unless needed by the project's type checker.
- Keep `__init__.py` lightweight and avoid re-exports that create circular imports. Follow the project's package layout.
- Prefer an API's context manager (`with` or `async with`) when it handles setup, completion, errors, and cleanup.

### Return Types

- Make the return type explain the result without making readers inspect the function's code.
- Keep simple types such as `list[str]` or `tuple[User, Organization]` inline. When a tuple or nested structure is hard
  to understand, use a type with clear field names.
- Use a dataclass for internal data, an existing validation model when checking or serializing data, a `TypedDict`
  when a dictionary is needed, or a `NamedTuple` when a tuple is needed. A type alias alone does not explain unnamed fields.

Avoid return types where readers must work out what each position means:

```python
async def search(...) -> tuple[list[tuple[int, str, list[str]]], int | None]: ...
```

Use named fields to make the result clear:

```python
@dataclass(frozen=True)
class SearchResult:
    document_id: int
    title: str
    highlights: list[str]


@dataclass(frozen=True)
class SearchPage:
    results: list[SearchResult]
    next_cursor: int | None


async def search(...) -> SearchPage: ...
```

## Asyncio

- Prefer `asyncio.TaskGroup` over `asyncio.gather` when supported and its error and cancellation behavior fits the task.
- Run independent async tasks at the same time. Run them in order or limit how many run at once when ordering, rate
  limits, or resource limits require it.

## SQLAlchemy and Alembic

- Prefer existing service or repository methods over writing custom queries.
- Extend an existing service or repository method when the change is small and reusable. Write a custom query when
  using the existing methods would require large or awkward changes.
- Reuse the declarative base's configured type mappings. If `type_annotation_map` already handles an enum, declare
  `status: Mapped[MyStatus]` without repeating an explicit SQL type solely to map it.
- Prefer cascading deletes when child records should be deleted with their parent and data retention rules allow it.
- In projects where SQLAlchemy models define the schema, make schema changes in the models first and generate
  migrations with Alembic autogeneration. Inspect and correct generated migrations before applying them.
- Before generating a revision, check existing migration files and any available version-control history. Add changes
  to an existing unapplied revision when the migration rules allow it. Keep revisions that have been applied or shared
  unchanged, and follow the existing migration order and release process.
