# DataGovAu/ABR/Lines.rb
# DataGovAu::ABR::Lines

require 'digest'

require_relative './Error'

module DataGovAu
  module ABR
    # One XML file of an extract read as the text it is rather than as XML: its records, each on a line of its own, the bytes before the first of them and after the last, and wherever two records are parted by anything other than a line break, what parts them. That is enough to write the file out again byte for byte from its records, which is what lets a release be kept as its changes from the week before. A record which runs over more than one line stops it, a file laid out so being one which could not be rebuilt from its records.
    class Lines
      ABN = /<ABN [^>]*>(\d{11})<\/ABN>/
      RECORD_END = '</ABR>'
      RECORD_START = '<ABR '
      SEPARATOR = "\r\n"

      # Each is complete once each_record has run through: the header and padding before the first record, what follows the last, and how many there were.
      attr_reader :name, :before, :after, :records

      # Each separator other than a line break, with the positions it falls at: after which record, counted from the first of the file. The extract puts a second carriage return after every hundredth record.
      attr_reader :gaps

      # Each record as its ABN and its text, in the order the file holds them.
      def each_record(&block)
        return enum_for(:each_record) unless block
        @io.each_line{|line| take(line.encoding == Encoding::BINARY ? line : line.b, &block)}
        @after = @pending
        self
      end

      # Of every byte read, so that a file rebuilt later can be set against the one read now.
      def sha256
        @digest.hexdigest
      end

      private

      def initialize(io, name = nil)
        @io = io
        @name = name
        @before = String.new
        @pending = String.new
        @records = 0
        @gaps = {}
        @digest = Digest::SHA256.new
      end

      def take(line)
        @digest << line
        start = line.index(RECORD_START)
        return outside(line) unless start
        finish = record_end(line, start)
        frame(line[0...start])
        @pending = line[finish..]
        @records += 1
        record = line[start...finish]
        yield abn_of(record), record
      end

      # A line holding no record, which belongs before the records until the first of them and after them from then on. Should a record follow it, it lay between two records, and is held as part of what parts them.
      def outside(line)
        (@records.zero? ? @before : @pending) << line
      end

      def record_end(line, start)
        finish = line.index(RECORD_END, start)
        raise ExtractMalformed, "#{@name}: record #{@records + 1} runs over more than one line" unless finish
        finish += RECORD_END.length
        raise ExtractMalformed, "#{@name}: two records on one line, after record #{@records}" if line.index(RECORD_START, finish)
        finish
      end

      def frame(prefix)
        return @before << prefix if @records.zero?
        gap = @pending + prefix
        (@gaps[gap] ||= []) << @records unless gap == SEPARATOR
      end

      def abn_of(record)
        record[ABN, 1] or raise ExtractMalformed, "#{@name}: record #{@records} carries no ABN"
      end
    end
  end
end
