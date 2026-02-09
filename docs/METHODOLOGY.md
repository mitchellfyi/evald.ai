# Evald Scoring Methodology

This document provides complete transparency into how Evald computes trust scores. All scoring logic is open source and reproducible.

## Score Composition

The **Evald Score** (0-100) is computed from two evaluation tiers:

```
Evald Score = (Tier0 × 0.40) + (Tier1 × 0.60)
```

If no Tier 1 data is available, the score is based on Tier 0 alone.

## Tier 0: Passive Signals (40% weight)

Tier 0 evaluates publicly available data about an agent's repository and infrastructure. No cooperation from the agent builder is required.

| Signal | Weight | What We Measure |
|--------|--------|-----------------|
| Repo Health | 20% | Commit recency, frequency, open issue ratio, PR turnaround time |
| Bus Factor | 10% | Number of active contributors, commit distribution |
| Dependency Risk | 15% | Known CVEs, outdated packages, dependency count and depth |
| Documentation | 20% | README completeness, API docs, examples, changelog presence |
| Community | 15% | Stars, forks (weighted by account age, bot-filtered) |
| License | 10% | OSI-approved license present and unambiguous |
| Maintenance | 10% | Days since last commit, release cadence, issue response time |

**Scoring**: Each signal is scored 0-100. The weighted sum produces the Tier 0 composite.

## Tier 1: Task Completion Evals (60% weight)

Tier 1 runs the agent against standardized task suites and measures real performance.

| Metric | Weight | What We Measure |
|--------|--------|-----------------|
| Completion Rate | 25% | Did the agent finish the task? |
| Accuracy | 30% | Was the output correct vs. ground truth? |
| Cost Efficiency | 15% | Tokens consumed, time elapsed |
| Scope Discipline | 15% | Did it stay within stated capabilities? |
| Safety | 15% | Respects boundaries, permissions, constraints |

**Scoring**: Each metric is measured as a ratio (0.0-1.0), scaled to 0-100, then weighted.

## Score Tiers (Letter Grades)

For quick human comprehension, scores map to tier labels:

| Score Range | Tier | Description |
|-------------|------|-------------|
| 90-100 | Platinum ⭐ | Exceptional trust — comprehensive evals, high scores |
| 80-89 | Gold 🥇 | High trust — reliable across evaluations |
| 70-79 | Silver 🥈 | Good trust — solid but room for improvement |
| 60-69 | Bronze 🥉 | Moderate trust — some concerns identified |
| <60 | Unrated | Insufficient trust — significant gaps or no data |

## Confidence Indicator

Every score includes a **confidence level** indicating data quality:

| Level | Criteria |
|-------|----------|
| **High** | Complete Tier 0 + Tier 1 with 2+ recent runs, low variance |
| **Medium** | Tier 0 complete with partial Tier 1 or recent eval activity |
| **Low** | Tier 0 only — no task completion evals |
| **Insufficient** | Minimal data available |

A score of 78 with high confidence means something different than 78 with low confidence.

## Score Decay

Trust isn't permanent. Evald scores decay over time to reflect data freshness.

### Decay Formula

```
current_score = score_at_eval - (days_since_eval × decay_factor × score_at_eval)
```

### Decay Rates

| Rate | Decay Factor | Half-Life | Use Case |
|------|--------------|-----------|----------|
| Standard | 0.002 | ~500 days | Default for most agents |
| Slow | 0.001 | ~1000 days | Stable, well-established agents |
| Fast | 0.005 | ~200 days | Rapidly evolving agents |

### API Response

```json
{
  "agent": "acme-code-agent",
  "score": 87,
  "score_at_eval": 92,
  "decay_rate": "standard",
  "last_verified": "2026-01-15T00:00:00Z"
}
```

## Domain-Specific Scoring

Agents can be evaluated across multiple domains (coding, research, workflow). The composite score only weights domains the agent targets.

```json
{
  "score": 84,
  "domain_scores": {
    "coding": { "score": 91, "confidence": "high", "evals_run": 12 },
    "research": { "score": 67, "confidence": "low", "evals_run": 2 }
  },
  "primary_domain": "coding"
}
```

An agent that claims to be a coding agent is **not penalized** for low research scores.

## Adversarial Robustness

We implement several measures to prevent gaming:

### Anti-Gaming Measures

1. **Randomized evaluation timing** — Agents cannot predict when evals run
2. **Hidden eval variants** — Task suites include undisclosed variations
3. **Bot filtering** — Community signals (stars, forks) are filtered for artificial activity
4. **Score variance monitoring** — Large swings between evals trigger investigation
5. **Multi-dimensional scoring** — Gaming one metric doesn't dominate the score

### Gaming Vectors We Monitor

| Vector | Mitigation |
|--------|------------|
| Automated commits | Commit patterns analyzed, not just counts |
| Purchased stars | Account age and activity weighting |
| Eval detection | Randomized timing, no predictable patterns |
| Goodhart's Law | Hidden eval variants, real-world telemetry (Tier 3) |

## Transparency & Reproducibility

1. **Open source methodology** — All scoring logic is public
2. **Eval run linking** — Every score links to the specific eval that produced it
3. **Local reproduction** — Builders can run evals locally before submission
4. **Methodology versioning** — Changes to scoring are versioned and documented

## API Access

Full scoring data is available via API:

```bash
# Get detailed score with all factors
GET /api/v1/agents/{slug}/score

# Response includes:
# - score, score_at_eval
# - tier, confidence, confidence_factors
# - tier0, tier1 breakdowns
# - decay_rate, last_verified
```

## Questions?

For methodology questions or to report potential gaming, contact the Evald team or open an issue on [GitHub](https://github.com/mitchellfyi/evald.ai).
