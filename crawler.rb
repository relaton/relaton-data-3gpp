# frozen_string_literal: true

require 'fileutils'
require 'relaton_3gpp'

FileUtils.rm_rf('data')

system("sudo apt-get install mdbtools")

Relaton3gpp::DataFetcher.fetch