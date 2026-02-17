# frozen_string_literal: true

module FixturyBot
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :fixtury_bot do
        desc "Generate all fixturys to fixture files"
        task generate: :environment do
          fixtury_name = ENV["FIXTURY"]
          FixturyBot.generate(fixtury_name)
          puts "Fixtures generated successfully"
        end

        desc "Validate fixtures match current fixtury definitions"
        task validate: :environment do
          fixtury_name = ENV["FIXTURY"]
          result = FixturyBot.validate(fixtury_name)

          if result.valid?
            puts "All fixtures are valid"
            exit 0
          else
            puts "Fixture validation failed:"
            result.differences.each do |fixtury, diffs|
              puts "\nFixtury: #{fixtury}"
              diffs.each do |diff|
                case diff[:type]
                when :new
                  puts "  + New fixture: #{diff[:database]}/#{diff[:table]}/#{diff[:fixture]}"
                when :removed
                  puts "  - Removed fixture: #{diff[:database]}/#{diff[:table]}/#{diff[:fixture]}"
                when :modified
                  puts "  ~ Modified fixture: #{diff[:database]}/#{diff[:table]}/#{diff[:fixture]}"
                  diff[:changes].each do |attr, change|
                    puts "      #{attr}: #{change[:committed].inspect} → #{change[:generated].inspect}"
                  end
                end
              end
            end
            exit 1
          end
        end
      end
    end
  end
end
