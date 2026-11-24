# test/DataGovAu/AbnBulkExtract/ExtractDate_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::ExtractDate do
  describe "a zip whose first file is named for a date" do
    it "takes the name of that file" do
      _(DataGovAu::AbnBulkExtract::ExtractDate.new(zip_header('20261028_Public01.xml')).member_name).must_equal '20261028_Public01.xml'
    end

    it "takes the date the name begins with" do
      _(DataGovAu::AbnBulkExtract::ExtractDate.new(zip_header('20261028_Public01.xml')).date).must_equal Date.new(2026, 10, 28)
    end

    # The brief had the files named without the separator, and the extract now carries one, so the date alone is read and the rest of the name left alone.
    it "reads the date whether or not a separator follows it" do
      _(DataGovAu::AbnBulkExtract::ExtractDate.new(zip_header('20261028Public01.xml')).date).must_equal Date.new(2026, 10, 28)
    end
  end

  describe "what it will not date" do
    it "stops where what was read does not begin a zip" do
      _(->{DataGovAu::AbnBulkExtract::ExtractDate.new('not a zip at all').date}).must_raise DataGovAu::AbnBulkExtract::ExtractUndated
    end

    it "stops where the first file is not named for a date" do
      _(->{DataGovAu::AbnBulkExtract::ExtractDate.new(zip_header('readme.txt')).date}).must_raise DataGovAu::AbnBulkExtract::ExtractUndated
    end

    # Guessing from a truncated name would date a release wrongly, which is worse than stopping.
    it "stops where the name runs past what was read" do
      _(->{DataGovAu::AbnBulkExtract::ExtractDate.new(zip_header('20261028_Public01.xml', declared_length: 9000)).date}).must_raise DataGovAu::AbnBulkExtract::ExtractUndated
    end

    it "stops upon nothing at all" do
      _(->{DataGovAu::AbnBulkExtract::ExtractDate.new('').date}).must_raise DataGovAu::AbnBulkExtract::ExtractUndated
    end
  end
end
