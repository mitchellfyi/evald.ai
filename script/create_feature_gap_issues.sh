#!/usr/bin/env bash
#
# Creates GitHub issues for identified feature gaps in evald.ai
#
# Usage:
#   GITHUB_TOKEN=ghp_... ./script/create_feature_gap_issues.sh
#   # or
#   gh auth login && ./script/create_feature_gap_issues.sh
#
# Prerequisites: gh CLI installed and authenticated

set -euo pipefail

REPO="mitchellfyi/evald.ai"
CREATED=0
FAILED=0

create_issue() {
  local title="$1"
  local body="$2"
  local labels="$3"

  echo "Creating: $title"
  if gh issue create --repo "$REPO" --title "$title" --body "$body" --label "$labels" 2>/dev/null; then
    CREATED=$((CREATED + 1))
    echo "  ✓ Created"
  else
    # Try without labels if label creation fails
    if gh issue create --repo "$REPO" --title "$title" --body "$body" 2>/dev/null; then
      CREATED=$((CREATED + 1))
      echo "  ✓ Created (without labels)"
    else
      FAILED=$((FAILED + 1))
      echo "  ✗ Failed"
    fi
  fi
  # Rate limit courtesy
  sleep 1
}

echo "=== evald.ai Feature Gap Issues ==="
echo "Repository: $REPO"
echo ""

# Ensure labels exist
echo "Setting up labels..."
for label in "enhancement" "tier0" "tier1" "scoring" "platform" "devex" "ui" "api"; do
  gh label create "$label" --repo "$REPO" --force 2>/dev/null || true
done
echo ""

# --- Issue 1: License Clarity Analyzer ---
create_issue \
  "Implement Tier 0 License Clarity Analyzer" \
  "$(cat <<'EOF'
## Problem

The README and schema define "License clarity" as one of the 7 Tier 0 passive signals, and the `agent_scores` table has a `tier0_license` column. The `Agent` model includes license in `TIER0_WEIGHTS` (weight: 0.10). However, **no `LicenseClarityAnalyzer` service exists** to compute this score.

The `Tier0::ScoringEngine` only loads 5 analyzers (repo_health, bus_factor, dependency_risk, documentation, community_signal) — license is missing.

## Expected Behavior

A `Tier0::LicenseClarityAnalyzer` service should:
- Check for the presence of a LICENSE file in the repo via GitHub API
- Identify the license type (MIT, Apache-2.0, GPL, etc.)
- Verify the license is OSI-approved
- Check for license ambiguity (multiple licenses, unclear terms, no SPDX identifier)
- Score clarity and permissiveness on a 0–100 scale
- Store result in `tier0_license` on `agent_scores`

## Acceptance Criteria

- [ ] Create `app/services/tier0/license_clarity_analyzer.rb`
- [ ] Integrate into `Tier0::ScoringEngine` alongside existing analyzers
- [ ] Add tests in `test/services/tier0/license_clarity_analyzer_test.rb`
- [ ] Score is computed and stored during Tier 0 evaluations
- [ ] Handle edge cases: no license, dual license, custom license

## Context

This is one of two missing Tier 0 analyzers (the other is Maintenance Pulse). Without it, 10% of the Tier 0 signal weight is not being calculated, making composite scores incomplete.
EOF
)" \
  "enhancement,tier0,scoring"

# --- Issue 2: Maintenance Pulse Analyzer ---
create_issue \
  "Implement Tier 0 Maintenance Pulse Analyzer" \
  "$(cat <<'EOF'
## Problem

The README lists "Maintenance pulse" as a Tier 0 signal measuring "Days since last commit, release cadence, issue response time." The `agent_scores` table has a `tier0_maintenance` column and the `Agent` model includes it in `TIER0_WEIGHTS` (weight: 0.10). However, **no `MaintenancePulseAnalyzer` service exists**.

## Expected Behavior

A `Tier0::MaintenancePulseAnalyzer` service should:
- Measure days since last commit (more recent = higher score)
- Calculate release cadence (regular releases score higher)
- Measure average issue response time
- Measure average PR review time
- Compute a composite maintenance health score (0–100)
- Store result in `tier0_maintenance` on `agent_scores`

## Scoring Guidance

