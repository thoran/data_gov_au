# test/DataGovAu/AsicCompanies/ExtractDate_test.rb

require_relative './helper'

describe DataGovAu::AsicCompanies::ExtractDate do
  describe "a zip whose first file is dated" do
    it "takes the date its first file was written" do
      _(DataGovAu::AsicCompanies::ExtractDate.new(asic_zip_header).date).must_equal Date.new(2026, 11, 24)
    end

    # The name is for the month, and would give every release of November the same name.
    it "takes the date from the zip and not from the name of the file inside" do
      _(DataGovAu::AsicCompanies::ExtractDate.new(asic_zip_header('COMPANY_202611.csv', date: Date.new(2026, 11, 3))).date).must_equal Date.new(2026, 11, 3)
    end

    it "takes the name of that file" do
      _(DataGovAu::AsicCompanies::ExtractDate.new(asic_zip_header).member_name).must_equal 'COMPANY_202611.csv'
    end
  end

  describe "what it will not date" do
    it "stops where what was read does not begin a zip" do
      _(->{DataGovAu::AsicCompanies::ExtractDate.new('not a zip at all').date}).must_raise DataGovAu::AsicCompanies::ExtractUndated
    end

    it "stops where what was read stops within the header" do
      _(->{DataGovAu::AsicCompanies::ExtractDate.new(asic_zip_header[0, 20]).date}).must_raise DataGovAu::AsicCompanies::ExtractUndated
    end

    # A zip written without a date carries zeros, which would otherwise come out as a day which does not exist.
    it "stops where the zip gives no date" do
      _(->{DataGovAu::AsicCompanies::ExtractDate.new(asic_zip_header(packed_date: 0)).date}).must_raise DataGovAu::AsicCompanies::ExtractUndated
    end

    it "stops upon nothing at all" do
      _(->{DataGovAu::AsicCompanies::ExtractDate.new('').date}).must_raise DataGovAu::AsicCompanies::ExtractUndated
    end
  end
end
