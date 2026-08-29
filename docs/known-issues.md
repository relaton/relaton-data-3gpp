# Known issues in the generated dataset

This repository contains only *generated* data. Every issue below originates in
the generator, [`relaton/relaton-3gpp`](https://github.com/relaton/relaton-3gpp),
and cannot be fixed by editing `data/` — a hand-edit would be overwritten by the
next crawler run. Each issue self-heals once a fixed gem is released and the
crawler is re-run with the `force` input (see [CLAUDE.md](../CLAUDE.md)).

Findings recorded 2026-08-14 against the dataset at commit `389b9eeeb64`.

---

## 1. `adoptedAs` relations point at the document's own identifier

### Symptom

28 documents carry a `relation:` entry whose embedded `bibitem` has a
`docidentifier` and `docnumber` **identical to the parent document's**. The
relation therefore says "this document was adopted as itself", which carries no
information a consumer can act on.

From `data/tr-21-905-rel-99-3-0-0.yaml` (abridged):

```yaml
id: TR21905REL99300
docidentifier:
- content: 3GPP TR 21.905:REL-99/3.0.0
  type: 3GPP
  primary: true
docnumber: TR 21.905:REL-99/3.0.0
date:
- type: published
  at: '1999-12-17'
relation:
- type: adoptedAs
  description:
    content: equivalent
  bibitem:
    title:
    - content: Vocabulary for 3GPP Specifications      # identical
    source:
    - type: src
      content: https://www.3gpp.org/ftp/.../21905-300.zip   # identical
    docidentifier:
    - content: 3GPP TR 21.905:REL-99/3.0.0             # identical to parent
      type: 3GPP
      primary: true
    docnumber: TR 21.905:REL-99/3.0.0                  # identical to parent
    date:
    - type: published
      at: '2000-03-15'                                 # the only difference
```

Of the fields the embedded bibitem can carry, **only `date` differs** from the
parent: title, source, docidentifier, docnumber, version, contributor, place,
language and script all match byte-for-byte. The parent always holds the earlier
date.

The embedded bibitem also drops `id`, `schema_version` and the whole `ext:` block
(doctype, flavor, radiotechnology, release). That is structural, not data loss in
the relation itself: `Relation#bibitem` is typed as `Relaton::Bib::ItemBase`
(`relaton-bib/lib/relaton/bib/model/relation.rb:18`), which declares neither
`id`, `schema_version` nor `ext` — `id` lives on `Relaton::Bib::Item`
(`relaton-bib/lib/relaton/bib/model/item.rb:26`). So the identifier that collides
is the `docidentifier`/`docnumber`, not an XML `id` attribute.

### Root cause

The identifier does not include the publication date, but the upstream data has
multiple rows per document that differ only by date:

1. `Parser#number` (`relaton-3gpp/lib/relaton/3gpp/parser.rb:105`) builds the
   identifier as `<TS|TR> <spec>:<release>/<version>`. The date is not part of
   it. `docidentifier.content` is simply `"3GPP " + docnumber`.
2. The upstream
   [`3GPPBibliography.csv`](https://www.3gpp.org/ftp/Information/Databases/3GPPBibliography.csv)
   contains 1624 duplicate row-groups — grouped by spec number and version, with
   2 to 5 rows each, differing only in publication date (or in a missing link or
   contributor). Catalogued in
   [relaton-3gpp#18](https://github.com/relaton/relaton-3gpp/issues/18).
3. `DataFetcher#save_doc` (`data_fetcher.rb:107`) derives the output filename
   from that same `docnumber`, so duplicate rows collide on one file and the
   second row is routed into `merge_duplication` → `transposed_relation` →
   `check_transposed_date`.
4. When the two rows' dates differ, `add_transposed_relation`
   (`data_fetcher.rb:202`) embeds the later-dated row wholesale as an
   `adoptedAs` / `equivalent` relation of the earlier one:

   ```ruby
   def add_transposed_relation(bib1, bib2)
     bib2.relation.each { |r| bib1.relation << r }
     bib2.relation.clear
     desc = Bib::LocalizedMarkedUpString.new content: "equivalent"
     rel = Bib::Relation.new(type: "adoptedAs", bibitem: bib2, description: desc)
     bib1.relation << rel
   end
   ```

Because both rows describe the same document, the relation is self-referential
by construction.

The `adoptedAs:equivalent` modelling came from guidance in issue #18: the first
published item is the real one, and subsequent "transposed" items were published
at other venues with unmodified content, so they are adoptions. That holds only
if the adopting venue has its *own* identifier. The CSV carries no venue and no
second identifier, so the relation degenerates into a self-reference whose only
real payload is the extra date.

### Scale

- **28 files** contain a `relation:` block; **29 relations** in total.
- **29 of 29 (100%)** have a relation identifier equal to the parent's. There
  are no legitimate relations anywhere in the dataset.
- `adoptedAs` is the only relation type present in the corpus, and relations are
  never nested more than one level deep.
- Only 28 of 88,464 documents are affected, against 1624 duplicate groups
  upstream. Merges leave no trace in the output, so the dataset alone cannot say
  which groups took which path — but by inspection of the code the remainder are
  groups where `check_transposed_date` found *equal* dates (it returns
  `[bib, existed, false]`, adding no relation) or where the rows differed only in
  a missing link or an extra contributor, handled by `update_source?` /
  `add_contributor` without a relation.

Affected files, with the parent date and the relation date(s):

| File (under `data/`) | Parent | Relation(s) |
| --- | --- | --- |
| `tr-03-39-rel-96-5-0-0.yaml` | 1996-10-11 | 2000-09-28 |
| `tr-21-905-rel-99-3-0-0.yaml` | 1999-12-17 | 2000-03-15 |
| `tr-22-80u-umts-2-0-1.yaml` | 1997-12-19 | 1998-03-20 |
| `tr-23-913-rel-4-1-0-0.yaml` | 1999-12-03 | 1999-12-17 |
| `tr-23-972-rel-99-0-0-3.yaml` | 1999-10-29 | 1999-12-09 |
| `tr-25-854-rel-5-1-0-0.yaml` | 2001-04-05 | 2001-10-01 |
| `tr-33-833-rel-12-0-6-0.yaml` | 2014-06-04 | 2014-06-27 |
| `tr-43-903-rel-8-0-0-4.yaml` | 2008-02-20 | 2008-02-28 |
| `tr-50-099-rel-4-0-0-2.yaml` | 2000-04-02 | 2000-11-06 |
| `ts-03-20ext-ph1-3-0-0.yaml` | 1995-01-01 | 2003-09-01 |
| `ts-08-08-rel-98-7-5-0.yaml` | 2000-02-16 | 2000-04-17 |
| `ts-10-71-rel-98-2-0-6.yaml` | 1999-11-03 | 1999-11-11 |
| `ts-10-71-rel-98-2-0-7.yaml` | 1999-11-29 | 1999-12-06 |
| `ts-10-78-rel-98-1-6-0.yaml` | 1998-03-10 | 1998-06-04 |
| `ts-11-10-3-rel-96-5-0-0.yaml` | 1996-04-12 | 1999-11-11 |
| `ts-11-10-4-rel-96-5-3-0.yaml` | 2001-03-29 | 2001-04-11 |
| `ts-11-11dcs-ph1-3-3-4.yaml` | 1994-02-21 | 1994-11-07 |
| `ts-22-115-rel-99-3-1-0.yaml` | 1999-04-23 | 1999-06-23 |
| `ts-23-108-rel-99-3-0-0.yaml` | 1999-06-23 | 1999-10-13 |
| `ts-23-920-rel-99-1-0-0.yaml` | 1999-04-01 | 1999-04-23 |
| `ts-25-411-rel-99-0-0-0.yaml` | 1999-01-15 | 1999-04-23 |
| `ts-25-424-rel-99-3-1-0.yaml` | 1999-10-13 | 1999-12-12 |
| `ts-25-425-rel-11-11-4-0.yaml` | 2015-03-21 | 2015-06-30 |
| `ts-25-431-rel-99-0-0-0.yaml` | 1999-01-15 | 1999-04-23 |
| `ts-26-073-rel-99-0-1-0.yaml` | 1999-04-23 | 1999-06-23 |
| `ts-26-075-rel-99-1-0-0.yaml` | 1999-06-23 | 1999-12-17, 1999-10-13 |
| `ts-26-094-rel-99-0-1-0.yaml` | 1999-04-26 | 1999-06-23 |
| `ts-34-121-1-rel-12-12-0-0.yaml` | 2015-12-14 | 2016-03-17 |

`ts-26-075-rel-99-1-0-0.yaml` is the only three-row group. Note its relations are
not in chronological order (1999-12-17 precedes 1999-10-13), because each new row
is appended as it is read rather than sorted by date.

### Status

Reported upstream via the hand-off
`relaton__relaton-3gpp__self-referential-adopted-as-relations.md`. The fix
belongs in `relaton-3gpp`; no change is possible in this repository.

---

## 2. `create_id` collapses distinct documents onto the same `id`

### Symptom

12 `id:` values are each shared by two different documents. For example:

| `id` | Documents |
| --- | --- |
| `TS25101REL99100` | `TS 25.101:REL-9/9.10.0` and `TS 25.101:REL-99/1.0.0` |
| `TS25331REL99110` | `TS 25.331:REL-9/9.11.0` and `TS 25.331:REL-99/1.1.0` |
| `TS37460REL111110` | `TS 37.460:REL-11/1.11.0` and `TS 37.460:REL-11/11.1.0` |

Full set of colliding ids: `TS25101REL99100`, `TS25141REL99100`,
`TS25321REL99100`, `TS25331REL99100`, `TS25331REL99110`, `TS25413REL99100`,
`TS25423REL99100`, `TS25433REL99100`, `TS31102REL99100`, `TS31111REL99100`,
`TS37460REL111110`, `TS37462REL111110`.

### Root cause

`ItemData#create_id` (`relaton-3gpp/lib/relaton/3gpp/item_data.rb:11`) derives the
`id` by deleting every non-word character:

```ruby
self.id = pubid.to_s.sub(/\A3GPP\s+/, "").gsub(/\W+/, "")
```

That is lossy — the separators are the only thing distinguishing `REL-9/9.10.0`
from `REL-99/1.0.0`, so both collapse to `REL99100`.

### Impact

Filenames and `index-v1.yaml` keys are unaffected: `Core::DataFetcher#output_file`
replaces separators with `-` rather than deleting them, so the two files stay
distinct, and the index is keyed on the raw `docnumber`. The collision is confined
to the `id:` field — but it is a duplicate-anchor hazard for any consumer that
assembles multiple documents into a single XML tree.

### Status

Reported in the same hand-off as issue 1. Not fixable in this repository.

---

## Auditing

All commands are read-only and run from the repository root.

```bash
# Issue 1: expect 28 files with a relation block, and no nested ones
grep -rl "^relation:" data | wc -l
grep -rl "^ \+relation:" data | wc -l

# Issue 1: expect 29 relations, all of them adoptedAs.
# (Relation entries sit at column 0 under `relation:`, as do date and source
# types, so filter to the relation types rather than counting `^- type: `.)
grep -rh "^- type: " data | sort | uniq -c | grep -v "published\|src"

# Issue 1: every relation docnumber should equal its parent's.
# Compares all 29 relations, including the two in ts-26-075-rel-99-1-0-0.yaml.
for f in $(grep -rl "^relation:" data); do
  parent=$(grep -m1 "^docnumber:" "$f")
  grep "^    docnumber:" "$f" | while read -r rel; do
    echo "$f | ${parent#docnumber: } | ${rel#*docnumber: }"
  done
done

# Issue 2: expect 12 duplicated id values
grep -rh "^id:" data | sort | uniq -d
```
