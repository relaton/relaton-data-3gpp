# frozen_string_literal: true

system("sudo apt-get install mdbtools")

mode = ARGV.shift || ""
mode = mode == "force" ? "-#{mode}" : ""

require "relaton_3gpp"
Relaton3gpp::DataFetcher.fetch("status-smg-3GPP#{mode}")

system("zip index-v1.zip index-v1.yaml")
system("git add current.yaml index-v1.zip index-v1.yaml")
