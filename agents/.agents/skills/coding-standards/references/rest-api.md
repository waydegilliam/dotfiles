# REST API Design

Use this guide for REST APIs organized by entity, such as users, projects, or documents. Follow the backend's existing
structure and naming rules.

## Code Structure

Keep each entity's code together, for example under `entity/<name>/`, so it is easy to find and change. Use file names
that fit the language and project. Split these parts into separate files only when it helps.

| Part | What belongs here |
| --- | --- |
| Models and schemas | Stored fields, links to other records, data rules, and input and output types. |
| Services | Read and write data, apply business rules, and reuse existing data helpers. |
| Setup and access checks | Set up services, load records, and check who can use them. |
| Routes or controllers | Read requests, call services, and return responses or HTTP errors. |
| Query helpers | Share complex database queries. Keep simple queries in the service. |

Keep shared database setup, authentication, and common types and helpers outside entity folders. Add only the parts
an entity needs. An internal entity may need models and services without API routes.

## Inputs, Outputs, and Rules

- Define stored data, service inputs, request inputs, and public responses separately. Use the language's usual types
  and validation tools. Expose only the fields clients should read or change.
- Check request data before passing it to a service. Get server-owned values, such as the current user or organization,
  from trusted context. Check access to related records before using their IDs.
- For updates, change only fields the caller sent. A missing field is different from a field set to null.
- Keep business rules and database work in services so routes and background jobs can reuse them. Keep HTTP handling
  in routes or controllers. Share record loading and access checks where needed.

## Stored and Calculated Data

- Calculate values from existing records when those records are complete and reliable. Avoid storing a second copy
  of the same information just because another API returns it.
- Check for missing records, filters, or a need to preserve past values before choosing to calculate a value. Store
  calculated values when speed or consistent results require it, following the backend's existing approach.
- When a value should not be stored, keep it out of the storage model, create/update inputs, database writes, and
  migrations. It can still appear in a response.
- For example, count a collection's stored documents instead of saving a separate document count, if those records
  include every document the count should cover.

## File Structure Example: Argos Matters

In Argos, a matter brings together owners, source files and messages, activity, and access rules. The example below
shows its Python files. The same roles apply in other languages; use the names and tools that fit the backend.
Only the relevant parts of `argos-api` are shown.

```text
argos-api/src/argos_api/
├── main.py
├── auth/
├── database/
├── dependencies.py
├── models.py
├── service.py
├── audited_service.py
├── entity/
│   ├── matter/
│   │   ├── models.py
│   │   ├── service.py
│   │   ├── routes.py
│   │   ├── dependencies.py
│   │   ├── permissions.py
│   │   ├── queries.py
│   │   ├── source_registry.py
│   │   ├── source_inputs.py
│   │   ├── source_mutation.py
│   │   ├── namespace.py
│   │   ├── namespace_v2.py
│   │   ├── initial_product_review_workflow.py
│   │   ├── sales_contract_review_workflow.py
│   │   ├── termination_workflow.py
│   │   ├── workflow_intake_document.py
│   │   └── utils.py
│   ├── matter_access/
│   ├── matter_activity/
│   ├── matter_comment/
│   ├── matter_custom_field/
│   └── matter_queue_item/
└── worker/workflows/
    ├── matter_mutate/
    └── matter_index/
```

### Shared Code

- `main.py` registers the entity routes with the app.
- `auth/` handles shared authentication and permissions. `database/` sets up database access.
- The top-level `dependencies.py` supplies database sessions and the background-work client to request handlers.
- The top-level `models.py`, `service.py`, and `audited_service.py` provide common types, database operations, and
  audit logging. Entities reuse them so they handle common work in the same way.
- Related entities have their own folders. For example, `matter_comment/` owns comment code and `matter_access/`
  owns matter access checks. The matter routes include several of these related routes under `/matters`.
- `worker/workflows/` runs background work, such as processing matter sources and updating the search index.

### Main Matter Modules

These files all live in `entity/matter/`.

