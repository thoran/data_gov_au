# DataGovAu/AsicCompanies.rb
# DataGovAu::AsicCompanies

# Description: ASIC's weekly snapshot of its company register, fetched from data.gov.au and kept a release a week.

require_relative './AsicCompanies/Config'
require_relative './AsicCompanies/Error'
require_relative './AsicCompanies/ExtractDate'
require_relative './AsicCompanies/Extract'
require_relative './AsicCompanies/Fetch'
require_relative './AsicCompanies/Parser'
require_relative './AsicCompanies/Release'

module DataGovAu
  module AsicCompanies
    # The dataset's name in the catalogue, of which this module's name is the camel-cased form.
    DATASET = 'asic-companies'

    # Required of anything which leaves the machine, the register being published under CC BY 3.0 AU.
    ATTRIBUTION = 'Contains data sourced from the Australian Securities and Investments Commission, used under CC BY 3.0 AU.'
  end
end
