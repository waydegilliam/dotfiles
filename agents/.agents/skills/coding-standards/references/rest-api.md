# REST API Design

Use this guide for REST APIs organized by entity, such as users, projects, or documents. Follow the backend's existing
structure and naming rules.

## Code Structure

Keep each entity's code together, for example under `entity/<name>/`, so it is easy to find and change. Use file names
that fit the language and project. Split these parts into separate files only when it helps.

| Part                    | What belongs here                                                              |
| ----------------------- | ------------------------------------------------------------------------------ |
| Models and schemas      | Stored fields, links to other records, data rules, and input and output types. |
| Services                | Read and write data, apply business rules, and reuse existing data helpers.    |
| Setup and access checks | Set up services, load records, and check who can use them.                     |
| Routes or controllers   | Read requests, call services, and return responses or HTTP errors.             |
| Query helpers           | Share complex database queries. Keep simple queries in the service.            |

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

## File Structure Example: Document Management

This Python example manages documents, their file revisions, and imports from external systems. A `file` is the
document's stable identity, with a title, owner, and access rules. A `file_revision` represents one content version,
with a storage reference, checksum, and processing status. Only selected files are shown; use the names and tools
that fit the backend.

```text
backend/src/app/
├── main.py
├── auth/
├── database/
├── clients/
│   ├── aws.py
│   ├── google_drive.py
│   ├── sharepoint.py
│   └── turbopuffer.py
└── entity/
    ├── file/
    │   ├── models.py
    │   ├── service.py
    │   ├── routes.py
    │   └── dependencies.py
    ├── file_revision/
    │   ├── models.py
    │   ├── service.py
    │   ├── routes.py
    │   └── dependencies.py
    ├── integration/
    │   ├── models.py
    │   └── service.py
    ├── drive_connection/
    │   ├── models.py
    │   ├── service.py
    │   └── routes.py
    └── sharepoint_connection/
        ├── models.py
        ├── service.py
        └── routes.py
```

### Entities and API Routes

`main.py` registers the API routes. Shared authentication and database setup live in `auth/` and `database/`.

| Area                     | Responsibility                                                                                                                                                |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `file/`                  | Owns document metadata, access rules, and the current revision reference. Exposes `/files` endpoints.                                                         |
| `file_revision/`         | Owns version history, stored content references, and processing state. Exposes `/files/{file_id}/revisions` endpoints.                                        |
| `integration/`           | Owns shared integration identity, organization ownership, and external document mappings. Reuses file and revision services when importing changes.           |
| `drive_connection/`      | Owns Google Drive connection settings, credential references, selected drives or folders, and sync cursors. Exposes connection setup and sync routes.         |
| `sharepoint_connection/` | Owns SharePoint connection settings, credential references, selected sites or document libraries, and sync cursors. Exposes connection setup and sync routes. |

Each provider connection belongs to an integration. Its service handles provider-specific setup and sync state,
then passes imported documents to the shared integration service for file and revision creation.

Within each entity, `models.py` separates stored records, service inputs, request inputs, and public responses.
`service.py` owns data operations and business rules. `routes.py` handles HTTP requests and responses, while
`dependencies.py` builds services, loads records, and checks access. Revision access follows the parent file's rules;
loading a revision also checks that it belongs to the requested file.

Keep a revision's original content unchanged; new content creates a new revision. Processing status and derived
outputs, such as extracted text and previews, can change independently. Allocate revision numbers atomically and
enforce uniqueness per file so concurrent uploads cannot create conflicting versions.

### Client Integrations

- `clients/aws.py` wraps [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) operations
  for storing and retrieving file content, previews, and extracted text.
- `clients/google_drive.py` wraps the [Google Drive API](https://developers.google.com/workspace/drive/api/guides/about-sdk)
  for listing and downloading files. Its connection entity owns which drives and folders to sync.
- `clients/sharepoint.py` wraps [Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/sharepoint)
  operations for SharePoint sites, document libraries, and files. Its connection entity owns which sources to sync.
- `clients/turbopuffer.py` writes document text, vectors, and metadata to [turbopuffer](https://turbopuffer.com/docs)
  and runs search queries. Entity services define indexed fields and access filters.

Keep clients focused on provider operations. Entity services own application rules, such as which account can import
a document. Track imported versions by connection, external document ID, and external version ID so repeated syncs
do not create duplicate revisions.

### Example: Adding a File Revision

For `POST /files/{file_id}/revisions`:

1. The route accepts `FileRevisionCreateRequestData` referring to a completed upload. Dependencies check file edit
   access and verify that the upload belongs to the current organization.
2. The route builds `FileRevisionCreate` and calls `FileRevisionService.create`. The service creates a pending
   revision and records its processing request in the same transaction.
3. The API returns `FileRevisionPublic` with processing status without waiting for extraction and indexing.

External imports use the same revision creation and processing path. Add other modules, such as shared query helpers
or separate permission rules, only when the entity needs them.
