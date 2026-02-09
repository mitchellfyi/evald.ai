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
        "EVALD_API_KEY": "your-api-key"
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
        "EVALD_API_KEY": "your-api-key"
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

{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
```

## License

MIT
