# evald.ai API Documentation

## Authentication

All API requests require a Bearer token:
```
Authorization: Bearer your-api-key
```

## Endpoints

### Agents

#### List Agents
`GET /api/v1/agents`

Parameters:
- `page` (integer) - Page number
- `per_page` (integer) - Items per page (max 100)
- `sort` (string) - Sort by: stars, name, updated_at
- `language` (string) - Filter by language

Response:
```json
{
  "agents": [...],
  "meta": { "page": 1, "total": 500 }
}
```

#### Get Agent
`GET /api/v1/agents/:id`

Response includes domain-specific scores:
```json
{
  "agent": "devin",
  "name": "Devin",
  "score": 84,
  "confidence": "high",
  "domain_scores": {
    "coding": {
      "score": 91,
      "confidence": "high",
      "evals_run": 12
    },
    "research": {
      "score": 67,
      "confidence": "low",
      "evals_run": 2
    }
  },
  "primary_domain": "coding",
  "tier0": { ... },
  "tier1": { ... }
}
```

#### Get Agent Score
`GET /api/v1/agents/:id/score`

Response:
```json
{
  "agent": "devin",
  "score": 84,
  "confidence": "high",
  "domain_scores": {
    "coding": { "score": 91, "confidence": "high", "evals_run": 12 },
    "research": { "score": 67, "confidence": "low", "evals_run": 2 }
  },
  "primary_domain": "coding",
  "tier0": { ... },
  "tier1": { ... },
  "last_verified": "2026-02-01T00:00:00Z"
}
```

#### Compare Agents
`GET /api/v1/agents/compare`

Parameters:
- `agents` (string) - Comma-separated agent slugs (max 5)
- `task` or `domain` (string) - Filter comparison by domain (coding, research, workflow)

When a domain filter is provided, the recommendation is based on domain-specific scores.

Response:
```json
{
  "task": "coding",
  "agents": [...],
  "recommendation": {
    "recommended": "devin",
    "reason": "Highest Coding domain score (91) among compared agents"
  }
}
```

#### Search Agents
`GET /api/v1/agents/search`

Parameters:
- `q` (string) - Search query
- `capability` (string) - Filter by category
- `min_score` (integer) - Minimum Evald Score
- `domain` (string) - Filter by target domain (coding, research, workflow)
- `primary_domain` (string) - Filter by primary domain

Results are ordered by domain score when domain filter is provided.

### API Keys

#### List Your Keys
`GET /api/v1/api_keys`

#### Create Key
`POST /api/v1/api_keys`

### Rate Limits
- 60 requests per minute per API key
- 100 requests per minute per IP (unauthenticated)

## Error Tracking

This API uses Sentry for error tracking and performance monitoring. All unhandled exceptions and errors are automatically captured and reported in production and staging environments.
