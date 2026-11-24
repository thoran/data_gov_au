# DataGovAu/AbnBulkExtract/Rebuild.rb
# DataGovAu::AbnBulkExtract::Rebuild

require 'digest'

require_relative './Delta'
require_relative './Error'
require_relative './Extract'
require_relative './Lines'

module DataGovAu
  module AbnBulkExtract
    # A release written out again from the release before it, held whole, and its delta and frame: the older release's records with the delta laid over them, cut into files at the counts the frame gives, and each file put back between the bytes the frame holds for it.
    class Rebuild
      # Each file of the rebuilt release as a run of pieces, every one given with the frame's member it belongs to: what comes before the file's first record, its records with what parts each from the next, and what follows its last.
      def each_piece
        return enum_for(:each_piece) unless block_given?
        records = merged_records
        @frame.members.each do |member|
          yield member, member.before
          gaps = gaps_by_position(member)
          member.records.times do |index|
            yield member, gaps.fetch(index, Lines::SEPARATOR) unless index.zero?
            yield member, next_record(records, member)
          end
          yield member, member.after
        end
        raise RebuildMismatch, "records are left over after #{@frame.members.last&.name}" if left_over?(records)
      end

      # Each file rebuilt is hashed and set against the hash of the file it was made from, so that a delta is trusted only once it has given back every file exactly.
      def check
        raise RebuildMismatch, "the frame was made against #{@frame.against}, not #{@older}" unless @frame.against == @older.to_s
        digests = Hash.new{|hash, name| hash[name] = Digest::SHA256.new}
        each_piece{|member, piece| digests[member.name] << piece}
        differing = @frame.members.reject{|member| digests[member.name].hexdigest == member.sha256}
        raise RebuildMismatch, "rebuilt otherwise than they were made: #{differing.collect(&:name).join(', ')}" unless differing.empty?
        self
      end

      private

      def initialize(older, delta, frame)
        @older = older
        @delta = delta
        @frame = frame
      end

      # The older release's records with the delta laid over them, in ABN order.
      def merged_records
        Enumerator.new do |yielder|
          changes = @delta.each_change
          change = taken(changes)
          Extract.new(@older).each_record_line do |abn, record|
            change = additions_before(abn, change, changes, yielder)
            change = overlaid(abn, record, change, changes, yielder)
          end
          additions_before(nil, change, changes, yielder)
        end
      end

      # Every change before the ABN given, or every change left where there is none, each of which must be an addition, the older release not holding those ABNs.
      def additions_before(abn, change, changes, yielder)
        while change && (abn.nil? || change.abn < abn)
          raise RebuildMismatch, "the delta #{change.kind == Delta::CHANGED ? 'changes' : 'removes'} ABN #{change.abn}, which #{@older} does not hold" unless change.kind == Delta::ADDED
          yielder << change.record
          change = taken(changes)
        end
        change
      end

      # A record of the older release, given as it was, as the delta changed it, or not at all where the delta removed it.
      def overlaid(abn, record, change, changes, yielder)
        unless change && change.abn == abn
          yielder << record
          return change
        end
        raise RebuildMismatch, "the delta adds ABN #{abn}, which #{@older} already holds" if change.kind == Delta::ADDED
        yielder << change.record if change.kind == Delta::CHANGED
        taken(changes)
      end

      # What follows each record, by the number of records up to and including it, wherever that is other than a line break.
      def gaps_by_position(member)
        member.gaps.each_with_object({}){|(gap, positions), by_position| positions.each{|position| by_position[position] = gap}}
      end

      def next_record(records, member)
        records.next
      rescue StopIteration
        raise RebuildMismatch, "records ran out in #{member.name}"
      end

      def left_over?(records)
        records.peek
        true
      rescue StopIteration
        false
      end

      def taken(enumerator)
        enumerator.next
      rescue StopIteration
        nil
      end
    end
  end
end
