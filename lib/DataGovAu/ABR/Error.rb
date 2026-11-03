# DataGovAu/ABR/Error.rb
# DataGovAu::ABR::ExtractUndated

require_relative '../Error'

module DataGovAu
  module ABR
    # A zip did not name the date of the extract it holds, so the release cannot be named.
    class ExtractUndated < Error; end
  end
end
