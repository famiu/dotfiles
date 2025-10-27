#!/usr/bin/env bash

set -euo pipefail

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

stow --dotfiles -t "$HOME" $ACTION .
