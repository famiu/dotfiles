---
name: herdr-worktrees
description: Route worktree requests and manage Herdr worktrees. Use whenever the user asks to create, open, inspect, close, remove, or work in a worktree, and before running any git worktree command. Follow an explicit tool choice first. Otherwise use a dedicated session-owned worktree tool when one exists, or use Herdr when HERDR_ENV=1.
---

# Herdr worktrees

Choose the worktree owner before running a lifecycle command. Loading this skill does not by itself select Herdr.

A Herdr worktree is a Git checkout opened as a grouped Herdr workspace with its own tab and root pane. When Herdr is selected, use it for the full worktree lifecycle. Do not mix Herdr commands with another manager's worktree lifecycle unless the user explicitly requests a handoff.

Repository conventions and explicit user instructions override the fallback naming and workflow guidance in this skill.

## Choose the worktree owner

Choose the worktree manager before running any lifecycle command:

1. Follow an explicit user choice.
2. If the current orchestrator exposes a dedicated worktree tool or API that creates and manages worktrees for the current session, use it and stop following the Herdr-specific sections of this skill.
3. Otherwise, use Herdr when `HERDR_ENV=1`.
4. Outside Herdr, use the current environment's normal worktree workflow.

A dedicated worktree tool or API associates the current task, thread, session, or workspace with a managed worktree and owns its lifecycle. A shell, the Git CLI, or permission to run `git worktree` does not qualify. Neither does the mere presence of the `herdr` binary.

When `HERDR_ENV=1` and no dedicated session-owned tool applies, use Herdr instead of raw `git worktree` commands. Do not take ownership from another manager unless the user explicitly chooses Herdr.

## Check Herdr and the repository

After selecting Herdr, verify that the current agent is running inside it:

```bash
test "${HERDR_ENV:-}" = 1
```

If the check fails, tell the user that Herdr worktree management is unavailable from the current pane and stop. If command syntax is uncertain, inspect `herdr worktree` and the relevant subcommand's `--help`; the installed CLI is authoritative.

Resolve the repository root and inspect the checkout and its worktrees:

```bash
repo="$(git rev-parse --show-toplevel)"
git -C "$repo" status --short --branch
herdr worktree list --cwd "$repo"
```

Resolve `repo` again in later shell invocations that do not share environment state.

Uncommitted source-checkout changes do not appear in a new worktree. If the task depends on them, ask how the user wants to make them available. Do not commit, stash, discard, copy, or otherwise migrate them without permission.

Before creating a worktree, reuse the current checkout when it is already a linked worktree for the same task, its branch and changes are appropriate, and no unrelated work could be disturbed. Create a new worktree only when the current checkout is unsuitable.

## Create a worktree

Use `--workspace "$HERDR_WORKSPACE_ID"` when the Herdr workspace identifies the source, or `--cwd "$repo"` when the repository identifies it. Use `--no-focus` for background work unless the user asks to switch context.

```bash
herdr worktree create \
  --workspace "$HERDR_WORKSPACE_ID" \
  --branch <branch-name> \
  --no-focus
```

Use a user-supplied branch name. Otherwise follow repository conventions and choose a short task-specific name. If no convention exists, use a lowercase slash-separated name such as `fix/session-timeout`. Add issue numbers, agent names, or other prefixes only when they are relevant or required by convention.

Add `--base <base-ref>` when the user requests a base. Otherwise omit it so Herdr uses the current checkout's `HEAD`; do not assume the repository's default branch. Add `--label` only when the user requests one or a useful label is clear from context.

If the branch already exists locally, Herdr checks it out. Otherwise Herdr creates it from the base or `HEAD`. Omit `--path` unless the user requests a location, and let Herdr use its configured worktree directory.

Read the JSON response and use the returned `.result.workspace.workspace_id`, `.result.tab.tab_id`, `.result.root_pane.pane_id`, and `.result.worktree` values. Never predict IDs or reconstruct the worktree path from naming conventions. Use the returned path for worktree-specific Git operations.

## Start the worker

When the user asks to spin up a worktree to perform a task, start a worker agent in the returned root pane. Creating, opening, or inspecting a worktree alone does not imply starting a worker.

Use the requested agent kind. Otherwise use the current harness's canonical Herdr kind. If the mapping is unclear, inspect `herdr agent start --help` and do not guess. Give the worker a unique name matching `[a-z][a-z0-9_-]{0,31}`.

```bash
herdr agent start <agent-name> --kind <agent-kind> --pane <root-pane-id>
herdr agent prompt <agent-name> \
  "<task and relevant constraints>" \
  --wait \
  --timeout 120000
```

Give the worker the task, acceptance criteria, relevant repository instructions, constraints, and validation expectations. State whether it may commit, push, or open a PR. Do not grant permissions the user has not given.

## Coordinate the worker

Inspect the worker after every wait, including successful waits, timeouts, failures, and blocked states:

```bash
herdr agent get <agent-name>
herdr agent read <agent-name> \
  --source recent-unwrapped \
  --lines 120
```

A settled lifecycle state does not prove success. Verify the reported outcome, validation output, and remaining issues before treating the task as complete. Continue coordinating when more work is needed and no user-owned decision blocks progress.

Surface blocked requests involving approval, credentials, destructive actions, security-sensitive choices, or other user authorization. Do not answer or approve them autonomously. Routine implementation decisions within the assigned task do not require escalation.

Report the worktree path, branch, Herdr workspace ID, worker name, outcome, validation performed, and unresolved issues.

## List or reopen worktrees

List worktrees by source workspace or repository:

```bash
herdr worktree list --workspace <source-workspace-id>

repo="$(git rev-parse --show-toplevel)"
herdr worktree list --cwd "$repo"
```

Open an existing checkout that belongs under Herdr management but is not currently open:

```bash
repo="$(git rev-parse --show-toplevel)"
herdr worktree open --cwd "$repo" --branch <branch-name> --no-focus
herdr worktree open --cwd "$repo" --path <worktree-path> --no-focus
```

Pass exactly one of `--branch` or `--path`. If Herdr already has the checkout open, use the returned workspace instead of opening another. Do not use `worktree open` to take ownership from another active worktree manager unless the user explicitly requests Herdr management.

## Close or remove a worktree

Closing and removing have different effects:

- `herdr workspace close <workspace-id>` closes the Herdr workspace but leaves the checkout and branch on disk.
- `herdr worktree remove --workspace <workspace-id>` closes the linked workspace and runs `git worktree remove`. It leaves the branch intact.

Do not close or remove a worktree merely because its task finished. Keep it available for review unless the user asks for cleanup.

Before removal, inspect the status using the path returned by Herdr, then try normal removal:

```bash
git -C <worktree-path> status --short --branch
herdr worktree remove --workspace <workspace-id>
```

If Git refuses because the checkout has modified or untracked files, report them. Use `--force` only after the user explicitly approves discarding those files. Remove the branch separately only when the user asks.
