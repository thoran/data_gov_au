# data_gov_au

A client for data.gov.au's CKAN API.


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


## Licence

MIT. See LICENSE.
