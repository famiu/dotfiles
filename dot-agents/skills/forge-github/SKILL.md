---
name: forge-github
description: Forge provider for github.com and GitHub Enterprise hosts. Supplies gh-based PR creation, metadata, review, discussion, checks, mergeability, identity resolution, and blocking change detection to generic PR workflows.
slash: false
---

# GitHub forge provider

Execute GitHub-specific operations requested by `create-prs`, `review-prs`, and `shepherd-prs`. Return authoritative state and operation results; do not decide PR content, feedback validity, review verdict, readiness, lifecycle, or merge actions.

Use `gh` for GitHub reads and writes and `git` for local state. Do not use the website when `gh` can perform the operation.

## Resolve the target

Resolve the exact host, owner, repository, PR number, URL, base branch, head repository, head branch, and head SHA. In the commands below, `<repo>` means `<host>/<owner>/<repository>`.

Use `-R <repo>` with every `gh pr` or `gh run` command and `--hostname <host>` with every `gh api` call. Do not rely on current-directory defaults after resolving a target.

Resolve the authenticated login with:

```bash
gh repo view <repo> \
  --json nameWithOwner,url,defaultBranchRef,viewerPermission,pullRequestTemplates

gh api --hostname <host> user --jq .login
```

Use the raw login for account-aware filtering and return `@<login>` as the provider-formatted forge identity. For a maintainer ping, return `@<login>` for a user or `@<organization>/<team-slug>` for a team, without backticks or escaping; the workflow inserts this mention verbatim. Do not infer the authenticated identity from the PR author.

## Read authoritative state

Read baseline PR state with structured output:

```bash
gh pr view <pr> -R <repo> \
  --json number,url,title,body,state,mergedAt,updatedAt,isDraft,baseRefName,baseRefOid,headRefName,headRefOid,headRepository,headRepositoryOwner,author,labels,assignees,milestone,projectItems,maintainerCanModify,reviewDecision,reviewRequests,mergeable,mergeStateStatus,statusCheckRollup

gh pr diff <pr> -R <repo> --patch

gh api --hostname <host> \
  repos/<owner>/<repository>/compare/<base-oid>...<head-oid> \
  --jq '{status, ahead_by, behind_by, merge_base: .merge_base_commit.sha}'
```

Use the compare response as the authoritative divergence state for those base and head revisions. Treat `statusCheckRollup` as a summary. Use paginated REST endpoints for collection state:

```bash
gh api --hostname <host> --paginate repos/<owner>/<repository>/pulls/<pr>/commits
gh api --hostname <host> --paginate repos/<owner>/<repository>/issues/<pr>/comments
gh api --hostname <host> --paginate repos/<owner>/<repository>/pulls/<pr>/reviews
gh api --hostname <host> --paginate repos/<owner>/<repository>/pulls/<pr>/comments
gh api --hostname <host> --paginate repos/<owner>/<repository>/commits/<head-sha>/check-runs
gh api --hostname <host> --paginate repos/<owner>/<repository>/commits/<head-sha>/statuses
```

Issue comments, submitted reviews, and inline review comments are separate data sets. REST is authoritative for their bodies, timestamps, review state, and reply linkage. Use GraphQL for review-thread IDs and resolution:

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

Map a REST inline comment to its thread by following `in_reply_to_id` to the root, then matching that comment's `node_id` to the first comment ID returned for a GraphQL thread.

## Create and update PRs

Read templates and recent merged PR conventions from the target repository:

```bash
gh repo view <repo> --json defaultBranchRef,pullRequestTemplates

gh pr list -R <repo> --state merged --limit 10 \
  --json number,title,body,labels,reviewRequests,mergedAt
```

Before creation, query all PRs matching the source owner, branch, and base:

```bash
gh api --hostname <host> --method GET --paginate \
  repos/<target-owner>/<target-repository>/pulls \
  -f state=open \
  -f head='<source-owner>:<source-branch>' \
  -f base='<base-branch>'
```

Verify `head.repo.full_name` and `head.ref` exactly match the source repository and branch before treating a result as the existing PR.

If the caller needs a fork, first look up the selected source repository:

```bash
gh repo view <source-host>/<source-owner>/<source-repository> \
  --json nameWithOwner,url,parent,viewerPermission
git remote get-url <fork-remote>
```

Reuse it only when its owner and name match the selected source and `parent.nameWithOwner` matches the target. Verify that `<fork-remote>` points to that fork; use `git remote add` when absent or `git remote set-url` when incorrect. If the selected fork does not exist, create it and add the remote:

```bash
gh repo fork <repo> --remote --remote-name <fork-remote>
gh repo view <source-host>/<source-owner>/<source-repository> \
  --json nameWithOwner,url,parent,viewerPermission
```

For either path, publish the source branch only after repository and remote verification:

```bash
git push -u <fork-remote> <source-branch>
```

Use `--org <organization>` only when the caller has selected an organization-owned fork.

Write multiline Markdown to a temporary file. For a same-repository branch, pass `--head <source-branch>`; for a user-owned fork, pass `--head <source-owner>:<source-branch>`:

```bash
gh pr create -R <repo> \
  --base <base-branch> \
  --head <source> \
  --title '<title>' \
  --body-file <body-file>
```

Add `--draft` only when requested. `gh pr create --head` cannot select an organization-owned head repository. Use REST in that case:

```bash
gh api --hostname <host> --method POST \
  repos/<target-owner>/<target-repository>/pulls \
  -f title='<title>' \
  -f head='<source-owner>:<source-branch>' \
  -f base='<base-branch>' \
  -F body=@<body-file>
```

