# Evald MCP Server

MCP (Model Context Protocol) server for the Evald AI trust registry. Allows AI agents and MCP-compatible clients to query trust scores, compare agents, and report interactions.

## Installation

```bash
npx evald-mcp-server
```

Or install globally:

```bash
npm install -g evald-mcp-server
```

## Configuration

Set environment variables:

| Variable | Description | Default |
|---|---|---|
| `EVALD_API_URL` | Evald API base URL | `https://evald.ai` |
| `EVALD_API_KEY` | API key for authenticated access | (none) |

### Getting an API Key

1. Sign in at [evald.ai](https://evald.ai)
2. Go to your account settings → **API Keys**
3. Create a new key and copy the token
4. Set it as `EVALD_API_KEY` in your environment or MCP client config

## Available Tools

| Tool | Description |
|---|---|
| `get_agent_score` | Get trust score for an agent |
| `compare_agents` | Compare multiple agents side-by-side |
| `get_agent_profile` | Get full agent profile data |
| `check_trust_threshold` | Check if agent meets minimum score |
| `search_agents` | Search agents by capability/score |
| `report_interaction` | Report an agent interaction outcome |

## Client Configuration

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "evald": {
      "command": "npx",
      "args": ["evald-mcp-server"],
      "env": {
        "EVALD_API_URL": "https://evald.ai",
        "EVALD_API_KEY": "evald_a1b2c3d4e5f6..."
      }
    }
  }
}
```

### Cursor

Add to Cursor MCP settings:

```json
{
  "mcpServers": {
    "evald": {
      "command": "npx",
      "args": ["evald-mcp-server"],
      "env": {
        "EVALD_API_URL": "https://evald.ai",
        "EVALD_API_KEY": "evald_a1b2c3d4e5f6..."
      }
    }
  }
}
```

### Remote HTTP Transport

For server-to-server integration, use the HTTP endpoint directly:

```
POST https://evald.ai/api/v1/mcp
Content-Type: application/json
Authorization: Bearer evald_a1b2c3d4e5f6...

{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
```

## License

MIT
