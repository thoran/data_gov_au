# test/DataGovAu/Dataset_test.rb

require_relative '../helper'

describe DataGovAu::Dataset do
  it "reports what the catalogue says of it" do
    _(dataset.name).must_equal 'abn-bulk-extract'
    _(dataset.title).must_equal 'ABN Bulk Extract'
    _(dataset.organisation).must_equal 'Australian Business Register'
    _(dataset.licence).must_equal 'Creative Commons Attribution 3.0 Australia'
  end

  # CKAN's times carry no zone and are UTC, so read as local they would be wrong by the offset.
  it "reads its modified time as UTC" do
    _(dataset.modified_at).must_equal Time.utc(2026, 10, 27, 21, 41, 0, 366366)
  end

  it "gives its resources in the catalogue's order" do
    _(dataset.resources.collect(&:filename)).must_equal ['bulkextract.xsd', 'public_split_1_10.zip']
  end

  it "gives no resources where the catalogue lists none" do
    stub_package('abn-bulk-extract', {'success' => true, 'result' => package.merge('resources' => nil)})
    _(DataGovAu::Catalogue.new.dataset('abn-bulk-extract').resources).must_equal []
  end

  it "gives up its entry as the catalogue gave it" do
    _(dataset.to_h).must_equal package
  end
end
