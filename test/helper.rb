# test/helper.rb

lib_dir = File.expand_path(File.join(__FILE__, '..', '..', 'lib'))
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

# webmock's http_rb adapter's require 'http' finds thoran's http.rb gem, takes
# HTTP::VERSION for the http gem's, and crashes trying to monkey-patch an
# HTTP::Client which isn't there. The same workaround as http.rb's own suite.
def skip_webmocks_http_rb_adapter
  gem 'webmock'

  $LOADED_FEATURES << File.join(
    Gem.loaded_specs['webmock'].full_gem_path,
    'lib/webmock/http_lib_adapters/http_rb_adapter.rb'
  )
end

skip_webmocks_http_rb_adapter

require 'json'
require 'minitest/autorun'
require 'minitest/spec'
require 'tmpdir'
require 'webmock/minitest'

require 'data_gov_au'

PACKAGE_SHOW_URL = "#{DataGovAu::Catalogue::API_URL}/package_show"

def resource_entry(name, filename, format, last_modified, size)
  {
    'name' => name,
    'format' => format,
    'size' => size,
    'last_modified' => last_modified,
    'url' => "https://data.gov.au/data/dataset/abc/resource/def/download/#{filename}",
  }
end

# A package_show result shaped as data.gov.au's.
def package(resources: nil)
  {
    'name' => 'abn-bulk-extract',
    'title' => 'ABN Bulk Extract',
    'organization' => {'name' => 'australian-business-register', 'title' => 'Australian Business Register'},
    'license_title' => 'Creative Commons Attribution 3.0 Australia',
    'metadata_modified' => '2026-10-27T21:41:00.366366',
    'resources' => resources || default_resources,
  }
end

def default_resources
  [
    resource_entry('Bulk Extract Schema', 'bulkextract.xsd', 'XML', '2023-01-19T00:00:00', 12866),
    resource_entry('ABN Bulk Extract Part 1', 'public_split_1_10.zip', 'ZIP', '2026-10-27T21:39:23.580175', 40),
  ]
end

def stub_package(name = 'abn-bulk-extract', body = {'success' => true, 'result' => package}, status: 200, url: PACKAGE_SHOW_URL)
  stub_request(:get, "#{url}?id=#{name}").to_return(status: status, body: JSON.generate(body))
end

def dataset(catalogue = DataGovAu::Catalogue.new)
  stub_package
  catalogue.dataset('abn-bulk-extract')
end
