# DataGovAu/ABR/Comparison.rb
# DataGovAu::ABR::Comparison

require 'fileutils'

require_relative './Delta'
require_relative './Extract'
require_relative './Frame'
require_relative './Rebuild'
require_relative './Release'

module DataGovAu
  module ABR
    # A release set against the one before it, both held whole: what changed between them written as the newer release's delta, and what lies outside the records as its frame. Both are checked by rebuilding the newer release from the older before either is trusted. Nothing is removed: the zips stay as they are.
    class Comparison
      PARTIAL_SUFFIX = '.partial'

      # Every release held whole which has no delta yet, set against the newest one held whole before it, oldest first, so that a run which missed a week catches up in order. A week missed, or one held only in part, is compared across.
      def self.pending(config)
        releases = Release.dates_held(config).reverse.collect{|date| Release.new(config, date)}.select(&:whole?)
        releases.each_cons(2).reject{|_older, newer| newer.delta?}.collect{|older, newer| new(older, newer)}
      end

      attr_reader :older, :newer

      # Written under partial names, checked, and only then given their own, so that a delta which is present is one which has rebuilt its release exactly. A comparison which stops leaves neither behind. Yields once the delta is written and again once it is checked, for a caller which reports progress.
      def perform
        write
        yield :written if block_given?
        check
        yield :checked if block_given?
        File.rename(partial(@newer.frame_path), @newer.frame_path)
        File.rename(partial(@newer.delta_path), @newer.delta_path)
        @newer
      rescue StandardError
        [@newer.frame_path, @newer.delta_path].each{|path| FileUtils.rm_f(partial(path))}
        raise
      end

      def write
        frame = Frame.new(@older.to_s)
        delta.write{|changes| set_against(changes, frame)}
        frame.write(partial(@newer.frame_path))
      end

      # The frame is read back from what was written rather than taken from memory, so that it is the files on disk which are checked.
      def check
        Rebuild.new(@older, Delta.new(partial(@newer.delta_path)), Frame.read(partial(@newer.frame_path))).check
      end

      # Its added, changed and removed count what was written.
      def delta
        @delta ||= Delta.new(partial(@newer.delta_path))
      end

      private

      def initialize(older, newer)
        @older = older
        @newer = newer
      end

      def partial(path)
        path + PARTIAL_SUFFIX
      end

      # The two releases read in step, ABN by ABN, the newer one's files each framed once read through.
      def set_against(changes, frame)
        older = Extract.new(@older).each_record_line
        newer = Extract.new(@newer).each_record_line(->(lines){frame << member_of(lines)})
        older_record, newer_record = taken(older), taken(newer)
        while older_record || newer_record
          case step(changes, older_record, newer_record)
          when :older then older_record = taken(older)
          when :newer then newer_record = taken(newer)
          else older_record, newer_record = taken(older), taken(newer)
          end
        end
      end

      # Removed where only the older release holds the ABN, added where only the newer does, and changed where both do and the text differs. ABNs are eleven digits, so they compare as strings as they do as numbers.
      def step(changes, older_record, newer_record)
        if newer_record.nil? || (older_record && older_record.first < newer_record.first)
          changes.remove(older_record.first)
          :older
        elsif older_record.nil? || newer_record.first < older_record.first
          changes.add(newer_record.last)
          :newer
        else
          changes.change(newer_record.last) unless older_record.last == newer_record.last
          :both
        end
      end

      def member_of(lines)
        Frame::Member.new(lines.name, lines.before, lines.after, lines.records, lines.gaps, lines.sha256)
      end

      def taken(enumerator)
        enumerator.next
      rescue StopIteration
        nil
      end
    end
  end
end
