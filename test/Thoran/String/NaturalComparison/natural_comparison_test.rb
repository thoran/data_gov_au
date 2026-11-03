# test/Thoran/String/NaturalComparison/natural_comparison_test.rb

require_relative '../../../helper'

describe Thoran::String::NaturalComparison do
  it "compares strings without numbers as strings do" do
    _('abc'.natural_comparison('abc')).must_equal 0
    _('abb'.natural_comparison('abc')).must_equal(-1)
    _('abc'.natural_comparison('abb')).must_equal 1
  end

  it "compares the numbers in them as numbers" do
    _('file2'.natural_comparison('file10')).must_equal(-1)
    _('file10'.natural_comparison('file2')).must_equal 1
  end

  it "goes on to what follows a number where the numbers are equal" do
    _('file1a'.natural_comparison('file1b')).must_equal(-1)
    _('file1a2'.natural_comparison('file1a10')).must_equal(-1)
  end

  it "reads a padded number as the number it is" do
    _('Public01'.natural_comparison('Public1')).must_equal 0
  end

  # Each call folds case before matching, so the recursion is handed strings already folded.
  it "folds case where asked, through the recursion as well" do
    _('FILE1A'.natural_comparison('file1a', true)).must_equal 0
    _('FILE1Z'.natural_comparison('file1a', true)).must_equal 1
  end

  it "answers to natcmp" do
    _('file2'.natcmp('file10')).must_equal(-1)
  end
end
