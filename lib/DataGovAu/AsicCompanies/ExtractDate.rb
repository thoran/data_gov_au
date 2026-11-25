# DataGovAu/AsicCompanies/ExtractDate.rb
# DataGovAu::AsicCompanies::ExtractDate

require 'date'

require_relative './Error'

module DataGovAu
  module AsicCompanies
    # The date the register was extracted, read from the zip's record of when the file inside it was written. The file is named for the month alone, as COMPANY_202611.csv, and the catalogue's last_modified dates its own record rather than the data, a day earlier in UTC than the extract's date in Sydney.
    class ExtractDate
      # A zip's local file header stands at the start of the file: a signature, the version, flags and method, the time and then the date its first file was last written, in MS-DOS form, the checksum and lengths, the name's length, the extra field's length, and then the name.
      DATE_OFFSET = 12
      HEADER_LENGTH = 30
      NAME_LENGTH_OFFSET = 26
      PEEK_LENGTH = 256
      SIGNATURE = "PK\x03\x04".b

      # The MS-DOS date packs the year since 1980 into its top seven bits, the month into the next four and the day into the last five.
      def date
        @date ||= (
          validate_header
          packed = @bytes[DATE_OFFSET, 2].unpack1('v')
          year, month, day = 1980 + (packed >> 9), (packed >> 5) & 0x0f, packed & 0x1f
          raise ExtractUndated, "the zip dates its first file as #{year}-#{month}-#{day}, which is no date" unless Date.valid_date?(year, month, day)
          Date.new(year, month, day)
        )
      end

      def member_name
        @member_name ||= (
          validate_header
          length = @bytes[NAME_LENGTH_OFFSET, 2].unpack1('v')
          raise ExtractUndated, 'the zip names its first file beyond what was read' if HEADER_LENGTH + length > @bytes.length
          @bytes[HEADER_LENGTH, length].dup.force_encoding(Encoding::UTF_8)
        )
      end

      private

      def initialize(bytes)
        @bytes = bytes.to_s.b
      end

      def validate_header
        raise ExtractUndated, 'what was read does not begin a zip file' unless @bytes[0, SIGNATURE.length] == SIGNATURE
        raise ExtractUndated, 'what was read stops within the zip file header' if @bytes.length < HEADER_LENGTH
      end
    end
  end
end
