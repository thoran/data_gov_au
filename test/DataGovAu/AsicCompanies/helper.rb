# test/DataGovAu/AsicCompanies/helper.rb

require_relative '../../helper'
require 'DataGovAu/AsicCompanies'

ASIC_MEMBER = 'COMPANY_202611.csv'

# The register's three resources as data.gov.au lists them: the help file, the register unzipped, and the register zipped.
def asic_resources
  [
    resource_entry('Company Dataset - Help File', 'company-dataset-help-file.pdf', 'PDF', '2025-07-11T05:11:45.416035', 30),
    resource_entry('Company Dataset - Current', 'company_202611.csv', 'CSV', '2026-11-23T13:53:40.097462', 200),
    resource_entry('Company Dataset - Current', 'company_202611.zip', 'ZIP', '2026-11-23T13:53:52.017496', 40),
  ]
end

# A package_show result shaped as data.gov.au's for the register.
def asic_package(resources: asic_resources)
  {
    'name' => 'asic-companies',
    'title' => 'ASIC - Company Dataset',
    'organization' => {'name' => 'australian-securities-and-investments-commission-asic', 'title' => 'Australian Securities and Investments Commission (ASIC)'},
    'license_title' => 'Creative Commons Attribution 3.0 Australia',
    'metadata_modified' => '2026-11-23T14:26:20.873629',
    'resources' => resources,
  }
end

def stub_asic_catalogue(body = {'success' => true, 'result' => asic_package})
  stub_package(DataGovAu::AsicCompanies::DATASET, body)
end

def asic_config_in(directory, **settings)
  DataGovAu::AsicCompanies::Config.new(directory: directory, **settings)
end

def asic_zip_resource(resources = asic_resources)
  resources.detect{|resource| resource['format'] == 'ZIP'}
end

# The start of a zip: its first local file header, carrying when its first file was written in MS-DOS form, and that file's name. A signature, the version, flags and method, the time and date, twelve bytes which do not matter here, the name's length, the extra field's length, and the name.
def asic_zip_header(name = ASIC_MEMBER, date: Date.new(2026, 11, 24), hour: 0, minute: 53, packed_date: nil)
  packed_date ||= ((date.year - 1980) << 9) | (date.month << 5) | date.day
  packed_time = (hour << 11) | (minute << 5)
  "PK\x03\x04".b + ("\x00".b * 6) + [packed_time, packed_date].pack('vv') + ("\x00".b * 12) + [name.bytesize, 0].pack('vv') + name.b
end

# The range request by which a release is named, answered as data.gov.au answers it.
def stub_asic_peek(resource = asic_zip_resource, header = asic_zip_header)
  stub_request(:get, resource['url']).
    with(headers: {'Range' => "bytes=0-#{DataGovAu::AsicCompanies::ExtractDate::PEEK_LENGTH - 1}"}).
      to_return(status: 206, body: header)
end

# Rows from the register of 20261124: a company under a former name and then its current one, a company deregistered with no ABN, and a name holding quotes.
def asic_rows
  [
    ['LOVINI HOLDINGS PTY LTD', '000000019', 'APTY', 'LMSH', 'PROP', 'REGD', '08/01/1990', '', 'NSW', '46869041', '', '', '89000000019', 'MONAKA PTY LTD', '28/01/2016'],
    ['MONAKA PTY LTD', '000000019', 'APTY', 'LMSH', 'PROP', 'REGD', '08/01/1990', '', 'NSW', '46869041', '', 'Y', '89000000019', '', ''],
    ['COMMONWEALTH PORTLAND CEMENT COMPANY PTY LTD', '000000260', 'APTY', 'LMSH', 'PROP', 'DRGD', '27/05/1907', '13/03/2026', 'NSW', '00010535', '', 'Y', '0', '', ''],
    ['TUMUT BOWLING & RECREATION CLUB LTD. TRADING AS "CLUB TUMUT" LTD', '001001074', 'APUB', 'LMGT', 'ULSN', 'REGD', '12/05/1972', '', 'NSW', '14592147', '', 'Y', '62001001074', '', ''],
  ]
end

# The register as ASIC writes it: a byte-order mark, then the header and each row tab-separated, every line ending CRLF.
def asic_register_text(rows = asic_rows, header: DataGovAu::AsicCompanies::Parser::COLUMNS.keys)
  "﻿" + ([header] + rows).collect{|fields| fields.join("\t") + "\r\n"}.join
end

# A release holding the register zipped, as the fetch leaves one.
def asic_release_holding(directory, date = Date.new(2026, 11, 24), text = asic_register_text)
  release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), date)
  release.create_directory
  Zip::File.open(File.join(release.directory, 'company_202611.zip'), create: true) do |zip|
    zip.get_output_stream(ASIC_MEMBER){|io| io.write(text)}
  end
  release
end
