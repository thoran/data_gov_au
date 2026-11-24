# DataGovAu/ABR/Fetch.rb
# DataGovAu::ABR::Fetch

require_relative '../Catalogue'
require_relative './Error'
require_relative './ExtractDate'
require_relative './Release'
require_relative '../../Thoran/String/NaturalComparison/natural_comparison'

module DataGovAu
  module ABR
    class Fetch
      DATASET = 'abn-bulk-extract'
      EXTRACT_FORMAT = Release::EXTRACT_FORMAT

      def catalogue
        @catalogue ||= Catalogue.new(api_url: @config.api_url, user_agent: @config.user_agent)
      end

      def dataset
        @dataset ||= catalogue.dataset(DATASET)
      end

      # The zipped halves of the extract, in the order the catalogue's own names put them: the first is the one a release is named from. Sorted by the numbers in those names rather than by their characters, so that a tenth part would not come between the first and the second.
      def extract_resources
        @extract_resources ||= dataset.resources.select{|resource| resource.format == EXTRACT_FORMAT}.sort{|a, b| a.name.to_s.natural_comparison(b.name.to_s)}
      end

      # Every other resource of the dataset, the schema, the readme and the list of resources among them, kept alongside each release so that a release on disk carries what is needed to read it.
      def supporting_resources
        @supporting_resources ||= dataset.resources.reject{|resource| resource.format == EXTRACT_FORMAT}
      end

      # The extract's own halves and the resources alongside them, so that a release on disk carries what is needed to read it without going back to the catalogue.
      def resources
        @resources ||= extract_resources + supporting_resources
      end

      # The latest last_modified among the extract's own halves, the schema and the readme changing on their own schedule. It dates the catalogue's record rather than the data, and so reports a release rather than naming one: see ExtractDate.
      def modified_on
        @modified_on ||= (
          times = extract_resources.collect(&:last_modified).compact
          raise CatalogueUnavailable, 'the catalogue reports no extract files' if times.empty?
          times.max.to_date
        )
      end

      # The date the extract carries itself, read from the first few hundred bytes of its first half rather than from the catalogue, whose last_modified dates its own record and moves whenever a resource is touched.
      def released_on
        @released_on ||= ExtractDate.new(first_extract.first_bytes(ExtractDate::PEEK_LENGTH)).date
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

      def first_extract
        @first_extract ||= (
          resource = extract_resources.first
          raise CatalogueUnavailable, 'the catalogue reports no extract files' unless resource
          resource
        )
      end
    end
  end
end
