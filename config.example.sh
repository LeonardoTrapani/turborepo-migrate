# Turborepo Migration Config
# Copy to config.sh and edit

# Target turborepo directory (can run script from anywhere)
TARGET_DIR="/path/to/your/turborepo"

# Workspace settings
WORKSPACE_NAME="my-monorepo"
PACKAGE_MANAGER="pnpm"  # npm, yarn, pnpm
USE_BRANCH_PREFIX=true  # branches: repo-name/branch-name

# Repositories: "name|url" (one per line)
REPOS=(
  "app1|git@github.com:yourorg/app1.git"
  "app2|git@github.com:yourorg/app2.git"
  "api|git@github.com:yourorg/api-server.git"
)
