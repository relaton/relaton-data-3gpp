# frozen_string_literal: true

mode = ARGV.shift || ""
mode = mode == "force" ? "-#{mode}" : ""

require "relaton/3gpp/data_fetcher"
Relaton::ThreeGpp::DataFetcher.fetch("status-smg-3GPP#{mode}")
