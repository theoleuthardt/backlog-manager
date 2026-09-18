# CodeRabbit CLI Setup

This repo runs its CodeRabbit reviews locally through the CLI on the feature
branch, as a replacement for CodeRabbit's GitHub App integration — the App is
deliberately not used (see the "Working with Claude Code" section in the root
[`CLAUDE.md`](../CLAUDE.md) for where the review sits in the workflow).

## Installation

```bash
# Homebrew (macOS/Linux)
brew install coderabbit

# Install script (macOS/Linux)
curl -fsSL https://cli.coderabbit.ai/install.sh | sh

# Windows (PowerShell)
irm https://cli.coderabbit.ai/install.ps1 | iex
```

Verify:

```bash
coderabbit --version
```

## Authentication

Log in once per machine; the browser OAuth flow opens automatically on first
review, or start it explicitly:

```bash
coderabbit auth login
```

Check the current status with `coderabbit auth status`.

## Running a review

From the feature branch (after the PR is opened):

```bash
coderabbit review --agent --base main
```

- `--base main` diffs the feature branch against `main`, so only the change
  under review is analyzed.
- `--agent` emits NDJSON with structured findings (severity, file,
  codegenInstructions) instead of the human walkthrough.
- The same [`.coderabbit.yaml`](../.coderabbit.yaml) rules that the GitHub App
  used apply to CLI reviews — no separate configuration is needed.

Output is NDJSON: one JSON object per line, ending in a
`{"type":"complete", ...}` event. A heartbeat line only means the review is
still running; wait for `complete` and read its `findings` count.
`review_skipped` with zero findings means no review ran.

Useful scope variants:

```bash
coderabbit review --agent --uncommitted   # staged + unstaged edits to tracked files
coderabbit review --agent --committed     # committed changes only
coderabbit review --agent --dir frontend  # limit to one directory
```

## Working through findings

For each finding: verify it against the code first, fix what is still valid
with a minimal change, and skip the rest with a reason. Fix critical/major
findings before merging the PR; commit and push, then re-run the review to
confirm it comes back clean.

Inside Claude Code, the `code-review` skill wraps this whole loop — running
the review, parsing the NDJSON, and applying fixes. `coderabbit` is an alias:
`cr review --agent --base main` works the same.

## Disabling the GitHub App

Reviews come from either the CLI or the App, not both. If the `coderabbitai`
App is still installed on the repository (it shows up as a reviewer/commenter
on PRs), remove it so reviews don't run twice: GitHub → Settings →
Applications → Installed GitHub Apps → CodeRabbit → Configure, remove the
repository. Its PR comments stop immediately; the CLI is unaffected.