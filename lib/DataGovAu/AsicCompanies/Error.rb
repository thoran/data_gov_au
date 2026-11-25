# DataGovAu/AsicCompanies/Error.rb
# DataGovAu::AsicCompanies::ExtractUndated

require_relative '../Error'

module DataGovAu
  module AsicCompanies
    # The zip did not date the file it holds, so the release cannot be named.
    class ExtractUndated < Error; end
  end
end
