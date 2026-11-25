# test/DataGovAu/AsicCompanies/Fetch_test.rb

require_relative './helper'

describe DataGovAu::AsicCompanies::Fetch do
  describe "what it finds in the catalogue" do
    before do
      stub_asic_catalogue
    end

    it "takes the zipped register" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).extract_resource.filename).must_equal 'company_202611.zip'
      end
    end

    it "takes the help file alongside it" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).supporting_resources.collect(&:format)).must_equal ['PDF']
      end
    end

    # The zip holds the register already, at a fifth of the size.
    it "leaves out the register unzipped" do
      Dir.mktmpdir do |directory|
        formats = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).resources.collect(&:format)
        _(formats).must_equal ['ZIP', 'PDF']
      end
    end
  end

  describe "the date it reports the catalogue modified" do
    it "is the zipped register's last_modified" do
      stub_asic_catalogue
      Dir.mktmpdir do |directory|
        _(DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).modified_on).must_equal Date.new(2026, 11, 23)
      end
    end
  end

  describe "a catalogue holding no zipped register" do
    it "stops rather than naming a release it cannot date" do
      resources = asic_resources.reject{|resource| resource['format'] == 'ZIP'}
      stub_asic_catalogue({'success' => true, 'result' => asic_package(resources: resources)})
      Dir.mktmpdir do |directory|
        _(->{DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).release}).must_raise DataGovAu::CatalogueUnavailable
      end
    end
  end

  describe "the request it makes of the catalogue" do
    it "identifies itself as its config says" do
      Dir.mktmpdir do |directory|
        stub = stub_request(:get, "#{PACKAGE_SHOW_URL}?id=asic-companies").
          with(headers: {'User-Agent' => 'data_gov_au (mine)'}).
            to_return(status: 200, body: JSON.generate({'success' => true, 'result' => asic_package}))
        DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory, user_agent: 'data_gov_au (mine)')).dataset
        assert_requested(stub)
      end
    end
  end

  describe "the release it works on" do
    before do
      stub_asic_catalogue
      stub_asic_peek
    end

    # The catalogue reports its record modified on the 23rd in UTC, while the zip dates the register the 24th in Sydney, and it is the zip which names the release.
    it "is dated by the zip and not by the catalogue" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory))
        _(fetch.release.date).must_equal Date.new(2026, 11, 24)
        _(fetch.modified_on).must_equal Date.new(2026, 11, 23)
      end
    end

    it "names its directory for the date the zip carries" do
      Dir.mktmpdir do |directory|
        _(File.basename(DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).release.directory)).must_equal '20261124'
      end
    end
  end

  describe "a first run" do
    before do
      stub_asic_catalogue
      stub_downloads(asic_resources.reject{|resource| resource['format'] == 'CSV'})
      stub_asic_peek
    end

    it "retrieves the zip and the help file, and records the catalogue entry" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory))
        fetch.perform
        _(fetch.release.complete?).must_equal true
        _(Dir.children(fetch.release.directory).sort).must_equal ['catalogue.json', 'company-dataset-help-file.pdf', 'company_202611.zip']
        _(JSON.parse(File.read(fetch.release.catalogue_path))['name']).must_equal 'asic-companies'
      end
    end

    it "yields each resource as it is reached" do
      Dir.mktmpdir do |directory|
        reached = []
        DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).perform{|resource| reached << resource.filename}
        _(reached).must_equal ['company_202611.zip', 'company-dataset-help-file.pdf']
      end
    end
  end

  # One download per weekly release: a second run in the same week is to cost nothing but the catalogue call and the range request which names the release.
  describe "a second run in the same week" do
    it "retrieves nothing" do
      Dir.mktmpdir do |directory|
        kept = asic_resources.reject{|resource| resource['format'] == 'CSV'}
        stub_asic_catalogue
        stub_downloads(kept)
        stub_asic_peek
        DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory)).perform
        WebMock.reset!
        stub_asic_catalogue
        kept.each{|resource| stub_request(:get, resource['url']).to_raise('a held file was retrieved again')}
        stub_asic_peek
        fetch = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory))
        fetch.perform
        _(fetch.release.complete?).must_equal true
      end
    end
  end

  describe "a run after a download was cut short" do
    it "retrieves only what is missing" do
      Dir.mktmpdir do |directory|
        stub_asic_catalogue
        stub_downloads(asic_resources.reject{|resource| resource['format'] == 'CSV'})
        stub_asic_peek
        fetch = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory))
        fetch.perform
        zip = fetch.extract_resource
        File.truncate(fetch.release.path_for(zip), 10)
        WebMock.reset!
        stub_asic_catalogue
        stub_request(:get, zip.url).to_return(status: 200, body: 'x' * zip.size)
        stub_asic_peek
        later = DataGovAu::AsicCompanies::Fetch.new(asic_config_in(directory))
        later.perform
        # The zip is both peeked at, by range, to name the release, and retrieved whole: it is the whole which is to happen once.
        assert_requested(:get, zip.url, times: 1){|request| !request.headers.key?('Range')}
        _(later.release.complete?).must_equal true
      end
    end
  end
end
