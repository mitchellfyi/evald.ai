# evald.ai

**The trust score for AI agents.**

## Local Development

### Prerequisites
- Ruby 3.4+ (see `.ruby-version`)
- PostgreSQL
- Redis (optional for dev)

### Setup

```bash
# Clone the repo
git clone https://github.com/mitchellfyi/evald.ai.git
cd evald.ai

# Copy environment variables
cp .env.example .env

# Run the setup script
bin/setup

# Start the dev server
bin/dev
```

The app will be available at `http://localhost:3000`.

## Documentation

- [API Documentation](docs/API.md) - API endpoints and authentication
- [Architecture Decision Records](docs/adr/) - Key technical decisions

### Configuration

Edit `.env` with your local settings:
- `DATABASE_URL` - PostgreSQL connection string
- `GITHUB_TOKEN` - For GitHub API scraping (optional for basic dev)

---

Evald continuously evaluates open-source and commercial AI agents so you don't have to. Every agent gets a public trust profile built from real data — not self-reported benchmarks, not GitHub stars, not vibes.

originally hypothesised at https://www.mitchellbryson.com/articles/the-trust-stack-ai-agents

## The problem

You're evaluating an AI agent for your codebase, your customer data, or your production environment. Right now your options are:

- Read the README and hope it's accurate
- Check GitHub stars (a popularity contest, not a quality signal)
- Ask on Twitter/Discord and get anecdotal answers
- Spend days running your own evals

MCP tells you **how** agents connect. A2A tells you **how** agents talk to each other. Nothing tells you **whether you should trust them**.

Evald does.

## How it works

Every agent gets an **Evald Score** (0–100) computed from two tiers of evaluation.

### Tier 0 — Passive Signals (automated, no agent cooperation needed)

We scrape public data and compute trust signals from what's already out there.

| Signal | What we measure |
|---|---|
| **Repo health** | Commit recency, frequency, open issue ratio, PR turnaround time |
| **Bus factor** | Number of active contributors, commit distribution |
| **Dependency risk** | Known CVEs, outdated packages, dependency count and depth |
| **Documentation quality** | README completeness, API docs, examples, changelog presence |
| **Community signal** | Stars, forks, weighted by account age and activity (bot-filtered) |
| **License clarity** | OSI-approved license present and unambiguous |
| **Maintenance pulse** | Days since last commit, release cadence, issue response time |

Tier 0 runs continuously. Every agent with a public repo gets a Tier 0 profile automatically.

### Tier 1 — Task Completion Evals (automated, we run the agent)

We deploy agents against standardized task suites and measure real performance.

**Coding agents**
- Bug fixes across varying complexity (syntax \u2192 logic \u2192 architectural)
- Feature implementation from spec
- Refactoring with correctness preservation
- Test generation and coverage

**Research agents**
- Factual retrieval accuracy against ground truth
- Multi-source synthesis and comparison
- Citation accuracy and hallucination rate

**Workflow agents**
- Task completion rate on structured workflows
- Instruction adherence (does it stay in scope?)
- Error handling and graceful degradation
- Escalation behavior (does it ask for help when it should?)

**Every Tier 1 eval measures:**

| Metric | Description |
|---|---|
| **Completion rate** | Did the agent finish the task? |
| **Accuracy** | Was the output correct? |
| **Cost efficiency** | Tokens consumed and time elapsed |
| **Scope discipline** | Did it stay within stated capabilities or hallucinate actions? |
| **Safety behavior** | Does it respect boundaries, permissions, and constraints? |

Tier 1 runs on a schedule. Results are versioned — you can see how an agent performs across releases.

## Score decay

Evald Scores decay over time. An agent that scored 92 six months ago but hasn't been re-evaluated shows a decayed score with a `last_verified` timestamp. Trust isn't permanent.

```
{
  "agent": "acme-code-agent",
  "score": 87,
  "score_at_eval": 92,
  "last_verified": "2026-01-15T00:00:00Z",
  "decay_rate": "standard",
  "next_eval_scheduled": "2026-03-15T00:00:00Z"
}
```

## API

```bash
# Get an agent's trust profile
GET /v1/agents/{agent_id}

# Get the Evald Score
GET /v1/agents/{agent_id}/score

# Compare agents for a use case
GET /v1/compare?agents=agent-a,agent-b,agent-c&task=code-review

# Search agents by capability
GET /v1/search?capability=coding&min_score=80
```

```bash
curl https://api.evald.ai/v1/agents/devin/score

{
  "agent": "devin",
  "score": 84,
  "tier0": {
    "repo_health": 91,
    "dependency_risk": 78,
    "documentation": 88,
    "maintenance_pulse": 85
  },
  "tier1": {
    "completion_rate": 0.82,
    "accuracy": 0.79,
    "cost_efficiency": 0.71,
    "scope_discipline": 0.93,
    "safety": 0.96
  },
  "last_verified": "2026-02-01T00:00:00Z"
}
```

## Agent profiles

Every agent gets a public profile page at `evald.ai/agents/{name}`.

Profiles include:
- Evald Score with full breakdown
- Builder / org with link to source
- Version history with score trends over time
- Tier 0 and Tier 1 details
- "Frequently deployed with" based on co-occurrence data
- Claim status (unclaimed / claimed / verified)

Agent builders can **claim their profile** to add context, respond to findings, and get notified when their score changes.

## Roadmap

- [x] Tier 0 — passive signal scoring from public repos
- [x] Tier 1 — automated task completion evals
- [x] Tier 2 — behavioral and safety evals (adversarial testing, prompt injection resistance, permission boundary testing)
- [x] Tier 3 — production telemetry integration (opt-in SDK for real-world performance data)
- [x] Tier 4 — security audits (penetration testing, compliance checks, paid certification)
- [x] Agent comparison and recommendation engine
- [x] CI/CD integration (block deploys below score threshold)
- [x] Badge embeds for READMEs (`![
