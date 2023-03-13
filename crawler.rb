# frozen_string_literal: true

require 'fileutils'

mode = ARGV.shift || ""

unless mode.empty?
  mode = "-#{mode}"
end

# FileUtils.rm_rf('data')

system("sudo apt-get install mdbtools")

system("relaton fetch-data status-smg-3GPP#{mode}")

system("git add current.yaml")
