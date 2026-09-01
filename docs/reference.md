# FixtureKit Reference

Canonical API, configuration, and contract reference.

## Core Concepts

- **Definition**: `FixtureKit.define { ... }` returns a `FixtureKit::Definition`.
- **Fixture**: wraps an identifier and a definition; handles cache save/mount.
- **Cache**: persists and replays SQL for touched models.
- **Coder**: decides what gets cached during generate and how to replay it on mount. `FixtureKit::ActiveRecordCoder` is registered by default; additional coders can be registered to capture state outside ActiveRecord.
- **Repository**: exposes records via methods, loaded lazily and memoized per test.
- **Runner**: owns configuration, registry, startup state, and adapter and coder instances.

## Framework Entrypoints

### RSpec

Require:

```ruby
require "fixture_kit/rspec"
```

Effects:
- Configures `fixture_path` default to `"spec/fixture_kit"`.
- Configures adapter to `FixtureKit::RSpecAdapter`.
- Adds `fixture` class macro for example groups.
- Adds `fixture` instance reader for examples.

### Minitest

Require:

```ruby
require "fixture_kit/minitest"
```

Effects:
- Configures `fixture_path` default to `"test/fixture_kit"`.
- Configures adapter to `FixtureKit::MinitestAdapter`.
- Adds `fixture` class macro for test classes.
- Adds `fixture` instance reader for tests.

## Fixture Declaration API

Declaration signature in both frameworks:

```ruby
fixture(name = nil, extends: nil, &definition_block)
```

