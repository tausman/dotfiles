---
name: review-pr-collaborate
description: Collaborative PR review workflow. Use when the user wants to review a PR and draft comments interactively before posting them all at once. Helps track which PR/branch is being reviewed, checks out the code using jj review, and batches all comments for submission. Triggers on "review PR", "collaborate on PR review", "let's review this PR", "draft PR comments", or when the user wants to iteratively build up PR review feedback.
---

# Collaborative PR Review

Interactive workflow for reviewing a PR with the user, drafting comments together, and posting them all at once when ready.

## Workflow Overview

1. **Identify the PR** -- determine which PR to review
2. **Check out the code** -- ensure the PR's changes are available locally on a single commit
3. **Review files together** -- walk through changes, discuss, draft comments
4. **Batch post comments** -- when the user gives the go-ahead, post all comments at once

---

## Phase 1: Identify the PR

Accept the PR in any of these formats:
- PR number (e.g., `12345`)
- PR URL (e.g., `https://github.com/owner/repo/pull/123`)
- Branch name (e.g., `someone/feature-branch`)
- "current PR" -- detect from current branch

Determine the PR details:
```bash
# If given a PR number or URL
gh pr view <pr-number-or-url> --json number,headRefName,baseRefName,url,title,body,additions,deletions,changedFiles

# If on a branch, try to detect
gh pr view --json number,headRefName,baseRefName,url,title,body,additions,deletions,changedFiles
```

Extract and store:
- **PR number**
- **Branch name** (headRefName)
- **Base branch** (baseRefName)
- **Repository** (owner/repo)
- **PR URL**

Present a summary to the user:
```
Reviewing PR #<number>: <title>
Branch: <headRefName> -> <baseRefName>
Files changed: <changedFiles> (+<additions>, -<deletions>)
URL: <url>
```

---

## Phase 2: Check Out the Code

### Check if already on the right commit

First, check if the current working copy already contains the PR's changes:

```bash
# See what branch/bookmark the current commit is on
jj log

# Check if the PR branch is already available
jj bookmark list | grep <branch-name>
```

If the current commit already matches the PR changes (same branch or same diff), skip checkout.

### Use jj review to check out

If not already checked out, use the custom `jj review` alias which:
1. Fetches the remote branch
2. Finds the common ancestor with trunk
3. Creates a new commit with all the PR's changes squashed into one

```bash
jj review <branch-name>
```

This gives a single commit with the full PR diff, ideal for reviewing.

### Verify checkout

After checkout, verify:
```bash
jj status
jj diff --stat
```

Confirm the changed files match what the PR shows.

---

## Phase 3: Collaborative Review

### Get the list of changed files

```bash
jj diff --stat
```

### Review approach

Work through files with the user. For each file or area of interest:

1. **Read the file** at the relevant sections
2. **Show the diff** for that file: `jj diff <file-path>`
3. **Discuss** with the user -- they may have observations, questions, or want to draft a comment
4. **Draft comments** when the user wants to leave feedback

### Tracking comments

Maintain an internal list of all drafted comments. Each comment has:

- **file_path**: The file the comment is on
- **line**: The line number in the new version of the file (RIGHT side)
- **body**: The comment text (MUST end with `\n\n_ai assisted comment_`)
- **comment_url** (optional): If replying to an existing thread, the URL of the comment

Track these as a numbered list and present them to the user periodically:

```
Drafted comments (3):
1. [src/handler.go:42] Missing error check on db.Query return
2. [src/handler.go:87] Consider using context.WithTimeout here
3. [src/config.go:15] This default value should be configurable
```

### Comment format

EVERY comment body MUST end with:
```

_ai assisted comment_
```

This is a hard requirement -- append it to every comment before posting.

### User interactions during review

The user may:
- **Add a comment**: "Comment on line X of file Y: ..."
- **Edit a comment**: "Change comment 2 to say ..."
- **Delete a comment**: "Remove comment 3"
- **View all comments**: "Show me all drafted comments"
- **Move to next file**: "Next file" or "Let's look at ..."
- **Ask questions**: "What does this function do?" -- answer from code context
- **Give the go-ahead**: "Post them" / "Submit" / "Send all comments" / "LGTM, post"

---

## Phase 4: Batch Post Comments

When the user gives the go-ahead, post ALL comments at once using the GitHub API.

### For new inline comments (not replies to existing threads)

Use the GitHub PR review API to post all comments as a single review:

```bash
# Build the comments array for the review
# Each comment needs: path, line (or position), body

gh api \
  -X POST \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews" \
  -f event="COMMENT" \
  -f body="" \
  --input <(cat <<'EOF'
{
  "event": "COMMENT",
  "body": "",
  "comments": [
    {
      "path": "src/handler.go",
      "line": 42,
      "side": "RIGHT",
      "body": "Missing error check on db.Query return\n\n_ai assisted comment_"
    },
    {
      "path": "src/handler.go",
      "line": 87,
      "side": "RIGHT",
      "body": "Consider using context.WithTimeout here\n\n_ai assisted comment_"
    }
  ]
}
EOF
)
```

**Important**: The `line` must reference a line within the diff (a line that was added or is context in the diff). Use `side: "RIGHT"` for lines in the new version.

To get the correct commit_id for the review:
```bash
# Get the latest commit SHA on the PR branch
gh pr view <pr_number> --json headRefOid --jq '.headRefOid'
```

Include the `commit_id` in the review payload so comments are anchored to the right commit.

### For replies to existing comment threads

Use the reply-pr-thread script for each reply:

```bash
# For each reply-type comment
reply-pr-thread.sh "<comment-url>" "<body>"
```

Or use the API directly:
```bash
gh api \
  -X POST \
  "repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies" \
  -f body="<body>"
```

### Post-submission report

After posting, report results:

```
Posted <N> comments on PR #<number>:
- <N> new inline comments (via review)
- <N> thread replies
PR: <url>
```

If any comments fail to post, report which ones failed and why.

---

## Error Handling

- **jj review fails**: Check if the branch exists remotely, suggest `jj git fetch`
- **Comment line not in diff**: Warn the user that the line must be within the diff range. Suggest the nearest valid line.
- **API rate limits**: Report and suggest waiting
- **Auth issues**: Suggest `gh auth login`

## Key Principles

- **Batch, don't trickle** -- never post comments one at a time during the review. Collect everything and post when the user says go.
- **Always append footer** -- every comment body ends with `\n\n_ai assisted comment_`
- **Single commit view** -- use `jj review` to get all changes on one commit for easy reviewing
- **User is in control** -- don't post anything without explicit go-ahead
- **Track state clearly** -- always be able to show the user what comments are queued
