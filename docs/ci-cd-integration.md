# CI/CD Integration

Evaled.ai provides a deploy gate API that enables score-based deployment checks in your CI/CD pipelines.

## API Endpoint

**POST** `/api/v1/deploy_gates/check`

### Request Body

```json
{
  "agents": ["agent-slug-1", "agent-slug-2"],
  "min_score": 70
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `agents` | array | *required* | List of agent slugs to check |
| `min_score` | integer | 70 | Minimum score threshold (0-100) |

### Response

```json
{
  "pass": true,
  "threshold": 70,
  "checked_at": "2026-02-09T05:00:00Z",
  "agents": [
    {
      "agent": "agent-slug-1",
      "name": "Agent One",
      "score": 85,
      "pass": true,
      "last_verified": "2026-02-08T12:00:00Z"
    }
  ],
  "summary": "1/1 agents passed (min_score: 70)"
}
```

| Field | Description |
|-------|-------------|
| `pass` | `true` if ALL agents meet the threshold |
| `threshold` | The min_score used for the check |
| `agents` | Array of individual agent results |
| `summary` | Human-readable summary |

### HTTP Status Codes

- **200 OK**: All agents passed
- **422 Unprocessable Entity**: One or more agents failed
- **400 Bad Request**: Missing or invalid parameters

## GitHub Actions

See [github-action.yml](./github-action.yml) for a ready-to-use workflow template.

### Quick Start

1. Copy `docs/github-action.yml` to `.github/workflows/evaled-deploy-gate.yml`
2. Update the `AGENTS` array with your agent slugs
3. Set `MIN_SCORE` to your desired threshold
4. (Optional) Add `EVALED_API_KEY` to your repository secrets

### Example Usage

```yaml
- name: Check Agent Quality
  run: |
    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"agents": ["my-agent"], "min_score": 80}' \
      https://evaled.ai/api/v1/deploy_gates/check
```

## Environment-Specific Thresholds

You can configure different thresholds per environment:

```yaml
# Staging: allow lower scores for testing
MIN_SCORE_STAGING: 60

# Production: require higher scores
MIN_SCORE_PRODUCTION: 80
```

## Use Cases

1. **Pre-deploy validation**: Block deployments if agent dependencies fall below quality thresholds
2. **PR checks**: Validate agent scores before merging
3. **Scheduled audits**: Run periodic checks to monitor agent quality
4. **Multi-agent systems**: Ensure all component agents meet minimum standards
