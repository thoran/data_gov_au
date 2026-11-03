# DataGovAu/ABR/Extract.rb
# DataGovAu::ABR::Extract

require 'zip'

require_relative './Error'
require_relative './Parser'
require_relative '../../Thoran/String/NaturalComparison/natural_comparison'

module DataGovAu
  module ABR
    # A release's records, read out of the zips as they lie. rubyzip inflates a member as it is read and Ox is handed that stream, so neither a 477 MB zip nor one of the 605 MB XML files inside it is ever held whole.
    class Extract
      # Each XML file of the release in turn, as its own parser, so that a caller can report its progress and set what each file gave up against what it promised.
      def each_file
        return enum_for(:each_file) unless block_given?
        raise NothingToParse, "#{@release.directory} holds no zip files" if members.empty?
        members.each do |path, name|
          Zip::File.open(path) do |zip|
            zip.get_entry(name).get_input_stream{|io| yield name, Parser.new(io)}
          end
        end
      end

      def each_record(&block)
        return enum_for(:each_record) unless block
        each_file{|_name, parser| parser.each_record(&block)}
      end

      # Every XML file of the release in the order the extract was written, which is the order of the sequence numbers its names carry. Sorted by those numbers rather than by the characters of the names, so that the order does not rest on the ABR going on padding them: unpadded, the characters would put file 2 after file 19, and the records would stop being one ascending run without anything in them saying so.
      def members
        @members ||= paths.flat_map{|path|
          Zip::File.open(path){|zip| zip.entries.collect{|entry| [path, entry.name]}}
        }.sort{|(_, a), (_, b)| a.natural_comparison(b)}
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
