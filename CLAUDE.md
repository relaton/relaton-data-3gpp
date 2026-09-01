# CLAUDE.md

## What this repository is

A **generated dataset**, not an application. It holds Relaton bibliographic
records for 3GPP specifications:

- `data/*.yaml` — 88,464 documents, one file per `docnumber`, flat directory.
- `index-v2.yaml` / `index-v2.zip` — the current index, written by the gem. Each
  row keys on a serialised `Pubid::Tgpp::Identifier` hash, which lets a consumer
  narrow a lookup to one `root.number` bucket instead of scanning all 88,464
  rows.
- `index-v1.yaml` / `index-v1.zip` — the legacy index, written by **this repo**.
  Each row keys on a bare string (`TR 21.905:REL-99/3.0.0` →
  `data/tr-21-905-rel-99-3-0-0.yaml`).
- `current.yaml` — last-seen `Last-Modified` of the upstream CSV, used to skip
  no-op crawls.
- `crawler.rb` — the entry point: it calls the generator, then rebuilds
  `index-v1`.
- `index_builder.rb` — the `index-v1` builder. See "The two indexes".

**Do not hand-edit `data/`, `index-v*.*`, or `current.yaml`.** They are
regenerated wholesale by the crawler and any manual change will be overwritten.

## Where the data comes from

Upstream source is
[`3GPPBibliography.csv`](https://www.3gpp.org/ftp/Information/Databases/3GPPBibliography.csv).
All parsing and serialisation lives in the
[`relaton`](https://github.com/relaton/relaton) monorepo, which absorbed the
standalone `relaton-3gpp` gem — `crawler.rb` just invokes
`Relaton::ThreeGpp::DataFetcher.fetch`. The `Gemfile` pins `relaton` to `main`,
and pins `pubid` to `main` as well: `relaton.gemspec` asks for a released
`pubid`, but the 3GPP index needs `main` (a bare reference must parse, and
`parts` must default to `[]` on deserialization). Bundler reads a git
dependency's gemspec, never its Gemfile, so relaton's own pin does not reach
this bundle.

Consequently **content bugs in `data/` are almost always generator bugs** and
must be fixed in `relaton`, not here. See
[`docs/known-issues.md`](docs/known-issues.md) for the ones currently open.

## The two indexes

The gem writes **`index-v2` only**. Every released `relaton` before the pubid
migration, and the legacy `relaton-3gpp` gem, read `index-v1.zip` from this
branch and require a bare String `:id`; they pass no `pubid_class:`, so a
v2-shaped file fails `Relaton::Index::FileIO#check_format` and they reject the
whole index. **`index-v1` must keep being published for as long as those
consumers exist.** Since the gem no longer writes it, this repo owns it — the
same arrangement as `relaton-data-iana` and `relaton-data-bipm`.

`index_builder.rb` rebuilds it from `data/`, not by converting `index-v2`. Every
record stores the v1 id verbatim in its `docnumber`, so the builder reads that
field and nothing else. Four properties worth keeping:

- **`index-v1` has no pubid dependency.** A record whose id pubid rejects is
  absent from `index-v2` but still present in `index-v1`, which is what a legacy
  consumer needs.
- **A distinct pool key.** `Relaton::Index` pools its `Type` objects by name, so
  the builder uses `:"3GPP_V1"`. Asking for `"3gpp"` again with a different
  `file:` would evict the fetcher's `index-v2` from the pool.
- **Rows are sorted by `:id`.** Crawl order shuffles between runs and would make
  every v1 diff noise. Sorted order makes a diff mean something. The rows
  themselves are unchanged: the set was verified identical to the last
  crawl-ordered publish, 88,464 of 88,464.
- **An empty result raises.** `crawler.rb` runs the builder after every fetch,
  so a crawl that failed partway would otherwise replace the published file with
  `--- []` — worse than publishing nothing, because the result is still a valid
  index and no consumer notices. A record the builder cannot read is reported
  and skipped instead: one bad file must not cost the whole legacy index.

Neither file is zipped or committed here. `relaton/support`'s shared
`crawler.yml` zips every `index*.yaml` that changed and commits the YAML and the
ZIP together.

## Refreshing the data

`.github/workflows/crawler.yml` runs on a schedule (Mon/Wed/Fri 14:00 UTC) and
on `workflow_dispatch`, which offers a `force` checkbox. Ticking it makes the
fetcher wipe `data/` and rebuild the index from scratch rather than doing an
incremental update. **A `force` run is what picks up a generator fix** — an
ordinary run short-circuits when the upstream CSV is unchanged, and then writes
no index at all.

Locally the same thing is `bundle exec ruby crawler.rb` (or
`... crawler.rb force`), but note it downloads a >20 MB CSV and rewrites the
whole tree. To rebuild only `index-v1`, without the network and without touching
`data/`:

```sh
bundle exec ruby -e 'require "./index_builder"; ThreeGppIndexBuilder.build_index_v1'
```

That reads all 88,464 records and takes about 50 seconds.

`.github/workflows/deploy.yml` builds the GitHub Pages index site via the shared
`relaton/support` workflow.

## Testing

`spec/index_builder_spec.rb` covers `index_builder.rb` — the only code this repo
owns. Run it by hand with `bundle exec rake` (or `bundle exec rspec`). The
examples build their own small corpora in `Dir.mktmpdir` and never read
`data/`, so they are fast and need no network.

**There is deliberately no CI workflow for it.** This repo's GitHub Actions
build and publish the dataset; they are not a test harness. Run the suite
locally when you touch `index_builder.rb`.

Everything else is verified by read-only audit queries over `data/` and the
indexes; see the "Auditing" section of
[`docs/known-issues.md`](docs/known-issues.md). Tests for the parsing and merge
logic live in the `relaton` monorepo's `spec/3gpp/`.

## Branches

The default branch is `v2`. `deploy.yml` deliberately lists `master`, `main` and
`v2` because the `relaton-data-*` repos are mid-migration.
