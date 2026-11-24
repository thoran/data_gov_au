# DataGovAu/ABR/CompressedFile.rb
# DataGovAu::ABR::CompressedFile

require 'zstd-ruby'

module DataGovAu
  module ABR
    # A file of lines compressed with zstd, written and read as a stream so that neither end holds the whole of it. The streaming compressor is driven directly: zstd-ruby's own StreamWriter flushes at every write, ending a block each time and giving up much of what a high level is for.
    class CompressedFile
      LEVEL = 19
      READ_LENGTH = 1_048_576

      # Yields the file, to be written to with <<, and finishes the stream once the block returns.
      def write
        File.open(@path, 'wb') do |file|
          @file = file
          @stream = Zstd::StreamingCompress.new(level: @level)
          yield self
          file.write(@stream.finish)
        end
      ensure
        @file = @stream = nil
      end

      def <<(text)
        @file.write(@stream.compress(text))
        self
      end

      # Each line with its line break, a line which straddles two reads being held back until the rest of it arrives.
      def each_line(&block)
        return enum_for(:each_line) unless block
        stream = Zstd::StreamingDecompress.new
        pending = String.new
        File.open(@path, 'rb') do |file|
          while (chunk = file.read(READ_LENGTH))
            pending = whole_lines(pending << stream.decompress(chunk), &block)
          end
        end
        yield pending unless pending.empty?
      end

      private

      def initialize(path, level: LEVEL)
        @path = path
        @level = level
      end

      # Yields every line ending in a line break and gives back what follows the last of them.
      def whole_lines(text)
        last_break = text.rindex("\n")
        return text unless last_break
        text[0..last_break].each_line{|line| yield line}
        text[(last_break + 1)..]
      end
    end
  end
end