Rules:
- Provide exactly one of `name` or block.
- Both provided: raises `FixtureKit::InvalidFixtureDeclaration`.
- Neither provided: raises `FixtureKit::InvalidFixtureDeclaration`.
- `extends` can be combined with a block for inline inheritance (see [Fixture Inheritance](#fixture-inheritance-extends)).
- More than one declaration in same context/class: raises `FixtureKit::MultipleFixtures`.
- Nested context/class can declare its own fixture and override parent declaration.

Named fixture lookup:
- Reads `<fixture_path>/<name>.rb`.
- File must evaluate to `FixtureKit::Definition`.
- Missing file or invalid return value raises `FixtureKit::FixtureDefinitionNotFound`.

Anonymous fixture:
- Declared inline via block.
- Identifier is derived from framework scope class and normalized by adapter.

## `FixtureKit.define`

```ruby
FixtureKit.define do
  # setup data
  expose(user: user)
end
```

`Definition#expose(**records)`:
- Exposed names become repository methods.
- Duplicate exposed names raise `FixtureKit::DuplicateNameError`.
- Records are captured as class/id pairs at the moment `expose` is called, not
  at the end of the definition. The record objects themselves are not retained.
- Exposing a record that is not persisted raises
  `FixtureKit::UnpersistedRecordError`. This applies to records inside an
  exposed collection as well, and to records that have been destroyed.

Because capture happens when `expose` is called, expose a record only once it
has been saved:

```ruby
FixtureKit.define do
  user = User.new(name: "Alice")
  expose(user: user)  # raises FixtureKit::UnpersistedRecordError
  user.save!
end
```

The same timing applies to collections, but an emptied or later-appended
collection cannot be detected — it is captured as-is:

```ruby
FixtureKit.define do
  projects = []
  expose(projects: projects)          # captured as an empty collection
  projects << Project.create!(...)    # not reflected in `fixture.projects`
end
```

The conventional form -- `expose` as the last statement of the definition --
avoids both cases.

## Fixture Inheritance (`extends`)

```ruby
FixtureKit.define(extends: "base_fixture_name") do
  # parent records are available via `parent`
  record = SomeModel.create!(related: parent.exposed_name)
  expose(record: record)
end
```

`extends` accepts a named fixture string. The parent fixture is generated and mounted before the child definition runs.

### `parent`

Inside the definition block, `parent` returns the parent fixture's `Repository`. Use it to reference the parent's exposed records:

```ruby
FixtureKit.define(extends: "project_management") do
  task = Task.create!(project: parent.project, assignee: parent.owner)
  expose(task: task)
end
```

`Repository` responds to `to_hash`, so `parent` can be splatted to re-expose all of the parent's records alongside new ones:

```ruby
FixtureKit.define(extends: "project_management") do
  task = Task.create!(project: parent.project, assignee: parent.owner)
  expose(**parent, task: task)
end
```

### Chained inheritance

Inheritance can be chained — a child can extend a fixture that itself extends another:

```ruby
# base.rb
FixtureKit.define do
  owner = User.create!(name: "Owner", email: "owner@example.com")
  expose(owner: owner)
end

# child.rb
FixtureKit.define(extends: "base") do
  project = Project.create!(name: "Project", owner: parent.owner)
  expose(project: project)
end

# grandchild.rb
FixtureKit.define(extends: "child") do
  task = Task.create!(title: "Task", project: parent.project, assignee: parent.project.owner)
  expose(task: task)
end
```

### Inline inheritance

`extends` works with both named and anonymous (inline) fixtures:

```ruby
fixture(extends: "project_management") do
  task = Task.create!(title: "Inline Task", project: parent.project, assignee: parent.owner)
  expose(task: task)
end
```

### Exposed record behavior

Parent records are **not** auto-exposed in the child. Only names explicitly passed to `expose` in the child definition are available on the test `fixture` reader. The parent's database records are still inserted — they just aren't accessible by name unless re-exposed.

### Circular inheritance

Circular `extends` chains are detected at registration time and raise `FixtureKit::CircularFixtureInheritance`.

## Configuration

Configure via:

```ruby
FixtureKit.configure do |config|
  # ...
end
```

Default values:

- `fixture_path`: `"fixture_kit"`
- `cache_path`: `"tmp/cache/fixture_kit"`
- adapter class: `FixtureKit::MinitestAdapter`
- adapter options: `{}`

### Settings

`config.fixture_path = String`
- Base directory for named fixture files.

`config.cache_path = String`
- Base directory for cache JSON files.

`config.adapter(adapter_class = nil, **options)`
- Getter: no args returns current adapter class.
- Setter: stores adapter class and options for adapter initialization.

`config.callbacks`
- Returns callback registry (`FixtureKit::Callbacks`).

`config.coders`
- Returns the registered coder classes as a `Set`.
- Default: `Set.new([FixtureKit::ActiveRecordCoder])`.

`config.register(coder_class)`
- Adds a coder class to the registered set. Coder instances are created lazily once per runner and reused across fixtures.

## Coder Contract

Subclass `FixtureKit::Coder` and implement:

`#generate(&block)`
- Called once when fixture cache is being built.
- Set up observation, then call the block to evaluate the user's fixture definition (and any inner coders).
- Return data to be cached for this coder. Will be passed to `#encode` before serialization.
- For inherited fixtures (`extends:`), the parent is mounted via `#mount` inside the block. A coder that needs the parent's contribution should record what it replays during `#mount` and fold it into its result here (see `ActiveRecordCoder`). The previous `parent_data:` keyword has been removed.

`#mount(data)`
- Called once per test mount with the data this coder produced. Re-create the state on the test database.
- Also runs while a child fixture is being generated (the parent is mounted inside the child's `#generate` block). Coders that need their replayed models reflected in the child cache record them here.

`#encode(data)`
- Convert the in-memory representation produced by `#generate` to a JSON-serializable form. Default: identity.

`#decode(data)`
- Inverse of `#encode`. Default: identity.

Coder registration:

```ruby
FixtureKit.configure do |config|
  config.register(MyCoder)
end
```

Chain semantics:
- Coders form a chain; outer coders wrap inner coders' generate blocks.
- The innermost block is the user's `FixtureKit.define` body.
- Order is determined by registration; `ActiveRecordCoder` is registered first by default.

## Foreign Key Verification

When `ActiveRecord.verify_foreign_keys_for_fixtures` is `true` (Rails default since 8.0 `load_defaults`), `FixtureKit::ActiveRecordCoder#mount` calls `connection.check_all_foreign_keys_valid!` after replaying cached statements. A violation raises `FixtureKit::Error` with a stale-cache hint.

- PostgreSQL and SQLite implement the check.
- MySQL inherits the abstract no-op.

## Primary Key Sequence Reset

After replaying cached INSERTs, `FixtureKit::ActiveRecordCoder#mount` resets the primary key sequence for each touched table:
- Rails 8.2+: `connection.reset_column_sequences!(tables)` in one batched call per connection.
- Rails 8.0/8.1: per-table `connection.reset_pk_sequence!(table)`.
- Adapters that expose neither (MySQL, SQLite): skipped — their PK generators advance from explicit-id INSERTs.

This prevents `PG::UniqueViolation` when fixtures are mounted onto a database whose sequence is at its initial value (e.g., parallel test workers with their own DB copies).

## Adapter Contract

Subclass `FixtureKit::Adapter` and implement:

`#execute { ... }`
- Runs fixture generation in framework-specific isolation.

`#identifier_for(identifier)`
- Receives non-string fixture identifier and returns normalized String identifier.
- `_anonymous/` prefixing and the declaration-site digest suffix are applied by `FixtureKit::Cache`.

Adapter initialization:

```ruby
adapter_instance = config.adapter.new(config.adapter_options)
```

Options are available via `attr_reader :options` in `FixtureKit::Adapter`.

## Callback Events

Register using configuration methods:

`config.on_register { |fixture, scope| ... }`
- Runs when a fixture is registered (declared), before any caching.
- `scope` is the declaring context passed to `register`. For the RSpec adapter it is the
  example group (`describe`/`context`) that declared the fixture, so
  `scope.metadata[:file_path]` gives the originating spec file.

`config.on_cache_save { |fixture| ... }`
- Runs before cache save.

`config.on_cache_saved { |fixture, duration| ... }`
- Runs after cache save.
- `duration` is elapsed seconds as `Float`.

`config.on_cache_mount { |fixture| ... }`
- Runs before cache mount.

`config.on_cache_mounted { |fixture, duration| ... }`
- Runs after cache mount.
- `duration` is elapsed seconds as `Float`.

The `fixture` argument is a `FixtureKit::Event` instance. Methods:
- `fixture.identifier` — String cache identifier (no `.json` suffix).
- `fixture.path` — file path where the fixture definition block was defined.

Behavior:
- Multiple callbacks per event supported.
- Callbacks run in registration order.

## Cache Identifiers and Paths

Cache file path format:

```text
<cache_path>/<identifier>.json
```

Identifier behavior:
- Named fixture: identifier is the fixture name string.
- Anonymous fixture: identifier is `_anonymous/<adapter-normalized-scope>.<digest>`.

The digest is the first 12 hex characters of a SHA-256 of the declaration site
(the `fixture` block's file and line, plus its `extends:` target). The scope name
alone is not unique: test frameworks derive it from the group description, which
drops non-alphanumeric characters, and test runners that load specs in batches
call `RSpec::Core::World#reset` between them, which resets the counter RSpec uses
to disambiguate duplicate descriptions. Without the digest, two spec files
sharing a top-level description would share one cache entry, and the second
fixture to generate would mount the first one's records.

Examples:
- Named: `teams/basic` -> `tmp/cache/fixture_kit/teams/basic.json`
- Anonymous RSpec: `_anonymous/foo/with_fixture_kit/hello.3f2a9c1d4b8e`
- Anonymous Minitest: `_anonymous/my_feature_test.7c1b0e5a9d24`

## Runtime API in Tests

`fixture`
- Returns `FixtureKit::Repository` for the mounted fixture.

`Repository`
- Methods are generated from exposed names.
- First access loads model with `find_by(id: ...)`.
- Loaded value is memoized for subsequent access in that test.
- If row is missing before first access, value is `nil`.

## Environment Variables

`FIXTURE_KIT_PRESERVE_CACHE`
- If truthy, runner start does not clear cache directory.
- Truthy values (case-insensitive): `1`, `true`, `yes`.

## Error Classes

Public error classes:
- `FixtureKit::Error`
- `FixtureKit::DuplicateNameError`
- `FixtureKit::InvalidFixtureDeclaration`
- `FixtureKit::MultipleFixtures`
- `FixtureKit::CacheMissingError`
- `FixtureKit::CacheCorruptError`
- `FixtureKit::FixtureDefinitionNotFound`
- `FixtureKit::RunnerAlreadyStartedError`
- `FixtureKit::CircularFixtureInheritance`
- `FixtureKit::UnpersistedRecordError`

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0
