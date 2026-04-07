---
name: api-documentation-style
description: Use this skill when writing, reviewing, or modifying documentation strings (docstrings, JSDoc, GraphQL descriptions, OpenAPI descriptions, etc.) that are publicly accessible via an API to a consumer. This includes REST endpoints, GraphQL types/fields/mutations/queries, SDK methods, and any other public-facing API surface.
---

# API Documentation Style Guide

These rules MUST be followed whenever writing or reviewing documentation strings that are publicly accessible via an API.

## Formatting References

- When referencing API elements (objects, models, types, URLs, mutations, actions, properties, fields, endpoints, queries), always use backticks. Examples:
  - `/v1/user`
  - `Query.user`
  - a `User` type response
  - the `email` field
  - the `createUser` mutation

- When referencing string literals (error codes, enum values, status strings), wrap them in backticks AND double quotes. Examples:
  - `"BAD_REQUEST"`
  - `"ACTIVE"`
  - `"pending_verification"`

## Documentation Content

- Every type and field MUST be documented unless its purpose is extremely obvious.
- Documentation MUST NOT repeat the type or field name. Describe what it represents or does, not what it is called.
- Documentation MUST explain the thing it is documenting — its purpose, behavior, or meaning.

## Prohibited Content

- NEVER reference internal implementation details in API documentation. This includes:
  - Database table names, column names, or values
  - Internal service names or architecture
  - Implementation-specific details that are not relevant to the API consumer
