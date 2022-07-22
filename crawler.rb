# frozen_string_literal: true

require 'fileutils'

# FileUtils.rm_rf('data')

system("sudo apt-get install mdbtools")

system("relaton fetch-data status-smg-3GPP")

system("git add current.yaml")
