# DataGovAu/AsicCompanies/Extract.rb
# DataGovAu::AsicCompanies::Extract

require 'zip'

require_relative './Error'
require_relative './Parser'

module DataGovAu
  module AsicCompanies
    # A release's rows, read out of the zip as it lies. rubyzip inflates the register as it is read and the parser takes it a line at a time, so neither the 79 MB zip nor the 401 MB register inside it is ever held whole.
    class Extract
      # Each file in the release's zip, as its name and the stream rubyzip inflates.
      def each_member
        return enum_for(:each_member) unless block_given?
        raise NothingToParse, "#{@release.directory} holds no zip file" if paths.empty?
        paths.each do |path|
          Zip::File.open(path) do |zip|
            zip.entries.select(&:file?).each{|entry| entry.get_input_stream{|io| yield entry.name, io}}
          end
        end
      end

      # Each file in the release's zip, as its own parser, so that a caller can report its progress.
      def each_file
        return enum_for(:each_file) unless block_given?
        each_member{|name, io| yield name, Parser.new(io)}
      end

      def each_record(&block)
        return enum_for(:each_record) unless block
        each_file{|_name, parser| parser.each_record(&block)}
      end

      def paths
        @paths ||= @release.zip_paths
      end

      private

      def initialize(release)
        @release = release
      end
    end
  end
end
