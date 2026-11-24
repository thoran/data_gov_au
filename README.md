# data_gov_au

A client for data.gov.au's CKAN API, and the datasets built on it: first the Australian Business Register's weekly ABN bulk extract.


## Installation

Needs Ruby 3.2 or later.

```shell
$ gem install data_gov_au
```

Or from a checkout:

```shell
$ rake install
```


## Usage

```ruby
require 'data_gov_au'

dataset = DataGovAu::Catalogue.new.dataset('abn-bulk-extract')

dataset.title          # => "ABN Bulk Extract"
dataset.organisation   # => "Australian Business Register"
dataset.licence        # => "Creative Commons Attribution 3.0 Australia"
dataset.modified_at    # => 2026-10-27 21:41:00.366366 UTC

resource = dataset.resources.find{|resource| resource.format == 'ZIP'}
resource.filename      # => "public_split_1_10.zip"
resource.size          # => 500487995
resource.download(File.join('releases', resource.filename))
```

A dataset is asked for by its name or its id, CKAN taking either. It is asked for afresh each time rather than held, a resource's URL being the catalogue's to change.

A dataset gives its `name`, `title`, `organisation`, `licence`, `modified_at` and `resources`, and a resource its `name`, `format`, `size`, `url`, `last_modified` and `filename`. Each one's `to_h` is the entry exactly as the catalogue gave it.

### Downloads

`download` writes to a `.partial` file beside the path given and renames it into place once whole, so that a download cut short leaves nothing which would pass for the file. A body other than the length the catalogue reports stops with `DataGovAu::DownloadFailed`, and leaves nothing behind.

`held_at?(path)` says whether the file at a path is the one the catalogue describes: present, and at the length it reports. Where the catalogue gives no length, presence alone stands for it.

`first_bytes(length)` asks for the start of a file by range, which is enough to read a zip's first local file header, say, for a few hundred bytes rather than the whole file. A server which ignores the range and answers with the whole body stops it, holding that body being what asking by range is meant to avoid.

### Times

CKAN gives its times without a zone. They are UTC, and `modified_at` and `last_modified` are read as such.

### Settings

```ruby
DataGovAu::Catalogue.new(user_agent: 'mine/1.0', api_url: 'https://data.gov.au/data/api/3/action')
```

Both have defaults: the user agent names this library and its version, and the API is data.gov.au's. Any CKAN portal's action API answers the same calls. Either can also be set once the catalogue is made, or in a block:

```ruby
DataGovAu::Catalogue.new{|c| c.user_agent = 'mine/1.0'}
```

### Errors

Everything raised is a `DataGovAu::Error`: `CatalogueUnavailable` where the catalogue could not be read or reported no result, as for a name it does not know, and `DownloadFailed` where a resource could not be retrieved or arrived at the wrong length.


## The ABN Bulk Extract

`DataGovAu::AbnBulkExtract`, built on the catalogue, holds the Australian Business Register's weekly bulk extract: a snapshot of the public ABN register, two zip files of around 477 MB each, holding twenty XML files and some 12 GB uncompressed. It fetches each release, reads its records, and keeps each release after the first as its changes from the one before. It is named for the dataset's name in the catalogue, `abn-bulk-extract`, which `DataGovAu::AbnBulkExtract::DATASET` holds.

```ruby
require 'DataGovAu/AbnBulkExtract'
```

`require 'DataGovAu/ABR'` and `DataGovAu::ABR`, its name before 0.4.0, still load, deprecated, until 0.5.0.

Its parts, in the order a release passes through them:

- `Config`: the settings the rest share.
- `Fetch`: the current release found through the catalogue, and whatever of it is not held retrieved.
- `ExtractDate`: the date the extract carries, read from the first bytes of a zip.
- `Release`: a release on disk, its directory named for that date.
- `Extract` and `Parser`: a release's records, read out of its zips.
- `Comparison`: a release set against the one before it, through `Lines`, `Delta`, `Frame`, `CompressedFile` and `Rebuild`.

