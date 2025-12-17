# turborepo-migrate

Migrate multiple Git repositories into a [Turborepo](https://turbo.build/repo) monorepo while **preserving all branches, tags, and commit history**.

Perfect for consolidating microservices, multiple apps, or splitting a polyrepo into a high-performance monorepo.

## Features

- **Full history preservation** - all commits, branches, tags intact
- **Run from anywhere** - configure target directory, no need to copy scripts
- **Simple config** - shell variables, no YAML/JSON parsing
- **Idempotent** - safe to run multiple times
- **Branch prefixing** - avoid conflicts with `repo-name/branch-name` convention

## Quick Start

```bash
# 1. Clone this tool
git clone https://github.com/yourorg/turborepo-migrate
cd turborepo-migrate

# 2. Configure
cp config.example.sh config.sh
nano config.sh  # set TARGET_DIR and REPOS

# 3. Run
./migrate.sh run

# 4. Verify
./migrate.sh verify
```

## Requirements

| Dependency | Install |
|------------|---------|
| git-filter-repo | `brew install git-filter-repo` or `pip3 install git-filter-repo` |
| Turborepo | Target dir must have `turbo.json` |

## Configuration

Edit `config.sh`:

```bash
# Where to migrate (must be existing turborepo with turbo.json)
TARGET_DIR="/path/to/your/turborepo"

# Metadata
WORKSPACE_NAME="my-monorepo"
PACKAGE_MANAGER="pnpm"  # npm | yarn | pnpm

# Branch naming: true = "app-name/feature", false = "feature"
USE_BRANCH_PREFIX=true

# Repos to migrate: "name|git-url"
REPOS=(
  "web|git@github.com:myorg/web-app.git"
  "api|git@github.com:myorg/api-server.git"
  "mobile|git@github.com:myorg/mobile-app.git"
)
```

## Commands

```bash
./migrate.sh run      # Execute migration
./migrate.sh verify   # Check migration completeness
```

Override config location:
```bash
CONFIG_FILE=/path/to/config.sh ./migrate.sh run
```

## How It Works

```
1. Clone         git clone --mirror <repo>
2. Rewrite       git filter-repo --to-subdirectory-filter apps/<name>/
3. Merge         git merge --allow-unrelated-histories
4. Branches      Create local branches with optional prefix
```

### Result Structure

```
your-turborepo/
├── apps/
│   ├── web/        # migrated from web-app repo
│   ├── api/        # migrated from api-server repo
│   └── mobile/     # migrated from mobile-app repo
├── packages/
├── turbo.json
└── package.json
```

## After Migration

```bash
cd /path/to/turborepo

# Install deps
pnpm install

# Test build
pnpm build

# Push everything
git push --all origin
git push --tags origin
```

### Update App package.json

Each migrated app may need updates:

```json
{
  "name": "@my-monorepo/web",
  "scripts": {
    "build": "...",
    "dev": "...",
    "lint": "..."
  }
}
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `git-filter-repo not installed` | `brew install git-filter-repo` or `pip3 install git-filter-repo` |
| `TARGET_DIR is not a git repo` | Initialize git in target: `git init` |
| `No turbo.json` | Create turborepo first: `npx create-turbo@latest` |
| `Failed to clone` | Check SSH keys: `ssh -T git@github.com` |

## License

MIT
