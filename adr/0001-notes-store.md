# ADR 0001: `elowen-notes` uses ArangoDB, with MongoDB portability constraints

## Status

Accepted

## Decision

`elowen-notes` will use ArangoDB as its primary store.

## Why

- Notes are best modeled as documents with explicit links between them.
- Obsidian-like backlinks and connected-note traversal map naturally to graph edges.
- ArangoSearch provides a built-in retrieval path for Markdown content and note metadata.

## Portability constraints

To preserve a realistic migration path to MongoDB later:

- application identifiers stay explicit (`note_id`, `revision_id`, `attachment_id`) and do not rely on Arango `_key` generation as domain identity
- the `elowen-notes` service API owns all query semantics; callers do not issue AQL directly
- graph relations are modeled as explicit edge records (`note_links`, `note_sources`) that can be migrated to Mongo collections
- full-text and ranking behavior stays behind the service boundary
- note documents store Markdown as data (`body_markdown`) rather than depending on Arango-specific content transforms

## Consequences

- ArangoDB becomes an additional infrastructure component in local and future cluster deployments.
- `elowen-notes` can exploit document + graph + search features now.
- A future MongoDB migration remains feasible, but it will still require re-implementing search and traversal internals behind the same service contract.
