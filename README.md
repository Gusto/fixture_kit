# FixturyBot

Generate Rails fixtures from Factory Bot definitions.

## The Problem

- **Rails fixtures** are fast (pre-loaded into the database, no runtime inserts) but painful to maintain by hand — especially as the schema evolves.
- **Factory Bot** is flexible and easy to write, but slow — every test that calls `create` hits the database.

## The Solution

FixturyBot lets you define test data using Factory Bot, generate YAML fixture files, and load those fixtures in your tests. You get Factory Bot's ergonomics at fixture speed.

## Installation

Add to your Gemfile:

```ruby
group :development, :test do
  gem "fixtury_bot"
end
```

## Quick Start

### 1. Define a Fixtury

Create one file per fixtury in `spec/fixtury/`:

```ruby
# spec/fixtury/bookstore.rb
FixturyBot.define(:bookstore) do
  store = create(:store, name: "Powell's Books")
  owner = create(:user, :admin, store: store)
  books = create_list(:book, 3, store: store)
  featured_book = create(:book, :bestseller, store: store, title: "Dune")

  # Non-exposed records are still generated as fixtures,
  # but won't be accessible in tests.
  create(:audit_log)
  create(:tax_config)

  expose(store:, owner:, books:, featured_book:)
end
```

### 2. Generate Fixtures

```bash
# Generate all fixturys
bundle exec fixtury_bot generate

# Generate a specific fixtury
bundle exec fixtury_bot generate bookstore
```

This generates YAML fixtures at `spec/fixtures/fixtury_bot/bookstore/`:

```
spec/fixtures/fixtury_bot/bookstore/
├── .fixtury_bot.yml          # Metadata (databases + exposed records)
├── primary/
│   ├── stores.yml
│   ├── users.yml
│   ├── books.yml
│   ├── audit_logs.yml
│   └── tax_configs.yml
└── analytics/                # Additional databases, if applicable
    └── events.yml
```

### 3. Use in Tests

```ruby
RSpec.describe Book do
  fixtury :bookstore

  it "belongs to a store" do
    expect(fixtury.featured_book.store).to eq(fixtury.store)
  end

  it "has multiple books" do
    expect(fixtury.books.size).to eq(3)
    expect(fixtury.books).to all(be_a(Book))
  end

  it "supports bracket notation" do
    expect(fixtury[:owner]).to eq(fixtury.owner)
  end
end
```

### 4. Validate Fixtures

Ensure committed fixtures match current fixtury definitions:

```bash
bundle exec fixtury_bot validate
bundle exec fixtury_bot validate bookstore
```

## Configuration

```ruby
# config/initializers/fixtury_bot.rb (or spec/support/fixtury_bot.rb)
FixturyBot.configure do |config|
  config.fixtury_path = "spec/fixtury"
  config.fixtures_path  = "spec/fixtures/fixtury_bot"
  config.autogenerate = false if ENV["CI"]

  # Run before each fixtury generate (e.g. seed Faker for deterministic data)
  config.setup do
    Faker::Config.random = Random.new(12345)
  end
end
```

Paths are auto-detected based on whether `spec/` or `test/` exists.

## Autogenerate

By default, FixturyBot auto-generates fixtures when they're missing or stale during test runs. This means you don't need to manually run `fixtury_bot generate` — fixtures are created on the fly the first time a test needs them, and regenerated whenever the source fixtury file changes.

Staleness is detected by comparing a SHA256 digest of the source file (where `FixturyBot.define` was called) against the digest stored when fixtures were last generated.

### CI Setup

On CI, disable autogenerate so that missing or stale fixtures fail fast:

```ruby
FixturyBot.configure do |config|
  config.autogenerate = false if ENV["CI"]
end
```

Pre-generate fixtures in a CI setup step and cache the output directory:

```bash
bundle exec fixtury_bot generate
```

When `autogenerate` is `false`:
- Missing fixtures raise `ArgumentError`
- Stale fixtures (source file changed) raise `FixturyBot::StaleFixturesError`

## Fixturys

Each fixtury is a standalone block that uses Factory Bot to build test data. One fixtury per file is the recommended convention.

### `create` and `create_list`

These proxy directly to `FactoryBot.create` and support traits and attributes:

```ruby
FixturyBot.define(:example) do
  create(:user)
  create(:user, :verified, email: "alice@example.com")
  create_list(:product, 5, active: true)
end
```

Every record created inside a fixtury is tracked and written to YAML fixtures, whether exposed or not.

### `expose`

`expose` takes a hash of name-record pairs, controlling which records are accessible in your tests — similar to `export` in a JavaScript module. Records that aren't exposed are still persisted as fixtures but can't be accessed via the `fixtury` helper.

```ruby
FixturyBot.define(:example) do
  store = create(:store)
  owner = create(:user, store: store)
  products = create_list(:product, 10, store: store)

  # Expose all at once using Ruby's shorthand syntax
  expose(store:, owner:, products:)
end
```

In tests, `fixtury.store` returns the record, `fixtury.products` returns an array.

You can also use explicit names when the variable name differs from the desired expose name:

```ruby
expose(admin: user, items: line_items)
```

Records that aren't exposed are still written to fixtures but can't be accessed via the `fixtury` helper:

```ruby
FixturyBot.define(:with_config) do
  tax_config = create(:tax_config, rate: 0.08)
  store = create(:store, tax_config: tax_config)
  order = create(:order, store: store)

  expose(store:, order:)
  # tax_config is in fixtures but not accessible via fixtury.tax_config
end
```

### Record Naming

- **Exposed single records** use the expose name as the fixture name: `expose(owner: user)` produces fixture `owner`
- **Exposed lists** keep auto-generated names for individual records: `expose(books: create_list(:book, 3))` produces fixtures `book_1`, `book_2`, `book_3`
- **Non-exposed records** are auto-named: `create(:audit_log)` becomes `audit_log_1`

## Multi-Database Support

Records are automatically grouped by their database connection:

```
spec/fixtures/fixtury_bot/bookstore/
├── primary/
│   ├── stores.yml
│   └── users.yml
└── analytics/
    └── events.yml
```

## How It Works

1. **Execution** — FixturyBot runs your fixtury block, calling Factory Bot to create records in a test database. Every record is tracked.
2. **Serialization** — Tracked records are serialized to YAML. Foreign keys are resolved to fixture references (e.g., `user: owner` instead of `user_id: 42`). Polymorphic associations are handled automatically. Timestamps are omitted.
3. **Loading** — In tests, `fixtury` loads the YAML fixtures using `ActiveRecord::FixtureSet`. Only exposed records are returned through the `fixtury` accessor.
4. **Validation** — Re-runs the fixtury and diffs the output against committed fixtures to detect drift.

### Association Resolution

Foreign keys are converted to fixture references:

```yaml
# Raw database value:
user_id: 42

# What FixturyBot writes:
user: owner
```

Polymorphic associations include the type:

```yaml
commentable: featured_book (Book)
```

## Rake Tasks

With Rails, rake tasks are available automatically:

```bash
rake fixtury_bot:generate
rake fixtury_bot:generate FIXTURY=bookstore

rake fixtury_bot:validate
rake fixtury_bot:validate FIXTURY=bookstore
```

## Requirements

- Ruby >= 3.3
- Rails >= 8.0
- Factory Bot >= 5.0

## License

MIT License. See [LICENSE](LICENSE) for details.
