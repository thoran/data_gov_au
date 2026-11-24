# Proposed

What is still undecided, under ROADMAP.md's headings. The direction is in ROADMAP.md, and the discrete jobs in TODO.


## The catalogue

- Whether `DataGovAu::Catalogue` becomes a library of its own once something other than data.gov.au wants it, it speaking the action API which every CKAN portal shares.


## The ABN Bulk Extract

- Whether `SearchByRegistrationEvent` on the ABN Lookup web services should cross-check the new-versus-reactivated split, it being the only independent source for the distinction. Monthly granularity, needs a free GUID, and the methods page gives one shared parameter table rather than listing them per method, so the parameters want confirming against the WSDL first.
- Whether a name change on an existing ABN should be surfaced alongside new and reactivated. Under the interval model it costs nothing to ask; a sole trader registering a first business name has committed to something.


## Releases kept as differences

- Merging the first release forward into a later one, which is what letting old releases go would want. Until then a long chain costs nothing more to rebuild than a short one: one pass.
- Whether the schema and readme, unchanged for months at a time, are kept with every release or once.
