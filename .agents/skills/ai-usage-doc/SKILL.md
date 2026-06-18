---
name: ai-usage-doc
description: Generate and maintain a mandatory AI_USAGE.md file documenting AI tool usage in a repository — tools used, a per-task usage log, and a critical evaluation. Use when the user asks to create, update, append to, or document AI usage, AI_USAGE.md, AI disclosure, or AI-assisted code reporting.
---

# AI Usage Documentation (AI_USAGE.md)

Creates and maintains `AI_USAGE.md` in the repo root with three required sections: **Tools Used**, **Usage Log by Task**, and **Critical Evaluation**. The full output format lives in [TEMPLATE.md](TEMPLATE.md) — read it before writing the file.

## Decide the mode first

1. Check whether `AI_USAGE.md` already exists in the repo root.
   - **Missing** → run **Create** workflow.
   - **Exists** → assume the user wants to **Append** a new task entry unless they say otherwise.

## Create workflow (template + guided fill)

1. Read [TEMPLATE.md](TEMPLATE.md) for exact headings and table formats.
2. Interview the user section by section — do **not** invent entries. Ask in this order:
   - **Tools Used**: for each tool → name, specific version/model, and role in the workflow.
   - **Usage Log**: for each significant AI use → the six required fields (Task, Tool, Prompt verbatim/paraphrased, Result, Team modifications, Lessons/limitations).
   - **Critical Evaluation**: approximate % of AI-assisted code, concrete cases where AI was wrong/suboptimal + how it was caught and fixed, and a team reflection on productivity & quality impact.
3. Offer to pre-fill drafts from git history or this conversation, but mark anything inferred as `<!-- DRAFT: confirm -->` and have the user verify before finalizing.
4. Write `AI_USAGE.md` to the repo root. Keep entry IDs sequential (`T-001`, `T-002`, …).

## Append workflow (new entry + recalc)

1. Read the existing `AI_USAGE.md`.
2. Collect the six usage-log fields for the new task and assign the next sequential ID.
3. If the new tool isn't already in **Tools Used**, add a row there too.
4. **Recalculate** the AI-assisted percentage in **Critical Evaluation**: ask the user for the updated figure (or recompute from a stated basis) and replace the old value — never leave a stale percentage.
5. Update the "Last updated" date at the top.

## Rules

- Every usage-log entry MUST contain all six fields, even if a value is "N/A — explain why".
- Prompts should be verbatim when available; a faithful paraphrase is acceptable, label it `(paraphrased)`.
- Never fabricate tools, prompts, percentages, or reflections — ask the user.
- Keep the file in the repo root and use the headings exactly as in [TEMPLATE.md](TEMPLATE.md) so it passes automated checks.

## Checklist before finishing

- [ ] All three top-level sections present
- [ ] Each tool has name + version/model + role
- [ ] Each task entry has all six fields and a unique ID
- [ ] AI-assisted % present and recalculated (append mode)
- [ ] At least one concrete incorrect/suboptimal case documented
- [ ] Team reflection on productivity & quality included
- [ ] "Last updated" date current
