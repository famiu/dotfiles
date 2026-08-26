---
name: forge-github
description: Forge provider for github.com and GitHub Enterprise hosts. Supplies gh-based PR creation, metadata, review, discussion, checks, mergeability, identity resolution, and blocking change detection to generic PR workflows.
slash: false
---

# GitHub forge provider

Execute GitHub-specific operations for `create-prs`, `review-prs`, and `shepherd-prs`. Return authoritative state and operation results; the calling workflow owns content, judgment, readiness, lifecycle, and merge decisions.

Load the `gh` skill and follow its guidance. Use `gh` for remote operations and `git` for local state; do not use the website when `gh` suffices. The stricter targeting and verification rules below take precedence.

## Resolve the target

Resolve the exact host, owner, repository, PR number, URL, base branch, head repository, head branch, and head SHA. Below, `<repo>` means `<host>/<owner>/<repository>`.

Use `-R <repo>` with every `gh pr` or `gh run` command and `--hostname <host>` with every `gh api` call. Do not rely on current-directory defaults after resolving a target.

Resolve repository metadata and the authenticated login with:

```bash
gh repo view <repo> \
  --json nameWithOwner,url,defaultBranchRef,viewerPermission,pullRequestTemplates
gh api --hostname <host> user --jq .login
```

Use the raw login for account-aware filtering. Return `@<login>` as the forge identity and `@<login>` or `@<organization>/<team-slug>` as an unescaped maintainer mention. Do not infer identity from the PR author.

## Read authoritative state

Read the baseline PR state, diff, and divergence:

```bash
gh pr view <pr> -R <repo> \
  --json number,url,title,body,state,mergedAt,updatedAt,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,headRepository,headRepositoryOwner,author,labels,assignees,milestone,projectItems,maintainerCanModify,reviewDecision,reviewRequests,mergeable,mergeStateStatus,statusCheckRollup
gh pr diff <pr> -R <repo> --patch
gh api --hostname <host> \
  repos/<owner>/<repository>/compare/<base-oid>...<head-oid> \
  --jq '{status, ahead_by, behind_by, merge_base: .merge_base_commit.sha}'
```

The compare response is authoritative for divergence between those revisions. `statusCheckRollup` is only a summary. Read complete collection state from the paginated REST endpoints:

```text
repos/<owner>/<repository>/pulls/<pr>/commits
repos/<owner>/<repository>/issues/<pr>/comments
repos/<owner>/<repository>/pulls/<pr>/reviews
repos/<owner>/<repository>/pulls/<pr>/comments
repos/<owner>/<repository>/commits/<head-sha>/check-runs
repos/<owner>/<repository>/commits/<head-sha>/statuses
```

Issue comments, reviews, and inline review comments are separate data sets. REST is authoritative for their bodies, timestamps, review state, and reply linkage. Use GraphQL for thread IDs and resolution:

```bash
gh api --hostname <host> graphql --paginate \
  -F owner=<owner> -F name=<repository> -F number=<pr> \
  -f query='query($owner: String!, $name: String!, $number: Int!, $endCursor: String) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $number) {
        reviewThreads(first: 100, after: $endCursor) {
          nodes { id isResolved comments(first: 1) { nodes { id } } }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  }'
```

Map a REST inline comment to its thread by following `in_reply_to_id` to the root, then matching that comment's `node_id` to a thread's first comment ID.

## Create and update PRs

Read `pullRequestTemplates` and supply recent repository conventions to the caller with:

```bash
gh pr list -R <repo> --state merged --limit 10 \
  --json number,title,body,labels,reviewRequests,mergedAt
```

Before creation, query open PRs for the exact source owner, branch, and base:

```bash
gh api --hostname <host> --method GET --paginate \
  repos/<target-owner>/<target-repository>/pulls \
  -f state=open \
  -f head='<source-owner>:<source-branch>' \
  -f base='<base-branch>'
```

Treat a result as the existing PR only after verifying `head.repo.full_name` and `head.ref` against the selected source.

When a fork is needed, verify the selected source repository's owner, name, parent, permission, and local remote URL. Reuse it only when its owner and name match the selected source, its parent matches the target, and the remote points to it. Otherwise create the selected fork or correct the remote, then verify again. Use `--org <organization>` only for a caller-selected organization fork. Publish the source branch only after these checks:

```bash
gh repo view <source-host>/<source-owner>/<source-repository> \
  --json nameWithOwner,url,parent,viewerPermission
git remote get-url <fork-remote>
gh repo fork <repo> --remote --remote-name <fork-remote>
git push -u <fork-remote> <source-branch>
```

Write multiline Markdown to a temporary file. For a same-repository branch, use `--head <source-branch>`; for a user fork, use `--head <source-owner>:<source-branch>`:

```bash
gh pr create -R <repo> \
  --base <base-branch> \
  --head <source> \
  --title '<title>' \
  --body-file <body-file>
```

Add `--draft` only when requested. Because `gh pr create --head` cannot select an organization-owned head repository, use REST for that case:

```bash
gh api --hostname <host> --method POST \
  repos/<target-owner>/<target-repository>/pulls \
  -f title='<title>' \
  -f head='<source-owner>:<source-branch>' \
  -f base='<base-branch>' \
  -F body=@<body-file>
```

