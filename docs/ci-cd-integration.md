# CI/CD Integration Guide

Integrate Evald's trust scoring into your deployment pipeline to ensure AI agents meet safety and reliability thresholds before going to production.

## Overview

The Evald Deploy Gate acts as a quality checkpoint in your CI/CD pipeline. It queries your agent's trust score and blocks deployments if the score falls below your configured threshold.

**Why use deploy gates?**
- 🛡️ Prevent deploying agents that don't meet safety standards
- 📊 Track trust score changes over time
- 🔔 Get early warnings when agent quality degrades
- ✅ Demonstrate compliance with AI governance policies

## GitHub Actions

### Quick Start

Add the Evald deploy gate to your workflow:

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # Check trust score before deploying
      - name: Evald Deploy Gate
        uses: evald-ai/evald.ai/.github/actions/evald-gate@main
        with:
          agent-id: 'your-agent-slug'
          minimum-score: '70'
      
      # Your deployment steps here
      - name: Deploy
        run: ./deploy.sh
```

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `agent-id` | ✅ | - | Agent slug or ID. Supports multiple comma-separated values: `agent1,agent2` |
| `minimum-score` | ❌ | `70` | Minimum trust score threshold (0-100) |
| `api-key` | ❌ | - | API key for private agents or higher rate limits |
| `api-url` | ❌ | `https://evald.ai` | Evald API base URL |
| `fail-on-below` | ❌ | `true` | Fail the workflow if score is below threshold |

### Outputs

| Output | Description |
|--------|-------------|
| `score` | Current trust score (lowest if multiple agents) |
| `passed` | Whether all agents met the threshold (`true`/`false`) |
| `summary` | Human-readable summary (e.g., "2/3 agents passed") |
| `details` | Full JSON response from the API |

### Examples

#### Basic Usage

```yaml
- name: Evald Deploy Gate
  uses: evald-ai/evald.ai/.github/actions/evald-gate@main
  with:
    agent-id: 'my-ai-agent'
```

#### Multiple Agents

Check multiple agents in a single step:

```yaml
- name: Evald Deploy Gate
  uses: evald-ai/evald.ai/.github/actions/evald-gate@main
  with:
    agent-id: 'agent-1,agent-2,agent-3'
    minimum-score: '80'
```

#### Using Outputs

Use the outputs for conditional logic:

```yaml
- name: Evald Deploy Gate
  id: evald
  uses: evald-ai/evald.ai/.github/actions/evald-gate@main
  with:
    agent-id: 'my-agent'
    fail-on-below: 'false'  # Don't fail, just check

- name: Deploy to Production
  if: steps.evald.outputs.passed == 'true'
  run: ./deploy.sh --production

- name: Deploy to Staging
  if: steps.evald.outputs.passed == 'false'
  run: |
    echo "⚠️ Trust score too low (${{ steps.evald.outputs.score }})"
    ./deploy.sh --staging
```

#### With API Key

For private agents or higher rate limits:

```yaml
- name: Evald Deploy Gate
  uses: evald-ai/evald.ai/.github/actions/evald-gate@main
  with:
    agent-id: 'private-agent'
    api-key: ${{ secrets.EVALD_API_KEY }}
```

#### Custom Threshold per Environment

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - uses: evald-ai/evald.ai/.github/actions/evald-gate@main
        with:
          agent-id: 'my-agent'
          minimum-score: '60'  # Lower threshold for staging

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    steps:
      - uses: evald-ai/evald.ai/.github/actions/evald-gate@main
        with:
          agent-id: 'my-agent'
          minimum-score: '85'  # Higher threshold for production
```

## API Reference

The deploy gate action uses the Evald API. You can also call it directly for custom integrations.

### Endpoint

```
POST https://evald.ai/api/v1/deploy_gates/check
```

### Request

```json
{
  "agents": ["agent-slug-1", "agent-slug-2"],
  "min_score": 70
}
```

### Response

```json
{
  "pass": true,
  "threshold": 70,
  "checked_at": "2025-02-10T12:00:00Z",
  "agents": [
    {
      "agent": "agent-slug-1",
      "name": "My AI Agent",
      "score": 85.5,
      "pass": true,
      "last_verified": "2025-02-09T15:30:00Z"
    }
  ],
  "summary": "1/1 agents passed (min_score: 70)"
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| `200` | All agents passed |
| `422` | One or more agents failed |
| `400` | Invalid request (missing agents parameter) |

## Other CI/CD Systems

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - |
      RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"agents": ["my-agent"], "min_score": 70}' \
        https://evald.ai/api/v1/deploy_gates/check)
      
      PASSED=$(echo $RESPONSE | jq -r '.pass')
      if [ "$PASSED" != "true" ]; then
        echo "Deploy gate failed"
        exit 1
      fi
    - ./deploy.sh
```

### CircleCI

```yaml
version: 2.1

jobs:
  deploy:
    docker:
      - image: cimg/base:current
    steps:
      - checkout
      - run:
          name: Check Evald Deploy Gate
          command: |
            RESPONSE=$(curl -s -X POST \
              -H "Content-Type: application/json" \
              -d '{"agents": ["my-agent"], "min_score": 70}' \
              https://evald.ai/api/v1/deploy_gates/check)
            
            PASSED=$(echo $RESPONSE | jq -r '.pass')
            if [ "$PASSED" != "true" ]; then
              echo "Deploy gate failed: $(echo $RESPONSE | jq -r '.summary')"
              exit 1
            fi
      - run: ./deploy.sh
```

### Jenkins

```groovy
pipeline {
    agent any
    stages {
        stage('Evald Deploy Gate') {
            steps {
                script {
                    def response = httpRequest(
                        httpMode: 'POST',
                        url: 'https://evald.ai/api/v1/deploy_gates/check',
                        contentType: 'APPLICATION_JSON',
                        requestBody: '{"agents": ["my-agent"], "min_score": 70}'
                    )
                    def json = readJSON text: response.content
                    if (!json.pass) {
                        error("Deploy gate failed: ${json.summary}")
                    }
                }
            }
        }
        stage('Deploy') {
            steps {
                sh './deploy.sh'
            }
        }
    }
}
```

### Bash Script

For any CI system:

```bash
#!/bin/bash
set -e

AGENT="my-agent"
MIN_SCORE=70

RESPONSE=$(curl -sf -X POST \
  -H "Content-Type: application/json" \
  -d "{\"agents\": [\"$AGENT\"], \"min_score\": $MIN_SCORE}" \
  https://evald.ai/api/v1/deploy_gates/check)

PASSED=$(echo "$RESPONSE" | jq -r '.pass')
SUMMARY=$(echo "$RESPONSE" | jq -r '.summary')

echo "Deploy gate result: $SUMMARY"

if [ "$PASSED" != "true" ]; then
  echo "❌ Deploy gate check failed"
  exit 1
fi

echo "✅ Deploy gate passed"
```

## Best Practices

1. **Set appropriate thresholds**: Production should have higher thresholds than staging
2. **Monitor trends**: Watch for gradual score decreases that might indicate drift
3. **Don't bypass**: If an agent fails, investigate rather than lowering the threshold
4. **Use caching**: The API response includes `last_verified` to track evaluation freshness
5. **Combine with badges**: Display your trust score in your README with [Evald badges](/badges)

## Need Help?

- [Agent Registration](/agents/submit) - Register your agent
- [API Documentation](/api-docs) - Full API reference
- [Methodology](/methodology) - How trust scores are calculated