- Last commit < 7 days: high score
- Last commit 7–30 days: moderate score
- Last commit > 90 days: low score
- Regular release cadence (monthly or better): bonus
- Fast issue response (< 48h median): bonus

## Acceptance Criteria

- [ ] Create `app/services/tier0/maintenance_pulse_analyzer.rb`
- [ ] Integrate into `Tier0::ScoringEngine`
- [ ] Add tests in `test/services/tier0/maintenance_pulse_analyzer_test.rb`
- [ ] Use existing `GithubClient` methods for data retrieval
- [ ] Handle repos with no releases gracefully

## Context

This is one of two missing Tier 0 analyzers (the other is License Clarity). Without it, 10% of the Tier 0 signal weight is not being calculated.
EOF
)" \
  "enhancement,tier0,scoring"

# --- Issue 3: Co-occurrence / Frequently Deployed With ---
create_issue \
  "Implement 'Frequently Deployed With' co-occurrence feature" \
  "$(cat <<'EOF'
## Problem

The README states that agent profiles should show "Frequently deployed with based on co-occurrence data." The `AgentInteraction` model exists with scopes for tracking interactions between agents, but this data is **never surfaced in the UI** or used to compute co-occurrence recommendations.

## Expected Behavior

1. **Co-occurrence Analysis Service**: Analyze `agent_interactions` and `telemetry_events` to identify which agents are frequently used together
2. **Agent Profile Display**: Show a "Frequently Deployed With" section on agent profile pages listing the top 5 co-occurring agents
3. **API Endpoint**: Expose co-occurrence data via the API (`GET /api/v1/agents/:id/related`)

## Acceptance Criteria

- [ ] Create `app/services/co_occurrence_analyzer.rb` to compute agent relationships
- [ ] Add "Frequently Deployed With" section to `app/views/agents/show.html.erb`
- [ ] Add API endpoint for related agents
- [ ] Add background job to periodically recalculate co-occurrence data
- [ ] Add tests for the analyzer and API endpoint

## Data Sources

- `agent_interactions` table (reporter_agent_id ↔ target_agent_id relationships)
- `telemetry_events` (agents reporting interactions with other agents)
- API comparison requests (agents frequently compared together)
EOF
)" \
  "enhancement,platform"

# --- Issue 4: Telemetry Client SDK ---
create_issue \
  "Create Telemetry Client SDK for Tier 3 integration" \
  "$(cat <<'EOF'
## Problem

The README describes "Tier 3 — production telemetry integration (opt-in SDK for real-world performance data)." The API endpoint `POST /api/v1/telemetry` exists and the telemetry aggregation pipeline works, but **no client SDK exists** for agent builders to easily integrate telemetry reporting.

Currently, builders would need to manually construct HTTP requests to report telemetry, which creates a high barrier to adoption.

## Expected Behavior

Provide lightweight client SDKs (at minimum JavaScript/TypeScript) that agent builders can install to automatically report telemetry:

```javascript
// npm install @evald/telemetry
import { EvaldTelemetry } from '@evald/telemetry';

const telemetry = new EvaldTelemetry({
  apiKey: 'evald_...',
  agentId: 'my-agent'
});

// Wrap agent operations
const result = await telemetry.track('task_completion', async () => {
  return await myAgent.execute(task);
});
```

## Acceptance Criteria

- [ ] Create `sdk/` directory with JavaScript/TypeScript telemetry SDK
- [ ] SDK auto-reports: duration, success/failure, token usage, error types
- [ ] SDK supports batching and retry logic
- [ ] Publish as `@evald/telemetry` npm package (or `evald-telemetry`)
- [ ] Add documentation with integration examples
- [ ] Consider Python SDK as a follow-up

## API Contract

The SDK should POST to `/api/v1/telemetry` with:
```json
{
  "agent_id": "string",
  "event_type": "task_completion|error|interaction",
  "duration_ms": 1234,
  "success": true,
  "metadata": {}
}
```
EOF
)" \
  "enhancement,devex"

# --- Issue 5: CI/CD GitHub Action ---
create_issue \
  "Create reusable GitHub Action for deploy gate integration" \
  "$(cat <<'EOF'
## Problem

