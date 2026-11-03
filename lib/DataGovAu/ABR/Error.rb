# DataGovAu/ABR/Error.rb
# DataGovAu::ABR::ExtractUndated, NothingToParse

require_relative '../Error'

module DataGovAu
  module ABR
    # A zip did not name the date of the extract it holds, so the release cannot be named.
    class ExtractUndated < Error; end

    # No release is held, or the one held has no zip files, so there is nothing to parse.
    class NothingToParse < Error; end
  end
end
