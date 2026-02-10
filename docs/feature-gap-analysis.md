# Feature Gap Analysis — evald.ai

**Date:** 2026-02-09
**Scope:** Mission vs. current implementation

## Mission

Evald is an independent evaluation authority for AI agents — "the trust score for AI agents." It continuously evaluates open-source and commercial AI agents across 5 tiers (Tier 0–4) and exposes scores via web UI, API, MCP server, and CI/CD integrations.

## Summary

The core architecture is well-built with 23 models, 28 controllers, 40+ services, and 15 background jobs. However, **12 feature gaps** exist between what the README/mission promises and what is actually implemented.

| # | Gap | Severity | Category |
|---|-----|----------|----------|
| 1 | License Clarity Analyzer missing | **High** | Tier 0 scoring |
| 2 | Maintenance Pulse Analyzer missing | **High** | Tier 0 scoring |
| 3 | "Frequently Deployed With" not surfaced | Medium | Platform |
| 4 | Telemetry Client SDK missing | Medium | Developer Experience |
| 5 | CI/CD GitHub Action missing | Medium | Developer Experience |
| 6 | Score trend charts missing | Medium | UI |
| 7 | Webhook management UI for builders missing | Medium | Platform |
| 8 | User agent submission missing | Medium | Platform / Growth |
| 9 | Interactive API documentation page missing | Medium | API / DevEx |
| 10 | Tier 0 evaluations not scheduled | **High** | Scoring / Operations |
| 11 | Agent tagging system missing | Low | Platform |
| 12 | Comparison sharing missing | Low | UI |

## Gap Details

### 1. Tier 0 License Clarity Analyzer (HIGH)

**Status:** Schema field `tier0_license` exists, weight defined in `Agent::TIER0_WEIGHTS` (0.10), but **no service implementation**.

**Impact:** 10% of Tier 0 signal weight is uncomputed. The README lists 7 Tier 0 signals but only 5 have analyzer services.

**Files needed:**
- `app/services/tier0/license_clarity_analyzer.rb`
- `test/services/tier0/license_clarity_analyzer_test.rb`
- Update `app/services/tier0/scoring_engine.rb`

---

### 2. Tier 0 Maintenance Pulse Analyzer (HIGH)

**Status:** Schema field `tier0_maintenance` exists, weight defined in `Agent::TIER0_WEIGHTS` (0.10), but **no service implementation**.

**Impact:** 10% of Tier 0 signal weight is uncomputed. Combined with the missing License analyzer, 20% of Tier 0 scoring is non-functional.

**Files needed:**
- `app/services/tier0/maintenance_pulse_analyzer.rb`
- `test/services/tier0/maintenance_pulse_analyzer_test.rb`
- Update `app/services/tier0/scoring_engine.rb`

---

### 3. "Frequently Deployed With" Co-occurrence Feature (MEDIUM)

**Status:** `AgentInteraction` model exists with relationships between agents, but co-occurrence data is **never computed or displayed**.

**Impact:** README promises this on agent profiles. The data model exists but the feature is invisible to users.

**Files needed:**
- `app/services/co_occurrence_analyzer.rb`
- Update `app/views/agents/show.html.erb`
- New API endpoint `GET /api/v1/agents/:id/related`

---

### 4. Telemetry Client SDK (MEDIUM)

**Status:** The `POST /api/v1/telemetry` endpoint works and `TelemetryAggregationJob` processes events. But **no client SDK** exists for builders to integrate telemetry.

**Impact:** Tier 3 adoption is blocked. Builders must manually construct HTTP requests, which is a high barrier.

**Files needed:**
- `sdk/javascript/` — npm package
- Documentation and integration examples

---

### 5. CI/CD GitHub Action (MEDIUM)

**Status:** `POST /api/v1/deploy_gates/check` API works. A template exists in `docs/github-action.yml`. But **no reusable GitHub Action** exists.

