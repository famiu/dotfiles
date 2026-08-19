#!/usr/bin/env bash

set -uo pipefail

repo=""
pr=""
checkpoint=""
interval=12
max_failure_seconds=${SHEPHERD_PR_MAX_FAILURE_SECONDS:-600}
request_timeout=${SHEPHERD_PR_REQUEST_TIMEOUT:-30}
tmp_root=""
child_pid=""

if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' '{"reason":"attention","kind":"usage","message":"required command not found: jq"}'
    exit 2
fi

emit_attention() {
    jq -cn --arg kind "$1" --arg message "$2" \
        '{reason: "attention", kind: $kind, message: $message}'
}

usage_error() {
    emit_attention "usage" "$1"
    exit 2
}

cleanup() {
    [[ -n "$child_pid" ]] && kill "$child_pid" 2>/dev/null || true
    [[ -n "$tmp_root" ]] && rm -rf "$tmp_root"
}

trap 'exit 130' INT TERM
trap cleanup EXIT

script_path=${BASH_SOURCE[0]}
case "$script_path" in
    */*) script_parent=${script_path%/*} ;;
    *) script_parent=. ;;
esac
if ! script_dir=$(cd -- "$script_parent" && pwd); then
    usage_error "could not resolve script directory"
fi
query_file="$script_dir/watch-state.graphql"
normalizer_file="$script_dir/normalize-state.jq"

quiet_sleep() {
    run_child sleep "$1" 2>/dev/null || true
}

run_child() {
    local result

    "$@" &
    child_pid=$!
    wait "$child_pid"
    result=$?
    child_pid=""
    return "$result"
}

mode=${1:-}
case "$mode" in
    checkpoint|watch) shift ;;
    *) usage_error "mode must be checkpoint or watch" ;;
esac

while (($# > 0)); do
    case "$1" in
        --repo)
            (($# >= 2)) || usage_error "--repo requires a value"
            repo=$2
            shift 2
            ;;
        --pr)
            (($# >= 2)) || usage_error "--pr requires a value"
            pr=$2
            shift 2
            ;;
        --checkpoint)
            (($# >= 2)) || usage_error "--checkpoint requires a value"
            checkpoint=$2
            shift 2
            ;;
        --interval)
            (($# >= 2)) || usage_error "--interval requires a value"
            interval=$2
            shift 2
            ;;
        *)
            usage_error "unknown argument: $1"
            ;;
    esac
done

[[ "$repo" == */*/* ]] || usage_error "--repo must be HOST/OWNER/REPO"
[[ "$pr" =~ ^[1-9][0-9]*$ ]] || usage_error "--pr must be a positive integer"
[[ -n "$checkpoint" ]] || usage_error "--checkpoint is required"
[[ "$interval" =~ ^[1-9][0-9]*$ ]] || usage_error "--interval must be a positive integer"
[[ "$max_failure_seconds" =~ ^[1-9][0-9]*$ ]] || usage_error "SHEPHERD_PR_MAX_FAILURE_SECONDS must be a positive integer"
[[ "$request_timeout" =~ ^[1-9][0-9]*$ ]] || usage_error "SHEPHERD_PR_REQUEST_TIMEOUT must be a positive integer"

for required_command in cmp cp gh grep mkdir mktemp mv rm sed sh sleep tail timeout tr; do
    command -v "$required_command" >/dev/null 2>&1 || \
        usage_error "required command not found: $required_command"
done

timeout --signal=TERM --kill-after=1s 1s sh -c ':' >/dev/null 2>&1 || \
    usage_error "timeout must support --signal and --kill-after"

[[ -r "$query_file" ]] || usage_error "query file not found: $query_file"
[[ -r "$normalizer_file" ]] || usage_error "normalizer file not found: $normalizer_file"

host=${repo%%/*}
owner_repo=${repo#*/}
owner=${owner_repo%%/*}
name=${owner_repo#*/}

