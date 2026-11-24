# DataGovAu/AbnBulkExtract.rb
# DataGovAu::AbnBulkExtract

# Description: The Australian Business Register's weekly bulk extract: fetched from data.gov.au, stored locally, and queried for businesses which have newly appeared.

require_relative './AbnBulkExtract/Comparison'
require_relative './AbnBulkExtract/CompressedFile'
require_relative './AbnBulkExtract/Config'
require_relative './AbnBulkExtract/Delta'
require_relative './AbnBulkExtract/Error'
require_relative './AbnBulkExtract/Extract'
require_relative './AbnBulkExtract/ExtractDate'
require_relative './AbnBulkExtract/Fetch'
require_relative './AbnBulkExtract/Frame'
require_relative './AbnBulkExtract/Lines'
require_relative './AbnBulkExtract/Parser'
require_relative './AbnBulkExtract/Rebuild'
require_relative './AbnBulkExtract/Release'

module DataGovAu
  module AbnBulkExtract
    # The dataset's name in the catalogue, of which this module's name is the camel-cased form.
    DATASET = 'abn-bulk-extract'

    # Required of anything which leaves the machine, the extract being published under CC BY 3.0 AU.
    ATTRIBUTION = 'Contains data sourced from the Australian Business Register, used under CC BY 3.0 AU.'
  end
end
