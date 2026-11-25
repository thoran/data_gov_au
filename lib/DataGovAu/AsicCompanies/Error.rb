# DataGovAu/AsicCompanies/Error.rb
# DataGovAu::AsicCompanies::ExtractUndated, NothingToParse, RegisterMalformed

require_relative '../Error'

module DataGovAu
  module AsicCompanies
    # The zip did not date the file it holds, so the release cannot be named.
    class ExtractUndated < Error; end

    # No release is held, or the one held has no zip file, so there is nothing to parse.
    class NothingToParse < Error; end

    # The register is not laid out as ASIC writes it: its header names other columns, or a row has other than one field for each.
    class RegisterMalformed < Error; end
  end
end
