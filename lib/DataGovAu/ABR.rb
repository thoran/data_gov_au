# DataGovAu/ABR.rb
# DataGovAu::ABR

# Description: The Australian Business Register's weekly bulk extract: fetched from data.gov.au, stored locally, and queried for businesses which have newly appeared.

require_relative './ABR/Config'
require_relative './ABR/Error'
require_relative './ABR/ExtractDate'
require_relative './ABR/Fetch'
require_relative './ABR/Release'

module DataGovAu
  module ABR
    # Required of anything which leaves the machine, the extract being published under CC BY 3.0 AU.
    ATTRIBUTION = 'Contains data sourced from the Australian Business Register, used under CC BY 3.0 AU.'
  end
end
