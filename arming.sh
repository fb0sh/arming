#!/bin/sh

set -u

max_jobs=1

if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    cyan="$(tput setaf 6)"; green="$(tput setaf 2)"; yellow="$(tput setaf 3)"; red="$(tput setaf 1)"; reset="$(tput sgr0)"
else
    cyan=""; green=""; yellow=""; red=""; reset=""
fi

log_info() { printf "%s[INFO]%s %s\n" "$cyan" "$reset" "$*" 1>&2; }
log_warn() { printf "%s[WARN]%s %s\n" "$yellow" "$reset" "$*" 1>&2; }
log_error() { printf "%s[ERROR]%s %s\n" "$red" "$reset" "$*" 1>&2; }

usage() {
    cat <<'EOF'
Usage:
  arming.sh <target_dir>              # Update mode (git pull)
  arming.sh <target_dir> > git.list   # Export mode (write remotes)
  arming.sh <target_dir> < git.list   # Clone mode (read remotes)

Modes are auto-detected by pipes:
  - stdin is piped  -> clone
  - stdout is piped -> export
  - otherwise       -> update
EOF
    exit 1
}

ensure_git() {
    if ! command -v git >/dev/null 2>&1; then
        log_error "git is required but not found."
        exit 1
    fi
}

ensure_dir() {
    if [ ! -d "$1" ]; then
        if ! mkdir -p "$1"; then
            log_error "cannot create directory: $1"
            exit 1
        fi
    fi
}

derive_name() {
    url=$1
    trimmed=${url%.git}
    repo=${trimmed##*/}
    parent=${trimmed%/*}
    case $parent in
        *://*) user=${parent##*/} ;;
        *:*) user=${parent##*:} ;;
        *) user=$parent ;;
    esac
    [ -n "$repo" ] || repo="repo"
    [ -n "$user" ] || user="user"
    printf "%s_%s" "$repo" "$user"
}

export_mode() {
    dir=$1
    count=0
    for repo_dir in "$dir"/*; do
        [ -d "$repo_dir/.git" ] || continue
        remote=$(git -C "$repo_dir" config --get remote.origin.url 2>/dev/null || true)
        [ -n "$remote" ] || continue
        name=$(derive_name "$remote")
        printf "%s %s\n" "$remote" "$name"
        count=$((count + 1))
    done
    if [ $count -eq 0 ]; then
        log_warn "no git repositories found in $dir"
    else
        log_info "exported $count remotes"
    fi
}

clone_mode() {
    dir=$1
    ensure_dir "$dir"
    ok=0
    skip=0
    fail=0
    total=0
    tmp=$(mktemp "${TMPDIR:-/tmp}/arming.XXXXXX") || exit 1
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] || continue
        printf "%s\n" "$line" >> "$tmp"
        total=$((total + 1))
    done
    while IFS= read -r line || [ -n "$line" ]; do
        set -- $line
        [ $# -ge 1 ] || continue
        remote=$1
        shift
        if [ $# -ge 1 ]; then
            name=$1
        else
            name=$(derive_name "$remote")
        fi
        idx=$((ok + skip + fail + 1))
        prefix="[$idx/$total]"
        if [ -d "$dir/$name/.git" ]; then
            log_info "$prefix [SKIP] $name (exists)"
            skip=$((skip + 1))
            continue
        fi
        if (cd "$dir" && git clone --depth 1 "$remote" "$name"); then
            log_info "$prefix [OK]   $name"
            ok=$((ok + 1))
        else
            log_warn "$prefix [FAIL] $name"
            fail=$((fail + 1))
        fi
    done < "$tmp"
    rm -f "$tmp"
    total=$((ok + skip + fail))
    log_info "clone finished: ok $ok (skipped $skip), failed $fail (total $total)"
}

update_mode() {
    dir=$1
    ok=0
    fail=0
    found=0
    for repo_dir in "$dir"/*; do
        [ -d "$repo_dir/.git" ] || continue
        found=1
        name=$(basename "$repo_dir")
        if (cd "$repo_dir" && git pull --ff-only); then
            log_info "[OK]   $name"
            ok=$((ok + 1))
        else
            log_warn "[FAIL] $name"
            fail=$((fail + 1))
        fi
    done
    if [ $found -eq 0 ]; then
        log_warn "no git repositories found in $dir"
        return
    fi
    total=$((ok + fail))
    log_info "update finished: ok $ok, failed $fail (total $total)"
}

main() {
    [ "$#" -eq 1 ] || usage
    target_dir=$1
    ensure_git

    if [ ! -t 0 ]; then
        log_info "mode: clone to $target_dir"
        clone_mode "$target_dir"
    elif [ ! -t 1 ]; then
        log_info "mode: export from $target_dir"
        export_mode "$target_dir"
    else
        log_info "mode: update in $target_dir"
        update_mode "$target_dir"
    fi
}

main "$@"