Add `-f head_repo='<source-repository>'` when source and target are distinct repositories owned by the same organization. Add `-F draft=true` only for a draft.

Before updating metadata, read its current value. Use `gh pr edit` for title, body, labels, assignees, reviewers, milestone, and project, passing only fields the caller chose to change. Set `maintainer_can_modify` through REST when requested:

```bash
gh api --hostname <host> --method PATCH \
  repos/<owner>/<repository>/pulls/<pr> \
  -F maintainer_can_modify=<true-or-false>
```

## Discussion and review operations

For an inline reply, follow `in_reply_to_id` to the root and use its top-level ID:

```bash
gh api --hostname <host> \
  repos/<owner>/<repository>/pulls/<pr>/comments/<root-comment-id>/replies \
  -F body=@<body-file>
```

For discussion that does not belong to an inline thread, use:

```bash
gh pr comment <pr> -R <repo> --body-file <body-file>
```

Submit a review as a JSON request containing the pinned head SHA, attributed body, verdict, and any attributed inline comments:

```json
{
  "commit_id": "<head-sha>",
  "body": "<attributed-review-body>",
  "event": "COMMENT",
  "comments": [
    {
      "path": "<path>",
      "line": 42,
      "side": "RIGHT",
      "body": "<attributed-inline-body>"
    }
  ]
}
```

Use `REQUEST_CHANGES` or `APPROVE` only when directed by the caller. Before submission, verify each `path`, `line`, and `side` against a freshly fetched diff at the pinned SHA. Use `RIGHT` for added or context lines and `LEFT` for deleted lines. For multiline findings, add `start_line` and `start_side`, require `start_line < line`, and keep both sides consistent with the diff. Put findings that cannot map to current diff lines in the review body. Always provide an event so the review is submitted rather than left pending.

```bash
gh api --hostname <host> --method POST \
  repos/<owner>/<repository>/pulls/<pr>/reviews \
  --input <review-request.json>
```

GitHub forbids approving or requesting changes on the authenticated user's PR. Use a comment review or top-level comment instead.

Read a submitted review and its comments back from:

```text
repos/<owner>/<repository>/pulls/<pr>/reviews/<review-id>
repos/<owner>/<repository>/pulls/<pr>/reviews/<review-id>/comments
```

Verify the review's `commit_id`, state, body, and URL and every inline comment's body, target, attribution, ID, and URL.

Request or re-request a reviewer with `gh pr edit <pr> -R <repo> --add-reviewer <login-or-team>`. Change draft state with `gh pr ready <pr> -R <repo>`, adding `--undo` when directed.

Resolve a review thread by node ID:

```bash
gh api --hostname <host> graphql \
  -F thread=<thread-id> \
  -f query='mutation($thread: ID!) {
    resolveReviewThread(input: {threadId: $thread}) {
      thread { id isResolved }
    }
  }'
```

Before rerunning a failed workflow, match both `headSha` and workflow or check name, then inspect it:

```bash
gh run list -R <repo> --commit <head-sha> --limit 100 \
  --json databaseId,workflowName,displayTitle,status,conclusion,headSha,url
gh run view <run-id> -R <repo> --log-failed
gh run rerun <run-id> -R <repo> --failed
```

After every write, read back the changed object and return its durable ID or resulting state. For PR creation or update, return the verified URL and changed metadata. If the outcome is uncertain, fetch before retrying.

## Blocking watcher

Resolve this skill's absolute directory as `<skill-dir>`, then invoke its watcher:

```bash
<skill-dir>/scripts/watch-pr.sh checkpoint \
  --repo <repo> --pr <number> --checkpoint <watcher-checkpoint>

<skill-dir>/scripts/watch-pr.sh watch \
  --repo <repo> --pr <number> --checkpoint <watcher-checkpoint> --interval 12
```

The watcher checkpoint is a compact GitHub projection, separate from the workflow's activity checkpoint. `watch` requires an existing readable checkpoint; run `checkpoint` before the authoritative refresh.

The watcher requires Bash, `gh`, `jq`, and the standard commands it validates at startup, including a `timeout` implementation supporting `--signal` and `--kill-after`.

Run `watch` as one foreground blocking tool call with no tool timeout. Do not detach it. Empty polls produce no output and do not return control to the agent.

By default, polls run every 12 seconds, each GraphQL request receives `TERM` after 30 seconds and `KILL` five seconds later, and temporary failures retry with exponential backoff for up to ten minutes. Override these with `--interval`, `SHEPHERD_PR_REQUEST_TIMEOUT`, and `SHEPHERD_PR_MAX_FAILURE_SECONDS`.

The watcher emits one JSON event with reason `changed`, `terminal`, or `attention`. These are wakeup hints, not authoritative state; refresh fully before acting. The bounded detector samples recent reviews, threads, and checks, uses PR `updatedAt` as fallback coverage, and suppresses successful individual check transitions while aggregate checks remain pending. Interrupting the tool call terminates the watcher and its child `gh` process.

## Provider boundary

This provider does not judge feedback, choose code changes or review verdicts, decide when review is useful, or determine substantive thread resolution or readiness. It does not merge, close, or delete branches unless the calling workflow has explicit user authorization consistent with its policy.
