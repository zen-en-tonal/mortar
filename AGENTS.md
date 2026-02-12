# AGENTS.md

This document describes how to work effectively in this Elixir codebase as an automated agent (or a human contributor). Follow these guidelines to keep changes consistent, testable, and safe.

## Project overview

- Language: Elixir
- Web framework: None (this project does **not** use Phoenix)
- Database access: Ecto (schemas, migrations, repos, queries, transactions)
- Primary goals:
  - Maintain correctness and data integrity
  - Keep domain logic separate from persistence concerns
  - Prefer explicit, test-driven changes

## Repository layout (expected)

Common paths in this repo may include:

- `lib/`
  - Application code
  - Context modules (domain/persistence boundaries)
  - Ecto schemas, changesets, queries
- `priv/repo/migrations/`
  - Ecto migrations
- `test/`
  - ExUnit tests
  - Fixtures/factories (if used)
- `config/`
  - `config.exs`, `dev.exs`, `test.exs`, `runtime.exs`

If the actual layout differs, adapt these conventions to the existing structure—do not reorganize directories unless explicitly requested.

## Development workflow

### Commands

Run these commands from the repo root:

- Fetch deps:
  - `mix deps.get`
- Compile:
  - `mix compile`
- Run tests:
  - `mix test`
- Format:
  - `mix format`
- Static checks (if configured):
  - `mix credo`
  - `mix dialyzer`

If the repo uses different tooling, prefer existing scripts/aliases in `mix.exs` and `README`.

### Local database setup (Ecto)

Typical Ecto tasks (may vary by project):

- Create DB: `mix ecto.create`
- Run migrations: `mix ecto.migrate`
- Reset DB: `mix ecto.reset`
- Rollback: `mix ecto.rollback`

In tests, prefer the configured SQL sandbox strategy (commonly `Ecto.Adapters.SQL.Sandbox`) and avoid non-deterministic test ordering.

## Code conventions

### Modules and boundaries

Keep a clear separation between:

- **Domain logic**: pure functions and business rules (no DB calls)
- **Persistence**: Ecto schemas, changesets, queries, Repo operations
- **Service/orchestration**: transactions, cross-aggregate operations, background jobs (if any)

Prefer a “context-like” style even without Phoenix:

- Put high-level operations in `Mortar.*` context modules (e.g., `Mortar.Users`, `Mortar.Billing`)
- Keep schemas in `Mortar.*.<Schema>` or `Mortar.Schemas.*` (match existing code)

Do not introduce a Phoenix-style `MortarWeb` namespace.

### Ecto schemas & changesets

- Always define a `changeset/2` (or multiple) per schema for validated writes.
- Use `Ecto.Changeset` validations and constraints:
  - `validate_required/2`, `validate_length/3`, `validate_number/3`, etc.
  - `unique_constraint/3`, `foreign_key_constraint/3`, `check_constraint/3`
- Keep changesets focused:
  - Prefer separate changesets for create/update if rules differ.
- Avoid embedding business rules inside migrations; enforce them in changesets and (when needed) DB constraints.

### Queries

- Prefer composable query functions:
  - `base_query/0` + modifiers like `by_email/2`, `active/1`, `for_account/2`
- Avoid fetching too much data:
  - Use `select`, `preload`, `limit`, `order_by` intentionally.
- Use `Repo.exists?/1`, `Repo.aggregate/4`, and `Repo.one/2` appropriately.
- Handle “not found” explicitly:
  - Prefer `Repo.get/3` + explicit error handling rather than `Repo.get!/3` in library/business code (exceptions are fine in CLI scripts).

### Transactions

- Use `Repo.transaction/2` for multi-step writes.
- Prefer `Ecto.Multi` for complex workflows.
- Ensure each transaction returns a clear success/error shape (see “Error handling”).

### Migrations

- Migrations must be **backwards-safe** where possible:
  - Add nullable columns before backfilling, then add NOT NULL
  - Add indexes concurrently if supported/desired (depends on adapter)
- Always include indexes and constraints that match application expectations:
  - Uniques, FKs, checks as needed
- Do not change existing migration files after they’ve been merged/applied; create new migrations.

## Error handling

Use explicit return values and consistent shapes:

- For write operations:
  - `{:ok, result}` on success
  - `{:error, %Ecto.Changeset{}}` for validation/constraint failures
  - `{:error, reason}` for other failures (atoms or structured errors)

Avoid raising exceptions for expected invalid input paths.

If an existing error convention exists in the codebase, follow it.

## Testing guidelines

- Prefer unit tests for pure domain logic.
- Prefer integration tests for Repo interactions.
- Tests must be deterministic:
  - No timing dependencies
  - Avoid global state leaks
- If using the SQL sandbox:
  - Ensure tests that touch the DB check out a connection and run in transactions.
- Use factories/fixtures if the project has them; otherwise create minimal records with clear helpers.

When changing DB behavior:
- Add/adjust migrations
- Update schema + changeset
- Add/adjust tests that cover:
  - Happy path
  - Constraint failures
  - Edge cases around NULL/defaults/index uniqueness

## Logging & observability

- Keep logs structured and low-noise.
- Do not log secrets (API keys, tokens, passwords, raw credentials).
- If telemetry is used, follow existing event naming patterns.

## Security & data safety

- Never interpolate untrusted input into raw SQL.
- Prefer Ecto query APIs; if `fragment/1` is required, keep it minimal and parameterized.
- Ensure access control/authorization (if any exists) is enforced at the boundary module level.
- Avoid mass assignment:
  - Use explicit `cast/4` field lists, never `cast(params, Map.keys(params))`.

## Agent operating rules

When making changes:

1. **Read before writing**: inspect existing patterns in nearby modules.
2. **Small, cohesive commits**: one feature/fix per change set.
3. **Keep code formatted**: run `mix format` on modified files.
4. **Update tests**: include tests for new behavior; don’t weaken assertions to “make tests pass.”
5. **Avoid speculative refactors**: no renames/restructures unless requested or clearly necessary.
6. **Document decisions**: if behavior changes or constraints are introduced, update docs/comments where appropriate.

### PR / change description checklist

Include in the change summary:

- What behavior changed and why
- Schema/migration notes (if any)
- Testing performed (`mix test`, plus any focused tests)
- Any operational concerns (backfills, long-running migrations, required config changes)

## Common patterns (templates)

### “Context-style” API shape

- `list_*` for collections
- `get_*` / `fetch_*` for single records
- `create_*` / `update_*` / `delete_*` for writes

Return values should be consistent (`{:ok, _}` / `{:error, _}`).

### Example transaction shape

- Use `Ecto.Multi` to compose steps:
  - validate inputs
  - insert/update main record
  - insert/update dependent records
  - return final result in a stable shape

### Map / Keyword transparency

- Use `get_in/2`, `put_in/3`, `update_in/3` and `pop_in/2` for nested structures.


(Use the project’s existing style; do not introduce new patterns without necessity.)

