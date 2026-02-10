# @evald/telemetry

Official JavaScript/TypeScript SDK for [evald.ai](https://evald.ai) agent telemetry.

## Installation

```bash
npm install @evald/telemetry
# or
yarn add @evald/telemetry
# or
pnpm add @evald/telemetry
```

## Quick Start

```typescript
import { createTelemetry } from '@evald/telemetry';

const telemetry = createTelemetry({
  apiKey: 'your-api-key',
  agentId: 'my-agent-001',
});

// Track events
telemetry.track({
  type: 'custom_event',
  data: { foo: 'bar' },
});

// Track task completion
telemetry.trackTaskCompletion({
  taskId: 'task-123',
  success: true,
  durationMs: 1500,
});

// Track errors
telemetry.trackError(new Error('Something went wrong'));

// Graceful shutdown
await telemetry.shutdown();
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `apiKey` | `string` | *required* | Your evald.ai API key |
| `agentId` | `string` | *required* | Unique identifier for your agent |
| `endpoint` | `string` | `https://evald.ai/api/v1/telemetry` | API endpoint |
| `batching` | `boolean` | `true` | Enable event batching |
| `flushInterval` | `number` | `5000` | Batch flush interval (ms) |
| `batchSize` | `number` | `50` | Max events per batch |
| `maxRetries` | `number` | `3` | Max retry attempts |
| `debug` | `boolean` | `false` | Enable debug logging |

## API

### `createTelemetry(config)`

Create a new telemetry client instance.

### `telemetry.track(event)`

Track a custom event.

```typescript
telemetry.track({
  type: 'my_event',
  data: { key: 'value' },
  sessionId: 'optional-session-id',
  traceId: 'optional-trace-id',
});
```

### `telemetry.trackTaskCompletion(data)`

Track task completion with built-in structure.

```typescript
telemetry.trackTaskCompletion({
  taskId: 'task-123',
  success: true,
  durationMs: 2500,
  metadata: { model: 'gpt-4' },
});
```

### `telemetry.trackError(error, metadata?)`

Track an error event.

```typescript
// With Error object
telemetry.trackError(new Error('Failed to process'));

// With string
telemetry.trackError('Connection timeout', { endpoint: '/api/data' });
```

### `telemetry.trackStart(metadata?)`

Track agent startup.

```typescript
telemetry.trackStart({ version: '1.0.0' });
```

### `telemetry.trackStop(metadata?)`

Track agent shutdown.

```typescript
telemetry.trackStop({ reason: 'graceful' });
```

### `telemetry.flush()`

Manually flush all queued events.

```typescript
await telemetry.flush();
```

### `telemetry.shutdown()`

Gracefully shutdown the client, flushing remaining events.

```typescript
await telemetry.shutdown();
```

## Batching

By default, events are batched and sent every 5 seconds or when 50 events accumulate. This reduces network overhead for high-volume agents.

Disable batching for real-time delivery:

```typescript
const telemetry = createTelemetry({
  apiKey: 'your-api-key',
  agentId: 'my-agent',
  batching: false,
});
```

## Retry Behavior

Failed requests are automatically retried with exponential backoff (1s, 2s, 4s...) up to `maxRetries` attempts.

## TypeScript

Full TypeScript support with exported types:

```typescript
import { 
  EvaldTelemetry,
  TelemetryConfig,
  TelemetryEvent 
} from '@evald/telemetry';
```

## License

MIT
