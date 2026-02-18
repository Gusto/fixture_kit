# frozen_string_literal: true

require "fixtury_bot"

module FixturyBot
  module RSpec
    # Class methods (extended via config.extend)
    module ClassMethods
      # Declare which fixtury to use for this example group.
      # Can be overridden in nested groups (like `let`).
      #
      # Example:
      #   RSpec.describe User do
      #     fixtury :basic_users
      #
      #     it "has users" do
      #       expect(fixtury.alice).to be_present
      #     end
      #
      #     context "with admins" do
      #       fixtury :admin_users  # Override
      #
      #       it "has admin" do
      #         expect(fixtury.admin).to be_present
      #       end
      #     end
      #   end
      def fixtury(name)
        metadata[:fixtury_name] = name.to_sym
      end
    end

    # Instance methods (included via config.include)
    module InstanceMethods
      # Returns the FixtureSet for the current example's fixtury.
      # Access exposed records as methods: fixtury.alice, fixtury.posts
      def fixtury
        @_fixtury_loaded ||= begin
          fixtury_name = self.class.metadata[:fixtury_name]
          raise "No fixtury declared for this example group. Use `fixtury :name` in your describe/context block." unless fixtury_name

          FixturyBot.load_fixtury(fixtury_name)
        end
      end
    end
  end
end

# Configure RSpec integration
RSpec.configure do |config|
  config.extend FixturyBot::RSpec::ClassMethods
  config.include FixturyBot::RSpec::InstanceMethods

  config.before(:suite) do
    fixtury_path = FixturyBot.configuration.fixtury_path
    Dir[File.join(fixtury_path, "**/*.rb")].each { |f| require f }
  end
end
