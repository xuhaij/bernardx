---
name: cdp-automation
description: CDP browser automation patterns — element selection, interaction strategies, and page observation techniques
---

# CDP Automation Patterns

## Element Selection

Use CSS selectors to target elements:
- By ID: `#submit-btn`
- By name attribute: `input[name="email"]`
- By type: `button[type="submit"]`
- Combined: `select[name="category"]`

## Interaction Strategies

### Clicking
1. Focus the element first (prevents race conditions)
2. Click via CDP
3. Wait 500ms for page reaction

### Typing
1. Focus the input field
2. Clear existing value
3. Type new text
4. Wait 300ms

### Dropdowns
1. Set the `<select>` value via JS
2. Dispatch `change` event
3. Wait 300ms

### Checkboxes
1. Check if already checked
2. Click only if unchecked
3. Wait 500ms

## Page Observation

Extract structured page info via JS evaluation:
- Page title and URL
- Text content from headings, paragraphs, labels
- Interactive elements with their selectors, text, and current values

## Timing Guidelines

| Action | Wait After |
|--------|-----------|
| Navigation | 2000ms |
| Click | 500ms |
| Type | 300ms |
| Select change | 300ms |
| Dynamic content | Use `wait` tool |

## Common Pitfalls

- Elements may not be visible (check `offsetParent !== null`)
- Forms may validate on submit — read error messages before retrying
- Dynamic content may load after interaction — observe again after actions
- Some elements need focus before interaction