### Why a local copy

The extract is a snapshot of current state. Nothing in it says an ABN is new; that word only exists once you have two snapshots and can see the difference. data.gov.au publishes the current release alone and overwrites it in place each Tuesday, so a release not kept is not recoverable. The earliest baseline you can ever have is the first one you capture, which is why nothing is discarded.

### Settings

`DataGovAu::AbnBulkExtract::Config` holds what the rest share: `directory:`, `api_url:` and `user_agent:`, taken as keywords or through its setters, and it yields itself to a block. The API's URL and the user agent default as the catalogue's do. The directory, the extract's own, has no default, and is named as missing where it is first wanted, a release kept anywhere but where it was meant to be being a week lost to those held.

```ruby
config = DataGovAu::AbnBulkExtract::Config.new(directory: '/srv/data_gov_au/abn-bulk-extract')
config = DataGovAu::AbnBulkExtract::Config.new{|c| c.directory = '/srv/data_gov_au/abn-bulk-extract'}
```

The library reads no file: where the settings are kept is for the program using it.

### Fetching

```ruby
fetch = DataGovAu::AbnBulkExtract::Fetch.new(config)

fetch.release.to_s                     # => "20261028"
fetch.modified_on.strftime('%Y%m%d')   # => "20261027"
fetch.release.missing                  # => the resources not yet held

release = fetch.perform{|resource| puts resource.filename}
```

Fetches the current release, retrieving whatever of it is not already held. A second fetch in the same week makes one call to the catalogue and one range request, and retrieves nothing, so it can be run each week from a scheduler, a week not fetched being gone for good.

Two dates are given because they differ. A release is named for the date the extract carries itself, `released_on`, read from the names of the files inside its zips; the catalogue's own date, `modified_on`, is when data.gov.au last touched its record, which moves whether or not the data did. Reading the first is cheap: the name of the first file inside a zip sits in the first few hundred bytes, so it is asked for by range before anything large is retrieved.

### Parsing

```ruby
DataGovAu::AbnBulkExtract::Extract.new(release).each_record do |record|
  record[:abn]          # => "11000047950"
end
```

A release already held is had by its date, without going to the catalogue, and each file can be set against the count it carries:

```ruby
date = DataGovAu::AbnBulkExtract::Release.dates_held(config).first
release = DataGovAu::AbnBulkExtract::Release.new(config, date)

DataGovAu::AbnBulkExtract::Extract.new(release).each_file do |name, parser|
  parser.each_record{|record| record[:names]}
  parser.whole?         # => true, where the file reports no error and gave up as many records as it promised
end
```

Reading touches nothing on the network. `whole?` sets a file against the count it carries itself, so that a file which gave up fewer records than it promised is not taken for a smaller week. Nor is a file which reports an error, in the `error` attribute the schema requires of each, which is `none` in a file written out whole.

### On disk

```
/srv/data_gov_au/abn-bulk-extract/
  releases/
    20261028/
      public_split_1_10.zip
      public_split_11_20.zip
      bulkextract.xsd
      abnlookupbulkextractreadme.pdf
      abn-bulk-extract-resources.csv
      catalogue.json
    20261104/
      ...
      delta.zst
      frame.json.zst
```

The directory is the caller's to name, and what lies beneath it the library's. Each release directory is self-describing: the data, the schema and readme needed to read it, and the catalogue entry it was found through — where it came from, when, and under what licence. A parser corrected later can be run again over the releases it first got wrong, which is only possible while the releases are still held.

### Releases kept as differences

Each release after the first is kept beside its zips as its changes from the release before it, so that the zips can later go and the release still be had back exactly.

- `delta.zst`: a line for each ABN which changed, in ABN order. `A` and the record for an ABN added, `C` and the record for one changed, `R` and the ABN for one removed. The records stand as the extract writes them, so the week's new ABNs, cancellations and reactivations can be read from the delta alone. 20261104's is 2.0 MB.
- `frame.json.zst`: everything outside the records, file by file. Each file's name, the bytes before its first record and after its last, how many records it holds, what parts two records wherever that is other than a line break (the extract puts a second carriage return after every hundredth), and the SHA-256 of the whole file. 1.4 kB.

