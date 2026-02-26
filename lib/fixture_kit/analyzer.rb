# frozen_string_literal: true

# FixtureKit::Analyzer — Find high-ROI FixtureKit optimization targets.
#
# Analyzes RSpec specs via --dry-run to find factory_bot `let` blocks
# and rank them by how many examples each `let` is shared across.
# The more examples share a let, the bigger the speedup from caching
# it with FixtureKit.
#
# Usage:
#   rspec --dry-run --require fixture_kit/analyzer [spec files or dirs...]
#
# Options (via env vars):
#   ANALYZER_FORMAT=text|json    Output format (default: text)
#   ANALYZER_LIMIT=N             Max files to show (default: 50)
#   ANALYZER_LETS_PER_FILE=N     Max lets to show per file (default: 8)
#   ANALYZER_MIN_REUSE=N         Only show files with max reuse >= N (default: 2)
#   ANALYZER_OUTPUT=path         Write JSON to file (default: none)

module FixtureKit
  module Analyzer
    autoload :AstFactoryDetector, File.expand_path("analyzer/ast_factory_detector", __dir__)
    autoload :GroupAnalyzer,      File.expand_path("analyzer/group_analyzer", __dir__)
    autoload :LetDefinition,      File.expand_path("analyzer/let_definition", __dir__)
    autoload :FileResult,         File.expand_path("analyzer/file_result", __dir__)
    autoload :TextFormatter,      File.expand_path("analyzer/text_formatter", __dir__)
    autoload :Runner,             File.expand_path("analyzer/runner", __dir__)
  end
end

# Auto-hook into RSpec when loaded via --require
if defined?(RSpec)
  FixtureKit::Analyzer::Runner.install_rspec_hook!
end
