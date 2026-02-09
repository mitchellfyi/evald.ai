# Self-Healing CI

The self-healing CI workflow (`.github/workflows/self-healing-ci.yml`) automatically creates GitHub issues when the main CI workflow fails on `main`, assigning them to Copilot's coding agent for autonomous fixes.

## How It Works

1. **Trigger**: The workflow listens for the `CI` workflow to complete via `workflow_run`. It only acts on `failure` conclusions for the `main` branch.
2. **Log collection**: Failed job logs are pulled from the GitHub API and truncated to the last 200 lines per job.
3. **Duplicate detection**: Before creating a new issue, it checks for an existing open issue labeled `ci-fix` + `automated`. If one exists, it adds a comment with the new failure logs instead.
4. **Issue creation**: A well-structured issue is created with failure logs and clear instructions, then assigned to `copilot`.
5. **Escalation**: After 3 workflow-generated comments on the same issue, a `needs-human` label is added and the workflow stops adding more comments.

## Labels

| Label | Color | Description |
|-------|-------|-------------|
| `ci-fix` | `#d73a4a` | Automated CI failure fix request |
| `automated` | `#0e8a16` | Created by automation |
| `needs-human` | — | Added after 3 failed retry attempts |

Labels are created automatically if they don't exist.

## Safety Mechanisms

- **Main branch only**: Feature branch failures are ignored — those are the developer's responsibility.
- **No duplicates**: Only one open `ci-fix` issue at a time.
- **Retry limit**: After 3 comments from the workflow, human intervention is required.
- **No self-healing loops**: The workflow only triggers on the `CI` workflow, not on itself.
- **Cancelled runs are ignored**: Only `failure` conclusions trigger the workflow.

## Required Permissions

```yaml
permissions:
  issues: write
  actions: read
  checks: read
```

## Auto-Merge for Copilot Fix PRs

Auto-merge of Copilot's fix PRs is **not implemented** in this initial version. Here are the options and tradeoffs:

### Option 1: GitHub App for auto-approval (Recommended)
- Create a dedicated GitHub App with PR review permissions.
- A second workflow triggers on PRs from `copilot/**` branches, waits for CI to pass, then uses the App to approve and enable auto-merge.
- **Pro**: Clean separation of concerns, fine-grained permissions.
- **Con**: Requires creating and maintaining a GitHub App.

### Option 2: Bot account with reviewer permissions
- Use a separate bot account that can approve PRs.
- **Pro**: Simpler setup than a GitHub App.
- **Con**: Requires managing a separate account and its access tokens.

### Option 3: Manual review (Current approach)
- Copilot opens a draft PR. A human reviews and merges.
- **Pro**: No additional setup; human stays in the loop for all code changes.
- **Con**: Slower resolution; defeats part of the "self-healing" goal.

**Current choice**: Option 3 (manual review). This keeps humans in the loop while still getting the benefit of Copilot automatically diagnosing and proposing fixes. Auto-merge can be added later once trust in the system is established.
