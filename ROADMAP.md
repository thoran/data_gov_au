# Roadmap

The discrete jobs are in TODO. This holds the direction: what is larger than one change, what is still undecided, and the stance taken.


## Datasets

Each dataset gets a module of its own beneath `DataGovAu`, named for its publisher and built on the catalogue: first the Australian Business Register's ABN bulk extract, as `DataGovAu::ABR`. What a dataset needs beyond finding and downloading its resources — keeping releases, parsing them, storing and comparing them — stays with that dataset until a second shows which of it is shared.


## The catalogue

Only what a dataset has asked for: package_show, and downloading a resource once. package_search, organisations and the datastore are added when something wants them, as is streaming a download rather than holding its body.

`DataGovAu::Catalogue` speaks the action API which every CKAN portal shares; only its default URL is data.gov.au's. It may become a library of its own once something other than data.gov.au wants it.
