# test/DataGovAu/ABR/Config_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Config do
  describe "the catalogue's settings" do
    it "default to the catalogue's" do
      config = DataGovAu::ABR::Config.new
      _(config.api_url).must_equal DataGovAu::Catalogue::API_URL
      _(config.user_agent).must_equal "data_gov_au/#{DataGovAu::VERSION}"
    end

    it "take what is given over the defaults" do
      config = DataGovAu::ABR::Config.new(user_agent: 'data_gov_au (mine)', api_url: 'https://example.org/api/3/action')
      _(config.user_agent).must_equal 'data_gov_au (mine)'
      _(config.api_url).must_equal 'https://example.org/api/3/action'
    end

    it "take what is set in a block" do
      _(DataGovAu::ABR::Config.new{|c| c.user_agent = 'data_gov_au (mine)'}.user_agent).must_equal 'data_gov_au (mine)'
    end

    it "take what is set over the defaults after it is made" do
      config = DataGovAu::ABR::Config.new
      config.api_url = 'https://example.org/api/3/action'
      _(config.api_url).must_equal 'https://example.org/api/3/action'
    end
  end

  describe "the data directory" do
    it "has no default, and is named as missing where it is first wanted" do
      config = DataGovAu::ABR::Config.new
      error = _(->{config.releases_directory}).must_raise ArgumentError
      _(error.message).must_equal 'data_directory is missing.'
    end

    it "is expanded" do
      _(DataGovAu::ABR::Config.new(data_directory: '~/data_gov_au').data_directory).must_equal File.join(Dir.home, 'data_gov_au')
    end

    it "holds releases in a directory of the extract's own" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        _(config.directory).must_equal File.join(directory, 'abr')
        _(config.releases_directory).must_equal File.join(directory, 'abr', 'releases')
      end
    end

    it "is followed where it is set again" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        config.data_directory = File.join(directory, 'elsewhere')
        _(config.releases_directory).must_equal File.join(directory, 'elsewhere', 'abr', 'releases')
      end
    end
  end

  it "refuses a setting it does not take" do
    _(->{DataGovAu::ABR::Config.new(keep_releases: 6)}).must_raise ArgumentError
  end
end
