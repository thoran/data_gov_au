# DataGovAu/AbnBulkExtract/ExtractDate.rb
# DataGovAu::AbnBulkExtract::ExtractDate

require 'date'

require_relative './Error'

module DataGovAu
  module AbnBulkExtract
    # The date an extract carries itself, read from the name of the first file inside one of its zips. The catalogue's last_modified dates the record rather than the data and moves whenever data.gov.au touches a resource, so it would name a release which held nothing new.
    class ExtractDate
      DATED_NAME = /\A(\d{8})/
      # A zip's local file header stands at the start of the file: a signature, twenty-two bytes of versions, flags, method, time and lengths, the name's length, the extra field's length, and then the name. So the first few hundred bytes name the first file inside.
      HEADER_LENGTH = 30
      NAME_LENGTH_OFFSET = 26
      PEEK_LENGTH = 256
      SIGNATURE = "PK\x03\x04".b

      def date
        @date ||= (
          matched = DATED_NAME.match(member_name)
          raise ExtractUndated, "#{member_name.inspect} does not begin with a date" unless matched
          Date.strptime(matched[1], '%Y%m%d')
        )
      end

      def member_name
        @member_name ||= (
          raise ExtractUndated, 'what was read does not begin a zip file' unless @bytes[0, SIGNATURE.length] == SIGNATURE
          length = @bytes[NAME_LENGTH_OFFSET, 2].to_s.unpack1('v')
          raise ExtractUndated, 'the zip names its first file beyond what was read' if length.nil? || HEADER_LENGTH + length > @bytes.length
          @bytes[HEADER_LENGTH, length].dup.force_encoding(Encoding::UTF_8)
        )
      end

      private

      def initialize(bytes)
        @bytes = bytes.to_s.b
      end
    end
  end
end
