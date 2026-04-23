---
name: continuous-learning
description: Three-layer developer knowledge compiler — auto-capture session insights, distill patterns, promote to rules/skills
auto-trigger: At conversation end, auto-run full pipeline (capture → distill → review). At conversation start, load relevant patterns.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, TaskCreate, TaskUpdate
---

# Continuous Learning — Developer Knowledge Compiler

Transform scattered session work into compounding developer wisdom through a three-layer distillation pipeline.

## Philosophy

Knowledge must be **compiled once and continuously maintained**, not re-derived each session.
- claude-mem captures **what happened** (observations)
- This skill captures **what it means** (patterns → rules → skills)
- **Fully automatic** — no manual triggers needed. Pipeline runs at every session boundary.

## Three-Layer Model

```
L1 Sessions (会话摘要)     — What happened? Auto-captured at session end.
    ↓ evidence accumulates
L2 Patterns (开发模式)     — What recurs? Auto-distilled when ≥2 L1s cluster.
    ↓ confidence matures
L3 Rules & Skills (行为准则) — What to always do? Auto-promoted when confidence=high.
```

### Layer Definitions

| Layer | Storage | Question | Auto-Trigger |
|-------|---------|----------|--------------|
| L1 | `~/.claude/learning/sessions/` | What did we do and learn? | Session end → auto-capture |
| L2 | `~/.claude/learning/patterns/` | What pattern recurs? | ≥2 L1s share domain/theme → auto-distill |
| L3 | `~/.claude/rules/common/learned/` + `skills/learned/` | What's reliable? | L2 confidence=high (≥3 evidence) → auto-promote |

### Critical Constraints

1. **No layer skipping** — Every L2 must cite ≥2 L1 sessions as evidence
2. **No vague patterns** — "Code review helps" is NOT a pattern. "Running code-reviewer agent after >100 LOC catches 80% of issues" IS.
3. **L2 must extract methodology, not retell events** — L2 is about the thinking behind the work, not the work itself. Ask "what decision-making approach led to this outcome?" not "what happened?". Example: L1 says "added gradient CV metric to seal detection"; L2 should NOT be "gradient CV is useful for seals" but rather "when a single discriminator fails, measure the coefficient of variation of the underlying signal — texture consistency often outperforms geometric features".
4. **L3 must be MORE SPECIFIC than L2** — A rule is an actionable instruction, not a restated observation
5. **Evidence chain required** — Every rule traces: L3 → L2 → L1 sessions

## Automatic Lifecycle

### On Session End (auto-capture + auto-distill + auto-review)

Execute `workflows/auto-pipeline.md` — the full pipeline:

1. **Capture** — Extract L1 session summary if session is substantive
2. **Distill** — Scan L1 sessions for clusters, create/update L2 patterns
3. **Review** — Check L2 patterns at high confidence, auto-promote to L3
4. **Report** — One-line summary of what changed

### On Session Start (context loading)

Execute `workflows/session-start.md`:

1. Load high-confidence L2 patterns relevant to current working directory
2. Surface any L3 rules that apply to current project
3. Report pending reviews if any patterns need attention

## Quick Commands

| 输入 | 执行 | 说明 |
|------|------|------|
| `save` | `auto-pipeline` | 立即执行 ①②③ 全管道 |
| `提炼` | `distill` | 交互式引导提炼 |
| `复盘` | `review` | 交互式模式复盘 |
| `看板` | `dashboard.sh --open` | 打开可视化看板 |
| `学习状态` | `status` | 健康检查 |

## Integration Points

- **claude-mem**: Session observations are L0 raw material for pattern mining.
- **auto-memory**: feedback/user memories feed L2 pattern recognition.
- **rules/**: L3 outputs go to `~/.claude/rules/common/learned/`.
- **skills/learned/**: Highly actionable L3 patterns become installable skills.
- **Stop hook**: `evaluate-session.sh` logs session metadata to `session-log.jsonl`.

## Vault Structure

```
~/.claude/learning/
├── sessions/           # L1: YYYY-MM-DD-slug.md
├── patterns/           # L2: pattern-slug.md (with evidence + confidence)
│   └── .archive/       # Retired patterns
├── candidates/         # L2→L3 staging area
├── session-log.jsonl   # Raw session log from Stop hook
├── .index.json         # Metadata: counts, timestamps, pending reviews
└── dashboard.html      # Generated visual dashboard (auto-updated)
```

## Auto-Capture Criteria

Capture if ANY of:
- Session had ≥8 user messages (substantive work)
- Bug debugged / error resolved
- New approach or technique tried
- User gave feedback or correction
- Multi-step implementation completed
- Architecture or design decision made

Skip if:
- Question/answer only (<5 messages)
- Pure exploration with no learning
- Repeated routine work
