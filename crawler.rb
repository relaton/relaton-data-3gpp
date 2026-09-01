# frozen_string_literal: true

mode = ARGV.shift || ""
mode = mode == "force" ? "-#{mode}" : ""

require "relaton/3gpp/data_fetcher"
require_relative "index_builder"

Relaton::ThreeGpp::DataFetcher.fetch("status-smg-3GPP#{mode}")

# The fetcher writes index-v2 only. Released relaton versions and the legacy
# relaton-3gpp gem still read index-v1.zip from this branch, so rebuild it here
# from data/ on every run. A no-op crawl leaves data/ untouched, so this
# reproduces the same file and the CI diff step skips the commit.
#
# Zipping and committing are not done here: relaton/support's shared
# crawler.yml zips every index*.yaml that changed and commits the yaml and zip.
ThreeGppIndexBuilder.build_index_v1
