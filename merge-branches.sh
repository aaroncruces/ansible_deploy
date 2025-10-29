#!/usr/bin/env bash

# Default values
DEFAULT_REMOTE="origin"
DEFAULT_BRANCHES="nixdev whitetower"

# Parse command line arguments
REMOTE="$DEFAULT_REMOTE"
BRANCHES_STRING="$DEFAULT_BRANCHES"

while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)
      REMOTE="$2"
      shift 2
      ;;
    --branches)
      BRANCHES_STRING="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--remote REMOTE_NAME] [--branches \"branch1 branch2 ...\"]"
      echo "  --remote    : Remote repository name (default: $DEFAULT_REMOTE)"
      echo "  --branches  : Space-separated list of branches to merge (default: $DEFAULT_BRANCHES)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Convert branches string to array
read -ra BRANCHES <<< "$BRANCHES_STRING"

# Function to log messages
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Save the current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ -z "$current_branch" ]; then
  log "Error: Could not determine current branch. Exiting."
  exit 1
fi
log "Current branch is $current_branch"

# Commit any pending changes in current branch before starting merge process
log "Adding and committing any pending changes in current branch"
git add -A
if git diff --cached --quiet; then
  log "No changes to commit in current branch"
else
  git commit -m "merge" || { log "Error: Failed to commit pending changes"; exit 1; }
  log "Pushing current branch to ensure remote is up to date"
  git push -u $REMOTE "$current_branch" || { log "Error: Failed to push $current_branch"; exit 1; }
fi


# Ensure we're in a git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  log "Error: Not in a Git repository. Exiting."
  exit 1
fi

# Fetch latest remote data
log "Fetching latest data from $REMOTE remote"
git fetch $REMOTE || { log "Error: Failed to fetch from $REMOTE"; exit 1; }

# Create and track master if not already present, and pull updates
log "Setting up local master to track $REMOTE/master"
if git show-ref --quiet refs/heads/master; then
  log "Local master already exists, pulling updates"
  git checkout master || { log "Error: Failed to checkout master"; exit 1; }
  git pull $REMOTE master || { log "Error: Failed to pull $REMOTE/master"; exit 1; }
else
  git checkout -b master $REMOTE/master || { log "Error: Failed to track $REMOTE/master"; exit 1; }
fi

# Create, track, and pull each branch locally
for branch in "${BRANCHES[@]}"; do
  log "Setting up local branch $branch to track $REMOTE/$branch"
  if git show-ref --quiet refs/heads/"$branch"; then
    log "Local branch $branch already exists, pulling updates"
    git checkout "$branch" || { log "Error: Failed to checkout $branch"; exit 1; }
    git pull $REMOTE "$branch" || { log "Error: Failed to pull $REMOTE/$branch"; exit 1; }
  else
    git checkout -b "$branch" $REMOTE/"$branch" || { log "Error: Failed to track $REMOTE/$branch"; exit 1; }
  fi
done

# Merge all branches into master
log "Switching to master"
git checkout master || { log "Error: Failed to checkout master"; exit 1; }

for branch in "${BRANCHES[@]}"; do
  log "Merging $branch into master"
  git merge --no-edit "$branch" || { log "Error: Merge conflict or failure for $branch. Please resolve manually."; exit 1; }
done

log "Pushing updated master to $REMOTE/master"
git push $REMOTE master || { log "Error: Failed to push to $REMOTE/master"; exit 1; }

# Merge master back into each branch
for branch in "${BRANCHES[@]}"; do
  log "Switching to $branch"
  git checkout "$branch" || { log "Error: Failed to checkout $branch"; exit 1; }
  
  log "Merging master into $branch"
  git merge --no-edit master || { log "Error: Merge conflict or failure for $branch. Please resolve manually."; exit 1; }
  
  log "Pushing updated $branch to $REMOTE/$branch"
  git push $REMOTE "$branch" || { log "Error: Failed to push to $REMOTE/$branch"; exit 1; }
done

log "All merges and pushes completed successfully"

# Switch back to the original branch
log "Switching back to original branch: $current_branch"
git checkout "$current_branch" || { log "Error: Failed to checkout $current_branch"; exit 1; }