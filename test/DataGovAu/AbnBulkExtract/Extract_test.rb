# test/DataGovAu/AbnBulkExtract/Extract_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::Extract do
  describe "reading out of the zips" do
    it "yields the records of a zipped file" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28))
        _(DataGovAu::AbnBulkExtract::Extract.new(release).each_record.to_a.length).must_equal 9
      end
    end

    it "yields each file as its own parser" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28), {
          'public_split_1_10.zip' => ['20261028_Public01.xml', '20261028_Public02.xml'],
        })
        reached = []
        DataGovAu::AbnBulkExtract::Extract.new(release).each_file{|member, parser| reached << [member, parser.each_record{}.records_parsed]}
        _(reached).must_equal [['20261028_Public01.xml', 9], ['20261028_Public02.xml', 9]]
      end
    end

    it "yields each file as its name and the text inflated" do
      Dir.mktmpdir do |directory|
        release = whole_release(directory, Date.new(2026, 10, 28), older_files)
        members = DataGovAu::AbnBulkExtract::Extract.new(release).each_member.collect{|name, io| [name, io.read]}
        _(members).must_equal older_files.values.inject(:merge).to_a
      end
    end

    it "reads across both zips of a release" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28), {
          'public_split_1_10.zip' => ['20261028_Public01.xml'],
          'public_split_11_20.zip' => ['20261028_Public11.xml'],
        })
        _(DataGovAu::AbnBulkExtract::Extract.new(release).each_record.to_a.length).must_equal 18
      end
    end
  end

  # The records are one stream sorted by ABN and the zips cut across it, so public_split_11_20 sorts before public_split_1_10 while holding the later half. Taking the order from the zips' own names would read the halves back to front.
  describe "the order it reads in" do
    it "takes its order from the sequence numbers the files carry, not from the zips' names" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28), {
          'public_split_11_20.zip' => ['20261028_Public11.xml', '20261028_Public20.xml'],
          'public_split_1_10.zip' => ['20261028_Public01.xml', '20261028_Public10.xml'],
        })
        names = DataGovAu::AbnBulkExtract::Extract.new(release).members.collect{|_path, name| name}
        _(names).must_equal [
          '20261028_Public01.xml',
          '20261028_Public10.xml',
          '20261028_Public11.xml',
          '20261028_Public20.xml',
        ]
      end
    end

    # The naming has varied once already, the files having been yyyymmddPublicNN.xml before. Were the padding dropped, the characters alone would put file 2 after file 19 and the records would stop being one ascending run without anything in them saying so.
    it "takes it from the numbers rather than the padding" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28), {
          'public_split_11_20.zip' => ['20261028_Public11.xml', '20261028_Public2.xml'],
          'public_split_1_10.zip' => ['20261028_Public1.xml', '20261028_Public10.xml'],
        })
        names = DataGovAu::AbnBulkExtract::Extract.new(release).members.collect{|_path, name| name}
        _(names).must_equal [
          '20261028_Public1.xml',
          '20261028_Public2.xml',
          '20261028_Public10.xml',
          '20261028_Public11.xml',
        ]
      end
    end
  end

  describe "a release with nothing in it" do
    it "stops rather than reporting an empty extract" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 28))
        release.create_directory
        _(->{DataGovAu::AbnBulkExtract::Extract.new(release).each_file{}}).must_raise DataGovAu::AbnBulkExtract::NothingToParse
      end
    end
  end

  describe "without a block" do
    it "gives back an enumerator" do
      Dir.mktmpdir do |directory|
        release = release_holding(directory, Date.new(2026, 10, 28))
        _(DataGovAu::AbnBulkExtract::Extract.new(release).each_record).must_be_kind_of Enumerator
      end
    end
  end
end
