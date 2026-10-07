---
name: rust-architect
description: Architecture, naming, and testing conventions guidelines for architecting Rust codebases. Use when writing, reviewing, or refactoring Rust code: creating a new module or file, adding a repository/port/service/entity/value object, adding an HTTP handler or CLI command, deciding where a new .rs file goes, or writing/naming Rust tests.
---

# Philosophy

We try to follow a Domain Driven Design (DDD) approach with hexagonal architecture (aka ports and adapters) with some opinionated decisions. We try to follow clean architecture and we give a lot of importance to tests.

# Layers

We structure our code in three layers: application, domain, and infrastructure.

## Application Layer

This is the entry point to the application, the most common case will be http controllers but it can also be a CLI application, subscribers (message consuming from a queue system), etc. The main responsibility of this layer is to **VALIDATE** entry data and **TRANSFORM** it into Value Objects (VO). In the case of http this layer is the one responsible of parsing HTTP requests, validating the data and returning HTTP errors if not valid, transforming into VO and calling the domain layer, in the case that this the method needs to return a response it will transform the domain response into a response DTO and return it to the caller with the correct HTTP status code.

## Domain Layer

This is where the core **BUSINESS LOGIC** of the application lives. It is composed of entities, value objects, domain services, and domain events. The main responsibility of this layer is to implement the business rules and logic of the application and **ORCHESTRATE** calls to the ports in the infrastructure layer. We need to try to not depend on any external libraries or frameworks but some concessions could be done.

## Infrastructure Layer

