# Contributing to evald.ai

## Code Style
- Follow Rails conventions
- Run `bundle exec rubocop` before committing
- Keep methods under 20 lines

## Pull Requests
1. Create a feature branch
2. Write tests for new features
3. Ensure CI passes
4. Request review

## Running Checks Locally

Before pushing, run these checks to match what CI runs:

```bash
# Lint (RuboCop)
bin/rubocop

# Security scans
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit

# Tests (requires PostgreSQL running)
bin/rails db:prepare
bin/rails tailwindcss:build
bin/rails test
```

## CI/CD

### Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **CI** | `ci.yml` | Push to `main`, all PRs | Runs linting, security scans, and tests |
| **Deploy** | `deploy.yml` | After CI passes on `main` | Deploys to production via Dokku |
| **Rollback** | `rollback.yml` | Manual dispatch | Deploys a specific commit SHA to production |

### CI Jobs

- **scan_ruby** — Runs Brakeman (static analysis) and bundler-audit (gem vulnerabilities)
- **scan_js** — Runs importmap audit for JavaScript dependency vulnerabilities
- **lint** — Runs RuboCop with the project's style configuration
- **test** — Runs the full Minitest suite against PostgreSQL

### How Deploys Work

- Deploys are triggered automatically after the CI workflow passes on `main` (via `workflow_run`).
- This ensures code that hasn't passed all checks can never be deployed.
- Only one deploy runs at a time (concurrency group: `deploy-production`). A newer push cancels any in-progress deploy.
- Each deploy logs a summary with the commit SHA, environment, and timestamp.

### Rollback

If a bad deploy lands, use the **Rollback Deploy** workflow:

1. Go to **Actions** → **Rollback Deploy** → **Run workflow**
2. Enter the commit SHA you want to roll back to
3. The workflow will force-push that commit to the Dokku remote

### Branch Protection (Recommended)

For `main`, configure these branch protection rules:

- Require status checks to pass before merging (CI workflow)
- Require at least one approval
- Do not allow force pushes
- Require linear history (squash or rebase merges)
