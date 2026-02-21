# FixtureKit

Fast test fixtures with SQL caching.

## The Problem

Test data setup is slow. Every `Model.create!` or `FactoryBot.create` hits the database, and complex test scenarios can require dozens of inserts per test.

## The Solution

FixtureKit caches database records as raw SQL INSERT statements. On first use, it executes your fixture definition, captures the resulting database state, and generates optimized batch INSERT statements. Subsequent loads replay these statements directly—no ORM overhead, no callbacks, just fast SQL.

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

Create fixture files in `spec/fixture_kit/`. Use whatever method you prefer to create records—FixtureKit doesn't care.

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

## Configuration

```ruby
# spec/support/fixture_kit.rb
FixtureKit.configure do |config|
  # Where fixture definitions live (default: spec/fixture_kit)
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s

  # Where cache files are stored (default: tmp/cache/fixture_kit)
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s

  # Whether to regenerate caches on every run (default: true)
  config.autogenerate = true

  # Optional: customize how pregeneration is wrapped.
  # Default is FixtureKit::TestCase::Generator.
  # config.generator = FixtureKit::TestCase::Generator
end
```

Custom generators should subclass `FixtureKit::Generator` and implement `#run`.
`#run` receives the pregeneration block and should execute it in whatever lifecycle you need.

### Autogenerate

When `autogenerate` is `true` (the default), FixtureKit clears all caches at the start of each test run, then regenerates them on first use. Subsequent tests that use the same fixture reuse the cache from earlier in the run. This ensures your test data always matches your fixture definitions.

When `autogenerate` is `false`, FixtureKit pre-generates all fixture caches at suite start. This runs through the configured `generator`, and still rolls back database changes.

By default, FixtureKit uses `FixtureKit::TestCase::Generator`, which runs pregeneration inside an internal `ActiveSupport::TestCase` so setup/teardown hooks and transactional fixture behavior run as expected. The internal test case is removed from Minitest runnables, so it does not count toward suite totals.

When using `fixture_kit/rspec`, FixtureKit sets `FixtureKit::RSpec::Generator` as the generator. This runs pregeneration inside an internal RSpec example so your normal `before`/`around`/`after` hooks apply. The internal example uses a null reporter, so it does not count toward suite example totals.

### Preserving Cache Locally

If you want to skip cache clearing at suite start (e.g., to reuse caches across test runs during local development), set the `FIXTURE_KIT_PRESERVE_CACHE` environment variable:

```bash
FIXTURE_KIT_PRESERVE_CACHE=1 bundle exec rspec
```

This is useful when you're iterating on tests and your fixture definitions haven't changed.

### CI Setup

For CI, set `autogenerate` to `false`. FixtureKit will automatically generate any missing caches at suite start:

```ruby
FixtureKit.configure do |config|
  config.autogenerate = !ENV["CI"]
end
```

This means CI "just works" - no need to pre-generate caches or commit them to the repository. The first test run will generate all caches, and subsequent runs (if caches are preserved between builds) will reuse them.

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

1. **First load (cache miss)**: FixtureKit executes your definition block, subscribes to `sql.active_record` notifications to track which tables received INSERTs, queries all records from those tables, and generates batch INSERT statements with conflict handling (`INSERT OR IGNORE` for SQLite, `ON CONFLICT DO NOTHING` for PostgreSQL, `INSERT IGNORE` for MySQL).

2. **Subsequent loads (cache hit)**: FixtureKit loads the cached JSON file and executes the raw SQL INSERT statements directly. No ORM instantiation, no callbacks—just fast SQL execution.

3. **In-memory caching**: Once a cache file is parsed, the data is stored in memory. Multiple tests using the same fixture within a single test run don't re-read or re-parse the JSON file.

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
- **exposed**: Maps fixture accessor names to their model class and ID for querying after cache replay

## Cache Management

Delete the cache directory to force regeneration:
```bash
rm -rf tmp/cache/fixture_kit
```

Caches are automatically cleared at suite start when `autogenerate` is enabled, so manual clearing is rarely needed.

## Multi-Database Support

FixtureKit automatically handles multiple databases. Records are stored by model name in the cache, and when replaying, FixtureKit uses each model's database connection to execute the INSERT statements. This means records are automatically inserted into the correct database without any additional configuration.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0

## License

MIT License. See [LICENSE](LICENSE) for details.
