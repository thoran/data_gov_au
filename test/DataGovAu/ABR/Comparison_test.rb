# test/DataGovAu/ABR/Comparison_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Comparison do
  describe "the delta it writes" do
    it "holds what changed between the two, in ABN order" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        DataGovAu::ABR::Comparison.new(older, newer).perform
        changes = DataGovAu::ABR::Delta.new(newer.delta_path).each_change.collect{|change| [change.kind, change.abn]}
        _(changes).must_equal [['C', '22222222222'], ['A', '25000000000'], ['R', '55555555555'], ['A', '66666666666']]
      end
    end

    # 33333333333 moves from the first file to the second unchanged, and so is no change: the releases are read as one run of ABNs, across the files.
    it "holds nothing for a record which only moved between files" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        DataGovAu::ABR::Comparison.new(older, newer).perform
        _(DataGovAu::ABR::Delta.new(newer.delta_path).each_change.collect(&:abn)).wont_include '33333333333'
      end
    end

    it "counts what it holds" do
      Dir.mktmpdir do |directory|
        comparison = DataGovAu::ABR::Comparison.new(*two_releases(directory))
        comparison.perform
        _([comparison.delta.added, comparison.delta.changed, comparison.delta.removed]).must_equal [2, 1, 1]
      end
    end
  end

  describe "the frame it writes" do
    it "describes each file of the newer release" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        DataGovAu::ABR::Comparison.new(older, newer).perform
        frame = DataGovAu::ABR::Frame.read(newer.frame_path)
        text = newer_files['public_split_1_10.zip']['20261104_Public01.xml']
        _(frame.against).must_equal '20261028'
        _(frame.members.collect{|member| [member.name, member.records]}).must_equal [['20261104_Public01.xml', 3], ['20261104_Public11.xml', 3]]
        _(frame.members.first.sha256).must_equal Digest::SHA256.hexdigest(text)
      end
    end
  end

  describe "what it leaves on disk" do
    it "names the delta and frame only once they have rebuilt the release" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        DataGovAu::ABR::Comparison.new(older, newer).perform
        _(newer.delta?).must_equal true
        _(Dir.children(newer.directory).grep(/\.partial\z/)).must_equal []
      end
    end

    it "removes nothing" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        DataGovAu::ABR::Comparison.new(older, newer).perform
        _(older.whole?).must_equal true
        _(newer.whole?).must_equal true
      end
    end

    it "leaves no delta named where the rebuild fails" do
      Dir.mktmpdir do |directory|
        older, newer = two_releases(directory)
        failing = Class.new(DataGovAu::ABR::Comparison){def check = raise(DataGovAu::ABR::RebuildMismatch, 'rebuilt otherwise')}
        _(->{failing.new(older, newer).perform}).must_raise DataGovAu::ABR::RebuildMismatch
        _(newer.delta?).must_equal false
        _(Dir.children(newer.directory).grep(/\.partial\z/)).must_equal []
      end
    end
  end

  describe "a release whose ABNs do not rise" do
    it "stops rather than writing a delta" do
      Dir.mktmpdir do |directory|
        newer = {'public_split_1_10.zip' => {'20261104_Public01.xml' => member_text(1, [record_line('22222222222'), record_line('11111111111')])}}
        older, newer_release = two_releases(directory, older_files, newer)
        _(->{DataGovAu::ABR::Comparison.new(older, newer_release).perform}).must_raise DataGovAu::ABR::ExtractMalformed
        _(newer_release.delta?).must_equal false
      end
    end
  end

  describe "which releases want comparing" do
    it "is none where one release is held" do
      Dir.mktmpdir do |directory|
        whole_release(directory, Date.new(2026, 10, 28), older_files)
        _(DataGovAu::ABR::Comparison.pending(config_in(directory))).must_equal []
      end
    end

    it "is the newer of two releases held whole" do
      Dir.mktmpdir do |directory|
        two_releases(directory)
        pending = DataGovAu::ABR::Comparison.pending(config_in(directory))
        _(pending.collect{|comparison| [comparison.older.to_s, comparison.newer.to_s]}).must_equal [['20261028', '20261104']]
      end
    end

    it "is none once the newer has its delta" do
      Dir.mktmpdir do |directory|
        DataGovAu::ABR::Comparison.new(*two_releases(directory)).perform
        _(DataGovAu::ABR::Comparison.pending(config_in(directory))).must_equal []
      end
    end

    it "is each in turn, oldest first, where several weeks want comparing" do
      Dir.mktmpdir do |directory|
        two_releases(directory)
        whole_release(directory, Date.new(2026, 11, 11), newer_files)
        pending = DataGovAu::ABR::Comparison.pending(config_in(directory))
        _(pending.collect{|comparison| [comparison.older.to_s, comparison.newer.to_s]}).must_equal [['20261028', '20261104'], ['20261104', '20261111']]
      end
    end

    # A download cut short leaves a release which cannot be read as a whole, and so cannot be set against anything.
    it "passes over a release not held whole" do
      Dir.mktmpdir do |directory|
        _older, newer = two_releases(directory)
        File.truncate(File.join(newer.directory, 'public_split_11_20.zip'), 10)
        _(DataGovAu::ABR::Comparison.pending(config_in(directory))).must_equal []
      end
    end

    it "sets a release against the newest one before it held whole" do
      Dir.mktmpdir do |directory|
        _older, cut_short = two_releases(directory)
        whole_release(directory, Date.new(2026, 11, 11), newer_files)
        File.truncate(File.join(cut_short.directory, 'public_split_11_20.zip'), 10)
        pending = DataGovAu::ABR::Comparison.pending(config_in(directory))
        _(pending.collect{|comparison| [comparison.older.to_s, comparison.newer.to_s]}).must_equal [['20261028', '20261111']]
      end
    end
  end
end