[[ -n "$host" && -n "$owner" && -n "$name" && "$name" != */* ]] || \
    usage_error "--repo must be HOST/OWNER/REPO"

if ! tmp_root=$(mktemp -d 2>/dev/null); then
    emit_attention "temporary_storage" "could not create temporary directory"
    exit 1
fi
graphql_query=$(<"$query_file")

run_snapshot() {
    local output=$1
    local raw="$tmp_root/raw.json"
    local error="$tmp_root/last-error"

    : >"$error"
    if ! run_child timeout --signal=TERM --kill-after=5s "${request_timeout}s" \
        gh api --hostname "$host" graphql \
        -f query="$graphql_query" \
        -F owner="$owner" \
        -F name="$name" \
        -F number="$pr" \
        >"$raw" 2>"$error"; then
        return 1
    fi

    if ! jq -S -f "$normalizer_file" "$raw" >"$output" 2>>"$error"; then
        return 1
    fi
}

error_message() {
    if [[ -s "$tmp_root/last-error" ]]; then
        tail -c 1000 "$tmp_root/last-error" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g'
    else
        printf '%s' "GitHub polling failed without an error message"
    fi
}

is_permanent_error() {
    [[ -s "$tmp_root/last-error" ]] || return 1
    grep -Eqi \
        'bad credentials|authentication failed|not logged|HTTP 401|resource not accessible|repository unavailable|graphql response:.*(doesn.t exist on type|unknown argument|fragment cannot be spread|expected type)' \
        "$tmp_root/last-error"
}

is_terminal_error() {
    [[ -s "$tmp_root/last-error" ]] && grep -Fqi 'pull request not found' "$tmp_root/last-error"
}

emit_terminal() {
    jq -cn '{reason: "terminal"}'
}

is_terminal() {
    jq -e '
        .lifecycle.state != "OPEN"
        or .lifecycle.closed == true
        or .lifecycle.mergedAt != null
    ' "$1" >/dev/null
}

write_checkpoint() {
    local source=$1
    local checkpoint_dir
    local temporary

    checkpoint_dir=$(dirname "$checkpoint")
    temporary=""
    : >"$tmp_root/last-error"
    mkdir -p "$checkpoint_dir" 2>>"$tmp_root/last-error" || return 1
    temporary=$(mktemp "$checkpoint_dir/.watch-pr.XXXXXX" 2>>"$tmp_root/last-error") || return 1
    if ! cp "$source" "$temporary" 2>>"$tmp_root/last-error" \
        || ! mv -f "$temporary" "$checkpoint" 2>>"$tmp_root/last-error"; then
        rm -f "$temporary"
        return 1
    fi
}

snapshot_with_retry() {
    local current=$1
    local backoff=5
    local delay
    local elapsed
    local remaining
    local started=$SECONDS

    while ! run_snapshot "$current"; do
        if is_terminal_error; then
            emit_terminal
            return 2
        fi
        elapsed=$((SECONDS - started))
        if is_permanent_error || ((elapsed >= max_failure_seconds)); then
            emit_attention "github" "$(error_message)"
            return 1
        fi

        remaining=$((max_failure_seconds - elapsed))
        delay=$backoff
        ((delay > remaining)) && delay=$remaining
        quiet_sleep "$delay"
        if ((SECONDS - started >= max_failure_seconds)); then
            emit_attention "github" "$(error_message)"
            return 1
        fi
        ((backoff < 60)) && backoff=$((backoff * 2 > 60 ? 60 : backoff * 2))
    done

    return 0
}

capture_checkpoint() {
    local current=$1
    local result

    snapshot_with_retry "$current"
    result=$?
    ((result == 0)) || return "$result"

    if is_terminal "$current"; then
        emit_terminal
        return 2
    fi
    if ! write_checkpoint "$current"; then
        emit_attention "checkpoint" "$(error_message)"
        return 1
    fi
}

current="$tmp_root/current.json"

if [[ "$mode" == checkpoint ]]; then
    capture_checkpoint "$current"
    result=$?
    ((result == 2)) && exit 0
    exit "$result"
fi

[[ -f "$checkpoint" && -r "$checkpoint" ]] \
    || usage_error "watch requires an existing readable checkpoint; run checkpoint before the authoritative refresh"

while true; do
    quiet_sleep "$interval"

    snapshot_with_retry "$current"
    result=$?
    ((result == 0)) || exit $((result == 2 ? 0 : 1))

    if is_terminal "$current"; then
        jq -cn '{reason: "terminal"}'
        exit 0
    fi

    if cmp -s "$checkpoint" "$current"; then
        continue
    fi

    jq -cn '{reason: "changed"}'
    exit 0
done
