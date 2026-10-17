---
name: typescript-architect
description: Architecture, naming, and testing conventions guidelines for architecting TypeScript codebases. Use when writing, reviewing, or refactoring TypeScript code: creating a new module or file, adding a repository/port/service/entity/value object, adding an HTTP route or CLI command, deciding where a new .ts file goes, or writing/naming TypeScript tests.
---

# Philosophy

We try to follow a Domain Driven Design (DDD) approach with hexagonal architecture (aka ports and adapters) with some opinionated decisions. We try to follow clean architecture and we give a lot of importance to tests. Code is as functional as possible: a pure core (domain logic), effects pushed to the edges (HTTP, SQLite, external processes).

# Layers

We structure our code in three layers: application, domain, and infrastructure.

## Application Layer

This is the entry point to the application, the most common case will be HTTP routes (Hono) but it can also be a CLI, subscribers (consuming domain events), scheduled tasks, etc. The main responsibility of this layer is to **VALIDATE** entry data and **TRANSFORM** it into domain types. For HTTP this layer parses requests, validates them with Zod schemas (returning 400 automatically via the validator), calls the domain layer, and maps the domain result into a response DTO with the correct HTTP status code.

## Domain Layer

This is where the core **BUSINESS LOGIC** of the application lives. It is composed of entities, value objects, domain services, and domain events. The main responsibility of this layer is to implement the business rules and logic of the application and **ORCHESTRATE** calls to the ports in the infrastructure layer. It must not depend on HTTP, SQLite, or any adapter technology. Allowed dependencies are the "language-extension" libraries only: `zod` (types are inferred from schemas) and `better-result` (errors as values).

## Infrastructure Layer

