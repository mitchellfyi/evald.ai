/**
 * evald.ai Telemetry SDK
 * 
 * Simple telemetry client for agent monitoring and observability.
 */

export interface TelemetryConfig {
  /** Your evald.ai API key */
  apiKey: string;
  /** Unique identifier for your agent */
  agentId: string;
  /** API endpoint (defaults to https://evald.ai/api/v1/telemetry) */
  endpoint?: string;
  /** Enable batching (default: true) */
  batching?: boolean;
  /** Batch flush interval in ms (default: 5000) */
  flushInterval?: number;
  /** Max events per batch (default: 50) */
  batchSize?: number;
  /** Max retry attempts (default: 3) */
  maxRetries?: number;
  /** Enable debug logging (default: false) */
  debug?: boolean;
}

export interface TelemetryEvent {
  /** Event type (e.g., 'task_completion', 'error', 'custom') */
  type: string;
  /** Event payload data */
  data?: Record<string, unknown>;
  /** ISO timestamp (auto-generated if not provided) */
  timestamp?: string;
  /** Optional session identifier */
  sessionId?: string;
  /** Optional trace identifier for distributed tracing */
  traceId?: string;
}

interface QueuedEvent extends TelemetryEvent {
  timestamp: string;
  retryCount: number;
}

const DEFAULT_CONFIG = {
  endpoint: 'https://evald.ai/api/v1/telemetry',
  batching: true,
  flushInterval: 5000,
  batchSize: 50,
  maxRetries: 3,
  debug: false,
};

export class EvaldTelemetry {
  private config: Required<TelemetryConfig>;
  private queue: QueuedEvent[] = [];
  private flushTimer: ReturnType<typeof setInterval> | null = null;
  private isFlushing = false;

  constructor(config: TelemetryConfig) {
    this.config = {
      ...DEFAULT_CONFIG,
      ...config,
    };

    if (!this.config.apiKey) {
      throw new Error('evald: apiKey is required');
    }
    if (!this.config.agentId) {
      throw new Error('evald: agentId is required');
    }

    if (this.config.batching) {
      this.startFlushTimer();
    }

    this.log('Initialized with agentId:', this.config.agentId);
  }

  /**
   * Track a telemetry event
   */
  track(event: TelemetryEvent): void {
    const queuedEvent: QueuedEvent = {
      ...event,
      timestamp: event.timestamp || new Date().toISOString(),
      retryCount: 0,
    };

    if (this.config.batching) {
      this.queue.push(queuedEvent);
      this.log('Event queued:', event.type, `(queue size: ${this.queue.length})`);

      if (this.queue.length >= this.config.batchSize) {
        this.flush();
      }
    } else {
      this.sendEvents([queuedEvent]);
    }
  }

  /**
   * Track task completion
   */
  trackTaskCompletion(data: {
    taskId: string;
    success: boolean;
    durationMs?: number;
    metadata?: Record<string, unknown>;
  }): void {
    this.track({
      type: 'task_completion',
      data,
    });
  }

  /**
   * Track an error
   */
  trackError(error: Error | string, metadata?: Record<string, unknown>): void {
    const errorData = error instanceof Error
      ? { message: error.message, name: error.name, stack: error.stack }
      : { message: error };

    this.track({
      type: 'error',
      data: { ...errorData, ...metadata },
    });
  }

  /**
   * Track agent start
   */
  trackStart(metadata?: Record<string, unknown>): void {
    this.track({
      type: 'agent_start',
      data: metadata,
    });
  }

  /**
   * Track agent stop
   */
  trackStop(metadata?: Record<string, unknown>): void {
    this.track({
      type: 'agent_stop',
      data: metadata,
    });
  }

  /**
   * Flush all queued events immediately
   */
  async flush(): Promise<void> {
    if (this.queue.length === 0 || this.isFlushing) {
      return;
    }

    this.isFlushing = true;
    const events = this.queue.splice(0, this.config.batchSize);

    try {
      await this.sendEvents(events);
      this.log('Flushed', events.length, 'events');
    } catch (error) {
      // Re-queue failed events that haven't exceeded retry limit
      const retryableEvents = events
        .map(e => ({ ...e, retryCount: e.retryCount + 1 }))
        .filter(e => e.retryCount < this.config.maxRetries);

      if (retryableEvents.length > 0) {
        this.queue.unshift(...retryableEvents);
        this.log('Re-queued', retryableEvents.length, 'events for retry');
      }
    } finally {
      this.isFlushing = false;
    }
  }

  /**
   * Shutdown the telemetry client, flushing remaining events
   */
  async shutdown(): Promise<void> {
    this.stopFlushTimer();
    await this.flush();
    this.log('Shutdown complete');
  }

  private async sendEvents(events: QueuedEvent[]): Promise<void> {
    const payload = {
      agentId: this.config.agentId,
      events: events.map(({ retryCount, ...event }) => event),
    };

    const response = await this.fetchWithRetry(this.config.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.config.apiKey}`,
        'X-Agent-Id': this.config.agentId,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error(`Telemetry API error: ${response.status} ${response.statusText}`);
    }
  }

  private async fetchWithRetry(
    url: string,
    options: RequestInit,
    attempt = 1
  ): Promise<Response> {
    try {
      return await fetch(url, options);
    } catch (error) {
      if (attempt >= this.config.maxRetries) {
        throw error;
      }

      const backoffMs = Math.min(1000 * Math.pow(2, attempt - 1), 10000);
      this.log(`Retry attempt ${attempt} after ${backoffMs}ms`);

      await this.sleep(backoffMs);
      return this.fetchWithRetry(url, options, attempt + 1);
    }
  }

  private startFlushTimer(): void {
    this.flushTimer = setInterval(() => {
      this.flush();
    }, this.config.flushInterval);

    // Unref to not keep process alive
    if (typeof this.flushTimer.unref === 'function') {
      this.flushTimer.unref();
    }
  }

  private stopFlushTimer(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  private log(...args: unknown[]): void {
    if (this.config.debug) {
      console.log('[evald]', ...args);
    }
  }
}

/**
 * Create a telemetry client instance
 */
export function createTelemetry(config: TelemetryConfig): EvaldTelemetry {
  return new EvaldTelemetry(config);
}

export default EvaldTelemetry;
