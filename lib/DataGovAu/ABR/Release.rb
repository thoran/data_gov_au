# DataGovAu/ABR/Release.rb
# DataGovAu::ABR::Release

require 'date'
require 'fileutils'
require 'json'

require_relative '../Resource'
require_relative '../../Thoran/Array/NaturalSort/natural_sort'

module DataGovAu
  module ABR
    class Release
      DATE_FORMAT = '%Y%m%d'
      DELTA_NAME = 'delta.zst'
      EXTRACT_FORMAT = 'ZIP'
      FRAME_NAME = 'frame.json.zst'

      # The release dates already on disk, newest first, read from the directory names rather than from the database, so that what is held can be reported before anything has been loaded.
      def self.dates_held(config)
        return [] unless Dir.exist?(config.releases_directory)
        Dir.children(config.releases_directory).grep(/\A\d{8}\z/).collect{|name| Date.strptime(name, DATE_FORMAT)}.sort.reverse
      end

      attr_reader :date, :resources

      def directory
        @directory ||= File.join(@config.releases_directory, @date.strftime(DATE_FORMAT))
      end

      # A file is kept under the name data.gov.au serves it as.
      def path_for(resource)
        File.join(directory, resource.filename)
      end

      def held?(resource)
        resource.held_at?(path_for(resource))
      end

      # The zips held, read from the directory rather than from the catalogue, so that a release on disk can be parsed without going back to data.gov.au. Sorted by the numbers in their names rather than by their characters, the halves being named public_split_1_10 and public_split_11_20, of which the second sorts first.
      def zip_paths
        @zip_paths ||= Dir.glob(File.join(directory, '*.zip')).natural_sort
      end

      def missing
        @resources.reject{|resource| held?(resource)}
      end

      def complete?
        missing.empty?
      end

      def create_directory
        FileUtils.mkdir_p(directory)
      end

      # The catalogue entry the release was found through, kept beside the files so that a release on disk records where it came from, when, and under what licence.
      def record_catalogue(package)
        create_directory
        File.write(catalogue_path, JSON.pretty_generate(package))
        catalogue_path
      end

      def catalogue_path
        @catalogue_path ||= File.join(directory, 'catalogue.json')
      end

      # The resources of the catalogue entry recorded beside the files, which say what a release on disk should hold and at what lengths without going back to data.gov.au. Read afresh each time, the entry being written partway through a fetch.
      def recorded_resources
        return [] unless File.exist?(catalogue_path)
        JSON.parse(File.read(catalogue_path)).fetch('resources', []).collect{|entry| Resource.new(nil, entry)}
      end

      # Every zip the recorded catalogue entry lists is present, at the length it gives.
      def whole?
        zips = recorded_resources.select{|resource| resource.format == EXTRACT_FORMAT}
        !zips.empty? && zips.all?{|resource| held?(resource)}
      end

      # Its changes from the release before it.
      def delta_path
        @delta_path ||= File.join(directory, DELTA_NAME)
      end

      # What lies outside its records, and the hash of each of its files.
      def frame_path
        @frame_path ||= File.join(directory, FRAME_NAME)
      end

      # Both are given their names only once they have rebuilt the release exactly, so both being present means a delta which has been checked.
      def delta?
        File.exist?(delta_path) && File.exist?(frame_path)
      end

      def to_s
        @date.strftime(DATE_FORMAT)
      end

      private

      def initialize(config, date, resources = [])
        @config = config
        @date = date
        @resources = resources
      end
    end
  end
end