For this REST request, add `-f head_repo='<source-repository>'` when source and target are distinct repositories owned by the same organization, and add `-F draft=true` only for a draft.

Update requested metadata with `gh pr edit` after reading its current value. Pass only flags for fields the workflow chose to change:

```bash
gh pr edit <pr> -R <repo> \
  --title '<title>' \
  --body-file <body-file>

gh pr edit <pr> -R <repo> \
  --add-label '<label>' \
  --add-assignee '<login>' \
  --add-reviewer '<login-or-team>' \
  --milestone '<milestone>' \
  --add-project '<project>'
```

Set maintainer edit permission through REST when requested:

```bash
gh api --hostname <host> --method PATCH \
  repos/<owner>/<repository>/pulls/<pr> \
  -F maintainer_can_modify=true
```

Use `false` instead to disable maintainer edits.

After creation or update, read back the fields changed by the operation and return the verified URL and metadata.

## Discussion and review operations

Use a review comment's top-level ID for inline replies. If the selected comment has `in_reply_to_id`, follow it to the root before writing:

```bash
gh api --hostname <host> \
  repos/<owner>/<repository>/pulls/<pr>/comments/<root-comment-id>/replies \
  -F body=@<body-file>
```

For discussion that does not belong to an inline thread:

```bash
gh pr comment <pr> -R <repo> --body-file <body-file>
```

To submit a review with or without inline comments, write a JSON request containing the pinned head SHA, attributed review body, verdict, and any attributed inline bodies:

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

Use `REQUEST_CHANGES` or `APPROVE` only when directed by the calling workflow. Submit the request non-interactively:

```bash
gh api --hostname <host> --method POST \
  repos/<owner>/<repository>/pulls/<pr>/reviews \
  --input <review-request.json>
```

Use `RIGHT` for added or context lines and `LEFT` for deleted lines. Before submission, verify every `path`, `line`, and `side` against a freshly fetched diff at the pinned head SHA. For a multi-line finding, add `start_line` and `start_side`; require `start_line < line` and ensure both sides match the diff. Put findings that cannot be mapped to current diff lines in the review body. Always provide an event so GitHub submits the review rather than leaving it pending.

GitHub does not permit approving or requesting changes on the authenticated user's own PR. Use a comment review or top-level comment instead.

Read a submitted review back with:

```bash
gh api --hostname <host> \
  repos/<owner>/<repository>/pulls/<pr>/reviews/<review-id>

gh api --hostname <host> --paginate \
  repos/<owner>/<repository>/pulls/<pr>/reviews/<review-id>/comments
```

Verify the review's `commit_id`, state, body, and URL, plus each inline comment's body, target, attribution, ID, and URL, before returning the result to the calling workflow.

Request or re-request reviewers with:

```bash
gh pr edit <pr> -R <repo> --add-reviewer <login-or-team>
```

Mark a draft ready with `gh pr ready <pr> -R <repo>`; convert it back with `--undo` when directed by the calling workflow.

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

Inspect a failed workflow run before rerunning it:

```bash
gh run list -R <repo> --commit <head-sha> --limit 100 \
  --json databaseId,workflowName,displayTitle,status,conclusion,headSha,url

gh run view <run-id> -R <repo> --log-failed
gh run rerun <run-id> -R <repo> --failed
```

Match the run's `headSha` and workflow or check name before inspecting or rerunning it.

After every write, read back the changed object and return its durable ID or resulting state. If the result is uncertain, fetch before retrying.

## Blocking watcher

Resolve the absolute directory containing this `SKILL.md` as `<skill-dir>`, then invoke the watcher from there:

```bash
<skill-dir>/scripts/watch-pr.sh checkpoint \
  --repo <repo> \
  --pr <number> \
  --checkpoint <watcher-checkpoint>

<skill-dir>/scripts/watch-pr.sh watch \
  --repo <repo> \
  --pr <number> \
  --checkpoint <watcher-checkpoint> \
  --interval 12
```

The watcher checkpoint is a compact GitHub projection, separate from the workflow's activity checkpoint. `watch` requires an existing readable checkpoint; run `checkpoint` before the authoritative refresh.

The watcher requires Bash, `gh`, `jq`, and the standard commands it validates at startup, including a `timeout` implementation that supports `--signal` and `--kill-after`.

Run `watch` as one foreground blocking tool call with no tool timeout. Do not detach it. Empty polls produce no output and do not return control to the agent.

With defaults, polls occur every 12 seconds, each GraphQL request receives `TERM` after 30 seconds and `KILL` five seconds later, and temporary failures retry with exponential backoff for up to ten minutes. `--interval`, `SHEPHERD_PR_REQUEST_TIMEOUT`, and `SHEPHERD_PR_MAX_FAILURE_SECONDS` override the corresponding defaults.

The watcher emits one JSON event whose `reason` is `changed`, `terminal`, or `attention`. All are wakeup hints, not authoritative state; perform a full refresh before acting. The bounded detector samples recent reviews, threads, and checks, uses PR `updatedAt` as fallback coverage, and suppresses successful individual check transitions while aggregate checks remain pending. Interrupting the tool call terminates the watcher and child `gh` process.

## Provider boundary

This provider does not decide whether feedback is valid, whether code should change, which review verdict is warranted, when review is useful, whether a thread is resolved in substance, or whether the PR is ready. It does not merge, close, or delete branches unless a calling workflow has explicit user authorization consistent with its own policy.
