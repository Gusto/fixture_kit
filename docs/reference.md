# FixtureKit Reference

Canonical API, configuration, and contract reference.

## Core Concepts

- **Definition**: `FixtureKit.define { ... }` returns a `FixtureKit::Definition`.
- **Fixture**: wraps an identifier and a definition; handles cache save/mount.
- **Cache**: persists and replays SQL for touched models.
- **Repository**: exposes records via methods, loaded lazily and memoized per test.
- **Runner**: owns configuration, registry, startup state, and adapter instance.

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

## Adapter Contract

Subclass `FixtureKit::Adapter` and implement:

`#execute { ... }`
- Runs fixture generation in framework-specific isolation.

`#identifier_for(identifier)`
- Receives non-string fixture identifier and returns normalized String identifier.
- `_anonymous/` prefixing is applied by `FixtureKit::Cache`.

Adapter initialization:

```ruby
adapter_instance = config.adapter.new(config.adapter_options)
```

Options are available via `attr_reader :options` in `FixtureKit::Adapter`.

## Callback Events

Register using configuration methods:

`config.on_cache_save { |cache| ... }`
- Runs before cache save.

`config.on_cache_saved { |cache, duration| ... }`
- Runs after cache save.
- `duration` is elapsed seconds as `Float`.

`config.on_cache_mount { |cache| ... }`
- Runs before cache mount.

`config.on_cache_mounted { |cache, duration| ... }`
- Runs after cache mount.
- `duration` is elapsed seconds as `Float`.

The `cache` argument is a `FixtureKit::Cache` instance. Useful methods:
- `cache.identifier` — String cache identifier (no `.json` suffix).
- `cache.path` — full file path to the cache JSON file.

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
- Anonymous fixture: identifier is `_anonymous/<adapter-normalized-scope>`.

Examples:
- Named: `teams/basic` -> `tmp/cache/fixture_kit/teams/basic.json`
- Anonymous RSpec: `_anonymous/foo/with_fixture_kit/hello`
- Anonymous Minitest: `_anonymous/my_feature_test`

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
- `FixtureKit::FixtureDefinitionNotFound`
- `FixtureKit::RunnerAlreadyStartedError`
- `FixtureKit::CircularFixtureInheritance`

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0