Both are zstd at level 19, and `zstd -d` reads them.

A delta is trusted only once it has given its release back. Both files are written under partial names; the release is rebuilt from the one before it and them, file by file; and only where every file comes out at the hash taken as it was first read are the two given their own names. A comparison which stops leaves neither behind.

`Comparison.pending` is every release held whole which has no delta yet, each set against the newest release before it held whole, oldest first, so that weeks gone uncompared are caught up in order, and a week missed or held only in part is compared across. Over 20261028 and 20261104 it found 15,146 ABNs added, 47,985 changed and 11 removed, and wrote the delta and rebuilt the release from it in 7 minutes.

Nothing is removed. The zips stay as they were fetched; their removal is to come, on the caller's asking, and refused for a release which does not rebuild exactly through the whole chain.

A release can be kept so while the extract is laid out a record a line, as it is now, each record carrying its ABN and the ABNs rising throughout. The files were once written with records running over many lines. Were they again, the comparison would stop with `DataGovAu::AbnBulkExtract::ExtractMalformed`, and the release would stay whole.

```ruby
config = DataGovAu::AbnBulkExtract::Config.new(directory: '/srv/data_gov_au/abn-bulk-extract')
DataGovAu::AbnBulkExtract::Comparison.pending(config).each(&:perform)

release = DataGovAu::AbnBulkExtract::Release.new(config, Date.new(2026, 11, 4))
DataGovAu::AbnBulkExtract::Delta.new(release.delta_path).each_change do |change|
  change.kind     # => "A", "C" or "R"
  change.abn      # => "11000047950"
  change.record   # => the record as the extract holds it, or nil where the ABN was removed
end
```

### What the extract holds

Per ABN: the ABN, its status (`ACT` or `CAN`) and the date that status took effect; the date the record was last updated; entity type as both code and text; the legal name; every registered business name and trading name; state and postcode of the main business location; ACN or ARBN; GST status and date; and deductible gift recipient entries.

It does not hold industry classification, nor any contact details — no email, no telephone, no street address.

The twenty XML files are one stream sorted ascending by ABN, within each file and across all of them. The split into two zips is therefore a cut point and nothing more: part one holds the low half of the ABN range and part two the high half, so either alone is half the register.

Two caveats worth knowing. `ABNStatusFromDate` is the date the *current* status took effect, not necessarily the date of first registration, so a reactivated ABN looks new on that field alone. And the extract carries current information only, with no history: history is what accumulates here, one release at a time.

### What a record comes out as

Nothing is filtered, derived or discarded on the way in. Every element and attribute the schema allows for is carried through, dates as the strings the extract gives them, so that what is asked of the data later is not settled at ingest.

```ruby
{
  abn: '11000047950', abn_status: 'ACT', abn_status_from_date: '20000224',
  record_last_updated_date: '20260211', replaced: 'N',
  entity_type_code: 'PUB', entity_type_text: 'Australian Public Company',
  state: 'NSW', postcode: '2132',
  asic_number: '000047950', asic_number_type: 'undetermined',
  gst_status: 'ACT', gst_status_from_date: '20000701',
  names: [{type: 'MN', text: 'SYDNEY MISSIONARY & BIBLE COLLEGE'}, {type: 'BN', text: "SMBC's The Bridge"}],
  dgr: [{from_date: '20060301', status: 'ACT', name: nil}],
}
```

An individual's name comes as its parts rather than joined, joining being a decision for whoever asks: `{type: 'LGL', title: 'MR', given_names: ['WILLIAM', 'RICHARD'], family_name: 'LITT'}`.

Three things in that shape are there because the extract makes them matter.

An element present and empty is not an element absent. A blank `State` comes back as `''` while an absent `ASICNumber` comes back as `nil`, and the two are not run together.

