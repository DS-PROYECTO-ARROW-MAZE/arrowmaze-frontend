---
name: conventional-commits
description: Generate git commit messages following the Conventional Commits standard, in English, with type(scope) prefixes (feat, fix, test, docs, refactor, etc.). Use when the user asks to commit changes, write a commit message, or mentions commits, git history, or conventional commits.
---

# Conventional Commits

Generate commit messages that follow the [Conventional Commits](https://www.conventionalcommits.org/) standard. This repo already validates format via commitlint (`commitlint.config.js` extends `@commitlint/config-conventional`) and a husky `commit-msg` hook, so a malformed message will be rejected.

## Format

```
type(scope): subject
```

- **type** — required, lowercase (see table).
- **scope** — optional but recommended; the area of the codebase affected (e.g. `board`, `player`, `level`, `use-case`, `readme`).
- **subject** — required, **in English**, imperative mood, lowercase start, no trailing period.

Keep the subject line ≤ 72 chars. Add a blank line + body for extra detail when needed.

### Types

| Type       | Use for                                              |
|------------|------------------------------------------------------|
| `feat`     | A new feature                                        |
| `fix`      | A bug fix                                             |
| `test`     | Adding or correcting tests                           |
| `docs`     | Documentation only                                   |
| `refactor` | Code change that neither fixes a bug nor adds a feat |

### Examples

```
feat(board): add arrow rotation logic
fix(player): correct movement when hitting a wall
test(use-case): add unit tests for MovePlayerUseCase
docs(readme): update architecture diagram
refactor(level): apply Factory Method pattern to cell creation
```

## Workflow

When asked to commit:

1. Run `git status` and `git diff --staged` (and `git diff` for unstaged) to understand what changed.
2. If nothing is staged, stage the relevant files with `git add` (only what the user intends to commit).
3. Pick **one** type that best matches the dominant change. If changes are unrelated, suggest splitting into multiple commits.
4. Choose a scope from the affected area. Omit the scope only if no single area fits.
5. Write the subject in English, imperative mood ("add", not "added"/"adds").
6. Commit. The husky `commit-msg` hook runs commitlint automatically; the `pre-commit` hook runs `npm test`.

```bash
git commit -m "feat(board): add arrow rotation logic"
```

For a body, use multiple `-m` flags or a heredoc:

```bash
git commit -m "fix(player): correct movement when hitting a wall" \
           -m "Player no longer phases through walls when two moves are queued in the same tick."
```

## Rules

- Messages **must be in English**, even if the user writes in another language.
- Lowercase the type; do not capitalize the subject's first word; no period at the end of the subject.
- Use imperative mood, present tense.
- Breaking changes: append `!` after the scope (`feat(api)!: ...`) and/or add a `BREAKING CHANGE:` footer.
- Do not skip hooks (`--no-verify`) unless the user explicitly asks.

## Validate before committing

To check a message against this repo's rules without committing:

```bash
echo "feat(board): add arrow rotation logic" | npx --no -- commitlint
```
