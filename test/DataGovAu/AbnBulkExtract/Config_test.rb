# test/DataGovAu/AbnBulkExtract/Config_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::Config do
  describe "the catalogue's settings" do
    it "default to the catalogue's" do
      config = DataGovAu::AbnBulkExtract::Config.new
      _(config.api_url).must_equal DataGovAu::Catalogue::API_URL
      _(config.user_agent).must_equal "data_gov_au/#{DataGovAu::VERSION}"
    end

    it "take what is given over the defaults" do
      config = DataGovAu::AbnBulkExtract::Config.new(user_agent: 'data_gov_au (mine)', api_url: 'https://example.org/api/3/action')
      _(config.user_agent).must_equal 'data_gov_au (mine)'
      _(config.api_url).must_equal 'https://example.org/api/3/action'
    end

    it "take what is set in a block" do
      _(DataGovAu::AbnBulkExtract::Config.new{|c| c.user_agent = 'data_gov_au (mine)'}.user_agent).must_equal 'data_gov_au (mine)'
    end

    it "take what is set over the defaults after it is made" do
      config = DataGovAu::AbnBulkExtract::Config.new
      config.api_url = 'https://example.org/api/3/action'
      _(config.api_url).must_equal 'https://example.org/api/3/action'
    end
  end

  describe "the extract's directory" do
    it "has no default, and is named as missing where it is first wanted" do
      config = DataGovAu::AbnBulkExtract::Config.new
      error = _(->{config.releases_directory}).must_raise ArgumentError
      _(error.message).must_equal 'directory is missing.'
    end

    it "is expanded" do
      _(DataGovAu::AbnBulkExtract::Config.new(directory: '~/abn-bulk-extract').directory).must_equal File.join(Dir.home, 'abn-bulk-extract')
    end

    it "holds releases directly beneath it, adding no directory of its own above them" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        _(config.directory).must_equal directory
        _(config.releases_directory).must_equal File.join(directory, 'releases')
      end
    end

    it "is followed where it is set again" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        config.directory = File.join(directory, 'elsewhere')
        _(config.releases_directory).must_equal File.join(directory, 'elsewhere', 'releases')
      end
    end
  end

  it "refuses a setting it does not take" do
    _(->{DataGovAu::AbnBulkExtract::Config.new(keep_releases: 6)}).must_raise ArgumentError
  end
end
