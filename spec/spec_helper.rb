# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "relaton/index"

# The builder must not need pubid: index-v1 is string-keyed. It is required
# here only so an example can build a pubid-keyed index-v2 alongside it.
require "pubid"

require_relative "../index_builder"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random

  # Relaton::Index pools its Type objects process-wide, so one example's
  # index would otherwise survive into the next.
  config.before do
    Relaton::Index.close ThreeGppIndexBuilder::POOL_KEY
    Relaton::Index.close "3gpp"
  end
end

#
# Copy a fixture tree into an empty directory as `data/`, and run the block
# from there. The builder then sees the relative `data/*.yaml` paths it sees
# in a real crawl, and writes its index beside them.
#
def in_data_dir(fixture = "data")
  Dir.mktmpdir("relaton-data-3gpp-") do |dir|
    FileUtils.cp_r fixture_path(fixture), File.join(dir, "data")
    Dir.chdir(dir) { yield dir }
  end
end

def fixture_path(name)
  File.expand_path "fixtures/#{name}", __dir__
end
