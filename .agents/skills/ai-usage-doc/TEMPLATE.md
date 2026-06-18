# AI_USAGE.md output format

Write the generated file to the **repository root** as `AI_USAGE.md`. Reproduce the structure below exactly (headings, table columns, field order). Replace bracketed placeholders; remove instructional comments before finalizing.

---

````markdown
# AI Usage Documentation

> Mandatory disclosure of AI use in this repository.
> **Project:** [project name] · **Last updated:** [YYYY-MM-DD]

## 1. Tools Used

| Tool | Version / Model | Role in the team's workflow |
| ---- | --------------- | --------------------------- |
| [e.g. Claude] | [e.g. Sonnet 4.6 / claude-sonnet-4-6] | [e.g. Backend pair-programming, refactoring] |
| [e.g. GitHub Copilot] | [e.g. 1.x] | [e.g. In-editor autocomplete] |
| [e.g. ChatGPT] | [e.g. GPT-4] | [e.g. Debugging, research] |

## 2. Usage Log by Task

<!-- One entry per SIGNIFICANT use of AI. IDs are sequential: T-001, T-002, ... -->

### T-001 — [short task title]

- **Task / problem addressed:** [what needed solving]
- **AI tool used:** [tool + version]
- **Prompt / instruction:** [verbatim transcript, or faithful paraphrase — label `(paraphrased)`]
- **Result obtained:** [code snippet, design, or explanation produced]
- **Modifications made by the team:** [what was changed/rejected/added on top of the output]
- **Lessons learned / limitations identified:** [what worked, what to watch for next time]

### T-002 — [short task title]

- **Task / problem addressed:** …
- **AI tool used:** …
- **Prompt / instruction:** …
- **Result obtained:** …
- **Modifications made by the team:** …
- **Lessons learned / limitations identified:** …

## 3. Critical Evaluation

### AI-assisted code share

- **Approximate % of code that was AI-assisted:** [N]%
- **Basis for the estimate:** [how it was measured — e.g. lines, files, modules, rough judgment]

### Incorrect or suboptimal AI results

<!-- At least one concrete case. Add more as needed. -->

- **Case:** [what the AI got wrong or did poorly]
  - **How it was detected:** [tests, code review, runtime error, etc.]
  - **How it was corrected:** [the fix the team applied]

### Team reflection

- **Impact on productivity:** [honest assessment]
- **Impact on code quality:** [honest assessment]
- **Overall takeaways:** [what the team would keep / change about using AI]
````

---

## Field reference (from the requirement)

**Tools Used** — for each tool: name; specific version or model when possible; role assigned to that tool in the workflow.

**Usage log by task** — for each significant use, record: task/problem addressed; AI tool used; prompt or instruction (verbatim or faithful paraphrase); result obtained (code/design/explanation); modifications made by the team; lessons learned or limitations identified.

**Critical evaluation** — approximate percentage of AI-assisted code; cases where AI produced incorrect/suboptimal results and how they were detected and corrected; team reflection on the impact of AI on productivity and code quality.
