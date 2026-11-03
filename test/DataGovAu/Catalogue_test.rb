# test/DataGovAu/Catalogue_test.rb

require_relative '../helper'

describe DataGovAu::Catalogue do
  describe "the dataset it finds" do
    it "is the one package_show gives for the name asked" do
      stub_package
      _(DataGovAu::Catalogue.new.dataset('abn-bulk-extract').title).must_equal 'ABN Bulk Extract'
    end

    it "is asked for by id as readily as by name" do
      id = '5bd7fcab-e315-42cb-8daf-50b7efc2027e'
      stub_package(id)
      _(DataGovAu::Catalogue.new.dataset(id).name).must_equal 'abn-bulk-extract'
    end
  end

  describe "the request it makes" do
    it "identifies itself" do
      stub = stub_request(:get, "#{PACKAGE_SHOW_URL}?id=abn-bulk-extract").
        with(headers: {'User-Agent' => "data_gov_au/#{DataGovAu::VERSION}"}).
          to_return(status: 200, body: JSON.generate({'success' => true, 'result' => package}))
      DataGovAu::Catalogue.new.dataset('abn-bulk-extract')
      assert_requested(stub)
    end

    it "identifies itself as it is told to" do
      stub = stub_request(:get, "#{PACKAGE_SHOW_URL}?id=abn-bulk-extract").
        with(headers: {'User-Agent' => 'mine/1.0'}).
          to_return(status: 200, body: JSON.generate({'success' => true, 'result' => package}))
      DataGovAu::Catalogue.new(user_agent: 'mine/1.0').dataset('abn-bulk-extract')
      assert_requested(stub)
    end

    it "goes to the API it is told to" do
      stub = stub_package(url: 'https://ckan.example/api/3/action/package_show')
      DataGovAu::Catalogue.new(api_url: 'https://ckan.example/api/3/action').dataset('abn-bulk-extract')
      assert_requested(stub)
    end

    it "goes to the API it is set to after it is made" do
      stub = stub_package(url: 'https://ckan.example/api/3/action/package_show')
      catalogue = DataGovAu::Catalogue.new
      catalogue.api_url = 'https://ckan.example/api/3/action'
      catalogue.dataset('abn-bulk-extract')
      assert_requested(stub)
    end

    it "identifies itself as a block tells it to" do
      stub = stub_request(:get, "#{PACKAGE_SHOW_URL}?id=abn-bulk-extract").
        with(headers: {'User-Agent' => 'mine/1.0'}).
          to_return(status: 200, body: JSON.generate({'success' => true, 'result' => package}))
      DataGovAu::Catalogue.new{|c| c.user_agent = 'mine/1.0'}.dataset('abn-bulk-extract')
      assert_requested(stub)
    end
  end

  describe "when the catalogue cannot be read" do
    it "stops upon a failed response" do
      stub_package('abn-bulk-extract', {}, status: 503)
      _(->{DataGovAu::Catalogue.new.dataset('abn-bulk-extract')}).must_raise DataGovAu::CatalogueUnavailable
    end

    # CKAN answers a name it does not know with success false.
    it "stops where the answer reports no success" do
      stub_package('abn-bulk-extract', {'success' => false})
      _(->{DataGovAu::Catalogue.new.dataset('abn-bulk-extract')}).must_raise DataGovAu::CatalogueUnavailable
    end
  end
end