This layer is responsible for implementing ports and **COMMUNICATING WITH EXTERNAL SYSTEMS**. Most of the time we will be coding repositories to access the database (Kysely over SQLite), but clients to external APIs and process wrappers (e.g. ffmpeg/ffprobe) are implemented here too. As a convention, even if this is not entirely correct because this should go in the domain layer, we place the port interface in infrastructure, in the same file as its implementation, because it's convenient when adding new methods. `repositories/` holds one aggregate's dedicated port implementation (a port injected into a single aggregate's domain service); `shared/` holds infra usable across aggregates, regardless of whether it's a port (e.g. the clock, the domain-event outbox) — see the file structure below.

We must not hide behaviour in this layer: repositories should be as simple as possible and behave like collections with methods like `find`, `findById`, `save`, `delete`, etc. The domain layer implements the business logic, rules and entity transformations, not the infrastructure layer. No business logic such as domain event publishing in infra, only operations on entities plus optional logging. Write operations such as `save`, `insert`, `update` take the entity as a parameter, not loose properties. `delete` may operate on the entity identifier. Read methods always return entities or collections of entities.

# File Structure and Naming and other opinions

Files are kebab-case, named after the single type/concept they hold. Types are PascalCase, functions camelCase.

```
src/
  domain/
    <aggregate>/
      <value-object>.ts   # one file per value object: Zod schema + inferred type
      <entity>.ts         # schema + type + its transition functions, named after the type
      errors.ts           # every error type for this aggregate (TaggedError classes), together
    services/              # every aggregate's use-case services, together, flat
      <use-case>.ts         # one domain service per use case, e.g. widget-creator.ts
    shared/
      <shared-vo>.ts        # value objects/types used across aggregates
  application/              # every external entry point (adapters), one subfolder per interface
    http/
      app.ts                 # composes resource routers, error handler, exports AppType for RPC
      <resource>.ts          # one Hono sub-router per resource: routes + request/response DTOs
    cli/                      # only if the project has a CLI
      <command>.ts             # one file per command's orchestration
    subscribers/              # event subscribers, one file per subscriber
      <subscriber>.ts
    tasks/                    # scheduled/background task handlers, one file per task
      <task>.ts
  infrastructure/
    repositories/            # one aggregate's dedicated port implementation
      <implementation>-<port>.ts   # port interface + its implementation, together
    client/                  # port-shaped adapters nothing in domain/ injects
      <port>.ts
    shared/                  # infra usable across aggregates (ports or not)
      <thing>.ts
```

- We prefer not generic names: not `entity.ts`, not `value-objects.ts`, not `ports.ts`, not `types.ts`, not `utils.ts`. A file is named after the single type/concept it holds (`user.ts` holds `User`, `user-id.ts` holds `UserId`). No barrel `index.ts` files re-exporting everything; import from the concrete file.
- `errors.ts` is the one deliberately generic name: every error type for an aggregate (use-case error unions) lives together in one file, not scattered across the files that raise them.
- Every value object gets its own file. Don't bundle multiple value objects into one "value objects" file.
- **Value objects are Zod schemas**: the file exports the schema and the inferred (branded) type, e.g. `export const ChannelHandle = z.string().regex(...).brand('ChannelHandle'); export type ChannelHandle = z.infer<typeof ChannelHandle>;`. Validation rules live in the schema, nowhere else. The application layer composes these schemas into request schemas, so a parse failure becomes a 400 at the boundary and domain services receive already-validated branded types. There is no per-VO error class: the Zod issue message is the validation error.
- **Entities are immutable**: a schema plus an inferred type with transition functions in the same file. A transition takes the entity and returns a new one via object spread (`{ ...video, thumbnail }`), never mutates. Name such a function `with<Field>` when it simply sets one field (e.g. `withThumbnail`); reserve a verb-based name (`markDownloaded`, `startDownload`, `resetForRedownload`) for a transition that carries additional domain meaning beyond "set this field". State transitions live in the entity's file, never as behavior-named repository methods and never inlined in domain services operating on anemic data.
- A port is named after the concept it fronts, not the one method it happens to expose (`WidgetRepository`, not `WidgetLookup`, even if today it only has an `exists` method). "Repository" is used loosely for "adapter implementing a domain port," not strictly persistence.
- `infrastructure/repositories/` files are named `<implementation>-<port>.ts` (`sqlite-playlist-repository.ts` implements `PlaylistRepository` with SQLite/Kysely, `ffprobe-media-inspector.ts` implements `MediaInspector` against ffprobe). The prefix signals which technology backs the port. `infrastructure/shared/` and `infrastructure/client/` files are named after the port/thing itself, not this convention.
- A repository/port method either **reads** (returns `Promise<Entity>` / `Promise<Entity[]>` / `Promise<Entity | undefined>`, an entity or collection, never a wrapper/outcome object) or **writes** (returns `Promise<void>`). **Infra failures throw; they are not part of the port's type.** No `Result` on ports, no custom infra error classes: an unexpected SQLite or network failure is an exception that propagates to the adapter's top-level error handler (→ 500). A repository always returns the entities its name implies (`UserRepository` returns `User`).
- Business-meaningful outcomes that look like they belong in the repository (e.g. "was this newly created, or did it already exist?") are decided in the domain service, not returned by infra: call `find`, branch on `undefined`, then call `insert`/`save`. This trades DB-level atomicity for keeping business logic out of infra — a known, accepted race window, not an oversight.
- Optional values are native `T | undefined` (with `strict` + `noUncheckedIndexedAccess`), never `null`, never a custom `Option` type.
- **Export ordering**: within a file, order is: supporting types and constants, then the exported interface/type, then the exported function(s), then private module-level helpers. Helpers go after the exported code they support, not before.

## Domain Services

A domain service is an **interface plus a factory function**, laid out top to bottom so a reader meets the contract before the implementation:

1. Supporting types the service returns (e.g. an outcome union) and constants.
2. The service's interface: `export interface WidgetCreator` declaring every public operation (doc comments describing the contract go here, on the interface method, not on the implementation).
3. The factory: `export function createWidgetCreator(deps): WidgetCreator` returning an object literal implementing those operations.
4. Private module-level helper functions, never exported.

Domain errors are returned, never thrown: every operation that can fail for a business reason returns `Promise<Result<T, SomeUseCaseError>>` (`better-result`). Errors are `TaggedError` classes living in the aggregate's `errors.ts`, composed into per-use-case unions. Compose steps with `Result.gen` + `yield*`; handle them exhaustively (`matchError` or a `switch` on `_tag` with a `never` check).

Guideline (not a hard rule): every public operation should read at a glance — aim for **10–15 lines of body**. It reads as a sequence of named steps, each step a private helper named for *what* it does. Lookup-or-fail checks, multi-branch outcome handling and event building are the usual candidates to extract. When two branches or two operations share logic, extract it once rather than shrinking each copy. Exceptions are fine for genuinely complex flows (e.g. the scheduler) where splitting further would scatter one coherent algorithm across helpers that only make sense together — prefer readability over the line count.

```ts
export interface WidgetCreator {
  create(id: WidgetId): Promise<Result<Widget, CreateWidgetError>>;
}

export function createWidgetCreator(repository: WidgetRepository, clock: Clock): WidgetCreator {
  return {
    create: (id) =>
      Result.gen(async function* () {
        yield* await ensureAbsent(repository, id);
        const widget = createWidget(id, clock.now());
        await repository.insert(widget);
        return Result.ok(widget);
      }),
  };
}

async function ensureAbsent(repository: WidgetRepository, id: WidgetId): Promise<Result<void, WidgetAlreadyExists>> {
  // ...
}
```

Callers depend on the interface type and receive the instance by injection (built once in the composition root, e.g. `main.ts`); the interface exists to make the contract readable, not to enable mocking.

**Keep the core pure where it can be**: logic that needs no ports (the scheduler, playlist generation) is plain pure functions over immutable data, not a "service" with dependencies. A service orchestrates ports and calls pure functions; the pure functions do the thinking.

- Read models (`*View`, e.g. `TaskView`, `ChannelView`) hold the flat fields they expose, not the entity they're derived from.
- Domain services are call-agnostic: they know nothing about HTTP, CLI, subscribers, or tasks. Adapting any external trigger into a domain call — parsing/validating input, invoking the domain service, mapping its result back — is the application layer's sole responsibility.

## HTTP Routes (Hono)

- One file per resource exporting a factory that takes only the services it uses and returns a Hono sub-router with **chained** route definitions (chaining is what makes the RPC client's types work). `app.ts` composes the sub-routers and exports `AppType` for the frontend's `hono/client`.
- Request validation uses the Zod validator middleware with a request schema composed from the value objects' schemas. An invalid request never reaches the handler; the validator returns the 400.
- A handler body is: take validated input → call the service → map the `Result`. Domain errors are mapped explicitly per tag to a status code, no catch-all arm; exhaustiveness is enforced (`matchError` or `switch` on `_tag` with a `never` default). A mapping repeated across routes gets one small function.
- Unexpected exceptions (infra failures) are handled once by the app-level `onError` (→ 500 with `{"error": ...}`), never per route.
- Responses are typed JSON via `c.json(body, status)` with an explicit status. Every failure body is `{"error": string}`.
- Response DTOs are flat and carry only the fields their consumers use. Never compose one resource's response by spreading another response DTO into it. A genuinely nested JSON object gets its own DTO (a Zod schema in the shared domain package when the frontend consumes it). `toWidgetResponse(widget)` mapping functions live in the resource file.

## Shared domain workspace package

Schemas, inferred types and error classes that the frontend also needs live in the `domain` workspace package, imported by both server and SPA. Domain **services and ports stay in the server package** — the shared package is pure data and validation, with no dependencies beyond `zod`/`better-result`, so the dependency direction stays server → domain ← frontend.

# Testing

Tests are classified by **where they enter the code**, not by what they fake. Our goal is to couple our tests as much as possible to behaviour instead of implementation, so we can refactor the code without breaking the tests.

- **Acceptance tests**: enter through an application adapter (HTTP route, event subscriber, task). The default and by far the most numerous kind.
- **Behaviour tests**: enter through a domain service or pure domain function directly. The exception, reserved for domain logic too complex to cover through an adapter — plus **property-based tests** (fast-check) on the pure core, which are behaviour tests by nature.
- **Value object tests**: exhaustive validation rules, one file per value object.
- **Infrastructure tests**: a single adapter (repository, client) against its real dependency.

Acceptance and behaviour tests follow the same rules for persistence and test doubles (see below): persistence is real, only external dependencies are faked. A Playwright suite (`smoke-tests/`) is the true end-to-end layer (real server, real browser) and lives outside these conventions.

Tests are colocated: `widget-creator.test.ts` next to `widget-creator.ts`. Only introduce a top-level `tests/` directory when a project independently justifies it.

## Acceptance Tests

These test the domain logic and the application-level mapping. For HTTP, build the resource sub-router with its real services and call it with `app.request(...)` (or Hono's `testClient` for typed calls): "I send this request and I expect this response and these collateral effects". For subscribers, publish events and assert the final state of the repositories. Same for tasks.

Every test has the same 7 steps, top to bottom and inline: fresh test database + repositories/fakes → seed them → build the service with its factory → build the app/request → call it → assert the response → assert side effects (repositories, outbox events, scheduled tasks, fake state).

- No fixture objects that bundle fakes/repositories and no `buildService()` → `buildServiceWith()` chains. They hide which dependencies a test uses and make it easy to skip asserting them. The one allowed exception is a constructor helper for a service with many ports no test observes: it takes the asserted repositories as parameters and fills in the rest. A test that observes one of the ports the helper fills in builds the service inline with its factory instead of growing the helper or adding a second one.
- Assert whole values in one `expect(...).toEqual(...)`: the status and the whole parsed body against a complete expected object; `expect(await repository.list()).toEqual([...])`. Never field by field, never `length` alone.
- Requests and expected values are built from a valid default overridden with spread (`{ ...createRequest('@x'), quality: undefined }`).
- Seed state directly into repositories, never by calling another route: a test only exercises the route it names.
- DTO mapping is covered through route responses, not with standalone DTO tests.
- Module layout: imports, then every `it('should ...')` test, then helpers.

A domain service reached from several adapters (e.g. a reconciler called from a task, a subscriber and an HTTP route) has its logic tested exhaustively through one primary adapter, the one that does the recurring work. Every other adapter tests only what differs for it plus one happy path proving the service is wired. When an adapter's call path starts to diverge inside the service, the tests for that difference go in that adapter.

Tests whose request is rejected before reaching the service (validation 400) assert the response only and don't need a seeded database: build the service over an **unmigrated** database, so a request that wrongly got through fails loudly instead of passing.

## Behaviour Tests

Ideally we should not test domain services at all because the logic there is tested from acceptance tests. There could be exceptions for very complex domain logic that is hard to test from the application layer, but this should be the exception and not the rule. When one is justified, it calls the domain service directly and asserts its `Result` plus the final state of the repositories, under the same persistence and fakes rules as acceptance tests. Before adding one, check the acceptance tests of the adapters calling that service don't already cover it.

**Property-based tests are the other sanctioned kind of behaviour test.** Pure domain functions (scheduler, playlist generation) get fast-check properties asserting invariants (e.g. "`MEDIA-SEQUENCE` never goes backwards", "the schedule has no gaps or overlaps") alongside a few example-based tests for readability. Properties call the pure function directly — no database, no fakes.

## Persistence and Test Doubles

**Persistence is real, not faked.** Because our database is an embedded SQLite file (better-sqlite3), which is fast, cheap to create and _is_ the production engine, acceptance and behaviour tests wire the real `Sqlite*` repositories against a fresh database per test instead of fakes. This catches SQL, row-mapping, ordering, upsert and constraint bugs that a hand-written fake silently re-implements (and drifts from). Concretely:

- Every test starts with a fresh database from a `testDatabase()` helper (`infrastructure/shared/`): a freshly migrated database (in-memory or a temp file) with its own Kysely instance, so tests run in parallel without sharing state. No pool of pre-migrated databases: migrating a fresh one costs milliseconds.
- The test database is opened/configured by the same connection code as production (pragmas, WAL when file-backed), so tests exercise the real setup.
- Seed and assert through the port interfaces (`insert`, `list`, `find`, ...), never through raw SQL or Kysely in the test. When a whole-table assertion needs a read the port doesn't have, add a test-only method on the SQLite implementation rather than widening the port for tests.
- Storage-assigned values (autoincrement ids) are deterministic in a fresh database, so assert them as real values rather than masking them.
- Domain events are asserted through the real outbox: the real SQLite event publisher writes them and the test reads them back through the outbox's own repository, comparing whole expected rows. Scheduled tasks likewise through their real repository.

**Fakes are for everything else**: out-of-process or side-effecting dependencies (ffmpeg/ffprobe, outbound HTTP, external APIs, filesystem-backed ports). Fakes are hand-written and as simple as possible — **no mocking library, no `vi.mock`, no spies**. They are state-based (e.g. backed by an array in a closure) and may offer constructors for failure scenarios (e.g. `failingVideoDownloader()`).

The Clock is a port and is faked (`fixedClock(date)`) so time is deterministic; it is also what makes stored timestamps assertable. Ids are generated through the `IdGenerator` port (`infrastructure/shared/id-generator.ts`: `randomIds` in production, `sequentialIds()` in tests), never with `crypto.randomUUID()` inside the domain, so generated ids are assertable too.

## Transactions

When a use case writes more than once (typically an entity plus its domain event in the outbox), it groups the writes with the `Transactor` port (`infrastructure/shared/transactor.ts`). `transactor.run(work)` hands `work` a `TransactionScope` with the repositories and the `EventPublisher` bound to one SQLite transaction; it commits when `work` resolves and rolls back when it throws. Business checks (lookups that may return a domain error) happen before `run`, so `work` never deals with `Result`: it only writes. Single-write use cases call their repository directly.

## Value Object Tests

Each value object's validation rules are tested exhaustively in its own file (every accepted and rejected input, asserting the exact `safeParse` success value / failure message). Acceptance tests must not repeat those rules: per endpoint, one invalid-value test proves the schema → 400 mapping, plus tests for the adapter's own checks (e.g. a required field missing from the request). Services take branded types as parameters, so the type system already guarantees an adapter validates before calling the domain.

## Infrastructure Tests

Infrastructure tests use the real dependency, colocated with the code:

- Embedded engine (SQLite) → a real instance. Since acceptance tests already exercise the SQLite repositories end to end, their own tests focus on what acceptance tests don't reach: row-mapping edge cases, ordering, conflict handling.
- Networked service → testcontainers.
- Outbound HTTP dependency → the real client against a local fake server, not a container.
- Process wrappers (ffprobe) → the real binary against a tiny fixture file, when feasible.

## Testing Opinions

- Test naming: `it('should <behaviour>[ if <condition>]')`, short enough to read at a glance — drop the `if ...` part when there's no meaningful precondition beyond "given valid input". This naming focuses on behaviour instead of implementation.
  - Name the behaviour, not the mechanics: no HTTP status codes, event/task type names, or "and store nothing" side-effect lists — the asserts carry those details.
  - Happy path is the verb: `it('should create a channel')`, `it('should list all playlists')`.
  - Errors use *fail*: `it('should fail to create if path missing')`.
  - Tolerated no-ops use *skip* / *ignore*: `it('should skip if playlist is gone')`.
  - When one test file covers several routes, keep the operation in the name so it stays unambiguous (`fail to delete …` vs `fail to reconcile …`).
- Tests should be as deterministic as possible: fake clock for time, no real network, no sleeps. fast-check failures print their seed; pin it only while reproducing.

# Other Opinions

- Code should be as functional as possible: `map`/`filter`/`flatMap`/`reduce` and immutable variants (`toSorted`, `toReversed`) over imperative loops; object/array spread over mutation; `const` everywhere; `readonly` on domain types where practical.
- Model with discriminated unions and let the compiler enforce exhaustiveness (a `never` check in the `default` branch, or `matchError`).
- `Result` (better-result) for domain errors, `T | undefined` for absence, exceptions only for defects and infra failures.
- Libraries over frameworks: no DI container — wiring happens by hand in the composition root (`main.ts`).

# Deliberate deviations. Don't "fix" these

Some of these are deliberate deviations from DDD/hexagonal orthodoxy, for convenience or to avoid overengineering:

- Port interfaces live in `infrastructure/`, not `domain/` (dependency direction inverted, traded for editing convenience).
- Ports have no typed errors and no `Result`: infra failures are thrown exceptions until the domain service gives an outcome meaning; only the adapter's top-level error handler sees them.
- An idempotent "create" use case is two non-atomic port calls (`find` then `insert`), not one atomic upsert.
- Orchestration lives in `domain/services/`, not a separate `application/` layer. The `application/` folder holds only adapters (HTTP, CLI, subscribers, tasks) that translate an external trigger into a domain call — business orchestration itself never lives there.
- Value objects don't return `Result` from a constructor: they are Zod schemas validated at the boundary, and inside the domain the branded type is proof of validity.

If code looks like it violates textbook architecture in one of these ways, it's probably intentional. Ask before changing it.
