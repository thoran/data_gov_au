# DataGovAu/ABR/Error.rb
# DataGovAu::ABR::ExtractUndated, ExtractMalformed, RebuildMismatch, NothingToParse

require_relative '../Error'

module DataGovAu
  module ABR
    # A zip did not name the date of the extract it holds, so the release cannot be named.
    class ExtractUndated < Error; end

    # A file of the extract is not laid out as a release must be to be kept as a difference: a record a line, each carrying its ABN, and the ABNs rising throughout.
    class ExtractMalformed < Error; end

    # A release rebuilt from the one before it and its delta did not come out as the files it was made from.
    class RebuildMismatch < Error; end

    # No release is held, or the one held has no zip files, so there is nothing to parse.
    class NothingToParse < Error; end
  end
end
