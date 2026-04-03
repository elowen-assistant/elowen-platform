# Elowen Operations

## Local Runtime

- Start the stack with `docker compose -f elowen-platform/compose/docker-compose.yml up --build -d`.
- Stop the stack with `docker compose -f elowen-platform/compose/docker-compose.yml down`.
- VPS deploys should pull prebuilt GHCR images with `docker compose pull` and then `docker compose up -d`.
- The default local endpoints are:
  - API: `http://localhost:8080`
  - UI: `http://localhost:3000`
  - Notes: `http://localhost:8081`
  - ArangoDB: `http://localhost:8529`
  - NATS monitoring: `http://localhost:8222`

## Health Checks

- `GET /health` is available on `elowen-api` and `elowen-notes`.
- UI availability is validated with an HTTP 200 on `/`.
- `docker compose ps` should show Postgres as healthy before the API starts.
- Workflow #2 conversational replies require `OPENAI_API_KEY` plus reachable outbound HTTPS from `elowen-api` to the configured assistant base URL.

## Log Shape

- `ELOWEN_LOG_FORMAT=json` enables structured JSON logs in `elowen-api`, `elowen-edge`, and `elowen-notes`.
- Omit the variable or set it to `plain` for human-oriented local logs.
- `RUST_LOG` controls filtering in the Rust services.

## Correlation IDs

- Each job now owns a durable `correlation_id`.
- The `correlation_id` is created by `elowen-api` when the job is created.
- The same `correlation_id` is propagated through:
  - job dispatch messages
  - edge lifecycle events
  - persisted `job_events`
  - approval resolution events
- When troubleshooting a single execution chain, use the `correlation_id` from the UI job detail or the `jobs` table and filter logs/events around that value.

## Audit Surfaces

- Persistent job audit trail: `job_events`
- Current job execution state: `jobs`
- Approval gate history: `approvals`
- Generated summaries: `summaries`

## Troubleshooting

- If the UI appears frozen, verify the page is serving the static nginx build and reload after rebuilds.
- If a VPS deploy fails to start updated services, verify the requested GHCR tags exist and that the VPS can authenticate to `ghcr.io` if the packages are private.
- If `cargo check` fails on Windows with linker errors, load `vcvars64.bat` before running Rust commands.
- If note promotion fails, check `elowen-notes` logs first and verify ArangoDB is reachable on the configured URL.
- If conversational replies stop working, inspect `elowen-api` logs and verify `OPENAI_API_KEY`, `ELOWEN_ASSISTANT_MODEL`, and `ELOWEN_ASSISTANT_BASE_URL`.
- If dispatch stalls at probing or dispatched, inspect:
  - `elowen-edge` logs
  - `elowen.jobs.dispatch.{device_id}`
  - `elowen.jobs.events`

## Promotion Path

1. Create a thread and job in the UI or API.
2. Wait for the job to reach `awaiting_approval` or `completed`.
3. Promote the summary to notes from the job detail view.
4. Verify the promoted note appears in both:
  - the job detail related notes list
  - the parent thread related notes list
