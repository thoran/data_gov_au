# Roadmap

The discrete jobs are in TODO, and what is still undecided in PROPOSED.md. This holds the direction: what is larger than one change, and the stance taken.


## Datasets

Each dataset gets a module of its own beneath `DataGovAu`, built on the catalogue and named for the dataset's name there, camel-cased, with no level for its publisher: first the Australian Business Register's `abn-bulk-extract`, as `DataGovAu::AbnBulkExtract`, and then ASIC's `asic-companies`, as `DataGovAu::AsicCompanies`. A publisher's name, mechanically cased, would be unwieldy, and shortened would be chosen by hand; a dataset moved between publishers keeps its name in the catalogue; and the publisher is still to be had from the catalogue entry and the attribution. What a dataset needs beyond finding and downloading its resources — keeping releases, parsing them, storing and comparing them — stays with that dataset until a second shows which of it is shared.


## The catalogue

Only what a dataset has asked for: package_show, and downloading a resource once. package_search, organisations and the datastore are added when something wants them, as is streaming a download rather than holding its body.

`DataGovAu::Catalogue` speaks the action API which every CKAN portal shares; only its default URL is data.gov.au's.


## The stages

The library ships no command. Each stage, fetching and comparing and those to come, is a call of its own which skips work already done, so that a run which fails part way is finished by the next. Settings, scheduling, and how long anything is kept are for the program using it, which runs weekly, since data.gov.au keeps the current release alone and a week not fetched is gone for good.


## The ABN Bulk Extract

Releases land on Tuesdays around 21:39 UTC. The catalogue's last_modified is what a schedule waits on, and needs no download to read.


## The ASIC Company Dataset

Releases land on Mondays around 13:50 UTC, Tuesday in Sydney. Its rows are sorted by ACN, as the extract's records are by ABN, so two releases can be set against each other in step. Fetching came first, so that weeks were held before anything read them; its rows are now read a line at a time through dsv.


## Releases kept as differences

data.gov.au publishes the current release alone, so every release is kept, and kept whole that is about 1 GB of zips a week. Set against each other, 20261028 and 20261104 are 99.7 per cent the same record for record, byte for byte; none of the records which differ do so in layout alone; and the ABNs rise throughout both. So a release is kept as the release before it and its changes: the week's records added and changed, and the ABNs removed, about 40 MB as text and 2.0 MB under zstd -19.

The stance:

- The first release held and the newest stay whole.
- Nothing is removed but on the caller's asking, and not then unless the release rebuilds exactly through the whole chain. How many weeks of rebuilds, checked against hashes this library did not take, come first is the caller's to decide.
- The delta holds whole records rather than patching bytes, so that it is itself the week's list of what was added, changed and removed.

Set aside, measured over the same two releases:

- git, holding each release's XML. At its defaults it makes no deltas at all, each 605 MB file being over core.bigFileThreshold, so a week costs about as much as its zips. With the threshold raised, a repack of the two releases took 70 minutes and 11.6 GB of memory, and the week came to 9.7 MB. It also stored some files as deltas of other files of the same release, each larger than the file stored whole.
- zstd --patch-from, each file patched against last week's. Exact, and 0.53 MB for one file at level 19, so about 10.6 MB a week. Each change becomes a match against a distant part of a 605 MB reference, where in the delta the week's changed records sit side by side and compress against one another.


## 1.0

1.0 is where what a caller relies upon stops changing: whatever would break a caller if changed afterwards is settled before it, and whatever only adds waits for 1.x.

Before it:

- How a dataset's module is named, and whether it is made from the dataset's name when first looked up, a change to either afterwards renaming constants which callers hold.
- Datasets held elsewhere, which are most of the catalogue, pointed to: what each resource is and where it is held, read from the catalogue and not fetched.
- One shape for the datasets held: `DATASET`, `ATTRIBUTION`, a `Config` taking `directory:`, a `Fetch` which skips what is held, a `Release`, and records yielded alike, drawn out of the datasets' own copies once a third, the ACNC's `acnc-register`, shows what is shared.
- What is written to disk fixed, the releases' directories, `catalogue.json`, and the delta and frame, so that every 1.x reads whatever an earlier one wrote, a week once held being the only copy there is. Whether the schema and readme are kept once, and whether the ASIC register's releases are kept as differences, are settled first.
- Releases kept as differences finished: a release rebuilt through the whole chain, and zips removed only where it rebuilds exactly.
- The catalogue's classes and errors as they are to stay, and whether the catalogue becomes a library of its own decided.
- Each dataset held parsed, as the extract and the ASIC register are.

After it, in 1.x: storage, querying and output, more datasets, package_search and the datastore, and fetching from hosts elsewhere through libraries the caller gives.
