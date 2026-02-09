/**
 * Evald.ai JavaScript SDK
 * Lightweight telemetry client for AI agent monitoring
 */

class EvaldClient {
  constructor(options = {}) {
    this.apiKey = options.apiKey || process.env.EVALD_API_KEY;
    this.baseUrl = options.baseUrl || 'https://api.evald.ai/v1';
    this.agentId = options.agentId;
    this.batchSize = options.batchSize || 10;
    this.flushInterval = options.flushInterval || 5000;
    this._queue = [];
    this._timer = null;
  }

  async trackEvent(eventType, data = {}) {
    const event = {
      type: eventType,
      agentId: this.agentId,
      timestamp: new Date().toISOString(),
      ...data
    };
    
    this._queue.push(event);
    
    if (this._queue.length >= this.batchSize) {
      await this.flush();
    } else if (!this._timer) {
      this._timer = setTimeout(() => this.flush(), this.flushInterval);
    }
    
    return event;
  }

  async trackCompletion(taskId, result) {
    return this.trackEvent('completion', {
      taskId,
      success: result.success,
      duration: result.duration,
      tokens: result.tokens
    });
  }

  async trackError(taskId, error) {
    return this.trackEvent('error', {
      taskId,
      errorType: error.name || 'Error',
      message: error.message
    });
  }

  async flush() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
    
    if (this._queue.length === 0) return;
    
    const events = this._queue.splice(0, this._queue.length);
    
    try {
      const response = await fetch(`${this.baseUrl}/telemetry/events`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        body: JSON.stringify({ events })
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (error) {
      // Re-queue events on failure
      this._queue.unshift(...events);
      console.error('[Evald] Failed to send events:', error.message);
    }
  }

  async getScore() {
    const response = await fetch(`${this.baseUrl}/agents/${this.agentId}/score`, {
      headers: { 'Authorization': `Bearer ${this.apiKey}` }
    });
    return response.json();
  }
}

module.exports = { EvaldClient };
