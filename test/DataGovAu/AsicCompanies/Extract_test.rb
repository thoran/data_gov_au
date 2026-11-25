# test/DataGovAu/AsicCompanies/Extract_test.rb

require_relative './helper'

describe DataGovAu::AsicCompanies::Extract do
  it "yields the rows of the zipped register" do
    Dir.mktmpdir do |directory|
      records = DataGovAu::AsicCompanies::Extract.new(asic_release_holding(directory)).each_record.to_a
      _(records.collect{|record| record[:acn]}).must_equal ['000000019', '000000019', '000000260', '001001074']
    end
  end

  it "yields the register as its name and its own parser" do
    Dir.mktmpdir do |directory|
      reached = []
      DataGovAu::AsicCompanies::Extract.new(asic_release_holding(directory)).each_file{|name, parser| reached << [name, parser.each_record{}.records_parsed]}
      _(reached).must_equal [[ASIC_MEMBER, 4]]
    end
  end

  it "stops where the release holds no zip" do
    Dir.mktmpdir do |directory|
      release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24))
      release.create_directory
      _(->{DataGovAu::AsicCompanies::Extract.new(release).each_record.to_a}).must_raise DataGovAu::AsicCompanies::NothingToParse
    end
  end
end
