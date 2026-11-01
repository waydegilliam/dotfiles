---
name: gh-pr
description:
    Write GitHub pull requests with concise, reviewer-facing titles and descriptions that link the Linear, Sentry,
    Logfire, or Slack context behind the change, and set their draft or ready state. Use whenever submitting branches
    for review, or creating, editing, rewriting, or marking a PR draft or ready.
---

# GitHub Pull Requests

Write for a reviewer who has not seen the conversation: why the change exists, what behavior results, and where to find
the evidence.

## Submit for Review

1. For each branch without a PR, inspect its change with `git diff --merge-base <base>`, where `<base>` is its parent
   branch (`master` for the bottom layer). Read relevant code for context instead of summarizing the diff alone.
2. Gather [references](#references), then write the [title](#title) and [description](#description). Write each
   description to a temporary file to avoid shell quoting problems.
3. Choose the review state: ready for review unless the user asks for drafts or the work is incomplete.
4. Submit with the `gh-stack` skill, passing `--open` to `gh stack submit --auto` for ready PRs. Without `--open` it
   creates drafts.
5. Replace each generated title and description with `gh pr edit <number> --title <title> --body-file <file>`. Keep the
   gh-stack footer and bot content.
6. Return the PR URLs.

For a branch outside a stack, run `git push -u origin HEAD`, then
`gh pr create --base master --title <title> --body-file <file>`, adding `--draft` for drafts.

## Update a Pull Request

Read the PR with `gh pr view <number>` before changing it, and keep content you did not write, such as bot badges. After
pushing changes that alter what a PR does, rewrite its description to match. Mark a draft ready with
`gh pr ready <number>`.

## Title

Use a short imperative phrase that names the outcome, for example
`Select affected test suites with Mise monorepo tasks`. Keep issue IDs and links out of the title.

## Description

- Default to one short paragraph of 1-3 sentences. Lead with the problem or purpose and the resulting behavior.
- Add detail only to explain significant architectural or business-logic changes. Use a few short bullets only for
  distinct, substantial changes.
- Avoid headings, repeating the title, file-by-file summaries, and minor implementation details.
- Do not mention generated files or test updates, including client types, fixtures, and assertions.
- Call out anything a reviewer or deployer must act on in one short line: migrations, new settings or environment
  variables, or configuration in external services such as Slack app event subscriptions.
- Omit routine validation that CI already runs. Mention manual verification only when it is evidence CI cannot provide.

## References

When the PR addresses an existing problem, such as a bug, incident, alert, regression, or request, link its source so
reviewers can see why the change exists:

- **Linear issue:** add `Fixes ENG-123` on its own final line when the PR resolves the issue, which closes it on merge.
  Use `Refs ENG-123` or `Part of ENG-123` when it does not. Use the issue's actual identifier, whose prefix is its
  team's key.
- **Sentry:** the issue or alert URL.
- **Logfire:** the trace, query, issue, or alert URL.
- **Slack:** the permalink to the report or discussion.

Put Sentry, Logfire, and Slack links inline where the description explains the problem:

```markdown
Edited Slack messages that arrived before their originals failed ingestion with a foreign-key error
([Sentry](https://...), [report](https://...)). Queue edits until the original message exists, then apply them in order.

Fixes ENG-123
```

Find references in the conversation, the branch name, commit messages, and code comments. When the user describes a
known problem without a link, look it up with the connected Linear, Sentry, Logfire, or Slack tools. Never guess a URL
or issue ID: ask the user or leave it out. Skip references for routine work with no external trigger.
