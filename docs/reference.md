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

`#generate(parent_data: nil, &block)`
- Called once when fixture cache is being built.
- Set up observation, then call the block to evaluate the user's fixture definition (and any inner coders).
- Return data to be cached for this coder. Will be passed to `#encode` before serialization.
- `parent_data` is the cached data from the same coder on the parent fixture when `extends:` is used; `nil` otherwise.

`#mount(data)`
- Called once per test mount with the data this coder produced. Re-create the state on the test database.

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

## Parallel Test Suites

The cache is a directory of JSON files. What makes a parallel run safe is which
processes share that directory and which of them clear it.

`Runner#start` runs once per process and clears `cache_path` unless
`FIXTURE_KIT_PRESERVE_CACHE` is truthy. That clear is what keeps a cache from
outliving the code that produced it.

### Forked workers (Rails `parallelize`)

`ActiveSupport::Testing::Parallelization` forks its workers before Minitest runs
any suite, and each worker runs individual test methods rather than suites.
FixtureKit generates from `FixtureKit::Minitest::ClassMethods#run_suite`, so:

- `Runner#start` and every `generate` run in the parent process.
- Workers only `mount`, reading the files the parent wrote.

One shared `cache_path` is therefore correct, and it is what the default gives
you. Rails does not set `TEST_ENV_NUMBER` (it names the per-worker databases
itself), so there is no worker number to key the path on, and adding one would
only point the workers at directories the parent never writes to.

Each worker owns a database whose sequences sit at their initial value. The PK
sequence reset described above is what makes the parent's cached INSERTs
mountable there.

### Process-per-worker runners (`parallel_tests`)

Each worker boots the application and calls `Runner#start`, so every worker
clears the shared directory, entries the others have generated or are about to
mount included. Give each worker its own:

```ruby
config.cache_path = "tmp/cache/fixture_kit/#{ENV["TEST_ENV_NUMBER"]}"
```

Every worker then generates the fixtures its own share of the suite needs. The
generation work is duplicated, but the per-process clear keeps working and no
worker can observe another's files.

### Sharing one directory across processes

Reusing a directory between processes (a warm-up run that fills the cache before
the suite starts, a CI cache restored between jobs) needs
`FIXTURE_KIT_PRESERVE_CACHE`, since otherwise the first process to start deletes
what the previous one left.

Preserving the cache moves invalidation to you. `Cache#exists?` is
`File.exist?`: a file that exists is used, whatever wrote it and whenever.
Nothing compares it against the fixture definitions, the factories they call, or
the schema. A cache written under an older state of the code mounts without
complaint, and the failure lands wherever those stale records first break
something rather than at the fixture that produced them.

`cache_path` is the place to bound that. Put a digest of everything the cached
rows depend on in the path, and a cache written under any other state of the
code is never read: it is ignored and regenerated.

```ruby
CACHE_SOURCES = %w[
  spec/fixture_kit/**/*.rb
  spec/factories/**/*.rb
  db/schema.rb
].freeze

digest = Digest::SHA256.new
digest << FixtureKit::VERSION
CACHE_SOURCES.flat_map { |pattern| Rails.root.glob(pattern) }.sort.each do |path|
  digest << path.to_s << File.binread(path)
end

FixtureKit.configure do |config|
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit", digest.hexdigest[0, 16]).to_s
end
```

Watch every input the cached rows depend on: the fixture definitions, the
factories or object mothers they call, the schema file the suite actually loads
(`db/structure.sql` under `schema_format = :sql`), and any support file that
configures generation. Hashing each path alongside its content keeps two files
with identical contents distinct.

Two things to plan for:

- Directories from earlier states of the code are not reclaimed. Deleting one is
  only safe when no other process could be reading it, so prune them from a task
  rather than at boot.
- Any change to any watched file regenerates the whole cache, not only the
  fixtures that actually changed. Watch the narrowest set of files that still
  covers the cached rows.

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
- Preserving the cache makes invalidation your responsibility; see [Parallel Test Suites](#parallel-test-suites).

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
