---
name: bt-schema
description: Behavior tree node types, JSON format, and tree design patterns for generating BT projects
---

# Behavior Tree Schema

## Node Types

### Composites (have `children` array)

| Type | Behavior |
|------|----------|
| Sequence | Runs children left-to-right. Fails on first failure. |
| Selector | Runs children left-to-right. Succeeds on first success. |
| Parallel | Runs all children. Policy: "RequireAll" or "RequireOne". |
| RandomSelector | Like Selector, random order. |
| RandomSequence | Like Sequence, random order. |

### Decorators (have one child in `children` array)

| Type | Fields | Behavior |
|------|--------|----------|
| Repeat | `count: N` | Repeats child N times. |
| RetryUntilSuccessful | `count: N` | Retries child until success, max N times. |
| Inverter | — | Flips success/failure. |
| ForceSuccess | — | Always returns success. |
| ForceFailure | — | Always returns failure. |

### Leaves

| Type | Fields | Behavior |
|------|--------|----------|
| Script | `path: "scripts/..."`, optional `args: {}` | Runs a Lua script module (Enter/Tick/Exit). |
| Wait | `ms: N` | Waits N milliseconds, then succeeds. |
| Subtree | `tree: "name"` | References another tree directory. |

## JSON Format

```json
{
  "type": "Sequence",
  "name": "task_name",
  "children": [...]
}
```

Each node has `type`, `name`, and type-specific fields.

## Common Script Modules

Available at `scripts/common/`:

- `init_cdp.lua` — Connect to Chrome + optional AI client. Args: `{ url?: string, ai?: boolean }`
- `execute_step.lua` — **Deterministic action executor.** Args: `{ action, selector?, text?, ... }`
- `observe.lua` — Extract page state (title, content, elements)
- `verify.lua` — Check playground verify API, sets `task_done` on pass
- `cleanup.lua` — Close CDP connection

Legacy (for AI-decision trees only):
- `ai_decide.lua` — AI analyzes page, calls tools
- `execute_action.lua` — Execute AI-decided action
- `check_done.lua` — Check if task_done is set

## Deterministic Step Pattern (RECOMMENDED)

Generate trees that encode exact actions. No AI at runtime.

```json
{
  "type": "Sequence",
  "name": "scenario_name",
  "children": [
    {
      "type": "Script",
      "name": "init",
      "path": "scripts/common/init_cdp.lua",
      "args": { "ai": false }
    },
    {
      "type": "Script",
      "name": "type_name",
      "path": "scripts/common/execute_step.lua",
      "args": { "action": "type", "selector": "#name", "text": "John" }
    },
    {
      "type": "Script",
      "name": "click_submit",
      "path": "scripts/common/execute_step.lua",
      "args": { "action": "click", "selector": "#submit-btn" }
    },
    { "type": "Wait", "name": "wait_response", "ms": 1000 },
    { "type": "Script", "name": "verify", "path": "scripts/common/verify.lua" },
    { "type": "Script", "name": "cleanup", "path": "scripts/common/cleanup.lua" }
  ]
}
```

## execute_step.lua Actions

| Action | Required Fields | Description |
|--------|----------------|-------------|
| `click` | `selector` | Click element by CSS selector |
| `type` | `selector`, `text` | Clear + type text into input |
| `check` | `selector` | Check checkbox (no-op if already checked) |
| `select` | `selector`, `value` | Select dropdown option |
| `navigate` | `url` | Navigate to URL, wait 2s |
| `wait` | `ms` | Wait milliseconds |
| `evaluate` | `js` | Execute arbitrary JavaScript |

Each action auto-focuses the element and includes appropriate wait times.

## Tree Generation Rules

1. **Use init_cdp with `{ ai: false }`** — no API key needed at runtime
2. **One execute_step per action** — each step does one thing
3. **Add Wait nodes between logical groups** — 500-1000ms after form submissions, page transitions
4. **verify at the end** — calls playground API to confirm success
5. **Use exact selectors and text** from the page you observed — do NOT invent or guess
6. **Do NOT use ai_decide.lua or agent loop patterns** — the tree must be deterministic
