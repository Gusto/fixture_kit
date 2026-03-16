# FixtureKit

Fixture-level performance without giving up FactoryBot-style test setup.

Rails fixtures are very performant. But in large companies with hundreds of models and varying Rails familiarity, maintaining a well-manicured garden of YAML files quickly becomes unrealistic.

Teams reach for tools like FactoryBot to simplify test setup and keep things readable. The tradeoff is performance. FixtureKit gives you the speed wins while letting you keep the test setup tooling your teams already use, by generating and caching fixture data on-demand.

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

### 4. Extend existing fixtures

Use `extends` to build on top of an existing named fixture. The parent fixture's data is created first, and you can reference its exposed records via `parent`:

```ruby
# spec/fixture_kit/project_with_tasks.rb
FixtureKit.define(extends: "project_management") do
  task = Task.create!(
    title: "Ship v2",
    project: parent.project,
    assignee: parent.owner
  )

  expose(task: task)
end
```

```ruby
RSpec.describe Task do
  fixture "project_with_tasks"

  it "belongs to the parent project" do
    expect(fixture.task.project).to eq(Project.find_by(name: "Roadmap"))
  end
end
```

Parent records are **not** auto-exposed — only names you explicitly `expose` in the child are available on `fixture`. You can also extend inline:

```ruby
RSpec.describe Task do
  fixture(extends: "project_management") do
    task = Task.create!(title: "Ship v2", project: parent.project, assignee: parent.owner)
    expose(task: task)
  end

  it "creates a task under the inherited project" do
    expect(fixture.task.project.name).to eq("Roadmap")
  end
end
```

## Requirements

- Ruby >= 3.3
- ActiveRecord >= 8.0
- ActiveSupport >= 8.0

## Releasing

1. Bump the version in `lib/fixture_kit/version.rb`
2. Update lockfiles:
   ```sh
   bundle install
   cd spec/dummy && bundle install && cd ../..
   bundle exec appraisal install
   ```
3. Commit and push to main:
   ```sh
   git add lib/fixture_kit/version.rb spec/dummy/Gemfile.lock gemfiles/*.gemfile.lock
   git commit -m "Release vX.Y.Z"
   git push
   ```
4. Create a GitHub release:
   ```sh
   gh release create vX.Y.Z --title "vX.Y.Z" --target main --generate-notes
   ```

## License

MIT. See [LICENSE](LICENSE).
