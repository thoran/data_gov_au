# DataGovAu/AsicCompanies/Fetch.rb
# DataGovAu::AsicCompanies::Fetch

require_relative '../Catalogue'
require_relative './Error'
require_relative './ExtractDate'
require_relative './Release'

module DataGovAu
  module AsicCompanies
    class Fetch
      EXTRACT_FORMAT = Release::EXTRACT_FORMAT
      # The register again, unzipped and five times the size, holding what the zip does. Not kept.
      UNZIPPED_FORMAT = 'CSV'

      def catalogue
        @catalogue ||= Catalogue.new(api_url: @config.api_url, user_agent: @config.user_agent)
      end

      def dataset
        @dataset ||= catalogue.dataset(DATASET)
      end

      # The zipped register, from which a release is named.
      def extract_resource
        @extract_resource ||= (
          resource = dataset.resources.detect{|resource| resource.format == EXTRACT_FORMAT}
          raise CatalogueUnavailable, 'the catalogue reports no zipped register' unless resource
          resource
        )
      end

      # Every other resource but the unzipped register, the help file among them, kept alongside each release so that a release on disk carries what is needed to read it.
      def supporting_resources
        @supporting_resources ||= dataset.resources.reject{|resource| [EXTRACT_FORMAT, UNZIPPED_FORMAT].include?(resource.format)}
      end

      def resources
        @resources ||= [extract_resource] + supporting_resources
      end

      # The zipped register's last_modified. It dates the catalogue's record rather than the data, and so reports a release rather than naming one: see ExtractDate.
      def modified_on
        @modified_on ||= (
          time = extract_resource.last_modified
          raise CatalogueUnavailable, 'the catalogue gives the zipped register no last_modified' unless time
          time.to_date
        )
      end

      # The date the register was extracted, read from the first few hundred bytes of the zip rather than from the catalogue.
      def released_on
        @released_on ||= ExtractDate.new(extract_resource.first_bytes(ExtractDate::PEEK_LENGTH)).date
      end

      def release
        @release ||= Release.new(@config, released_on, resources)
      end

      # Nothing is retrieved twice: a release whose every file is already present at the length the catalogue reports is left alone, so a second run in the same week costs one call to the catalogue and one range request. Each resource is yielded as it is reached, for a caller that reports progress.
      def perform
        return release if release.complete?
        release.record_catalogue(dataset.to_h)
        release.missing.each do |resource|
          yield resource if block_given?
          resource.download(release.path_for(resource))
        end
        release
      end

      private

      def initialize(config)
        @config = config
      end
    end
  end
end
