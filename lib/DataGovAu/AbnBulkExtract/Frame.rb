# DataGovAu/AbnBulkExtract/Frame.rb
# DataGovAu::AbnBulkExtract::Frame

require 'json'
require 'zstd-ruby'

require_relative './CompressedFile'
require_relative './Error'

module DataGovAu
  module AbnBulkExtract
    # Everything in a release outside its records, file by file: each file's name, the bytes before its first record and after its last, how many records it holds, what parts two records wherever it is other than a line break, and the SHA-256 of the whole of it. With the release before it and its delta, that is all that is needed to write the release out again exactly, and the hashes say whether it was.
    class Frame
      Member = Struct.new(:name, :before, :after, :records, :gaps, :sha256)

      FIELDS = Member.members.collect(&:to_s)

      def self.read(path)
        contents = JSON.parse(Zstd.decompress(File.binread(path)))
        new(contents['against'], contents['members'].collect{|member| member_from(member)})
      end

      # Each gap's positions are held as the distance from one to the next, so that a gap falling at a regular interval, as the extract's does, is a run of one number repeated and compresses to almost nothing.
      def self.member_from(member)
        member = Member.new(*member.values_at(*FIELDS))
        member.before = member.before.b
        member.after = member.after.b
        member.gaps = member.gaps.to_h{|gap, distances| [gap.b, positions(distances)]}
        member
      end

      def self.positions(distances)
        total = 0
        distances.collect{|distance| total += distance}
      end

      # The date of the release the delta was made against, as its directory is named.
      attr_reader :against, :members

      def <<(member)
        @members << member
        self
      end

      def write(path)
        File.binwrite(path, Zstd.compress(JSON.generate(to_h), level: CompressedFile::LEVEL))
        path
      end

      def to_h
        {'against' => @against, 'members' => @members.collect{|member| member_h(member)}}
      end

      private

      def initialize(against, members = [])
        @against = against
        @members = members
      end

      def member_h(member)
        member.to_h.transform_keys(&:to_s).merge(
          'before' => text(member, member.before),
          'after' => text(member, member.after),
          'gaps' => member.gaps.to_h{|gap, positions| [text(member, gap), distances(positions)]},
        )
      end

      def distances(positions)
        positions.zip([0] + positions).collect{|position, previous| position - previous}
      end

      # The framing is markup and padding, and so text which JSON can carry. Framing which is not is worth stopping for rather than storing mangled.
      def text(member, bytes)
        utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
        raise ExtractMalformed, "#{member.name}: what lies outside its records is not UTF-8" unless utf8.valid_encoding?
        utf8
      end
    end
  end
end
