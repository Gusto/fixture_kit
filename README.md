# FixtureKit

Fast test fixtures with SQL caching.

## The Problem

Test data setup is slow. Every `Model.create!` or `FactoryBot.create` hits the database, and complex test scenarios can require dozens of inserts per test.

## The Solution

FixtureKit caches database records after the first test run. Subsequent runs replay the cached data using `upsert_all`, skipping the expensive setup code entirely.

- **First run**: Execute your setup code, capture all INSERTs, cache to disk
- **Subsequent runs**: Replay cached records instantly

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

  it "supports hash-style access" do
    expect(fixture[:owner]).to eq(fixture.owner)
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

## Configuration

```ruby
# spec/support/fixture_kit.rb
FixtureKit.configure do |config|
  # Where fixture definitions live (default: spec/fixture_kit)
  config.fixture_path = Rails.root.join("spec/fixture_kit").to_s

  # Where cache files are stored (default: tmp/cache/fixture_kit)
  config.cache_path = Rails.root.join("tmp/cache/fixture_kit").to_s

  # Run before each fixture executes (e.g., seed random data)
  config.setup do
    Faker::Config.random = Random.new(12345)
  end
end
```

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

1. **First run**: FixtureKit executes your definition block, subscribes to `sql.active_record` notifications to track which tables received INSERTs, then queries all records from those tables and caches them to a YAML file.

2. **Subsequent runs**: FixtureKit loads the cache and replays records using `upsert_all` with `on_duplicate: :skip`. This is much faster than re-running your setup code.

3. **Transaction isolation**: RSpec's `use_transactional_fixtures` wraps each test in a transaction that rolls back, so cached data doesn't persist between tests.

## Cache Management

Clear all caches:
```ruby
FixtureKit.clear_cache
```

Clear a specific fixture's cache:
```ruby
FixtureKit.clear_cache("bookstore")
```

Or delete the cache directory:
```bash
rm -rf tmp/cache/fixture_kit
```

## Multi-Database Support

FixtureKit automatically handles multiple databases. Records are grouped by their database connection and replayed to the correct database.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0

## License

MIT License. See [LICENSE](LICENSE) for details.