This layer is responsible for implementing ports and **COMMUNICATING WITH EXTERNAL SYSTEMS**. Most of the time we will be coding repositories to access the database, but external clients to external APIs should be implemented here too. As a convention, even if this is not entirely correct bc this should go in the domain layer, we will place the trait of the repository here, near the implementation bc it's convenient when adding new methods to the repository. `repositories/` holds one aggregate's dedicated port implementation (a port injected into a single aggregate's domain service); `shared/` holds infra usable across aggregates, regardless of whether it's a port (e.g. the clock, domain events) — see the file structure below.
We must not hide behaviour in this layer, repositories should be as simple as possible and should behave like collections with methods like `find`, `find_by_id`, `save`, `delete`, etc. The domain layer should be the one that implements the business logic, rules and entity transformations, not the infrastructure layer. The infrastructure layer should be as simple as possible and should not contain any business logic like domain event publishing, it should only contain the operations on entities and optional monitoring. Write operations such as save, insert, update should have the entity as a parameter, not the properties. Delete could operate on the entity identifier instead of the entity itself and read methods such as find(id), find_all, etc should always return entities or collections of entities.

# File Structure and Naming and other opinions

We try to organize our domain code into modules with the aggregate name as module name. This is an example of how we would structure the code:

```
src/
  domain/
    <aggregate>/
      <value_object>.rs   # one file per value object, named after the type
      <entity>.rs         # named after the type, even if it repeats the folder name
      errors.rs           # every error type for this aggregate, together
    services/              # every aggregate's use-case services, together, flat
      <use_case>.rs         # one domain service per use case, e.g. widget_creator.rs
  application/              # every external entry point (adapters), one subfolder per interface
    http/  (or grpc/, etc.)
      mod.rs                 # ApiServices + router wiring only
      error.rs               # ApiError + From<ValidationError>
      blocking.rs            # run_blocking
      validation.rs          # required() + shared missing-field messages
      <resource>/
        mod.rs                # handlers only
        dto.rs                # request/response wire types + From<Domain> conversions
    cli/                      # only if the project has a CLI
      mod.rs                  # Cli/Commands definitions (this is the CLI's "routing")
      <command>.rs             # one file per command's orchestration
    subscribers/              # event subscribers, one file per subscriber
      <subscriber>.rs
    tasks/                    # scheduled/background task handlers, one file per task
      <task>.rs
  infrastructure/
    repositories/            # one aggregate's dedicated port implementation
      <implementation>_<port>.rs   # trait + its implementation, together
    client/                  # port-shaped adapters nothing in domain/ injects
      <port>.rs
    shared/                  # infra usable across aggregates (ports or not)
      <thing>.rs
```

- We prefer not generic names: not `entity.rs`, not `value_objects.rs`, not `ports.rs`. A file is named after the single type/concept it holds (`user.rs` holds `User`, `user_id.rs` holds `UserId`).
- `errors.rs` is the one deliberately generic name: every error type for an aggregate (use-case error enums) lives together in one file, not scattered across the files that raise them.
- Every value object constructor fails with the single shared `ValidationError(String)` (`domain/shared/errors.rs`), never a per-VO error type. The application layer maps it once (e.g. `impl From<ValidationError> for ApiError` → 400), so handlers build VOs with a plain `?`.
- Every value object gets its own file. Don't bundle multiple value objects into one "value objects" file.
- A port is named after the concept it fronts, not the one method it happens to expose (`WidgetRepository`, not `WidgetLookup`, even if today it only has an `exists` method). "Repository" is used loosely for "adapter implementing a domain port," not strictly persistence.
- `infrastructure/repositories/` files are named `<implementation>_<port>.rs` (`sqlite_playlist_repository.rs` implements `PlaylistRepository` with SQLite, `youtube_video_downloader_repository.rs` implements `VideoDownloaderRepository` against YouTube/`yt-dlp`). The prefix signals which technology backs the port. `infrastructure/shared/` and `infrastructure/client/` files are named after the port/thing itself, not this convention, since they aren't per-aggregate repositories.
- A repository/port method either **reads** (returns `anyhow::Result<Entity>` / `anyhow::Result<Vec<Entity>>` / `anyhow::Result<Option<Entity>>`, an entity or collection, never a wrapper/outcome enum) or **writes** (returns `anyhow::Result<()>`, void on success). No custom infra error types (`RepositoryError`/`LookupError` and friends), infra failures are untyped `anyhow::Error`. A Repository always returns the entities that its name implies (`UserRepository` returns `User`).
- Business-meaningful outcomes that look like they belong in the repository (e.g. "was this newly created, or did it already exist?") are decided in the domain service, not returned by infra: call `find`, branch on `Some`/`None`, then call `insert`/`save`. This trades DB-level atomicity for keeping business logic out of infra, a known, accepted race window, not an oversight.
- State transitions live on the entity, never as behavior-named repository methods or as anemic domain models operated from domain service. We prefer immutable state transitions: a transition method takes `self` by value and returns a new `Self` (via struct-update syntax, `Self { field: new_value, ..self }`) rather than mutating `&mut self`. Name such a method `with_<field>` when it simply sets one field (e.g. `with_thumbnail`); reserve a verb-based name (`mark_downloaded`, `start_download`, `reset_for_redownload`) for a transition that carries additional domain meaning beyond "set this field".
- **Fn ordering**: within any `impl` block, and among free functions in a file, order is: `new` (if it exists), then every `pub` method or trait-impl method (trait-impl methods are the type's public surface even without the `pub` keyword), then private/helper methods. This applies uniformly, no exceptions — including repositories' `row_to_*` mapping helpers, which go after the trait-impl methods they support, not before.
- **Domain service layout**: every domain service file is laid out in four blocks, top to bottom, so a reader meets the contract before the implementation:
  1. The struct holding its dependencies, followed by an inherent `impl` with **only** `new`.
  2. The service's interface: a `pub trait <Service>Api: Send + Sync` declaring every public operation (doc comments describing the contract go here, on the trait method, not on the impl).
  3. `impl <Service>Api for <Service>` with the implementation of those operations.
  4. A second inherent `impl <Service>` holding every private helper, never `pub`.

  Guideline (not a hard rule): every public operation (block 3) should read at a glance — aim for **10–15 lines of body** after `rustfmt`. It reads as a sequence of named steps (`let channel = self.find_channel(&id)?; self.delete_channel_videos(&id)?; ...`), each step a private helper in block 4 named for *what* it does. Lookup-or-fail `match`es, multi-arm outcome handling, event building and repeated `map_err` chains are the usual candidates to extract. When two arms or two operations share logic (e.g. marking a failed download as errored), extract it once rather than shrinking each copy. Exceptions are fine for genuinely complex flows (e.g. reconciliation) where splitting further would scatter one coherent algorithm across helpers that only make sense together — prefer readability over the line count.

  Callers keep depending on the concrete service type (`State<PlaylistCreator>`, `video_downloader: VideoDownloader`) and just `use` the `…Api` trait to call it; the trait exists to make the contract readable, not to add dynamic dispatch. Supporting types the service returns (e.g. an outcome enum) and constants go above the struct.

  ```rust
  pub struct WidgetCreator {
      repository: Arc<dyn WidgetRepository>,
  }

  impl WidgetCreator {
      pub fn new(repository: Arc<dyn WidgetRepository>) -> Self {
          Self { repository }
      }
  }

  pub trait WidgetCreatorApi: Send + Sync {
      fn create(&self, id: WidgetId) -> Result<Widget, CreateWidgetError>;
  }

  impl WidgetCreatorApi for WidgetCreator {
      fn create(&self, id: WidgetId) -> Result<Widget, CreateWidgetError> {
          self.ensure_absent(&id)?;
          // ...
      }
  }

  impl WidgetCreator {
      fn ensure_absent(&self, id: &WidgetId) -> Result<(), CreateWidgetError> {
          // ...
      }
  }
  ```
- Read models (`*View`, e.g. `TaskView`, `ChannelView`) hold the flat fields they expose, not the entity they're derived from.
- Domain services are call-agnostic: they know nothing about HTTP, CLI, subscribers, or tasks. Adapting any external trigger into a domain call — parsing/validating input, invoking the domain service, mapping its result back — is the application layer's sole responsibility.

## HTTP Handlers

- A handler extracts only the service(s) it uses (`State<PlaylistCreator>`), never the whole `ApiServices`. `ApiServices` derives `FromRef` so axum resolves the sub-state.
- Handlers return typed results, never an opaque `Response`: `Result<(StatusCode, Json<T>), ApiError>` when the status varies, `Result<Json<T>, ApiError>` for a plain 200, `Result<StatusCode, ApiError>` for bodiless responses.
- Every failure is an `ApiError` (status + message, rendered as `{"error": ...}`). Input is validated with `?` only: VOs via `From<ValidationError>`, missing fields via `required(request.field, MISSING_X)?` (`http/validation.rs`).
- Domain errors are mapped explicitly per variant (`Err(e @ CreateChannelError::Lookup(_)) => Err(ApiError::new(StatusCode::BAD_GATEWAY, e))`), no catch-all arm. A mapping repeated across handlers gets one small function.
- Every service call goes through `run_blocking` (`http/blocking.rs`), since services are synchronous (SQLite, blocking HTTP). Don't judge per call whether it's needed.
- Response DTOs are flat and carry only the fields their consumers use. Never compose one resource's response by wrapping or `#[serde(flatten)]`-ing another response DTO. A genuinely nested JSON object (e.g. a video's `source`) gets its own DTO.

# Testing

Tests are classified by **where they enter the code**, not by what they fake. Our goal is to couple our tests as much as possible to behaviour instead of implementation, so we can refactor the code without breaking the tests.

- **Acceptance tests**: enter through an application adapter (HTTP handler, event subscriber, task). The default and by far the most numerous kind.
- **Behaviour tests**: enter through a domain service directly. The exception, reserved for domain logic too complex to cover through an adapter.
- **Value object tests**: exhaustive validation rules, one file per value object.
- **Infrastructure tests**: a single adapter (repository, client) against its real dependency.

Acceptance and behaviour tests follow the same rules for persistence and test doubles (see below): persistence is real, only external dependencies are faked. The Playwright suite in `smoke-tests/` is the true end-to-end layer (real binary, real browser) and lives outside these conventions.

## Acceptance Tests

This tests the domain logic and the validations at application level. We will place this tests in application (for example in http controllers or event subscribers) and the test will be the type of "I receive this request and I expect this response and these collateral effects". In the case of event subscribers we will send events and assert the final state of the repositories. Very similar for Tasks, we will create tasks and assert the final state of the repositories.

HTTP acceptance tests call the handler function directly with only the service it uses, not through a `Router`. A small helper per handler unwraps the `Json` (`create(service, request) -> Result<(StatusCode, ChannelResponse), ApiError>`). Route wiring (paths, methods, which handler each route reaches) is covered by the Playwright suite in `smoke-tests/`, not by Rust tests: every route the UI calls must be exercised by some spec there.

Every test has the same 7 steps, top to bottom and inline: `TestDatabase` + repositories/fakes → seed them → build the service with `Service::new(..)` → build the request → call the handler → assert the response → assert side effects (repositories, outbox events, scheduled tasks, fake state).

- No fixture structs that bundle fakes/repositories and no `service()` → `service_with()` builder chains. They hide which dependencies a test uses and make it easy to skip asserting them. The one allowed exception is a constructor helper for a service with many ports no test observes: it takes the asserted repositories as parameters and fills in the rest (`channel_video_reconciler(&db, channel_repository, ..)`). A test that observes one of the ports the helper fills in builds the service inline with `Service::new(..)` instead of growing the helper or adding a second one.
- Assert whole typed values in one `assert_eq!`: `Ok((StatusCode::CREATED, some_channel_response()))`, `Err(ApiError::bad_request("<exact message>"))`, `repository.list().unwrap() == vec![..]`. Never field by field, never `len()`, never raw JSON (that only re-tests serde).
- Requests and expected values are built from a valid default overridden with struct update syntax (`CreateChannelRequest { quality: None, ..create_request("@x") }`).
- Seed state directly into repositories, never by calling another handler: a test only exercises the handler it names.
- DTO mapping is covered through handler responses, not with standalone DTO tests.
- Module layout: imports, then every `it_should_*` test, then helpers.

A domain service reached from several adapters (e.g. the reconcilers, called from a task, a subscriber and an HTTP handler) has its logic tested exhaustively through one primary adapter, the one that does the recurring work (the task). Every other adapter tests only what differs for it (e.g. `force_reconcile` not rescheduling, error mapping) plus one happy path proving the service is wired. When an adapter's call path starts to diverge inside the service, the tests for that difference go in that adapter.

Tests whose request is rejected before reaching the service (validation 4XX) assert the response only and don't need a database: their `any_<service>()` helper builds repositories on an unmigrated in-memory connection (`Connection::open_in_memory()`), so a request that wrongly got through fails loudly instead of passing.

## Behaviour Tests

Ideally we should not tests domain services at all because the logic there is tested from acceptance tests. There could be exceptions for very complex domain logic that is hard to test from application layer, but this should be the exception and not the rule. When one is justified, it calls the domain service directly and asserts its result plus the final state of the repositories, under the same persistence and fakes rules as acceptance tests: a behaviour test is never a reason to keep a fake of our own persistence alive. Before adding one, check the acceptance tests of the adapters calling that service don't already cover it.

## Persistence and Test Doubles

**Persistence is real, not faked.** Because our database is an embedded SQLite file, which is fast, cheap to create and _is_ the production engine, acceptance and behaviour tests wire the real `Sqlite*` repositories against a fresh database per test instead of fakes. This catches SQL, row-mapping, ordering, upsert and constraint bugs that a hand-written fake silently re-implements (and drifts from). Concretely:

- Every test starts with `let db = TestDatabase::new();` (`infrastructure/shared/sqlite_connection.rs`): a freshly migrated database file in its own temp directory, removed when the test ends, so tests run in parallel without sharing state. No pool of pre-migrated databases: migrating a fresh one costs a few milliseconds.
- Each repository gets its own connection, `SqliteXRepository::new(db.connection())` (or `db.shared_connection()` for the ones taking `Arc<Mutex<Connection>>`), opened with the same `sqlite_connection::open` as production (WAL, busy timeout), so tests exercise the real multi-connection setup.
- Seed and assert through the port traits (`insert`, `list`, `find`, `list_for_...`), never through raw SQL. When a whole-table assertion needs a read the port doesn't have (e.g. listing every video), add a `#[cfg(test)]` inherent method on the SQLite implementation rather than widening the port for tests.
- Storage-assigned values (autoincrement ids) are deterministic in a fresh database, so assert them as real values (`ChannelVideo { id: 1, ..ChannelVideo::create(..) }`) rather than masking them.
- Domain events are asserted through the real outbox: the real `SqliteEventPublisher` writes them, and the test reads them back with `SqliteEventRepository::list_eligible()`, comparing against the expected `ScheduledEvent` rows (a `pending_event(id, DomainEvent)` helper builds them). Scheduled tasks likewise through the real `SqliteTaskRepository` (`list_non_completed()`).

**Fakes are for everything else**: out-of-process or side-effecting dependencies (external APIs such as YouTube, `yt-dlp`, outbound HTTP, and, for now, filesystem-backed ports). The fakes will be hand-written and will be as simple as possible, they will not use any mocking library. The fakes will be state-based, for example a fake backed by a `Mutex<Vec<T>>`, and may offer constructors for failure scenarios (e.g. `failing()`, `unavailable()`).

The Clock is treated like a port and faked (`FixedClock`) so time is deterministic; it is also what makes stored timestamps (e.g. event `created_at`) assertable.

## Value Object Tests

Each value object's validation rules are tested exhaustively in its own file (every accepted and rejected input, asserting the exact `Ok(vo)` / `Err(ValidationError(message))`). Acceptance tests must not repeat those rules: per endpoint, one invalid-value test proves the `ValidationError` → 4XX mapping, plus tests for the adapter's own checks (e.g. a required field missing from the request). Services take value objects as parameters, so the type system already guarantees a handler validates before calling the domain.

## Infrastructure Tests

Infrastructure tests use the real dependency, colocated with the code. Some examples:

- Embedded engine (e.g. SQLite) -> a real instance, not a container. Since acceptance tests already exercise the SQLite repositories end to end, their own tests focus on what acceptance tests don't reach: row-mapping edge cases, ordering, conflict handling.
- Networked service (Postgres, Kafka, Redis...) -> testcontainers.
- Outbound HTTP dependency -> the real HTTP client against a fake/mock server, not a container.

Keep tests in `#[cfg(test)] mod tests` in the same file as the code they test by default. Only introduce a top-level `tests/` directory (which needs a `lib.rs`, turning the project into a library + thin binary) when a project independently justifies it — not just to match a template.

## Testing Opinions

- Test naming: `it_should_<behaviour>[_if_<condition>]`, short enough to read at a glance — drop the `_if_...` part when there's no meaningful precondition beyond "given valid input". This naming focuses on behaviour instead of implementation.
  - Name the behaviour, not the mechanics: no HTTP status codes, event/task type names, or "and store nothing / change nothing" side-effect lists — the asserts carry those details.
  - Happy path is the verb: `it_should_create_a_channel`, `it_should_list_all_playlists`, `it_should_download_the_video`.
  - Errors use `fail`: `it_should_fail_to_create_if_path_missing`, `it_should_fail_if_invalid_handle_provided`.
  - Tolerated no-ops use `skip` / `ignore`: `it_should_skip_if_playlist_is_gone`, `it_should_ignore_reconcile_of_a_missing_channel`.
  - When one test module covers several handlers, keep the operation in the name so it stays unambiguous (`fail_to_delete_…` vs `fail_to_reconcile_…`).
- Tests should be as deterministic as possible. In the case of time we will use a fake clock that we can control. This will behave as a regular port.

# Other Opinions

- Code should be as functional as possible, we prefer mapping/folding/filtering over imperative loops, and immutable data over mutable data. We will use `Option` and `Result` types instead of nulls and exceptions. We will use `iterators` instead of `for` loops when possible. We will use `map`, `filter`, `fold`, etc. instead of imperative loops when possible.

# Deliberate deviations. Don't "fix" these

Some of these are deliberate deviations from DDD/hexagonal orthodoxy, for convenience or to avoid overengineering:

- Port traits live in `infrastructure/`, not `domain/` (dependency direction inverted, traded for editing convenience).
- Repositories have no typed error enums, everything is `anyhow::Error` until the domain service gives it meaning.
- An idempotent "create" use case is two non-atomic port calls (`find` then `insert`), not one atomic upsert.
- Orchestration lives in `domain/services/`, not a separate `application/` layer. The `application/` folder holds only adapters (HTTP, CLI, subscribers, tasks) that translate an external trigger into a domain call — business orchestration itself never lives there.

If code looks like it violates textbook architecture in one of these ways, it's probably intentional. Ask before changing it.
