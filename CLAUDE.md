# CLAUDE.md

## What this repository is

A **generated dataset**, not an application. It holds Relaton bibliographic
records for 3GPP specifications:

- `data/*.yaml` — 88,464 documents, one file per `docnumber`, flat directory.
- `index-v1.yaml` / `index-v1.zip` — generated index mapping each `docnumber` to
  its file (e.g. `TR 21.905:REL-99/3.0.0` → `data/tr-21-905-rel-99-3-0-0.yaml`).
- `current.yaml` — last-seen `Last-Modified` of the upstream CSV, used to skip
  no-op crawls.
- `crawler.rb` — a four-statement entry point that calls the generator.

**Do not hand-edit `data/`, `index-v1.*`, or `current.yaml`.** They are
regenerated wholesale by the crawler and any manual change will be overwritten.

## Where the data comes from

Upstream source is
[`3GPPBibliography.csv`](https://www.3gpp.org/ftp/Information/Databases/3GPPBibliography.csv).
All parsing and serialisation lives in the
[`relaton-3gpp`](https://github.com/relaton/relaton-3gpp) gem —
`crawler.rb` just invokes `Relaton::ThreeGpp::DataFetcher.fetch`. The `Gemfile`
pins it to the `lutaml-integration` branch.

Consequently **content bugs in `data/` are almost always generator bugs** and
must be fixed in `relaton-3gpp`, not here. See
[`docs/known-issues.md`](docs/known-issues.md) for the ones currently open.

## Refreshing the data

`.github/workflows/crawler.yml` runs on a schedule (Mon/Wed/Fri 14:00 UTC), on
push to `master`/`main` and `v*` tags, on pull requests, and on
`workflow_dispatch`. Note the push list predates the migration and omits `v2`,
which is now the default branch. The dispatch form takes a `force` input: when set, the
fetcher wipes `data/` and rebuilds the index from scratch rather than doing an
incremental update. **A `force` run is what picks up a generator fix** — an
ordinary run short-circuits when the upstream CSV is unchanged.

Locally the same thing is `bundle exec ruby crawler.rb` (or `... crawler.rb force`),
but note it downloads a >20 MB CSV and rewrites the whole tree.

`.github/workflows/deploy.yml` builds the GitHub Pages index site via the shared
`relaton/support` workflow.

## Testing

There is no test suite here — no `spec/`, no `Rakefile`. Verification means
running read-only audit queries over `data/`; see the "Auditing" section of
[`docs/known-issues.md`](docs/known-issues.md). Tests for the parsing and merge
logic live in `relaton-3gpp`'s `spec/`.

## Branches

The default branch is `v2`. `deploy.yml` deliberately lists `master`, `main` and
`v2` because the `relaton-data-*` repos are mid-migration.
