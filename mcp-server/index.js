#!/usr/bin/env node

// Evald MCP Server - stdio transport
// Connects to Evald's API and exposes trust registry tools via MCP protocol.
//
// Usage:
//   EVALD_API_URL=https://evald.ai npx evald-mcp-server
//   EVALD_API_URL=https://evald.ai EVALD_API_KEY=your-key npx evald-mcp-server

const readline = require("readline");
const https = require("https");
const http = require("http");
const { URL } = require("url");

const EVALD_API_URL = process.env.EVALD_API_URL || "https://evald.ai";
const EVALD_API_KEY = process.env.EVALD_API_KEY || "";
const PROTOCOL_VERSION = "2024-11-05";

const SERVER_INFO = {
  name: "evald-mcp-server",
  version: "1.0.0",
};

const TOOLS = [
  {
    name: "get_agent_score",
    description:
      "Get the Evald trust score for an AI agent. Returns composite score, confidence level, score breakdown by tier, and decay status.",
    inputSchema: {
      type: "object",
      properties: {
        agent_id: { type: "string", description: "Agent slug identifier" },
        agent_name: {
          type: "string",
          description: "Agent name (alternative to agent_id)",
        },
      },
    },
  },
  {
    name: "compare_agents",
    description:
      "Compare multiple AI agents side-by-side with per-dimension score breakdown and recommendation for a given task domain.",
    inputSchema: {
      type: "object",
      properties: {
        agents: {
          type: "array",
          items: { type: "string" },
          description: "Array of agent slug identifiers to compare (max 5)",
        },
        task_domain: {
          type: "string",
          description:
            "Optional task domain for recommendation (e.g., 'coding', 'research')",
        },
      },
      required: ["agents"],
    },
  },
  {
    name: "get_agent_profile",
    description:
      "Get full profile data for an AI agent including builder info, score trend, capabilities, tier details, and claim status.",
    inputSchema: {
      type: "object",
      properties: {
        agent_id: { type: "string", description: "Agent slug identifier" },
      },
      required: ["agent_id"],
    },
  },
  {
    name: "check_trust_threshold",
    description:
      "Check if an agent meets a minimum trust score threshold. Use as an automated gate before proceeding with an agent interaction.",
    inputSchema: {
      type: "object",
      properties: {
        agent_id: { type: "string", description: "Agent slug identifier" },
        minimum_score: {
          type: "number",
          description: "Minimum required Evald Score (0-100)",
        },
        required_tiers: {
          type: "array",
          items: { type: "string" },
          description:
            "Optional tier data requirements (e.g., ['tier0', 'tier1'])",
        },
      },
      required: ["agent_id", "minimum_score"],
    },
  },
  {
    name: "search_agents",
    description:
      "Search for AI agents by capability, minimum score, domain, or verification status. Returns matching agents sorted by score.",
    inputSchema: {
      type: "object",
      properties: {
        capability: {
          type: "string",
          description:
            "Filter by agent category/capability (e.g., 'coding', 'research', 'workflow')",
        },
        min_score: {
          type: "number",
          description: "Minimum Evald Score filter",
        },
        domain: {
          type: "string",
          description: "Task domain to search within",
        },
        verified_only: {
          type: "boolean",
          description: "Only return verified agents",
        },
        limit: {
          type: "number",
          description: "Maximum results to return (default: 20, max: 50)",
        },
      },
    },
  },
  {
    name: "report_interaction",
    description:
      "Report an interaction outcome with another agent. Reports from agents with higher Evald scores carry more weight in the reputation system.",
    inputSchema: {
      type: "object",
      properties: {
        reporter_agent_id: {
          type: "string",
          description: "Slug of the reporting agent",
        },
        target_agent_id: {
          type: "string",
          description: "Slug of the agent being reported on",
        },
        interaction_type: {
          type: "string",
          description:
            "Type of interaction (e.g., 'delegation', 'collaboration', 'query', 'task_execution')",
        },
        outcome: {
          type: "string",
          description: "Description of the interaction outcome",
        },
        success: {
          type: "boolean",
          description: "Whether the interaction was successful",
        },
        notes: { type: "string", description: "Optional additional notes" },
      },
      required: [
        "reporter_agent_id",
        "target_agent_id",
        "interaction_type",
        "outcome",
        "success",
      ],
    },
  },
];

/**
 * Forward a tool call to the Evald MCP HTTP endpoint.
 */
function callEvaldApi(method, params) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method,
      params,
    });

    const url = new URL("/api/v1/mcp", EVALD_API_URL);
    const client = url.protocol === "https:" ? https : http;

    const headers = {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body),
    };
    if (EVALD_API_KEY) {
      headers["Authorization"] = `Bearer ${EVALD_API_KEY}`;
    }

    const req = client.request(
      url,
      { method: "POST", headers },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error("Invalid JSON response from Evald API"));
          }
        });
      }
    );

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function jsonrpcResponse(id, result) {
  return JSON.stringify({ jsonrpc: "2.0", id, result });
}

function jsonrpcError(id, code, message) {
  return JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } });
}

async function handleMessage(line) {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    process.stdout.write(jsonrpcError(null, -32700, "Parse error") + "\n");
    return;
  }

  if (msg.jsonrpc !== "2.0" || typeof msg.method !== "string") {
    process.stdout.write(
      jsonrpcError(msg.id || null, -32600, "Invalid Request") + "\n"
    );
    return;
  }

  const { id, method, params = {} } = msg;

  switch (method) {
    case "initialize":
      process.stdout.write(
        jsonrpcResponse(id, {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: { tools: {} },
          serverInfo: SERVER_INFO,
        }) + "\n"
      );
      break;

    case "notifications/initialized":
      // No response for notifications
      break;

    case "tools/list":
      process.stdout.write(
        jsonrpcResponse(id, { tools: TOOLS }) + "\n"
      );
      break;

    case "tools/call":
      try {
        const apiResponse = await callEvaldApi("tools/call", params);
        if (apiResponse.result) {
          process.stdout.write(
            jsonrpcResponse(id, apiResponse.result) + "\n"
          );
        } else if (apiResponse.error) {
          process.stdout.write(
            jsonrpcError(id, apiResponse.error.code, apiResponse.error.message) + "\n"
          );
        } else {
          process.stdout.write(
            jsonrpcError(id, -32603, "Unexpected response from Evald API") + "\n"
          );
        }
      } catch (err) {
        process.stdout.write(
          jsonrpcError(id, -32603, `API call failed: ${err.message}`) + "\n"
        );
      }
      break;

    case "ping":
      process.stdout.write(jsonrpcResponse(id, {}) + "\n");
      break;

    default:
      process.stdout.write(
        jsonrpcError(id, -32601, `Method not found: ${method}`) + "\n"
      );
  }
}

// Main: read JSON-RPC messages from stdin, one per line
const rl = readline.createInterface({ input: process.stdin, terminal: false });
rl.on("line", handleMessage);

process.stderr.write(
  `Evald MCP Server started (API: ${EVALD_API_URL})\n`
);
