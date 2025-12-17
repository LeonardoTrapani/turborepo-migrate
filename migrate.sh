#!/bin/bash
set -e

# Colors
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

log() { echo -e "${!1}[$1]${NC} $2"; }
die() { log RED "$1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.sh}"

# Load config
load_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config not found: $CONFIG_FILE\nCopy config.example.sh to config.sh"
  source "$CONFIG_FILE"
  [[ -n "$TARGET_DIR" ]] || die "TARGET_DIR not set in config"
  [[ -n "$WORKSPACE_NAME" ]] || die "WORKSPACE_NAME not set in config"
  [[ ${#REPOS[@]} -gt 0 ]] || die "No REPOS defined in config"
}

check_deps() {
  command -v git-filter-repo &>/dev/null || die "git-filter-repo not installed\n  brew install git-filter-repo  OR  pip3 install git-filter-repo"
  [[ -d "$TARGET_DIR/.git" ]] || die "TARGET_DIR is not a git repo: $TARGET_DIR"
  [[ -f "$TARGET_DIR/turbo.json" ]] || die "No turbo.json in TARGET_DIR - not a turborepo"
}

# Get default branch name
default_branch() {
  local remote=$1
  for b in main master develop; do
    git show-ref --verify --quiet "refs/remotes/${remote}/${b}" && echo "$b" && return
  done
  git branch -r --list "${remote}/*" | grep -v HEAD | head -1 | sed "s|.*${remote}/||"
}

run_migrate() {
  load_config
  check_deps
  
  TEMP_DIR=$(mktemp -d)
  trap "rm -rf $TEMP_DIR" EXIT
  
  log BLUE "Migrating ${#REPOS[@]} repos to $TARGET_DIR"
  
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<< "$entry"
    log BLUE "Processing $name..."
    
    # Clone mirror
    git clone --mirror "$url" "$TEMP_DIR/${name}-bare.git" 2>&1 | grep -v "warning:" || true
    git clone "$TEMP_DIR/${name}-bare.git" "$TEMP_DIR/$name"
    
    # Fetch all branches
    (cd "$TEMP_DIR/$name" && git fetch origin "+refs/heads/*:refs/heads/*" --tags 2>&1 | head -3 || true)
    
    # Rewrite to apps/name/
    (cd "$TEMP_DIR/$name" && git filter-repo --to-subdirectory-filter "apps/${name}/" --force 2>&1 | grep -E "Parsed|finished" || true)
    
    log GREEN "Rewritten $name -> apps/$name/"
  done
  
  # Merge into target
  cd "$TARGET_DIR"
  
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<< "$entry"
    remote="${name}-temp"
    
    git remote remove "$remote" 2>/dev/null || true
    git remote add "$remote" "$TEMP_DIR/$name"
    git fetch "$remote" "+refs/heads/*:refs/remotes/${remote}/*" --tags
    
    # Merge default branch
    def_branch=$(default_branch "$remote")
    if [[ -n "$def_branch" ]]; then
      log BLUE "Merging $name/$def_branch..."
      git merge "${remote}/${def_branch}" --allow-unrelated-histories -m "Integrate $name" 2>&1 | grep -E "Merge|Already" || true
    fi
    
    # Create prefixed branches
    local count=0
    while IFS= read -r rb; do
      [[ -z "$rb" ]] && continue
      branch=$(echo "$rb" | sed "s|.*${remote}/||")
      [[ "$branch" == "$def_branch" ]] && continue
      
      if [[ "$USE_BRANCH_PREFIX" == true ]]; then
        local_branch="${name}/${branch}"
      else
        local_branch="$branch"
      fi
      
      git show-ref --verify --quiet "refs/heads/${local_branch}" || {
        git branch "$local_branch" "$rb" 2>/dev/null && ((count++))
      }
    done < <(git branch -r --list "${remote}/*" | grep -v HEAD)
    
    log GREEN "$name: created $count branches"
    git remote remove "$remote"
  done
  
  log GREEN "Migration complete!"
}

run_verify() {
  load_config
  [[ -d "$TARGET_DIR/.git" ]] || die "TARGET_DIR not a git repo"
  
  cd "$TARGET_DIR"
  log BLUE "Verifying migration..."
  
  for entry in "${REPOS[@]}"; do
    IFS='|' read -r name url <<< "$entry"
    
    # Check directory
    if [[ -d "apps/$name" ]]; then
      log GREEN "$name: apps/$name/ exists"
    else
      log RED "$name: apps/$name/ MISSING"
    fi
    
    # Count branches - check if default branch was merged (look for integration commit)
    merged_default=0
    git log --oneline --grep="Integrate $name" -1 &>/dev/null && merged_default=1
    
    if [[ "$USE_BRANCH_PREFIX" == true ]]; then
      prefixed_count=$(git branch 2>/dev/null | grep -c "^ *${name}/" || true)
      local_count=$((prefixed_count + merged_default))
    else
      local_count=$(git branch 2>/dev/null | wc -l)
    fi
    remote_count=$(git ls-remote --heads "$url" 2>/dev/null | wc -l)
    local_count=$(echo "$local_count" | tr -d '[:space:]')
    remote_count=$(echo "$remote_count" | tr -d '[:space:]')
    : "${local_count:=0}" "${remote_count:=0}"
    
    if [[ "$local_count" -ge "$remote_count" ]]; then
      log GREEN "$name: $local_count/$remote_count branches (default merged)"
    else
      log YELLOW "$name: $local_count/$remote_count branches (missing $((remote_count - local_count)))"
    fi
  done
}

usage() {
  cat <<EOF
Usage: $0 [command]

Commands:
  run      Run the migration
  verify   Verify migration completeness

Config: Set CONFIG_FILE env or place config.sh next to script
EOF
}

case "${1:-}" in
  run) run_migrate ;;
  verify) run_verify ;;
  *) usage ;;
esac
