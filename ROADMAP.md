# Roadmap

The discrete jobs are in TODO. This holds the direction: what is larger than one change, what is still undecided, and the stance taken.


## Datasets

Each dataset gets a module of its own beneath `DataGovAu`, named for its publisher and built on the catalogue: first the Australian Business Register's ABN bulk extract, as `DataGovAu::ABR`. What a dataset needs beyond finding and downloading its resources — keeping releases, parsing them, storing and comparing them — stays with that dataset until a second shows which of it is shared.


## The catalogue

Only what a dataset has asked for: package_show, and downloading a resource once. package_search, organisations and the datastore are added when something wants them, as is streaming a download rather than holding its body.

`DataGovAu::Catalogue` speaks the action API which every CKAN portal shares; only its default URL is data.gov.au's. It may become a library of its own once something other than data.gov.au wants it.


## The command

The command is the weekly capture, since data.gov.au keeps the current release alone and a week not fetched is gone for good. As the stages land, its default run is to take each in turn, each skipping work already done, so that a run which fails part way is finished by the next; each stage can also be run alone. Querying and output go through the library rather than the command.


## The ABN Bulk Extract

- Whether `SearchByRegistrationEvent` on the ABN Lookup web services should cross-check the new-versus-reactivated split, it being the only independent source for the distinction. Monthly granularity, needs a free GUID, and the methods page gives one shared parameter table rather than listing them per method, so the parameters want confirming against the WSDL first.
- Whether a name change on an existing ABN should be surfaced alongside new and reactivated. Under the interval model it costs nothing to ask; a sole trader registering a first business name has committed to something.
- Scheduling. Releases land Mondays around 21:37 UTC. The catalogue's last_modified is the trigger, and needs no download to read.
