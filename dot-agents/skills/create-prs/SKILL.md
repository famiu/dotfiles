---
name: create-prs
description: Create or update a pull request, merge request, or equivalent forge change proposal. Use when opening, drafting, editing, retitling, or refreshing one, including requests to prepare its title or description.
---

# Creating pull requests

Create or update one merge-bound change proposal. In this skill, **PR** means a pull request, merge request, or forge equivalent.

Use `git` for local history and diffs and the active forge skill for remote operations. Repository conventions and explicit user instructions override content and workflow defaults, but do not waive safety or authorization requirements. At the user's explicit request, omit any attribution required by this workflow.

## Resolve the forge

Resolve the host from an explicit PR URL, otherwise from the repository remote. Before any remote operation, load the unique available `forge-<provider>` skill whose description supports that host. The available skill catalog is the provider registry.

If no provider matches, report the forge as unsupported. If several match, ask the user which to use. Do not infer a provider from an installed CLI.

The forge skill owns provider-specific reads and writes; this skill owns PR content and workflow decisions.

## Establish context

Before writing:

1. Resolve the target repository and base branch, source repository and branch, remote default branch, and push state. Do not assume the base is `main`.
2. Read repository agent instructions, contribution guidance, and the PR template.
3. Inspect recent merged PRs through the forge for title, body, metadata, and review conventions.
4. Review the complete commit range and diff against the intended base. Describe the net effect, not the work session or latest commit.
5. Ask the forge whether the exact source repository and branch already have an open PR to the intended base. Update it unless the user explicitly wants another.

Uncommitted and unpushed changes are not part of a PR. Point them out before claiming otherwise. Do not commit, change the base, or change draft state unless requested. Push only when needed to publish a requested PR.

## Write the title

Match repository conventions for capitalization, punctuation, scopes, ticket IDs, and conventional-commit prefixes. If none exist, use a concise imperative title without a trailing period.

- Reuse a single commit's subject only when it accurately describes the complete diff.
- For multiple commits, summarize the combined outcome; do not concatenate subjects or blindly reuse the newest one.
- Make the title suitable for the repository's normal merge or squash subject.
- Describe the change, not the implementation process. Avoid vague titles such as "updates" or "misc fixes."

## Write the description

Open with the problem, need, or intended outcome. Include behavior changes, implementation details, tradeoffs, rollout notes, or screenshots only when they affect review, deployment, compatibility, or risk assessment. Do not narrate commits, list files, restate the diff, or add boilerplate headings.

Follow the repository template. Preserve required fields and checklists, remove instructional placeholders where permitted, and omit filler from optional sections.

Write for reviewers rather than issue trackers or changelog generators. Do not repeat tests or other verification already visible through CI or repository tooling. Mention non-visible verification only when it helps reviewers. Do not invent issue links, results, metrics, or impact. Use closing keywords only when the PR should close the referenced issue.

## Add attribution

When the agent opens a PR, its description must end with exactly one **created** attribution. When agent-authored code enters an already-open PR that has no agent attribution, add exactly one **modified** attribution:

```markdown
This PR was <created-or-modified> by `<model-slug>` via `<harness-name>`.
```

Use the exact runtime-provided model slug and harness name. Never guess or leave placeholders; ask the user if either is unavailable.

Once a PR has agent attribution, preserve it unchanged during all later updates, including agent-authored code changes. Never replace or refresh it to identify a later model or harness. Metadata-only edits to an unattributed PR must not add attribution. For a combined code and metadata update to an unattributed PR, follow the code-change rule.

## Create or update

If asked to use the web workflow or let the user submit the PR themselves, use the active forge's browser-based creation flow and stop before submission.

For a new PR, confirm that the source branch is published and no matching open PR exists. Ask the forge to create it with explicit source, target, title, body, and requested draft state. Apply optional metadata only when requested or required by repository policy.

For an existing PR, read its current metadata first and change only stale or requested fields. Preserve accurate human-authored context, links, checklists, and release notes. Correct stale metadata directly instead of posting a comment, and do not rewrite existing discussion.

## Verify

Read the result back through the forge. Confirm the title, body, base, head, draft state, URL, and changed metadata. When attribution is required, confirm it appears exactly once. Always confirm any pre-existing attribution is unchanged.

Report the PR URL and what was created or changed.
