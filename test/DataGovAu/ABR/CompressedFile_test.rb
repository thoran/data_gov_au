# test/DataGovAu/ABR/CompressedFile_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::CompressedFile do
  it "gives back the lines written" do
    Dir.mktmpdir do |directory|
      file = DataGovAu::ABR::CompressedFile.new(File.join(directory, 'lines.zst'))
      file.write{|lines| lines << "first\n" << "second\n"}
      _(file.each_line.to_a).must_equal ["first\n", "second\n"]
    end
  end

  # A line straddling the end of one read and the start of the next must come back whole.
  it "gives back lines which run across more than one read" do
    Dir.mktmpdir do |directory|
      written = (1..30_000).collect{|index| "#{index} #{'x' * (index % 97)}\n"}
      file = DataGovAu::ABR::CompressedFile.new(File.join(directory, 'lines.zst'), level: 1)
      file.write{|lines| written.each{|line| lines << line}}
      _(written.join.bytesize).must_be :>, DataGovAu::ABR::CompressedFile::READ_LENGTH
      _(file.each_line.to_a).must_equal written
    end
  end

  it "gives back a last line with no line break" do
    Dir.mktmpdir do |directory|
      file = DataGovAu::ABR::CompressedFile.new(File.join(directory, 'lines.zst'))
      file.write{|lines| lines << "first\n" << 'last'}
      _(file.each_line.to_a).must_equal ["first\n", 'last']
    end
  end

  it "is zstd, which the zstd command reads" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'lines.zst')
      DataGovAu::ABR::CompressedFile.new(path).write{|lines| lines << "first\n"}
      _(Zstd.decompress(File.binread(path))).must_equal "first\n"
    end
  end
end