| Module | What it does | Why it is separate |
| --- | --- | --- |
| `models.py` | Defines the stored `Matter`, its source links, and input and output types. `MatterCreate` and `MatterUpdate` are service inputs; `MatterCreateRequestData` and `MatterUpdateRequestData` are client inputs; `MatterPublic` is a response type. | Keeps data definitions together while separating what the database stores from what clients can send or see. |
| `service.py` | Defines `MatterService`: creates and updates matters, links sources, lists records, and calculates access levels. Closing a matter sets its close time; deleting one also marks its action items as deleted. | Gives routes and background jobs a shared place for matter operations and rules. |
| `routes.py` | Defines `/matters` endpoints for creating, listing, reading, changing, and deleting matters, plus source and queue actions. Calls services and starts background work. | Keeps request handling, HTTP responses, and the steps for each API action together. |
| `dependencies.py` | Builds `MatterService` with a database session and audit context. Loads matters, rejects deleted or wrong-organization records, and prepares list filters. | Reuses setup and record checks across endpoints. |
| `permissions.py` | Defines the rule for who can change a matter's owner. Routes also use it when changing privileged status. | Keeps that decision in a small function that is easy to read and reuse. |
| `queries.py` | Builds shared database queries for matter links, access checks, topics, and source counts. | Keeps complex queries reusable and out of request handlers. |

### Source Modules

A source is a file, message, or other record used to build a matter.

| Module | What it does | Why it is separate |
| --- | --- | --- |
| `source_registry.py` | Maps each source kind to its model, link table, document kind, and display label. | Gives source-handling code one place to find these mappings. |
| `source_inputs.py` | Turns uploads, existing source IDs, and selected external files into inputs for background processing. Checks external connections and saves uploads. | Lets create and source-edit routes share the same input handling. |
| `source_mutation.py` | Checks source removals, prevents removing the last source without adding another, and cleans up file links and activity citations. | Keeps source-removal rules and cleanup together. |

### Search, Special Flows, and Helpers

| Module | What it does | Why it is separate |
| --- | --- | --- |
| `namespace.py` | Defines matter fields and filters for a search index, including text and access fields. | Keeps the search data layout separate from the database model. |
| `namespace_v2.py` | Defines the V2 search index fields, including vectors used for similarity search. | Gives that index version its own definition. |
| `initial_product_review_workflow.py` | Accepts product-review intake data and files, creates a queued matter, and starts processing. | Keeps this special create flow out of the general matter routes. |
| `sales_contract_review_workflow.py` | Accepts sales-contract intake data and files. Starts a selected contract-review workflow when provided with attachments, or starts general matter processing. | Keeps contract-specific choices and setup together. |
| `termination_workflow.py` | Accepts employment-termination intake data and files, creates a queued matter, and starts processing. | Keeps this special create flow in one place. |
| `workflow_intake_document.py` | Turns the intake data for those three flows into Word documents. | Keeps document formatting out of request handling. |
| `utils.py` | Converts source references, finds source messages, and updates stored workflow status to match the background job. | Shares small matter-specific helpers across callers. |

The three special `*_workflow.py` files above define API routes that start work. The background jobs they start live
under `worker/workflows/`. A simpler entity may need only models, a service, and routes.

### Example: Updating a Matter

For `PATCH /matters/{matter_public_id}`:

1. The route accepts `MatterUpdateRequestData`. Dependencies load the matter and check the user's organization and
   edit access.
2. The route checks owner-change rules in `permissions.py` when needed. It resolves an owner's public ID to an
   internal ID and keeps only the fields the caller sent.
3. The route builds `MatterUpdate` and calls `MatterService.update`. The service applies matter rules, saves the
   changes, and uses the shared audit service to record them.
4. If ownership or privileged status changed, the route updates search access fields. It starts a search-index update
   for a matter that has not been deleted, then returns `MatterPublic`.

This split gives each part a clear job: models define the data, dependencies load it, services change it, and routes
handle the HTTP request and response.
