require_relative '../helper'
require 'DataGovAu/ABR'

describe "DataGovAu::ABR" do
  def with_deprecation_warnings
    shown = Warning[:deprecated]
    Warning[:deprecated] = true
    yield
  ensure
    Warning[:deprecated] = shown
  end

  it "is the bulk extract's module by its old name" do
    _(DataGovAu.const_get(:ABR)).must_be_same_as DataGovAu::AbnBulkExtract
  end

  it "warns that it is deprecated where deprecation warnings are shown" do
    with_deprecation_warnings do
      _{DataGovAu::ABR}.must_output nil, /DataGovAu::ABR is deprecated/
    end
  end
end
