# FixtureKit

Fast test fixtures with SQL caching.

- Full documentation (guides): [GitHub Wiki](https://github.com/Gusto/fixture_kit/wiki)
- API/reference (canonical): [docs/reference.md](docs/reference.md)

## Installation

```ruby
group :test do
  gem "fixture_kit"
end
```

## Quick Start

### 1. Define a fixture

```ruby
# spec/fixture_kit/project_management.rb
FixtureKit.define do
  owner = User.create!(name: "Alice", email: "alice@example.com")
  project = Project.create!(name: "Roadmap", owner: owner)

  expose(owner: owner, project: project)
end
```

### 2. Configure your framework

RSpec:

```ruby
# spec/rails_helper.rb
require "fixture_kit/rspec"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
```

Minitest:

```ruby
# test/test_helper.rb
require "fixture_kit/minitest"

class ActiveSupport::TestCase
  self.use_transactional_tests = true
end
```

### 3. Use the fixture in tests

RSpec:

```ruby
RSpec.describe Project do
  fixture "project_management"

  it "loads exposed records" do
    expect(fixture.project.owner).to eq(fixture.owner)
  end
end
```

Minitest:

```ruby
class ProjectTest < ActiveSupport::TestCase
  fixture "project_management"

  test "loads exposed records" do
    assert_equal fixture.owner, fixture.project.owner
  end
end
```

`fixture` returns a `Repository`, and exposed names become reader methods.

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0

## License

MIT. See [LICENSE](LICENSE).
