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

### 3. Configure RSpec

```ruby
# spec/rails_helper.rb
require "fixture_kit/rspec"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
```

When you call `fixture "name"` in an example group, FixtureKit registers that fixture with its runner.

## Configuration

```ruby
# spec/support/fixture_kit.rb
FixtureKit.configure do |config|
  # Where fixture definitions live (default: spec/fixture_kit)
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s

  # Where cache files are stored (default: tmp/cache/fixture_kit)
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s

  # Wrapper used to isolate generation work (default: FixtureKit::MinitestIsolator)
  # config.isolator = FixtureKit::MinitestIsolator
  # config.isolator = FixtureKit::RSpecIsolator

  # Optional callback, called whenever a fixture cache is generated.
  # Receives the fixture name as a String.
  # config.on_cache = ->(fixture_name) { puts "cached #{fixture_name}" }
end
```

Custom isolators should subclass `FixtureKit::Isolator` and implement `#run`.
`#run` receives the generation block and should execute it in whatever lifecycle you need.

By default, FixtureKit uses `FixtureKit::MinitestIsolator`, which runs generation inside an internal `ActiveSupport::TestCase` and removes that harness case from minitest runnables.

When using `fixture_kit/rspec`, FixtureKit sets `FixtureKit::RSpecIsolator`. It runs generation inside an internal RSpec example, and uses a null reporter so harness runs do not count toward suite example totals.

## Lifecycle

Fixture generation is managed by `FixtureKit::Runner`.

With `fixture_kit/rspec`:

1. `fixture "name"` registers the fixture with the runner during spec file load.
2. In `before(:suite)`, runner `start`:
   - clears `cache_path` (unless preserve-cache is enabled),
   - generates caches for all already-registered fixtures.
3. If new spec files are loaded later (for example, queue-mode CI runners), newly registered fixtures are generated immediately because the runner has already started.
4. At example runtime, fixture mounting loads from cache.

### Preserving Cache Locally

If you want to skip cache clearing at suite start (e.g., to reuse caches across test runs during local development), set the `FIXTURE_KIT_PRESERVE_CACHE` environment variable:

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

## How It Works

1. **Cache generation**: FixtureKit executes your definition block inside the configured isolator, subscribes to `sql.active_record` notifications to track inserted models, queries those model tables, and generates batch INSERT statements with conflict handling (`INSERT OR IGNORE` for SQLite, `ON CONFLICT DO NOTHING` for PostgreSQL, `INSERT IGNORE` for MySQL).

2. **Mounting**: FixtureKit loads the cached JSON file and executes the raw SQL INSERT statements directly. No ORM instantiation, no callbacks.

3. **Repository build**: FixtureKit resolves exposed records by model + id and returns a `Repository` for method-based access.

4. **Transaction isolation**: RSpec's `use_transactional_fixtures` wraps each test in a transaction that rolls back, so data doesn't persist between tests.

### Cache Format

Caches are stored as JSON files in `tmp/cache/fixture_kit/`:

```json
{
  "records": {
    "User": "INSERT OR IGNORE INTO users (id, name, email) VALUES (1, 'Alice', 'alice@example.com'), (2, 'Bob', 'bob@example.com')",
    "Project": "INSERT OR IGNORE INTO projects (id, name, user_id) VALUES (1, 'Website', 1)"
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
