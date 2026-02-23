# FixtureKit

Fast test fixtures with SQL caching.

## The Problem

Test data setup is slow. Every `Model.create!` or `FactoryBot.create` hits the database, and complex test scenarios can require dozens of inserts per test.

## The Solution

FixtureKit caches database records as raw SQL INSERT statements. It executes your fixture definition once, captures the resulting database state, and generates optimized batch INSERT statements. Fixture loads then replay these statements directly: no ORM overhead, no callbacks, just fast SQL.

Combined with RSpec's transactional fixtures, each test runs in a transaction that rolls back—so cached data can be reused across tests without cleanup.

## Installation

Add to your Gemfile:

```ruby
group :test do
  gem "fixture_kit"
end
```

## Quick Start

### 1. Define a Fixture

Create fixture files in `spec/fixture_kit/` (or `test/fixture_kit/` for test-unit/minitest-style setups). Use whatever method you prefer to create records.

**Using ActiveRecord directly:**

```ruby
# spec/fixture_kit/bookstore.rb
FixtureKit.define do
  store = Store.create!(name: "Powell's Books")
  owner = User.create!(name: "Alice", email: "alice@example.com", store: store)

  books = 3.times.map do |i|
    Book.create!(title: "Book #{i + 1}", store: store)
  end

  featured = Book.create!(title: "Dune", store: store, featured: true)

  expose(store: store, owner: owner, books: books, featured: featured)
end
```

**Using FactoryBot:**

```ruby
# spec/fixture_kit/bookstore.rb
FixtureKit.define do
  store = FactoryBot.create(:store, name: "Powell's Books")
  owner = FactoryBot.create(:user, :admin, store: store)
  books = FactoryBot.create_list(:book, 3, store: store)
  featured = FactoryBot.create(:book, :bestseller, store: store, title: "Dune")

  expose(store: store, owner: owner, books: books, featured: featured)
end
```

The filename determines the fixture name—no need to pass a name to `define`.

You can call `expose` multiple times to organize your setup code:

```ruby
FixtureKit.define do
  # Set up users
  admin = User.create!(name: "Admin", role: "admin")
  member = User.create!(name: "Member", role: "member")
  expose(admin: admin, member: member)

  # Set up projects
  project = Project.create!(name: "Website", owner: admin)
  expose(project: project)

  # Set up tasks
  tasks = 3.times.map { |i| Task.create!(title: "Task #{i + 1}", project: project) }
  expose(tasks: tasks)
end
```

Exposing the same name twice raises `FixtureKit::DuplicateNameError`.

### 2. Use in Tests

```ruby
# spec/models/book_spec.rb
RSpec.describe Book do
  fixture "bookstore"

  it "belongs to a store" do
    expect(fixture.featured.store).to eq(fixture.store)
  end

  it "has multiple books" do
    expect(fixture.books.size).to eq(3)
  end

  it "exposes records as methods" do
    expect(fixture.owner.email).to eq("alice@example.com")
  end
end
```

`fixture` returns a `Repository` and exposes records as methods (for example, `fixture.owner`).

You can also define fixtures anonymously inline:

```ruby
RSpec.describe Book do
  fixture do
    owner = User.create!(name: "Alice", email: "alice@example.com")
    featured = Book.create!(title: "Dune", owner: owner)
    expose(owner: owner, featured: featured)
  end

  it "uses inline fixture data" do
    expect(fixture.featured.owner).to eq(fixture.owner)
  end
end
```

### 3. Configure RSpec

```ruby
# spec/rails_helper.rb
require "fixture_kit/rspec"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
```

When you call `fixture "name"` or `fixture do ... end` in an example group, FixtureKit registers that fixture with its runner.

### 4. Configure Minitest

```ruby
# test/test_helper.rb
require "fixture_kit/minitest"

class ActiveSupport::TestCase
  self.use_transactional_tests = true
end
```

When you call `fixture "name"` or `fixture do ... end` in a test class, FixtureKit registers that fixture with its runner and mounts it during test setup.

## Configuration

```ruby
# spec/support/fixture_kit.rb
FixtureKit.configure do |config|
  # Where fixture definitions live (default: fixture_kit).
  # Framework entrypoints set a framework-specific default:
  # - fixture_kit/rspec -> spec/fixture_kit
  # - fixture_kit/minitest -> test/fixture_kit
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s

  # Where cache files are stored (default: tmp/cache/fixture_kit)
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s

  # Wrapper used to isolate generation work (default: FixtureKit::MinitestIsolator)
  # config.isolator = FixtureKit::MinitestIsolator
  # config.isolator = FixtureKit::RSpecIsolator

  # Optional callback, called right before a fixture cache is generated.
  # Called on first generation and forced regeneration.
  # Receives the fixture identifier:
  # - named fixtures: String (e.g. "teams/basic")
  # - anonymous fixtures: scope class
  # config.on_cache_save = ->(identifier) { puts "cached #{identifier}" }

  # Optional callback, called right before a fixture cache is mounted.
  # Receives the same fixture identifier shape as on_cache_save.
  # config.on_cache_mount = ->(identifier) { puts "mounted #{identifier}" }
end
```

