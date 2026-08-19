def check_bucket($state):
  ($state // "") as $value
  | if ($value == "FAILURE" or $value == "ERROR") then "failing"
    elif $value == "SUCCESS" then "passing"
    else "waiting"
    end;

def failed_checks($contexts):
  $contexts
  | map(
      if .__typename == "CheckRun" then
        select((.conclusion // "") as $value
          | ["FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE"]
          | index($value) != null)
        | {type: "check", id, name, status, conclusion, completedAt}
      elif .__typename == "StatusContext" then
        select(.state == "FAILURE" or .state == "ERROR")
        | {type: "status", id, name: .context, state}
      else empty
      end
    )
  | sort_by(.type, .name, .id);

if ((.errors // []) | length) > 0 then
  error("graphql response: " + ([.errors[].message] | join("; ")))
elif .data.repository == null then
  error("repository unavailable")
elif .data.repository.pullRequest == null then
  error("pull request not found")
else .data.repository.pullRequest
end as $pr
| {
    lifecycle: {
      state: $pr.state,
      closed: $pr.closed,
      mergedAt: $pr.mergedAt,
      isDraft: $pr.isDraft
    },
    head: $pr.headRefOid,
    # Covers edits and metadata changes outside the bounded connection windows.
    activity: $pr.updatedAt,
    merge: {
      mergeable: $pr.mergeable,
      mergeStateStatus: $pr.mergeStateStatus,
      reviewDecision: $pr.reviewDecision
    },
    reviewRequests: {
      total: $pr.reviewRequests.totalCount,
      items: (
        ($pr.reviewRequests.nodes // [])
        | map(.requestedReviewer | {
            type: (.__typename // ""),
            name: (.login // .slug // "")
          })
        | sort_by(.type, .name)
      )
    },
    checks: {
      state: check_bucket($pr.commits.nodes[0].commit.statusCheckRollup.state),
      failed: failed_checks($pr.commits.nodes[0].commit.statusCheckRollup.contexts.nodes // [])
    },
    reviews: {
      total: $pr.reviews.totalCount,
      items: (
        ($pr.reviews.nodes // [])
        | map({
            id,
            state,
            submittedAt,
            author: (.author.login // ""),
            commit: (.commit.oid // "")
          })
        | sort_by(.id)
      )
    },
    comments: {
      total: $pr.comments.totalCount,
      latest: (($pr.comments.nodes // []) | map({id, updatedAt}))
    },
    threads: {
      total: $pr.reviewThreads.totalCount,
      items: (
        ($pr.reviewThreads.nodes // [])
        | map({
            id,
            isResolved,
            commentCount: .comments.totalCount,
            latest: ((.comments.nodes // []) | map({id, updatedAt}))
          })
        | sort_by(.id)
      )
    }
  }