The README promises "CI/CD integration (block deploys below score threshold)" and the deploy gate API exists at `POST /api/v1/deploy_gates/check`. However, there is **no reusable GitHub Action** for easy CI/CD integration. Users must manually write workflow YAML to call the API.

A template exists in `docs/github-action.yml` but it's not a proper reusable GitHub Action that can be referenced as `uses: mitchellfyi/evald-action@v1`.

## Expected Behavior

A reusable GitHub Action that can be used in any workflow:

```yaml
- uses: mitchellfyi/evald-action@v1
  with:
    agent-id: my-agent
    minimum-score: 80
    api-key: ${{ secrets.EVALD_API_KEY }}
    fail-on-below: true
```

## Acceptance Criteria

- [ ] Create `.github/actions/evald-gate/action.yml` or separate `evald-action` repo
- [ ] Action calls `POST /api/v1/deploy_gates/check` and interprets the result
- [ ] Supports configurable minimum score threshold
- [ ] Outputs score details as step outputs for downstream use
- [ ] Provides clear pass/fail messaging in workflow logs
- [ ] Add badge generation output (optional)
- [ ] Add documentation in `docs/ci-cd-integration.md`

## Stretch Goals

- GitLab CI template
- Bitbucket Pipelines integration
- Generic CLI tool (`npx evald-gate --agent=my-agent --min-score=80`)
EOF
)" \
  "enhancement,devex"

# --- Issue 6: Score Trend Visualization ---
create_issue \
  "Add score trend charts to agent profile pages" \
  "$(cat <<'EOF'
## Problem

The README promises "Version history with score trends over time" on agent profiles. Score history data IS stored (multiple `agent_scores` records per agent), but the UI only shows a **flat list** of past evaluations. There are no charts or visual trend indicators.

For a platform positioning itself as "Moody's for AI agents," visual score trends are essential for communicating trust trajectory at a glance.

## Expected Behavior

Agent profile pages should display:
1. **Score trend line chart** showing composite score over time
2. **Tier breakdown area chart** showing how Tier 0/1/2 scores change over time
3. **Trend indicators** (↑ improving, → stable, ↓ declining) next to the current score
4. **Score decay visualization** showing projected decay if not re-evaluated

## Acceptance Criteria

- [ ] Add a line chart showing score history on `app/views/agents/show.html.erb`
- [ ] Use a lightweight charting library (Chart.js, or Turbo-compatible solution)
- [ ] Show at minimum: date, composite score, tier breakdown per evaluation
- [ ] Add trend indicator badge next to the current score
- [ ] Ensure charts are responsive and work on mobile
- [ ] Add tests for the chart data endpoint

## Technical Notes

- Data source: `AgentScore` records ordered by `evaluated_at`
- The profile controller already loads `@version_history` — just needs visualization
- Consider a JSON API endpoint for chart data to keep views clean
EOF
)" \
  "enhancement,ui"

# --- Issue 7: Webhook Management UI for Builders ---
create_issue \
  "Add webhook management UI for agent builders" \
  "$(cat <<'EOF'
## Problem

The webhook system is fully implemented at the backend level (`WebhookEndpoint`, `WebhookDelivery`, `WebhookService`, delivery/retry jobs). However, **agent builders have no UI to manage webhooks**. The builder dashboard only allows editing agent descriptions and links — not webhook subscriptions.

Builders who have claimed their agent should be able to set up webhooks to receive notifications when their agent's score changes.

## Expected Behavior

The builder dashboard should include a webhook management section where claimed agent owners can:
1. Create webhook endpoints (URL, events to subscribe to, secret for HMAC)
2. View delivery history and status
3. Test webhook delivery
4. Enable/disable webhook endpoints
5. Delete webhook endpoints

## Acceptance Criteria

- [ ] Add `builder/webhooks_controller.rb` with CRUD actions
- [ ] Add views for webhook management under builder namespace
- [ ] Allow builders to select which events to subscribe to (score.created, score.updated, safety_score.created, safety_score.updated)
- [ ] Show recent delivery attempts with status (success/failure/pending)
- [ ] Add "Send test" button to verify webhook URL
- [ ] Add routes under `/builder/agents/:id/webhooks`
- [ ] Add tests for the controller and views

## Subscribable Events

From the existing `WebhookEndpoint` model:
- `score.created`
- `score.updated`
- `safety_score.created`
- `safety_score.updated`
EOF
)" \
  "enhancement,platform"