Every record carries a `GST` element, those not registered among them, under the status `NON`. That status is in neither the schema nor the readme: the schema declares `GST/@status` as a plain `xsd:string` where it enumerates `ABN/@status` as `CAN|ACT`, and the readme says only that a record has "zero or one GST status". `NON` is known from counting the data, where it is the commonest of the three. A record with no `GST` element at all is a fourth case, so `nil` is kept distinct from `'NON'`.

An entity's own gift-deductible endorsement and each named fund it runs arrive as `DGR` elements of the same name. The first carries a status and no name:

```xml
<DGR status="ACT" DGRStatusFromDate="20060301" />
```

The second carries a name and no status:

```xml
<DGR DGRStatusFromDate="20000701">
  <NonIndividualName type="DGR">
    <NonIndividualNameText>SYDNEY MISSIONARY &amp; BIBLE COLLEGE BUILDING &amp; MAINTENANCE FUND</NonIndividualNameText>
  </NonIndividualName>
</DGR>
```

Both of those are from one record, ABN 11000047950, which has its own endorsement and runs one named fund. They mean different things, so they are kept apart rather than collapsed into one flag and one name.

A company's own name is a name of type `MN` and sits on `MainEntity`, while business and trading names are types `BN` and `TRD` and sit on `OtherEntity`. Asking whether a record has a business name is therefore not the same question as asking whether it has a name.


### On the parsing

Ox, over the stream rubyzip inflates as it is read, so neither a 477 MB zip nor one of the 605 MB XML files inside it is ever held whole.

Three parsers were first ranked on identical work — every record counted and four fields taken from each — over a 150 MB cut of one real file:

```
nokogiri sax      5.5-8.1 s    18-26 MB/s
nokogiri reader   2.4-3.8 s    37-59 MB/s
ox sax            1.4-2.0 s    73-100 MB/s
```

A rate over a cut file is not a runtime, though. Run it end to end instead — out of the zip, building the whole record rather than four fields of it — over a whole release, the same work either way:

```
ox sax            7 m 34 s    26.7 MB/s
nokogiri sax     12 m 32 s    16.1 MB/s
```

Both gave up 20,631,294 records. Inflating the zip and building the records are in that path too, so the gap closes from three to five times down to about twice: 1.7 times here, 1.9 on a single file measured back to back. Twice is worth having weekly; five times was never on offer.

Those are both slower than the same Ox work timed through `each_file`, at 5 m 48 s. The spread between 5 m 48 s and 7 m 34 s is run to run, these being runs bound by reading a gigabyte off disk and by the garbage collector rather than by the parser. So: six to eight minutes for a release, and about half what Nokogiri would take.

The cost of Ox is memory, which it spends to go faster: over one file it finished holding 195 MB against Nokogiri's 115 MB.

What does not grow is what is held of the data. No record outlives the block it is given to, and no file or zip is read whole, so 12 GB goes past in 605 MB pieces which are themselves never assembled. The process does settle higher over a release than over a file — one file peaks at 373 MB resident and twenty at 563 MB — but that is Ruby's heap finding its size, not records accumulating.

The order the files are read in matters more than it looks. The records are one run sorted ascending by ABN, within each file and across all twenty, which is what lets one release be diffed against another in step rather than held in memory. That ordering is the names' to give, and the names are the ABR's to change: they were `yyyymmddPublicNN.xml` when this was written against the brief and are `yyyymmdd_PublicNN.xml` in the data. Sorted by their characters the order holds only while the numbers stay padded — unpadded, file 2 falls after file 19 and the run stops ascending without anything in the data saying so. So they are sorted by the numbers in them, through a vendored `natural_comparison`.


### Attribution

Incorporates or develops data sourced from the Australian Business Register, used under [CC BY 3.0 AU](https://creativecommons.org/licenses/by/3.0/au/). The ABR does not endorse this tool or its output.

Any output leaving the machine must carry that attribution; `DataGovAu::AbnBulkExtract::ATTRIBUTION` holds the line.


## Licence

MIT. See LICENSE.
