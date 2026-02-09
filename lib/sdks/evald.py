"""
Evald.ai Python SDK
Lightweight telemetry client for AI agent monitoring
"""

import os
import time
import json
import threading
from datetime import datetime
from typing import Optional, Dict, Any, List
import urllib.request
import urllib.error


class EvaldClient:
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = "https://api.evald.ai/v1",
        agent_id: Optional[str] = None,
        batch_size: int = 10,
        flush_interval: float = 5.0
    ):
        self.api_key = api_key or os.environ.get("EVALD_API_KEY")
        self.base_url = base_url
        self.agent_id = agent_id
        self.batch_size = batch_size
        self.flush_interval = flush_interval
        self._queue: List[Dict] = []
        self._lock = threading.Lock()
        self._timer: Optional[threading.Timer] = None
    
    def track_event(self, event_type: str, data: Optional[Dict] = None) -> Dict:
        event = {
            "type": event_type,
            "agentId": self.agent_id,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            **(data or {})
        }
        
        with self._lock:
            self._queue.append(event)
            
            if len(self._queue) >= self.batch_size:
                self._flush_sync()
            elif self._timer is None:
                self._timer = threading.Timer(self.flush_interval, self._flush_sync)
                self._timer.start()
        
        return event
    
    def track_completion(self, task_id: str, result: Dict) -> Dict:
        return self.track_event("completion", {
            "taskId": task_id,
            "success": result.get("success"),
            "duration": result.get("duration"),
            "tokens": result.get("tokens")
        })
    
    def track_error(self, task_id: str, error: Exception) -> Dict:
        return self.track_event("error", {
            "taskId": task_id,
            "errorType": type(error).__name__,
            "message": str(error)
        })
    
    def flush(self):
        self._flush_sync()
    
    def _flush_sync(self):
        with self._lock:
            if self._timer:
                self._timer.cancel()
                self._timer = None
            
            if not self._queue:
                return
            
            events = self._queue[:]
            self._queue.clear()
        
        try:
            self._send_events(events)
        except Exception as e:
            with self._lock:
                self._queue = events + self._queue
            print(f"[Evald] Failed to send events: {e}")
    
    def _send_events(self, events: List[Dict]):
        url = f"{self.base_url}/telemetry/events"
        data = json.dumps({"events": events}).encode("utf-8")
        
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}"
            }
        )
        
        with urllib.request.urlopen(req) as resp:
            if resp.status >= 400:
                raise Exception(f"HTTP {resp.status}")
    
    def get_score(self) -> Dict:
        url = f"{self.base_url}/agents/{self.agent_id}/score"
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {self.api_key}"}
        )
        
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    
    def __enter__(self):
        return self
    
    def __exit__(self, *args):
        self.flush()
