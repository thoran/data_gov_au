# DataGovAu/AbnBulkExtract/Delta.rb
# DataGovAu::AbnBulkExtract::Delta

require_relative './CompressedFile'
require_relative './Error'
require_relative './Lines'

module DataGovAu
  module AbnBulkExtract
    # A release's changes from the release before it, a line for each ABN which changed, in ABN order: A and the record for an ABN added, C and the record for one changed, R and the ABN for one removed. A record unchanged from one week to the next, which nearly every one is, is not held. The changes being whole records, the week's new ABNs, cancellations and reactivations can be read from the delta alone.
    class Delta
      ADDED = 'A'
      CHANGED = 'C'
      REMOVED = 'R'

      Change = Struct.new(:kind, :abn, :record)

      # Counted as they are written.
      attr_reader :added, :changed, :removed

      # Yields the delta, to be written to with add, change and remove in ABN order.
      def write
        CompressedFile.new(@path).write do |file|
          @file = file
          yield self
        end
        @path
      ensure
        @file = nil
      end

      def add(record)
        @added += 1
        @file << ADDED << ' ' << record << "\n"
      end

      def change(record)
        @changed += 1
        @file << CHANGED << ' ' << record << "\n"
      end

      def remove(abn)
        @removed += 1
        @file << REMOVED << ' ' << abn << "\n"
      end

      # Each change in the order written, as its kind, its ABN, and for an ABN added or changed its record.
      def each_change
        return enum_for(:each_change) unless block_given?
        CompressedFile.new(@path).each_line{|line| yield parsed(line.chomp("\n"))}
      end

      private

      def initialize(path)
        @path = path
        @added = @changed = @removed = 0
      end

      def parsed(line)
        kind, text = line[0], line[2..]
        case kind
        when ADDED, CHANGED then Change.new(kind, abn_of(text), text)
        when REMOVED then Change.new(kind, text, nil)
        else raise ExtractMalformed, "#{@path}: a line which is no change: #{line[0, 40]}"
        end
      end

      def abn_of(record)
        record[Lines::ABN, 1] or raise ExtractMalformed, "#{@path}: a record which carries no ABN: #{record[0, 80]}"
      end
    end
  end
end
