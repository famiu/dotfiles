#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$repo_root"

show_help() {
    cat <<EOF
Usage:
  $0 [options]

Options:
  -D, --delete     Unstow (remove) the dotfiles
  -R, --restow     Restow (update symlinks)
  -h, --help       Show this help message

Examples:
  $0           Deploy dotfiles
  $0 -R        Redeploy dotfiles
  $0 -D        Delete deployed dotfiles
EOF
}

ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -D|--delete)
            ACTION="-D"
            shift
            ;;
        -R|--restow)
            ACTION="-R"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Try './deploy.sh --help' for usage."
            exit 1
            ;;
    esac
done

# Read from .gitmodules, not the index, so submodules missing a gitlink are still found.
mapfile -t declared_submodules < <(
    git config -f .gitmodules --get-regexp '\.path$' | awk '{print $2}'
)

declare -A is_registered=()
while IFS= read -r sm; do
    is_registered["$sm"]=1
done < <(git submodule status | awk '{print $2}')

dirty_submodules=()
clean_submodules=()
unregistered_submodules=()
for sm in "${declared_submodules[@]}"; do
    if [[ -z "${is_registered[$sm]:-}" ]]; then
        # No gitlink means no pinned commit to check out. Updating would clone whatever's on the remote's default
        # branch right now, unpinned. Skip it.
        unregistered_submodules+=("$sm")
        continue
    fi

    if [[ -n "$(git -C "$sm" status --porcelain --ignore-submodules=none 2>/dev/null)" ]]; then
        dirty_submodules+=("$sm")
    else
        clean_submodules+=("$sm")
    fi
done

if (( ${#unregistered_submodules[@]} > 0 )); then
    echo "Skipping unregistered submodules (no gitlink, run 'git submodule add' to pin one):"
    printf '  %s\n' "${unregistered_submodules[@]}"
fi

if (( ${#dirty_submodules[@]} > 0 )); then
    echo "Skipping dirty submodules:"
    printf '  %s\n' "${dirty_submodules[@]}"
fi

if (( ${#clean_submodules[@]} > 0 )); then
    git submodule update --init --recursive -- "${clean_submodules[@]}"
fi

stow --dotfiles -t "$HOME" $ACTION .
