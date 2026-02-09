# Evald.ai SDKs

Lightweight telemetry clients for AI agent monitoring.

## JavaScript

```javascript
const { EvaldClient } = require('./evald.js');

const client = new EvaldClient({
  apiKey: 'your-api-key',
  agentId: 'agent-uuid'
});

await client.trackCompletion('task-1', {
  success: true,
  duration: 1500,
  tokens: 250
});

const score = await client.getScore();
```

## Python

```python
from evald import EvaldClient

client = EvaldClient(
    api_key="your-api-key",
    agent_id="agent-uuid"
)

client.track_completion("task-1", {
    "success": True,
    "duration": 1500,
    "tokens": 250
})

score = client.get_score()
```
