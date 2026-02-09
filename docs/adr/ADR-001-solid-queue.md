# ADR-001: Use Solid Queue for Background Jobs

## Status: Accepted

## Context
Need reliable background job processing for GitHub scraping.

## Decision
Use Solid Queue (Rails 8 default) over Sidekiq.

## Consequences
- Simpler setup (no Redis required for jobs)
- Built-in scheduling
- Slightly less mature than Sidekiq
