# Proposed

What is still undecided, under ROADMAP.md's headings. The direction is in ROADMAP.md, and the discrete jobs in TODO.


## Datasets

- Whether a dataset's module is made from its name when first looked up, rather than from a list written in the library, so that a dataset is reached without the library knowing of it beforehand: `const_missing` turning the constant back into the name, requiring the dataset's own file where there is one, and otherwise making one with `Module.new`, holding the name alone, and naming it with `const_set` so that it is made once. Nothing is asked of the catalogue until something is fetched, so a lookup never waits upon the network. Against it: a mistyped constant makes a module rather than raising NameError, and fails only when fetched; a mistyped constant within the library itself, as `Catalog`, becomes a dataset; and `DataGovAu.constants` names only the datasets used so far.
- Whether a module's name is made from the dataset's name by a mapping which cannot give two names the same constant. Dropping the separators and capitalising does: 17 pairs among data.gov.au's 142,676 names come out alike, as `drinking-fountains` and `drinking_fountains`, and `motor-vehicle-duty-rates-2016-17` and `motor-vehicle-duty-rates-201617`. Instead, a hyphen before a letter becomes that letter capitalised, any other hyphen `_H`, an underscore `_U`, and a name beginning with other than a letter is prefixed `D_N`, so that an underscore in a constant only ever begins an escape. Over every name and over cases made to break it, each comes out a valid constant, none alike, and each turns back into its name. A constant then rests on its name alone, so no dataset added later renames one already made. `AbnBulkExtract` and `AsicCompanies` are unchanged; a hyphen before a digit is not, `table-1-abns-by-entity-type` becoming `Table_H1AbnsByEntityType`.
- Whether datasets are sorted into kinds, so that one of a known kind needs no file of its own. Kinds along several axes rather than in one tree: how a release is packaged (one zip, several, a plain file), what its records are written as (XML, CSV, tab-separated, XLSX), how it is dated (by the catalogue, by a resource's last_modified, by the file itself), and whether it replaces the last release or is added beside it. Each read from the catalogue where it says, which is not everywhere: it gives no frequency, a format can be wrong (the extract's readme, a PDF, is served as text/csv), and that ASIC's CSV is its zip unzipped is learnt only by looking. What the catalogue cannot say a dataset's own file would state, as its kind rather than as code. A dataset made from its name would hold its kind's classes as its own, its `Fetch` made as `Class.new(kind::Fetch)` and its `Release` likewise, so that `DataGovAu::AcncRegister::Fetch` is called as `DataGovAu::AsicCompanies::Fetch` is, and a caller cannot tell a made dataset from a written one. Generic classes taking the name, as `DataGovAu::Fetch.new(dataset: 'acnc-register', config:)`, would want no `Class.new`, but would be called otherwise than a written dataset's.
- Whether a dataset whose resources are held elsewhere is given a module which points rather than fetches: its title, organisation, licence and attribution, and for each resource its format, URL and host, with no `Fetch` and no `Release`, nothing being held. Of 6,000 datasets sampled across the catalogue, 91.6 per cent hold every resource elsewhere, 4.8 per cent every one on data.gov.au, 0.2 per cent some of each, and 3.4 per cent none. A resource's `url_type` is `upload` where data.gov.au holds the file, so this kind is read from the catalogue alone, and belongs to each resource rather than to the dataset: in a dataset holding some of each, those uploaded are fetched and the rest pointed to. With modules made from the name, nine datasets in ten would then want no file of their own.
- Whether a resource held elsewhere is fetched through a library for its host which the caller gives, as `elsewhere: {host => fetcher}`, rather than one this library requires where it happens to be installed, which would want this library to know which serves which host, and would make what it does turn on what is installed. A resource whose host has none given is pointed to and not fetched.


## The catalogue

- Whether `DataGovAu::Catalogue` becomes a library of its own once something other than data.gov.au wants it, it speaking the action API which every CKAN portal shares. Four of the hosts most pointed to from data.gov.au are CKAN portals themselves, Queensland's, New South Wales's, Transport for NSW's and South Australia's, so such a library would reach what those datasets point to by its `api_url` alone, and be the first of the libraries given for hosts elsewhere.


## The ABN Bulk Extract

- Whether `SearchByRegistrationEvent` on the ABN Lookup web services should cross-check the new-versus-reactivated split, it being the only independent source for the distinction. Monthly granularity, needs a free GUID, and the methods page gives one shared parameter table rather than listing them per method, so the parameters want confirming against the WSDL first.
- Whether a name change on an existing ABN should be surfaced alongside new and reactivated. Under the interval model it costs nothing to ask; a sole trader registering a first business name has committed to something.


## The ASIC Company Dataset

- Whether a company's rows, one for each name it has held and yielded one at a time, are also gathered by ACN into one company with its former names, the register being sorted by ACN.
- Whether its releases are kept as differences, as the extract's are.


## Releases kept as differences

- Merging the first release forward into a later one, which is what letting old releases go would want. Until then a long chain costs nothing more to rebuild than a short one: one pass.
- Whether the schema and readme, unchanged for months at a time, are kept with every release or once.
