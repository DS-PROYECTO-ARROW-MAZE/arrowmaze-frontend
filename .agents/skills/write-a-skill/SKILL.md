---
name: write-a-skill
description: Create new agent skills with proper structure, progressive disclosure, and bundled resources. Use when user wants to create, write, or build a new skill.
---

# Writing Skills

## Source of truth: `.agents/skills/`

This repo keeps **all real skill content in `.agents/skills/`**. The `.claude/skills/`
folder holds only lightweight pointers back to it, so there is a single source of truth.

When creating or updating a skill, you **always** do two things:

1. Write / edit the actual files under `.agents/skills/<skill-name>/`.
2. Generate the corresponding pointer file(s) under `.claude/skills/<skill-name>/`.

Never put real instructions in `.claude/skills/` — edit `.agents/skills/` and the
pointer picks it up.

### Pointer rules

- **`SKILL.md`** — keep only the YAML frontmatter (`name`, `description`, and any
  other frontmatter fields from the source), then a single pointer line in the body.
  The frontmatter is required so Claude Code can discover the skill and auto-trigger it.

  ```md
  ---
  name: zoom-out
  description: <copied verbatim from the source SKILL.md frontmatter>
  ---

  See @.agents/skills/zoom-out/SKILL.md
  ```

- **Every other file** (REFERENCE.md, EXAMPLES.md, *-FORMAT.md, TEMPLATE.md, scripts, …)
  — a single pointer line, no frontmatter:

  ```
  See @.agents/skills/zoom-out/REFERENCE.md
  ```

The pointer path mirrors the file's relative path under `.agents/skills/`.

## Process

1. **Gather requirements** - ask user about:
   - What task/domain does the skill cover?
   - What specific use cases should it handle?
   - Does it need executable scripts or just instructions?
   - Any reference materials to include?

2. **Draft the skill in `.agents/skills/`** - create:
   - SKILL.md with concise instructions
   - Additional reference files if content exceeds 500 lines
   - Utility scripts if deterministic operations needed

3. **Generate pointers in `.claude/skills/`** - create the pointer file(s) by hand
   following the rules above, mirroring each source file's relative path.

4. **Review with user** - present draft and ask:
   - Does this cover your use cases?
   - Anything missing or unclear?
   - Should any section be more/less detailed?

## Skill Structure

`.agents/skills/` holds the real content:

```
.agents/skills/skill-name/
├── SKILL.md           # Main instructions (required)
├── REFERENCE.md       # Detailed docs (if needed)
├── EXAMPLES.md        # Usage examples (if needed)
└── scripts/           # Utility scripts (if needed)
    └── helper.js
```

`.claude/skills/` mirrors the same paths, but every file is a one-line pointer
(SKILL.md additionally keeps its frontmatter):

```
.claude/skills/skill-name/
├── SKILL.md           # frontmatter + "See @.agents/skills/skill-name/SKILL.md"
├── REFERENCE.md       # "See @.agents/skills/skill-name/REFERENCE.md"
├── EXAMPLES.md        # "See @.agents/skills/skill-name/EXAMPLES.md"
└── scripts/
    └── helper.js      # "See @.agents/skills/skill-name/scripts/helper.js"
```

## SKILL.md Template

```md
---
name: skill-name
description: Brief description of capability. Use when [specific triggers].
---

# Skill Name

## Quick start

[Minimal working example]

## Workflows

[Step-by-step processes with checklists for complex tasks]

## Advanced features

[Link to separate files: See [REFERENCE.md](REFERENCE.md)]
```

## Description Requirements

The description is **the only thing your agent sees** when deciding which skill to load. It's surfaced in the system prompt alongside all other installed skills. Your agent reads these descriptions and picks the relevant skill based on the user's request.

**Goal**: Give your agent just enough info to know:

1. What capability this skill provides
2. When/why to trigger it (specific keywords, contexts, file types)

**Format**:

- Max 1024 chars
- Write in third person
- First sentence: what it does
- Second sentence: "Use when [specific triggers]"

**Good example**:

```
Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when user mentions PDFs, forms, or document extraction.
```

**Bad example**:

```
Helps with documents.
```

The bad example gives your agent no way to distinguish this from other document skills.

## When to Add Scripts

Add utility scripts when:

- Operation is deterministic (validation, formatting)
- Same code would be generated repeatedly
- Errors need explicit handling

Scripts save tokens and improve reliability vs generated code.

## When to Split Files

Split into separate files when:

- SKILL.md exceeds 100 lines
- Content has distinct domains (finance vs sales schemas)
- Advanced features are rarely needed

## Review Checklist

After drafting, verify:

- [ ] Real content lives in `.agents/skills/<skill-name>/`
- [ ] A matching pointer exists in `.claude/skills/<skill-name>/` for every source file
- [ ] Pointer `SKILL.md` keeps the source frontmatter; other pointers are a single line
- [ ] Description includes triggers ("Use when...")
- [ ] SKILL.md under 100 lines
- [ ] No time-sensitive info
- [ ] Consistent terminology
- [ ] Concrete examples included
- [ ] References one level deep
