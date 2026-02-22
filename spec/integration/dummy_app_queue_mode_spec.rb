# frozen_string_literal: true

require "open3"

RSpec.describe "Dummy app queue mode integration" do
  QUEUE_DUMMY_ROOT = File.expand_path("../dummy", __dir__)
  QUEUE_SIM_SCRIPT = "script/rspec_queue_mode_sim.rb"

  def run_queue_mode_simulation
    Open3.capture3(
      {
        "RAILS_ENV" => "test"
      },
      "bundle",
      "exec",
      "ruby",
      QUEUE_SIM_SCRIPT,
      chdir: QUEUE_DUMMY_ROOT
    )
  end

  it "loads and runs new RSpec batches in a single process" do
    stdout, stderr, status = run_queue_mode_simulation
    output = [stdout, stderr].join("\n")

    expect(status.success?).to be(true), <<~MESSAGE
      Expected queue mode simulation to pass.
      Command output:
      #{output}
    MESSAGE

    expected_markers = [
      "FKIT_ASSERT:QMODE_BATCH1_RAN",
      "FKIT_ASSERT:QMODE_LATE_CACHE_ABSENT_AFTER_BATCH1",
      "FKIT_ASSERT:QMODE_BATCH2_RAN",
      "FKIT_ASSERT:QMODE_LATE_CACHE_GENERATED",
      "FKIT_ASSERT:QMODE_COMPLETE"
    ]

    expected_markers.each do |marker|
      expect(output).to include(marker), "Expected marker #{marker.inspect} in output.\nOutput:\n#{output}"
    end
  end
end
