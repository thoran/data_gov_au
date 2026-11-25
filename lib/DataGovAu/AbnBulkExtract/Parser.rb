# DataGovAu/AbnBulkExtract/Parser.rb
# DataGovAu::AbnBulkExtract::Parser

require 'ox'

require_relative './Error'

module DataGovAu
  module AbnBulkExtract
    # One XML file of an extract, read as a stream and yielded one record at a time. Nothing is filtered, nothing is derived and nothing is discarded: every element and attribute the schema allows for is carried into the record, dates as the strings the extract gives them, so that what is asked of the data later is not settled here.
    #
    # A record comes out shaped so:
    #
    #   {
    #     abn: '11000047950', abn_status: 'ACT', abn_status_from_date: '20000224',
    #     record_last_updated_date: '20260211', replaced: 'N',
    #     entity_type_code: 'PUB', entity_type_text: 'Australian Public Company',
    #     state: 'NSW', postcode: '2132',
    #     asic_number: '000047950', asic_number_type: 'undetermined',
    #     gst_status: 'ACT', gst_status_from_date: '20000701',
    #     names: [{type: 'MN', text: 'SYDNEY MISSIONARY & BIBLE COLLEGE'}, ...],
    #     dgr: [{from_date: '20060301', status: 'ACT', name: nil}, ...],
    #   }
    #
    # An individual's name comes as its parts rather than joined, joining being a decision for whoever asks:
    #
    #   {type: 'LGL', title: 'MR', given_names: ['WILLIAM', 'RICHARD'], family_name: 'LITT'}
    class Parser
      # What a file reports where it was written out whole.
      NO_ERROR = 'none'

      # What the file says of itself, which is read before any record and lets what was parsed be set against what was promised.
      attr_reader :error, :extract_time, :file_sequence_number, :record_count, :records_parsed

      def each_record(&block)
        return enum_for(:each_record) unless block
        @block = block
        Ox.sax_parse(self, @io, convert_special: true, skip: :skip_none)
        self
      end

      # The file reports no error of its own, in the error attribute the schema requires of it.
      def error_free?
        @error == NO_ERROR
      end

      # Every record was yielded where the file reports no error and holds as many as its own TransferInfo promised.
      def whole?
        error_free? && !record_count.nil? && records_parsed == record_count
      end

      # Ox drives these four as it reads. They are public because Ox calls them, and are no part of what this class is for.

      def start_element(name)
        @element = name
        @text.clear
        case name
        when :ABR then start_record
        when :DGR then @record[:dgr] << {from_date: nil, status: nil, name: nil}
        when :NonIndividualName, :IndividualName then @name = {type: nil}
        end
      end

      def attr(name, value)
        case @element
        when :Transfer then @error = value if name == :error
        when :ABR then record_attribute(name, value)
        when :ABN then abn_attribute(name, value)
        when :GST then gst_attribute(name, value)
        when :DGR then dgr_attribute(name, value)
        when :ASICNumber then @record[:asic_number_type] = value if name == :ASICNumberType
        when :NonIndividualName, :IndividualName then @name[:type] = value if name == :type
        end
      end

      def text(value)
        @text << value
      end

      def end_element(name)
        case name
        when :ABR then finish_record
        when :ABN then @record[:abn] = taken
        when :EntityTypeInd then @record[:entity_type_code] = taken
        when :EntityTypeText then @record[:entity_type_text] = taken
        when :ASICNumber then @record[:asic_number] = taken
        when :State then @record[:state] = taken
        when :Postcode then @record[:postcode] = taken
        when :NameTitle then @name[:title] = taken
        when :GivenName then (@name[:given_names] ||= []) << taken
        when :FamilyName then @name[:family_name] = taken
        when :NonIndividualNameText then @name[:text] = taken
        when :NonIndividualName, :IndividualName then finish_name
        when :FileSequenceNumber then @file_sequence_number = taken.to_i
        when :RecordCount then @record_count = taken.to_i
        when :ExtractTime then @extract_time = taken
        end
      end

      private

      def initialize(io)
        @io = io
        @records_parsed = 0
        @text = +''
      end

      # The buffer is cleared at each element rather than made anew, there being some hundreds of millions of them in a release.
      def taken
        @text.dup
      end

      def start_record
        @record = {
          abn: nil,
          abn_status: nil,
          abn_status_from_date: nil,
          record_last_updated_date: nil,
          replaced: nil,
          entity_type_code: nil,
          entity_type_text: nil,
          state: nil,
          postcode: nil,
          asic_number: nil,
          asic_number_type: nil,
          gst_status: nil,
          gst_status_from_date: nil,
          names: [],
          dgr: [],
        }
      end

      def finish_record
        @records_parsed += 1
        @block.call(@record)
        @record = nil
      end

      # A name of type DGR belongs to the DGR element enclosing it, that being the only place the schema puts one; every other name belongs to the record.
      def finish_name
        if @name[:type] == 'DGR'
          @record[:dgr].last[:name] = @name[:text] if @record[:dgr].last
        else
          @record[:names] << @name
        end
        @name = nil
      end

      def record_attribute(name, value)
        case name
        when :recordLastUpdatedDate then @record[:record_last_updated_date] = value
        when :replaced then @record[:replaced] = value
        end
      end

      def abn_attribute(name, value)
        case name
        when :status then @record[:abn_status] = value
        when :ABNStatusFromDate then @record[:abn_status_from_date] = value
        end
      end

      def gst_attribute(name, value)
        case name
        when :status then @record[:gst_status] = value
        when :GSTStatusFromDate then @record[:gst_status_from_date] = value
        end
      end

      # The extract puts an entity's own endorsement and each named fund it runs in DGR elements of the same name, the first carrying a status and no name and the second a name and no status. Both are kept as they come.
      def dgr_attribute(name, value)
        entry = @record[:dgr].last
        return unless entry
        case name
        when :status then entry[:status] = value
        when :DGRStatusFromDate then entry[:from_date] = value
        end
      end
    end
  end
end
