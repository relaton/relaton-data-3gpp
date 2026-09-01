# frozen_string_literal: true

require "date"
require "yaml"
require "relaton/index"

#
# Builds `index-v1.yaml`, the legacy string-keyed index.
#
# The relaton gem's `Relaton::ThreeGpp::DataFetcher` writes only the
# pubid-keyed `index-v2`. Released relaton versions and the legacy
# relaton-3gpp gem still read `index-v1.zip` from this branch and require a
# bare String `:id`, so this repo keeps that file alive itself. Same
# arrangement as relaton-data-iana and relaton-data-bipm.
#
# The ids are read straight from each record's `docnumber`, which stores the
# v1 id verbatim. Nothing here parses a pubid, so a record pubid rejects still
# reaches the legacy index.
#
module ThreeGppIndexBuilder
  # Raised rather than publishing an empty index. crawler.rb runs the builder
  # after every fetch, so a crawl that failed partway would otherwise replace
  # the published file with `--- []` — worse than publishing nothing, because
  # the result is still a valid index and no consumer notices.
  class EmptyIndexError < StandardError; end

  FILE = "index-v1.yaml"
  GLOB = "data/*.yaml"

  # Relaton::Index pools its Type objects by name. Asking for "3gpp" again
  # with a different `file:` would evict the fetcher's index-v2 from the pool.
  POOL_KEY = :"3GPP_V1"

  #
  # Rebuild the index from the records on disk.
  #
  # @param [String] file index file to write
  # @param [String] glob records to read
  #
  # @raise [EmptyIndexError] if no record was found
  #
  # @return [Relaton::Index::Type] the index that was written
  #
  def build_index_v1(file: FILE, glob: GLOB)
    found = rows glob
    if found.empty?
      raise EmptyIndexError,
            "no record with a docnumber matched `#{glob}`; refusing to " \
            "overwrite `#{file}`. Run this from the repository root."
    end

    index = Relaton::Index.find_or_create POOL_KEY, file: file

    # A pooled Type outlives the crawl that filled it, and `add_or_update`
    # would otherwise merge the previous run's rows into this one.
    index.remove_all

    found.each { |id, path| index.add_or_update id, path }
    index.save
    index
  end

  private

  #
  # Read every record and pair its docnumber with its path, sorted by id so
  # that a later crawl produces a meaningful diff rather than a reshuffle.
  #
  # @return [Array<Array(String, String)>] id and path pairs
  #
  def rows(glob)
    # The `.sort` here only fixes the order the records are read and warned
    # about; the rows are ordered by id below.
    pairs = Dir.glob(glob).sort.each_with_object([]) do |path, acc|
      id = docnumber path
      acc << [id, path] if id
    end
    pairs.sort_by! { |id, _path| id }
    pairs
  end

  #
  # Read one record's docnumber. A record this cannot read is reported and
  # skipped: one bad file must not cost the whole legacy index. crawler.rb
  # runs the builder inside the crawl's single CI step, so an exception
  # escaping here would also discard the data/ update the fetcher just made.
  # Hence StandardError, as in relaton-data-iana's builder: a read error is as
  # survivable as a parse error.
  #
  # @return [String, nil] the v1 id, or nil
  #
  def docnumber(path)
    doc = YAML.safe_load File.read(path), permitted_classes: [Date, Time], aliases: true
    id = doc.is_a?(Hash) ? doc["docnumber"] : nil
    return id if id.is_a?(String) && !id.empty?

    warn "index-v1: skipping `#{path}`, it has no docnumber"
    nil
  rescue StandardError => e
    warn "index-v1: skipping `#{path}`, it cannot be read (#{e.class}: #{e.message})"
    nil
  end

  extend self
end
