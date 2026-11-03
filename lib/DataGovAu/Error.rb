# DataGovAu/Error.rb
# DataGovAu::Error

module DataGovAu
  class Error < StandardError; end

  # The catalogue could not be read, so what a dataset holds now remains unknown.
  class CatalogueUnavailable < Error; end

  # A resource could not be retrieved, or arrived at a length other than the one the catalogue reported.
  class DownloadFailed < Error; end
end