# --- Issue 8: User Agent Submission ---
create_issue \
  "Allow users to submit agents for evaluation" \
  "$(cat <<'EOF'
## Problem

Currently, new agents can only enter the system through:
1. The automated GitHub scraper discovering repos
2. Admin manually creating agents

There is **no way for regular users to suggest or submit agents** for evaluation. This limits the platform's growth and means valuable agents might be missed if they don't match the scraper's search terms.

## Expected Behavior

Users (both authenticated and unauthenticated) should be able to submit an agent for evaluation:

1. **Submission Form**: A public page where users enter the agent's GitHub repo URL and a brief description
2. **Validation**: Check that the repo exists and appears to be an AI agent
3. **Deduplication**: Check against existing agents and pending agents
4. **Review Queue**: Submission enters the `pending_agents` review queue for admin approval
5. **Notification**: User gets notified when their submission is reviewed

## Acceptance Criteria

- [ ] Add `GET /agents/submit` route and view with submission form
- [ ] Add `POST /agents/submit` to create a `PendingAgent` record
- [ ] Validate GitHub URL and check repo exists
- [ ] Deduplicate against existing `agents` and `pending_agents`
- [ ] Optionally trigger `AiAgentReviewJob` for automated classification
- [ ] Add rate limiting (max 5 submissions per user per day)
- [ ] Show submission status page for authenticated users
- [ ] Add email notification when submission is reviewed

## Routes

```ruby
get 'agents/submit', to: 'agents/submissions#new'
post 'agents/submit', to: 'agents/submissions#create'
get 'agents/submissions', to: 'agents/submissions#index'  # user's submissions
```
EOF
)" \
  "enhancement,platform"

# --- Issue 9: Public API Documentation Page ---
create_issue \
  "Add interactive API documentation page" \
  "$(cat <<'EOF'
## Problem

API documentation currently exists only as a markdown file (`docs/API.md`). There is **no web-accessible API documentation page** at a route like `/docs/api`. For a platform that wants developers to integrate via API, MCP, and CI/CD, discoverable and interactive API docs are essential.

## Expected Behavior

1. **Web-accessible docs**: A `/docs/api` page with endpoint documentation
2. **Try it out**: Interactive API explorer where users can test endpoints with their API key
3. **Code examples**: Show `curl`, JavaScript, Python, and Ruby examples for each endpoint
4. **OpenAPI spec**: Machine-readable API specification at `/api/v1/openapi.json`

## Acceptance Criteria

- [ ] Add route `GET /docs/api` with rendered API documentation
- [ ] Generate OpenAPI 3.0 spec from existing endpoints (consider `rswag` or manual spec)
- [ ] Include authentication instructions (API key via Bearer token)
- [ ] Document all API v1 endpoints with request/response examples
- [ ] Add to main navigation
- [ ] Consider embedding Swagger UI or Redoc for interactive exploration

## Endpoints to Document

- `GET /api/v1/agents` — List agents
- `GET /api/v1/agents/:id` — Agent detail
- `GET /api/v1/agents/:id/score` — Score breakdown
- `GET /api/v1/compare` — Compare agents
- `GET /api/v1/search` — Search agents
- `POST /api/v1/telemetry` — Submit telemetry
- `POST /api/v1/deploy_gates/check` — CI/CD deploy gate
- `POST /api/v1/claims` — Claim agent
- `POST /api/v1/mcp` — MCP JSON-RPC endpoint
EOF
)" \
  "enhancement,api"

# --- Issue 10: Schedule Tier 0 Evaluations ---
create_issue \
  "Schedule recurring Tier 0 evaluations for all agents" \
  "$(cat <<'EOF'
## Problem

The README states "Tier 0 runs continuously. Every agent with a public repo gets a Tier 0 profile automatically." However, Tier 0 evaluations are **not scheduled** in `config/recurring.yml`. The only scheduled jobs are:

- `github_scraper` (daily at 3am)
- `sandbox_cleanup` (hourly)
- `clear_solid_queue_finished_jobs` (hourly)

Tier 0 evaluations must be manually triggered via the admin panel. This means agent scores become stale and decay-only, contradicting the "continuous evaluation" promise.

## Expected Behavior

