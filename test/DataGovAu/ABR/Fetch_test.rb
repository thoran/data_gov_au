# test/DataGovAu/ABR/Fetch_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Fetch do
  describe "what it finds in the catalogue" do
    before do
      stub_catalogue
    end

    it "takes the zipped halves of the extract, in a settled order" do
      Dir.mktmpdir do |directory|
        names = DataGovAu::ABR::Fetch.new(config_in(directory)).extract_resources.collect(&:name)
        _(names).must_equal ['ABN Bulk Extract Part 1', 'ABN Bulk Extract Part 2 ']
      end
    end

    it "takes the schema and readme as supporting resources" do
      Dir.mktmpdir do |directory|
        formats = DataGovAu::ABR::Fetch.new(config_in(directory)).supporting_resources.collect(&:format)
        _(formats.sort).must_equal ['PDF', 'XML']
      end
    end

    it "covers the extract's halves and the schema and readme alongside them" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::ABR::Fetch.new(config_in(directory)).resources.length).must_equal 4
      end
    end
  end

  describe "the date it reports the catalogue modified" do
    it "is the latest last_modified among the extract's own halves" do
      stub_catalogue
      Dir.mktmpdir do |directory|
        _(DataGovAu::ABR::Fetch.new(config_in(directory)).modified_on).must_equal Date.new(2026, 10, 27)
      end
    end

    # The schema and the readme are republished on their own schedule, and would date a release wrongly were they counted.
    it "ignores a supporting resource modified later than the extract" do
      resources = [
        extract_resource('ABN Bulk Extract Part 1', 'public_split_1_10.zip', '2026-10-27T21:39:23', 40),
        supporting_resource('Readme', 'abnlookupbulkextractreadme.pdf', 'PDF', '2026-11-30T00:00:00', 30),
      ]
      stub_catalogue({'success' => true, 'result' => package(resources: resources)})
      Dir.mktmpdir do |directory|
        _(DataGovAu::ABR::Fetch.new(config_in(directory)).modified_on).must_equal Date.new(2026, 10, 27)
      end
    end

    it "stops where the catalogue reports no extract files" do
      resources = [supporting_resource('Readme', 'readme.pdf', 'PDF', '2026-10-27T00:00:00', 30)]
      stub_catalogue({'success' => true, 'result' => package(resources: resources)})
      Dir.mktmpdir do |directory|
        _(->{DataGovAu::ABR::Fetch.new(config_in(directory)).modified_on}).must_raise DataGovAu::CatalogueUnavailable
      end
    end
  end

  describe "the request it makes of the catalogue" do
    it "identifies itself as its config says" do
      Dir.mktmpdir do |directory|
        stub = stub_request(:get, "#{PACKAGE_SHOW_URL}?id=abn-bulk-extract").
          with(headers: {'User-Agent' => 'data_gov_au (mine)'}).
            to_return(status: 200, body: JSON.generate({'success' => true, 'result' => package}))
        DataGovAu::ABR::Fetch.new(config_in(directory, user_agent: 'data_gov_au (mine)')).dataset
        assert_requested(stub)
      end
    end
  end

  describe "the release it works on" do
    before do
      stub_catalogue
      stub_peek(first_extract_resource)
    end

    # The catalogue reports its record modified on the 27th while the extract names itself the 28th, and it is the extract which names the release.
    it "is dated by the extract and not by the catalogue" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        _(fetch.release.date).must_equal Date.new(2026, 10, 28)
        _(fetch.modified_on).must_equal Date.new(2026, 10, 27)
      end
    end

    it "names its directory for the date the extract carries" do
      Dir.mktmpdir do |directory|
        _(File.basename(DataGovAu::ABR::Fetch.new(config_in(directory)).release.directory)).must_equal '20261028'
      end
    end
  end

  describe "a catalogue holding no extract" do
    it "stops rather than naming a release it cannot date" do
      resources = [supporting_resource('Readme', 'readme.pdf', 'PDF', '2026-10-27T00:00:00', 30)]
      stub_catalogue({'success' => true, 'result' => package(resources: resources)})
      Dir.mktmpdir do |directory|
        _(->{DataGovAu::ABR::Fetch.new(config_in(directory)).release}).must_raise DataGovAu::CatalogueUnavailable
      end
    end
  end

  describe "a first run" do
    before do
      stub_catalogue
      stub_downloads(default_resources)
      stub_peek(first_extract_resource)
    end

    it "retrieves every file" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        fetch.perform
        _(fetch.release.complete?).must_equal true
        _(Dir.children(fetch.release.directory).sort).must_equal [
          'abnlookupbulkextractreadme.pdf',
          'bulkextract.xsd',
          'catalogue.json',
          'public_split_11_20.zip',
          'public_split_1_10.zip',
        ].sort
      end
    end

    it "records where the release came from" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        fetch.perform
        _(JSON.parse(File.read(fetch.release.catalogue_path))['name']).must_equal 'abn-bulk-extract'
      end
    end

    it "yields each resource as it is reached" do
      Dir.mktmpdir do |directory|
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        reached = []
        fetch.perform{|resource| reached << resource.filename}
        _(reached.length).must_equal 4
      end
    end
  end

  # One download per weekly release: a second run in the same week is to cost nothing but the catalogue call and the range request which names the release.
  describe "a second run in the same week" do
    it "retrieves nothing" do
      Dir.mktmpdir do |directory|
        stub_catalogue
        stub_downloads(default_resources)
        stub_peek(first_extract_resource)
        DataGovAu::ABR::Fetch.new(config_in(directory)).perform
        WebMock.reset!
        stub_catalogue
        default_resources.each{|resource| stub_request(:get, resource['url']).to_raise('a held file was retrieved again')}
        stub_peek(first_extract_resource)
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        fetch.perform
        _(fetch.release.complete?).must_equal true
      end
    end
  end

  describe "a run after a download was cut short" do
    it "retrieves only what is missing" do
      Dir.mktmpdir do |directory|
        stub_catalogue
        stub_downloads(default_resources)
        stub_peek(first_extract_resource)
        fetch = DataGovAu::ABR::Fetch.new(config_in(directory))
        fetch.perform
        cut_short = fetch.resources.find{|resource| resource.filename == 'public_split_11_20.zip'}
        File.delete(fetch.release.path_for(cut_short))
        WebMock.reset!
        stub_catalogue
        retried = stub_request(:get, cut_short.url).to_return(status: 200, body: 'x' * cut_short.size)
        stub_peek(first_extract_resource)
        later = DataGovAu::ABR::Fetch.new(config_in(directory))
        later.perform
        assert_requested(retried, times: 1)
        _(later.release.complete?).must_equal true
      end
    end
  end
end