Custom isolators should subclass `FixtureKit::Isolator` and implement `#run`.
`#run` receives the generation block and should execute it in whatever lifecycle you need.

By default, FixtureKit uses `FixtureKit::MinitestIsolator`, which runs generation inside an internal `ActiveSupport::TestCase` and removes that harness case from minitest runnables.

When using `fixture_kit/rspec`, FixtureKit sets `FixtureKit::RSpecIsolator`. It runs generation inside an internal RSpec example, and uses a null reporter so harness runs do not count toward suite example totals.

## Lifecycle

Fixture generation is managed by `FixtureKit::Runner`.

1. Calling `fixture "name"` or `fixture do ... end` registers the fixture with the runner.
2. Runner `start`:
   - clears `cache_path` (unless preserve-cache is enabled),
   - generates caches for all already-registered fixtures.
3. If new tests are loaded after start (for example, queue-mode CI runners), newly registered fixtures are cached immediately.
4. At test runtime, `fixture` mounts from cache and returns a `Repository`.

When runner start happens:

- `fixture_kit/rspec`: in `before(:suite)`.
- `fixture_kit/minitest`: lazily during test setup for the first test class that declares `fixture`.

## Fixture Declaration Rules

- Only one `fixture` declaration is allowed per test context.
- Declaring a fixture twice in the same context raises `FixtureKit::MultipleFixtures`.
- Child contexts/classes can declare their own fixture and override parent declarations.
- Providing both a name and a block (or neither) raises `FixtureKit::InvalidFixtureDeclaration`.

### Preserving Cache Locally

If you want to skip cache clearing when the runner starts (e.g., to reuse caches across test runs during local development), set the `FIXTURE_KIT_PRESERVE_CACHE` environment variable:

```bash
FIXTURE_KIT_PRESERVE_CACHE=1 bundle exec rspec
```

Truthy values are case-insensitive: `1`, `true`, `yes`.

This is useful when you're iterating on tests and your fixture definitions haven't changed.

## Nested Fixtures

Organize fixtures in subdirectories:

```ruby
# spec/fixture_kit/teams/sales.rb
FixtureKit.define do
  # ...
end
```

```ruby
fixture "teams/sales"
```

## Anonymous Fixture Cache Paths

Anonymous fixture caches are written under the `_anonymous/` directory inside `cache_path`.

- Minitest: class name is underscored into a path.
  - `MyFeatureTest` -> `_anonymous/my_feature_test.json`
- RSpec: class name is underscored after removing `RSpec::ExampleGroups::`.
  - `RSpec::ExampleGroups::Foo::WithFixtureKit::Hello` -> `_anonymous/foo/with_fixture_kit/hello.json`

## How It Works

1. **Cache generation**: FixtureKit executes your definition block inside the configured isolator, subscribes to `sql.active_record` notifications to track created/updated/deleted models, queries those model tables, and caches SQL statements for current table contents.

2. **Mounting**: FixtureKit loads the cached JSON file, clears each tracked table, and executes the raw SQL INSERT statements directly. No ORM instantiation, no callbacks.

3. **Repository build**: FixtureKit resolves exposed records by model + id and returns a `Repository` for method-based access.

4. **Transaction isolation**: Use framework transactions (`use_transactional_fixtures` in RSpec, `use_transactional_tests` in Minitest) so test writes roll back and cached data can be reused safely between tests.

### Cache Format

Caches are stored as JSON files in `tmp/cache/fixture_kit/`:

```json
{
  "records": {
    "User": "INSERT INTO users (id, name, email) VALUES (1, 'Alice', 'alice@example.com'), (2, 'Bob', 'bob@example.com')",
    "Project": "INSERT INTO projects (id, name, user_id) VALUES (1, 'Website', 1)"
  },
  "exposed": {
    "alice": { "model": "User", "id": 1 },
    "bob": { "model": "User", "id": 2 },
    "project": { "model": "Project", "id": 1 }
  }
}
```

- **records**: Maps model names to their INSERT statements. Using model names (not table names) allows FixtureKit to use the correct database connection for multi-database setups.
- **exposed**: Maps fixture accessor names to their model class and ID for querying after cache replay.

## Cache Management

Delete the cache directory to force regeneration:
```bash
rm -rf tmp/cache/fixture_kit
```

Caches are cleared at runner start unless `FIXTURE_KIT_PRESERVE_CACHE` is truthy.

## Multi-Database Support

FixtureKit automatically handles multiple databases. Records are stored by model name in the cache, and when replaying, FixtureKit uses each model's database connection to execute the INSERT statements. This means records are automatically inserted into the correct database without any additional configuration.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0

## License

MIT License. See [LICENSE](LICENSE) for details.