Tier 0 evaluations should run automatically on a regular schedule:
- **Daily**: Re-evaluate agents with the oldest `last_evaluated_at` timestamps
- **Batch processing**: Process agents in batches to avoid rate limits
- **Prioritization**: Evaluate higher-traffic agents more frequently
- **Decay-triggered**: Re-evaluate agents whose scores have decayed below a threshold

## Acceptance Criteria

- [ ] Add `Tier0RefreshJob` to `config/recurring.yml` (e.g., daily at 4am)
- [ ] Job should batch-process agents, starting with most stale
- [ ] Respect GitHub API rate limits (batch size based on remaining rate limit)
- [ ] Add `Tier1EvaluationJob` scheduling for agents needing re-evaluation
- [ ] Add monitoring/alerting if evaluations fail repeatedly
- [ ] Log evaluation outcomes for admin visibility

## Configuration

```yaml
# config/recurring.yml
tier0_refresh:
  class: Tier0RefreshJob
  schedule: every day at 4am
  args: []

tier1_scheduled:
  class: Tier1ScheduledEvaluationJob
  schedule: every week on monday at 2am
  args: []
```
EOF
)" \
  "enhancement,scoring"

# --- Issue 11: Agent Tagging System ---
create_issue \
  "Add flexible tagging system for agents" \
  "$(cat <<'EOF'
## Problem

Agents only have a basic `category` field with 5 options: coding, research, workflow, assistant, general. This is insufficient for discoverability. Users can't filter by more specific attributes like "code review", "documentation", "testing", "data analysis", "customer support", etc.

A tagging system would significantly improve agent discovery and comparison workflows.

## Expected Behavior

1. **Admin-managed tags**: Admins can create and manage a taxonomy of tags
2. **Agent tagging**: Each agent can have multiple tags (e.g., "code-review", "python", "security")
3. **Filtering**: Users can filter the agent listing by tags
4. **Search integration**: Tags are included in search results
5. **API support**: Tags exposed in API responses and searchable via API

## Acceptance Criteria

- [ ] Create `Tag` model with name and slug
- [ ] Create `agent_tags` join table (polymorphic tagging or simple join)
- [ ] Add tag management to admin panel
- [ ] Allow admin to tag agents during review/editing
- [ ] Add tag filtering to agent listing page
- [ ] Include tags in API agent responses
- [ ] Support `GET /api/v1/search?tags=code-review,python`
- [ ] Add tag badges to agent cards in the listing

## Tag Categories (Suggested)

- **Domain**: coding, research, workflow, data, security, devops
- **Capability**: code-review, testing, documentation, debugging, refactoring
- **Language/Stack**: python, javascript, rust, go
- **Integration**: mcp, a2a, langchain, autogen
EOF
)" \
  "enhancement,platform"

# --- Issue 12: Comparison Sharing ---
create_issue \
  "Add shareable permalinks for agent comparisons" \
  "$(cat <<'EOF'
## Problem

Users can compare agents via `/compare?agents=slug1,slug2`, but there is **no sharing mechanism**. The comparison view doesn't offer:
- A "Copy link" button
- Social sharing (Twitter/LinkedIn)
- Embeddable comparison widgets
- Short URLs for comparisons

For a platform designed to help people make trust decisions about agents, sharing comparisons is a core workflow.

## Expected Behavior

1. **Copy link button**: One-click copy of the comparison URL
2. **Stable URLs**: Comparison URLs that work reliably (current query param approach is fine)
3. **Social sharing**: Open Graph meta tags so comparison links preview well on social media
4. **Comparison badges**: Embeddable comparison images/badges for documentation

## Acceptance Criteria

- [ ] Add "Share comparison" button with copy-to-clipboard on comparison page
- [ ] Add Open Graph meta tags (og:title, og:description, og:image) for comparison URLs
- [ ] Generate comparison preview image (or use dynamic OG image service)
- [ ] Add social share buttons (Twitter, LinkedIn)
- [ ] Consider short URL generation for frequently shared comparisons
EOF
)" \
  "enhancement,ui"

echo ""
echo "=== Summary ==="
echo "Created: $CREATED issues"
echo "Failed:  $FAILED issues"
echo ""
echo "View issues: https://github.com/$REPO/issues"
