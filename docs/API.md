# evaled.ai API Documentation

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

#### Get Agent Score
`GET /api/v1/agents/:id/score`

### API Keys

#### List Your Keys
`GET /api/v1/api_keys`

#### Create Key
`POST /api/v1/api_keys`

### Rate Limits
- 60 requests per minute per API key
- 100 requests per minute per IP (unauthenticated)
