---
name: coding-standards
description:
    Apply coding standards when creating, editing, reviewing, or refactoring code in standalone files, snippets,
    directories, or projects, with or without version control. Use across application code, scripts, schemas,
    migrations, workflows, configuration, infrastructure, and styling. Follow local rules and style.
---

# Coding Standards

Use these standards to keep code simple, readable, and consistent across languages and environments.

Read local instructions, check tool settings, and look at nearby code first. Follow existing patterns and use these
standards where no local rule applies. Keep changes small and focused. Use language and framework guidance only when
the code uses those tools.

This skill works with or without Git or a project setup. For standalone code, follow the language's usual style and
the intended runtime. Use version-control history when available; otherwise read the files directly. Do not create a
repository or add tool settings just to use this skill.

Read the references relevant to the task before editing or reviewing its files:

- Read [references/python.md](references/python.md) for Python, asyncio, SQLAlchemy, or Alembic work.
- Read [references/rest-api.md](references/rest-api.md) when designing, building, or reviewing backend REST APIs and
  their models, inputs, outputs, services, and stored data.
- Read [references/typescript.md](references/typescript.md) for TypeScript, JavaScript, React, Tailwind, or CSS work.
- Read each relevant reference when a change covers several languages or parts of the system. For other languages,
  use the shared standards below and follow local rules.

## Naming

Name things from general to specific, where this fits the project's naming rules:

- Start with the broadest useful area or feature, then add the entity, action, state, or other details.
- Give related names the same prefix so they sort together. For example, `document`,
  `document_id`, and `document_sync_status`, or `DocumentSyncBatch` and `DocumentSyncBatchInput`.
- Use this pattern for files, directories, modules, types, variables, database objects, workflows, jobs, configuration,
  and infrastructure. Follow the language's rules for casing and separators.
- Use the full name across module or system boundaries, or where a short name could be unclear. Drop repeated context
  inside a clear scope, such as `Document.title` rather than `Document.document_title`.
- Keep function names verb-first where that is the usual style. Order the rest from general to specific, such as
  `list_document_sync_batches`.

## Simplicity

- Write code that is easy to scan and understand. Avoid clever tricks.
- Prefer fewer lines when the code stays clear.
- Use early returns to reduce nesting.
- Keep related logic together when splitting it into small functions would make it harder to follow.
- Remove changes the task does not need.

## State and Inputs

- Keep as little state as possible. Limit its allowed values and reduce the number of arguments.
- Use discriminated unions, or the language's equivalent, for states that cannot occur at the same time.
- Handle every variant. Fail on unknown variants instead of ignoring them or adding a fallback.
- Validate untrusted input where it enters the system. After validation, trust the types. Do not add checks, defaults,
  or fallbacks for states the types rule out.
- Keep required arguments required. Do not make them optional for caller convenience.
- Pass overrides only when needed. Keep inputs focused and argument counts low.

## Shared Standards

- Choose code and names that explain themselves, even if the names are longer.
- Make function inputs and outputs easy to understand. Use types with named fields when the meaning of a tuple or
  nested structure is unclear.
- Do not add explanatory comments unless asked or required by the project's rules.
- Do not add `TODO` or `FIXME` comments unless explicitly asked.
- Run the smallest set of checks that covers the change. Use existing formatters, linters, type checkers, and tests
  when available. Find commands in the documentation and tool settings. For standalone code, use the available tools
  and say what you could not check.
