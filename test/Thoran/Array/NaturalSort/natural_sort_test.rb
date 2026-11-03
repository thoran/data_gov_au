# test/Thoran/Array/NaturalSort/natural_sort_test.rb

require_relative '../../../helper'

describe Thoran::Array::NaturalSort do
  it "puts the extract's halves in the order their numbers give" do
    _(%w{public_split_11_20.zip public_split_1_10.zip}.natural_sort).must_equal %w{
      public_split_1_10.zip
      public_split_11_20.zip
    }
  end

  it "orders twenty unpadded names as their numbers do" do
    names = (1..20).to_a.shuffle.collect{|number| "20261028_Public#{number}.xml"}
    _(names.natural_sort).must_equal (1..20).collect{|number| "20261028_Public#{number}.xml"}
  end

  it "answers to natsort" do
    _(%w{file10 file2}.natsort).must_equal %w{file2 file10}
  end
end
