# frozen_string_literal: true

mode = ARGV.shift || ""
mode = mode == "force" ? "-#{mode}" : ""

require "relaton_3gpp"
Relaton3gpp::DataFetcher.fetch("status-smg-3GPP#{mode}")
