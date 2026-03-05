---
name: create-pr-stack
description: Create a stack of dependent draft PRs from a list of jj bookmarks. Each PR targets the previous bookmark's branch as its base (first PR targets the default branch). Uses /create-pr for each individual PR description. After all PRs are created, appends a PR Stack section with links to all PRs in every description. Use when implementing a plan that spans multiple bookmarks or when the user provides an ordered list of bookmarks for stacked review.
---

# Create PR Stack

Create a stack of dependent draft PRs where each PR is based off the previous one.

## Prerequisites

- Bookmarks exist and are pushed (`jj bookmark list`, `jj git push`)
- Each bookmark represents a logical unit of work (e.g., one phase or group of phases)
- Plan doc and/or ticket context is available

## Workflow

### 1. Gather Bookmarks

Accept an ordered list of bookmarks from the user or derive from the plan:

```
b1 -> b2 -> b3 -> b4
```

Verify each bookmark exists and is pushed:
```bash
jj bookmark list
jj git push --bookmark <name>  # for any that aren't pushed
```

### 2. Determine Base Branches

Each PR targets the branch immediately before it:

| PR | Head branch | Base branch |
|----|-------------|-------------|
| PR 1 | b1 | `main` / `master` / `trunk` (default branch) |
| PR 2 | b2 | b1 |
| PR 3 | b3 | b2 |
| PR 4 | b4 | b3 |

Detect the default branch:
```bash
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

### 3. Create Each PR Using /create-pr Format

For each bookmark in order, create a draft PR. **Use the exact same description format as `/create-pr`** -- Why, Summary, Architecture (if applicable), Changes, Test plan, Follow-up.

The `--base` flag sets the target branch:

```bash
# First PR -- base is the default branch
gh pr create --draft \
  --head "b1" \
  --base "main" \
  --title "<TICKET-ID> <summary for b1's changes>" \
  --body "$(cat <<'EOF'
## Why
...

## Summary
...

## Changes
...

## Test plan
...

## Follow-up
...
EOF
)"

# Subsequent PRs -- base is the previous bookmark
gh pr create --draft \
  --head "b2" \
  --base "b1" \
  --title "<TICKET-ID> <summary for b2's changes>" \
  --body "$(cat <<'EOF'
## Why
...

## Summary
...

## Changes
...

## Test plan
...

## Follow-up
...
EOF
)"
```

**Each PR description must follow the `/create-pr` format exactly:**
- **Why** -- concise motivation from the ticket
- **Summary** -- 3-5 bullets
- **Architecture** -- diagram if applicable (see `/create-pr` for guidance)
- **Changes** -- grouped by component
- **Test plan** -- actual tests run
- **Follow-up** -- next steps

Each PR's description should be scoped to **only the changes in that bookmark's diff against its base**, not the cumulative diff.

### 4. Collect All PR URLs

After all PRs are created, gather the URLs:

```bash
# Get URL for each PR by branch name
gh pr view b1 --json url --jq '.url'
gh pr view b2 --json url --jq '.url'
# ... etc
```

### 5. Append PR Stack Section to Every PR

Update **every** PR description to include a `## PR Stack` section at the bottom with links to all PRs in the stack. The current PR should be bolded.

```bash
gh pr edit b1 --body "$(cat <<'EOF'
<existing body>

## PR Stack
- **#101 CRED-2174 Add proto definitions and DB layer** (this PR)
- #102 CRED-2174 Add manager and gRPC server implementation
- #103 CRED-2174 Add authorization and integration tests
EOF
)"
```

Format for the PR Stack section:

**Single-repo stack:**

```markdown
## PR Stack
- **#<num> <title>** (this PR)
- #<num> <title>
- #<num> <title>
```

**Cross-repo stack** (when this stack is part of a multi-repo effort):

```markdown
## PR Stack

### this-repo
- **#101 CRED-2174 Add proto definitions** (this PR)
- #102 CRED-2174 Add DB layer

### other-repo
- [other-repo#45](https://github.com/org/other-repo/pull/45) CRED-2174 Add client integration
- [other-repo#46](https://github.com/org/other-repo/pull/46) CRED-2174 Add cleanup job
```

Rules:
- List PRs in stack order (base to top) within each repo
- Bold the current PR and mark it with `(this PR)`
- **Same repo**: use `#<number>` shorthand
- **Cross repo**: use full markdown link `[repo#num](URL)`
- Group by repo name using `###` subsections when multiple repos are involved
- Every PR in the stack gets this section
- If cross-repo PRs are provided (e.g., by `/ticket-worker`), include them in every PR's stack section

### 6. Report

After all PRs are created and updated:

```
PR Stack created (all drafts):

1. #101 <title> -> main
   <URL>
2. #102 <title> -> b1
   <URL>
3. #103 <title> -> b2
   <URL>

All PR descriptions include the full stack links.
```

## Deriving Bookmarks from a Plan

When called from `/implement-plan`, the bookmarks can be derived from the progress doc:

- If the plan has multiple bookmarks recorded in the progress table, use those in order
- If the plan has a single bookmark, use `/create-pr` instead (not a stack)
- If the user hasn't set bookmarks yet, ask which phases should be grouped into which bookmarks

## Updating an Existing Stack

If PRs already exist and the stack needs updating (e.g., after `/iterate-plan`):

1. Push updated bookmarks: `jj git push --bookmark <name>`
2. Update PR descriptions if the changes have shifted
3. Re-add the PR Stack section with any new PRs included
4. Use `gh pr edit` to update existing PRs -- don't create duplicates

## Key Principles

- **Same format as `/create-pr`** -- Why, Summary, Changes, Test plan, Follow-up. No deviations.
- **Always draft** -- every PR in the stack is created as a draft
- **Each PR is scoped** -- description covers only that PR's diff, not the whole stack
- **Stack links in every PR** -- reviewer can navigate the full stack from any PR
- **Order matters** -- base branch chains must be correct for GitHub to show the right diff
- **Current PR is bolded** -- easy to identify which PR you're looking at in the stack section
