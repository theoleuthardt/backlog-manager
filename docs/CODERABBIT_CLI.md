# CodeRabbit CLI Setup

This repo invokes CodeRabbit reviews locally through the CLI on the feature
branch; the GitHub App integration that used to post PR comments has been
removed from this repository (see the "Working with Claude Code" section in
the root [`CLAUDE.md`](../CLAUDE.md) for where the review sits in the
workflow). The CLI runs on your machine, but it sends the reviewed diffs to
the CodeRabbit API for analysis — nothing about "local" means the code stays
on your disk.

## Installation

Prefer a package manager; the install scripts are the fallback.

```bash
# Homebrew (macOS/Linux) — preferred
brew install coderabbit

# Install script (macOS/Linux) — fallback; downloads and executes a remote
# script, so prefer Homebrew where it's available
curl -fsSL https://cli.coderabbit.ai/install.sh | sh
```

```powershell
# Windows; the install.ps1 bootstrap downloads and executes immediately —
# the Authenticode check covers the coderabbit.exe binary it fetches, not
# the script itself
irm https://cli.coderabbit.ai/install.ps1 | iex
```

Verify (the installers update `PATH` for *new* shells, so if the command is
not found, open a new shell — or run the reload command the installer
printed — and try again):

```bash
coderabbit --version
```

## Authentication

Log in once per machine; the browser OAuth flow opens automatically on first
review, or start it explicitly:

```bash
coderabbit auth login

# EU SaaS region (saved and reused for reviews once chosen)
coderabbit auth login --region eu
```

Check the current status with `coderabbit auth status`.

## Running a review

From the feature branch (before or after opening the PR — the CLI reviews
the diff against `main`, not the PR object):

```bash
coderabbit review --agent --base main
```

- `--base main` diffs the feature branch against `main`, so only the change
  under review is analyzed.
- `--agent` emits NDJSON with structured findings (severity, `fileName`,
  `codegenInstructions`) instead of the human walkthrough.
- The same [`.coderabbit.yaml`](../.coderabbit.yaml) rules that the GitHub App
  used apply to CLI reviews — no separate configuration is needed.

Output is NDJSON: one JSON object per line, ending in a
`{"type":"complete", ...}` event. A heartbeat line only means the review is
still running. Before trusting the result: the process must exit with code 0,
and the run is unsuccessful if any `{"type":"error", ...}` event appears, the
output is interrupted, or `complete` carries `status: "review_skipped"` —
that means no review ran. Only after all of that passes does the `findings`
count say anything.

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

## GitHub App

The `coderabbitai` GitHub App integration has been removed from this
repository; the local CLI is the only review path, and the App should not be
re-installed alongside it — running both would duplicate every review. If it
ever needs removing again: personal account → GitHub → Settings →
Applications → Installed GitHub Apps → CodeRabbit → Configure; for an
organization installation, the organization's Settings → Third-party Access →
GitHub Apps (or the repository's Settings → Integrations → GitHub Apps).

## Two-developer workflow

The repo is developed by a single person right now, so no PR approval is
required. As soon as two developers work on the project again (each with
their own Claude Code and CodeRabbit CLI setup), the branch protection
rules must require an approval from the other person on every PR before
merge — the local CLI review replaces the App's automated review, not human
review.