**Impact:** CI/CD integration requires manual workflow authoring instead of a simple `uses:` reference.

**Files needed:**
- `.github/actions/evald-gate/action.yml` or separate repo
- Documentation updates

---

### 6. Score Trend Visualization (MEDIUM)

**Status:** Score history data is stored (multiple `AgentScore` records). The profile controller loads `@version_history`. But the UI shows only a **flat list**, no charts.

**Impact:** For "Moody's for AI agents," visual trend lines are essential. Users can't quickly assess whether an agent's trust is improving or declining.

**Files needed:**
- Chart library integration (Chart.js or similar)
- Update `app/views/agents/show.html.erb`
- Consider JSON endpoint for chart data

---

### 7. Webhook Management UI for Builders (MEDIUM)

**Status:** `WebhookEndpoint`, `WebhookDelivery` models and delivery jobs are fully implemented. But builders have **no UI to create or manage webhooks**.

**Impact:** Webhook functionality is unusable for agent builders who've claimed their profile.

**Files needed:**
- `app/controllers/builder/webhooks_controller.rb`
- Views under `app/views/builder/webhooks/`
- Routes under `/builder/agents/:id/webhooks`

---

### 8. User Agent Submission (MEDIUM)

**Status:** New agents only enter the system via the GitHub scraper or admin creation. **No public submission form** exists.

**Impact:** Limits platform growth. Agents that don't match scraper search terms are missed entirely.

**Files needed:**
- `app/controllers/agents/submissions_controller.rb`
- Submission form view
- Routes: `GET/POST /agents/submit`

---

### 9. Interactive API Documentation Page (MEDIUM)

**Status:** `docs/API.md` exists with endpoint documentation, but **no web-accessible API docs page**.

**Impact:** Developers must find and read markdown files. No interactive exploration or testing.

**Files needed:**
- Route `GET /docs/api`
- OpenAPI 3.0 spec generation
- Consider Swagger UI or Redoc integration

---

### 10. Scheduled Tier 0 Evaluations (HIGH)

**Status:** `config/recurring.yml` only schedules the GitHub scraper and cleanup jobs. **Tier 0 evaluations are not scheduled** despite the README claiming "Tier 0 runs continuously."

**Impact:** Agent scores go stale and only decay. Re-evaluation requires manual admin action, contradicting the continuous evaluation promise.

**Files needed:**
- Update `config/recurring.yml` with Tier 0 refresh schedule
- Consider batch processing with rate limit awareness

---

### 11. Agent Tagging System (LOW)

**Status:** Only a fixed `category` field with 5 options (coding, research, workflow, assistant, general). **No flexible tagging**.

**Impact:** Limited discoverability. Users can't filter by specific capabilities like "code-review" or "python."

**Files needed:**
- `Tag` model and `agent_tags` join table
- Migration
- Admin tag management
- Filtering in listing and API

---

### 12. Comparison Sharing (LOW)

**Status:** Comparisons work via query parameters (`/compare?agents=a,b`) but **no sharing UI** (copy link, social share, Open Graph tags).

**Impact:** Minor, but sharing comparisons is a key viral growth mechanism for a trust platform.

**Files needed:**
- Copy-to-clipboard button
- Open Graph meta tags for comparison pages
- Social share buttons

---

## Recommendations

### Immediate Priority (blocks core value)
1. **License Clarity Analyzer** — Complete Tier 0 signal coverage
2. **Maintenance Pulse Analyzer** — Complete Tier 0 signal coverage
3. **Scheduled Tier 0 Evaluations** — Enable continuous evaluation

### Short-term (improves user experience)
4. Score Trend Visualization
5. User Agent Submission
6. Interactive API Documentation

### Medium-term (improves developer adoption)
7. CI/CD GitHub Action
8. Telemetry Client SDK
9. Webhook Management UI

### Nice-to-have (growth features)
10. Agent Tagging System
11. Co-occurrence Feature
12. Comparison Sharing
