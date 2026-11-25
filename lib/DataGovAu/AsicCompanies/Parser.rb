# DataGovAu/AsicCompanies/Parser.rb
# DataGovAu::AsicCompanies::Parser

require 'dsv'

require_relative './Error'

module DataGovAu
  module AsicCompanies
    # The register as ASIC writes it, read as a stream and yielded a row at a time: tab-separated, each line ending CRLF, a byte-order mark before the header, and a quote in a name being part of the name rather than the start of a quoted field. Nothing is filtered, derived or discarded: every field comes as the string the register gives, an empty one as '', dates as dd/mm/yyyy, and an ABN of 0 where the company has none.
    #
    # A row is one name a company has held, so a company comes as many rows as it has had names, under the same ACN. A row comes out shaped so:
    #
    #   {
    #     company_name: 'LOVINI HOLDINGS PTY LTD', acn: '000000019',
    #     type: 'APTY', class: 'LMSH', sub_class: 'PROP', status: 'REGD',
    #     date_of_registration: '08/01/1990', date_of_deregistration: '',
    #     previous_state_of_registration: 'NSW', state_registration_number: '46869041',
    #     modified_since_last_report: '', current_name_indicator: '',
    #     abn: '89000000019', current_name: 'MONAKA PTY LTD', current_name_start_date: '28/01/2016',
    #   }
    class Parser
      BYTE_ORDER_MARK = "﻿"
      COLUMN_SEPARATOR = "\t"
      ROW_SEPARATOR = "\r\n"

      # The register's columns as its header names them, in order, and the key each is given under.
      COLUMNS = {
        'Company Name' => :company_name,
        'ACN' => :acn,
        'Type' => :type,
        'Class' => :class,
        'Sub Class' => :sub_class,
        'Status' => :status,
        'Date of Registration' => :date_of_registration,
        'Date of Deregistration' => :date_of_deregistration,
        'Previous State of Registration' => :previous_state_of_registration,
        'State Registration number' => :state_registration_number,
        'Modified since last report' => :modified_since_last_report,
        'Current Name Indicator' => :current_name_indicator,
        'ABN' => :abn,
        'Current Name' => :current_name,
        'Current Name Start Date' => :current_name_start_date,
      }

      attr_reader :records_parsed

      # The header is checked before any row is yielded, so that a register whose columns have moved stops rather than having its values yielded under the wrong names.
      def each_record
        return enum_for(:each_record) unless block_given?
        validate_header
        while (line = @io.gets(ROW_SEPARATOR))
          @records_parsed += 1
          yield record(fields(line))
        end
        self
      end

      private

      def initialize(io)
        @io = io
        @records_parsed = 0
      end

      def validate_header
        line = @io.gets(ROW_SEPARATOR)
        header = line && fields(line.force_encoding(Encoding::UTF_8).delete_prefix(BYTE_ORDER_MARK))
        return if header == COLUMNS.keys
        raise RegisterMalformed, "the header is #{header.inspect}, where #{COLUMNS.keys.inspect} was expected"
      end

      # One line into its fields through dsv, with no quoting, since the register quotes nothing.
      def fields(line)
        DSV.parse_line(line.force_encoding(Encoding::UTF_8), column_separator: COLUMN_SEPARATOR, row_separator: ROW_SEPARATOR, quote: :none)
      end

      def record(fields)
        return COLUMNS.values.zip(fields).to_h if fields.size == COLUMNS.size
        raise RegisterMalformed, "line #{@records_parsed + 1} has #{fields.size} fields, where #{COLUMNS.size} were expected"
      end
    end
  end
end
