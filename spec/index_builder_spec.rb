# frozen_string_literal: true

RSpec.describe ThreeGppIndexBuilder do
  # Copied verbatim from the published index-v1, in the order the builder
  # must produce.
  let(:expected_rows) do
    [
      { id: "TR 00.01U:UMTS/3.0.0", file: "data/tr-00-01u-umts-3-0-0.yaml" },
      { id: "TS 05.05:Ph1/3.14.0", file: "data/ts-05-05-ph1-3-14-0.yaml" },
      { id: "TS 23.207:REL-19/19.0.0", file: "data/ts-23-207-rel-19-19-0-0.yaml" },
      { id: "TS 29.198-04-1:REL-5/5.0.0", file: "data/ts-29-198-04-1-rel-5-5-0-0.yaml" },
      { id: "TS 29.215/2.0.0", file: "data/ts-29-215-2-0-0.yaml" },
    ]
  end

  it "indexes every record by its docnumber" do
    in_data_dir do
      index = described_class.build_index_v1
      expect(index.index).to eq expected_rows
    end
  end

  # Crawl order shuffles between runs, which would make every v1 diff noise.
  # The fixture filenames sort the opposite way round from their ids, so this
  # fails if the rows come out in glob order.
  it "orders the rows by id, so a later crawl gives a meaningful diff" do
    in_data_dir "unsorted" do
      index = described_class.build_index_v1
      expect(index.index).to eq [
        { id: "TR 00.01U:UMTS/3.0.0", file: "data/z-sorts-first-by-id.yaml" },
        { id: "TS 29.215/2.0.0", file: "data/a-sorts-second-by-id.yaml" },
      ]
    end
  end

  # The real legacy gate. A consumer without `pubid_class:` rejects the whole
  # index when any `:id` is not a plain String.
  it "writes a file that a consumer with no pubid_class accepts" do
    in_data_dir do
      described_class.build_index_v1
      Relaton::Index.close described_class::POOL_KEY

      rows = Relaton::Index.find_or_create(described_class::POOL_KEY,
                                           file: "index-v1.yaml").index
      expect(rows).to eq expected_rows
      expect(rows.map { |row| row[:id] }).to all be_a String
    end
  end

  it "serialises the rows in the v1 shape" do
    in_data_dir do
      described_class.build_index_v1
      expect(File.read("index-v1.yaml")).to start_with <<~YAML
        ---
        - :id: TR 00.01U:UMTS/3.0.0
          :file: data/tr-00-01u-umts-3-0-0.yaml
      YAML
    end
  end

  it "skips a record with no docnumber, and keeps the rest" do
    in_data_dir "no-docnumber" do
      index = nil
      expect do
        index = described_class.build_index_v1
      end.to output(/broken\.yaml/).to_stderr

      expect(index.index.map { |row| row[:id] }).to eq ["TS 23.207:REL-19/19.0.0"]
    end
  end

  # Relaton::Index pools Types by name. Asking for "3gpp" again with a
  # different `file:` would evict the fetcher's index-v2 from the pool.
  it "uses its own pool key, leaving the fetcher's index-v2 alone" do
    in_data_dir do
      v2 = Relaton::Index.find_or_create "3gpp", file: "index-v2.yaml",
                                                 pubid_class: ::Pubid::Tgpp::Identifier
      v2.add_or_update ::Pubid::Tgpp::Identifier.parse("3GPP TS 23.207:REL-19/19.0.0"),
                       "data/ts-23-207-rel-19-19-0-0.yaml"

      described_class.build_index_v1

      still_pooled = Relaton::Index.find_or_create "3gpp", file: "index-v2.yaml",
                                                           pubid_class: ::Pubid::Tgpp::Identifier
      expect(still_pooled).to be v2
      expect(still_pooled.index.size).to eq 1
    end
  end

  it "skips a record that does not parse, and keeps the rest" do
    in_data_dir "unreadable" do
      index = nil
      expect { index = described_class.build_index_v1 }
        .to output(/malformed\.yaml/).to_stderr
      expect(index.index.map { |row| row[:id] }).to eq ["TS 23.207:REL-19/19.0.0"]
    end
  end

  # The rescue must cover the read as well as the parse. crawler.rb runs the
  # builder inside the crawl's single CI step, so an exception escaping here
  # discards the data/ update the fetcher just made.
  it "skips a record it cannot read, and keeps the rest" do
    in_data_dir "unreadable" do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with("data/malformed.yaml")
                                   .and_raise(Errno::EACCES, "data/malformed.yaml")

      index = nil
      expect { index = described_class.build_index_v1 }
        .to output(/malformed\.yaml/).to_stderr
      expect(index.index.map { |row| row[:id] }).to eq ["TS 23.207:REL-19/19.0.0"]
    end
  end

  # crawler.rb runs this after every fetch. A crawl that failed partway would
  # otherwise replace the published index with `--- []`, which is worse than
  # publishing nothing: the file stays valid, so no consumer notices.
  it "refuses to write an empty index over the published one" do
    in_data_dir "empty" do
      File.write "index-v1.yaml", "--- []\n"
      expect { described_class.build_index_v1 }
        .to raise_error described_class::EmptyIndexError, /data\/\*\.yaml/
      expect(File.read("index-v1.yaml")).to eq "--- []\n"
    end
  end

  # A crawl reuses the pooled Type, so a second build must replace the rows
  # rather than merge them into the previous run's.
  it "rebuilds from scratch when the pooled index survives a previous run" do
    in_data_dir do
      described_class.build_index_v1
      index = described_class.build_index_v1 glob: "data/ts-29-215-2-0-0.yaml"
      expect(index.index.map { |row| row[:id] }).to eq ["TS 29.215/2.0.0"]
    end
  end
end
