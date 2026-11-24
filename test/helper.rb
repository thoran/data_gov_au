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
require 'DataGovAu/ABR'

PACKAGE_SHOW_URL = "#{DataGovAu::Catalogue::API_URL}/package_show"
# The extract is dated a day later than the catalogue reports its record modified.
EXTRACT_MEMBER = '20261028_Public01.xml'

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

def extract_resource(name, filename, last_modified, size)
  resource_entry(name, filename, 'ZIP', last_modified, size)
end

def supporting_resource(name, filename, format, last_modified, size)
  resource_entry(name, filename, format, last_modified, size)
end

# The extract's two zipped halves, plus the schema and readme which change on their own schedule.
def default_resources
  [
    supporting_resource('Bulk Extract Schema', 'bulkextract.xsd', 'XML', '2023-01-19T00:00:00', 12866),
    extract_resource('ABN Bulk Extract Part 1', 'public_split_1_10.zip', '2026-10-27T21:39:23.580175', 40),
    extract_resource('ABN Bulk Extract Part 2 ', 'public_split_11_20.zip', '2026-10-27T21:40:59', 40),
    supporting_resource('Readme', 'abnlookupbulkextractreadme.pdf', 'PDF', '2025-07-02T01:59:12', 30),
  ]
end

def stub_package(name = 'abn-bulk-extract', body = {'success' => true, 'result' => package}, status: 200, url: PACKAGE_SHOW_URL)
  stub_request(:get, "#{url}?id=#{name}").to_return(status: status, body: JSON.generate(body))
end

def dataset(catalogue = DataGovAu::Catalogue.new)
  stub_package
  catalogue.dataset('abn-bulk-extract')
end

def resource_from(entry)
  DataGovAu::Resource.new(DataGovAu::Catalogue.new, entry)
end

def fixture_path(name)
  File.join(__dir__, 'fixtures', name)
end

def stub_catalogue(body = {'success' => true, 'result' => package}, status: 200)
  stub_package(DataGovAu::ABR::Fetch::DATASET, body, status: status)
end

def stub_downloads(resources)
  resources.each{|resource| stub_request(:get, resource['url']).to_return(status: 200, body: 'x' * resource['size'])}
end

def config_in(directory, **settings)
  DataGovAu::ABR::Config.new(data_directory: directory, **settings)
end

# The start of a zip: its first local file header, which is enough to name the first file inside. A signature, twenty-two bytes which do not matter here, the name's length, the extra field's length, and the name.
def zip_header(name, declared_length: nil)
  "PK\x03\x04".b + ("\x00".b * 22) + [declared_length || name.bytesize].pack('v') + ("\x00".b * 2) + name.b
end

def first_extract_resource(resources = default_resources)
  resources.select{|resource| resource['format'] == 'ZIP'}.sort_by{|resource| resource['name'].to_s}.first
end

# The range request by which a release is named, answered as data.gov.au answers it: 206, and the first bytes alone. Registered after any whole-body stub for the same resource, webmock preferring the stub registered last.
def stub_peek(resource, name = EXTRACT_MEMBER)
  stub_request(:get, resource['url']).
    with(headers: {'Range' => "bytes=0-#{DataGovAu::ABR::ExtractDate::PEEK_LENGTH - 1}"}).
      to_return(status: 206, body: zip_header(name))
end

# A release on disk as the fetch leaves one: a directory named for the date the extract carries, holding the fixture zipped under the member names given, so that the parser is exercised through rubyzip rather than over a loose file.
def release_holding(directory, date, members = {'public_split_1_10.zip' => ['20261020Public01.xml']})
  release = DataGovAu::ABR::Release.new(config_in(directory), date)
  release.create_directory
  members.each do |zip_name, member_names|
    Zip::File.open(File.join(release.directory, zip_name), create: true) do |zip|
      member_names.each{|member| zip.add(member, fixture_path('20261020Public01.xml'))}
    end
  end
  release
end

def fixture_records
  @fixture_records ||= File.open(fixture_path('20261020Public01.xml'), 'rb'){|file| DataGovAu::ABR::Parser.new(file).each_record.to_a}
end

def fixture_record(abn)
  fixture_records.detect{|record| record[:abn] == abn}
end

# A record as the extract writes one now, on a line of its own.
def record_line(abn, status: 'ACT', name: 'A BUSINESS')
  %Q{<ABR recordLastUpdatedDate="20261020" replaced="N"><ABN status="#{status}" ABNStatusFromDate="20261013">#{abn}</ABN><EntityType><EntityTypeInd>PRV</EntityTypeInd></EntityType><MainEntity><NonIndividualName type="MN"><NonIndividualNameText>#{name}</NonIndividualNameText></NonIndividualName></MainEntity><GST status="NON" GSTStatusFromDate="19000101" /></ABR>}
end

# One XML file as the extract writes one now: a header carrying its sequence number and count, lines of padding, the records a line each with a second carriage return after every hundredth, and the close.
def member_text(sequence, records)
  header = %Q{<?xml version="1.0"?><Transfer error="none"><TransferInfo><FileSequenceNumber>#{sequence}</FileSequenceNumber><RecordCount>#{records.length}</RecordCount><ExtractTime>2026-10-28T12:25:33</ExtractTime></TransferInfo>}
  body = records.each_with_index.collect{|record, index| index.zero? ? record : ((index % 100).zero? ? "\r\r\n" : "\r\n") + record}.join
  header + ((' ' * 40) + "\r\n") * 2 + body + "\r\r\n</Transfer>\r\n"
end

# ABNs eleven digits long, rising.
def abns(count, from = 10_000_000_000)
  (0...count).collect{|index| (from + index * 7).to_s}
end

# A release held whole as the fetch leaves one: its zips, each holding the files given as name and text, and the catalogue entry they were found through, listing each zip at the length written.
def whole_release(directory, date, zips)
  release = DataGovAu::ABR::Release.new(config_in(directory), date)
  release.create_directory
  zips.each do |zip_name, files|
    Zip::File.open(File.join(release.directory, zip_name), create: true) do |zip|
      files.each{|name, text| zip.get_output_stream(name){|stream| stream.write(text)}}
    end
  end
  release.record_catalogue(package(resources: zips.keys.collect{|zip_name| extract_resource(zip_name, zip_name, '2026-10-27T21:39:23', File.size(File.join(release.directory, zip_name)))}))
  release
end

# Two weeks apart. Between them 22222222222 is cancelled, 25000000000 and 66666666666 appear, 55555555555 goes, and 33333333333, unchanged, moves from the first file to the second as the first fills.
def older_files
  {
    'public_split_1_10.zip' => {'20261028_Public01.xml' => member_text(1, [record_line('11111111111'), record_line('22222222222'), record_line('33333333333')])},
    'public_split_11_20.zip' => {'20261028_Public11.xml' => member_text(11, [record_line('44444444444'), record_line('55555555555')])},
  }
end

def newer_files
  {
    'public_split_1_10.zip' => {'20261104_Public01.xml' => member_text(1, [record_line('11111111111'), record_line('22222222222', status: 'CAN'), record_line('25000000000')])},
    'public_split_11_20.zip' => {'20261104_Public11.xml' => member_text(11, [record_line('33333333333'), record_line('44444444444'), record_line('66666666666')])},
  }
end

def two_releases(directory, older = older_files, newer = newer_files)
  [whole_release(directory, Date.new(2026, 10, 28), older), whole_release(directory, Date.new(2026, 11, 4), newer)]
end
