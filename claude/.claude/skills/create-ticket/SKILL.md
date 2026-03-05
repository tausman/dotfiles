---
name: create-ticket
description: Collaboratively create a well-structured ticket by working with the user to understand the problem, its importance, requirements, and acceptance criteria. Optionally performs codebase research to include relevant code references. Use when user wants to write a ticket, create a task, define requirements, or draft a Jira story.
---

# Create Ticket

Interactively build a complete, well-structured ticket through conversation with the user.

## Workflow

### 1. Understand the Problem

Start by asking the user:

1. **What is the problem or need?** - What's broken, missing, or could be improved?
2. **Why does this matter?** - Business impact, user pain, technical debt, risk?
3. **Who is affected?** - Users, teams, services?

If the user gives a vague or high-level description, ask clarifying follow-up questions. Don't proceed until the problem is clearly understood.

### 2. Assess Need for Research

Based on the problem description, determine if codebase research would strengthen the ticket:

- **Research IS needed** when: the problem involves existing code, a bug, a refactor, or a feature that extends current functionality
- **Research is NOT needed** when: the problem is purely process, documentation, or greenfield with no existing code context

If research is needed, use sub-agents or direct search to:
- Find relevant code areas (file:line references)
- Understand current behavior
- Identify related components or dependencies
- Capture small code snippets that illustrate the current state or the problem

### 3. Define Requirements

Work with the user to establish:

- **What needs to happen** - Concrete deliverables
- **Constraints** - Technical, timeline, compatibility requirements
- **Out of scope** - What this ticket explicitly does NOT cover

### 4. Build Acceptance Criteria

Collaboratively create a bullet list of acceptance criteria. Each item should be:

- **Specific** - No ambiguity about what "done" means
- **Verifiable** - Can be checked by someone reviewing the work
- **Independent** - Each criterion stands on its own

Format:
```
- [ ] <Criterion that can be verified>
```

### 5. Draft the Ticket

Present the full ticket to the user for review:

```markdown
## Title
<Concise, descriptive title>

## Problem Statement
<What is the problem and why it matters>

## Context
<Background, affected systems/users, current behavior>

### Code References (if applicable)
<file:line references, relevant snippets, current implementation details>

## Requirements
<What needs to be done, constraints, out of scope>

## Acceptance Criteria
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] <Criterion 3>
...
```

### 6. Iterate

After presenting the draft:
- Ask the user if anything needs to be added, removed, or changed
- Revise until the user is satisfied
- Offer to save the ticket to a file:
  - If a ticket ID is known: `~/artifacts/<TICKET>/ticket-<TICKET>.md`
  - Otherwise: `~/artifacts/misc/<short-description>/ticket-<short-description>.md`
  - Create the directory if it doesn't exist
  - User can override the output path explicitly

## Key Principles

- **Conversational** - This is a dialogue, not a form. Guide the user through thinking clearly about the work.
- **Ask before assuming** - If something is unclear, ask. Don't fill in gaps with assumptions.
- **Code-grounded** - When relevant, back up the ticket with real code references, not hand-wavy descriptions.
- **Concise but complete** - Every section earns its place. No boilerplate filler.
- **User controls scope** - The user decides what's in and out. Suggest, don't dictate.
