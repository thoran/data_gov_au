# test/DataGovAu/ABR/Delta_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Delta do
  def written(directory)
    delta = DataGovAu::ABR::Delta.new(File.join(directory, 'delta.zst'))
    delta.write do |changes|
      changes.change(record_line('22222222222', status: 'CAN'))
      changes.add(record_line('25000000000'))
      changes.remove('55555555555')
    end
    delta
  end

  it "gives back each change in the order written, as its kind, ABN and record" do
    Dir.mktmpdir do |directory|
      changes = written(directory).each_change.collect{|change| [change.kind, change.abn, change.record]}
      _(changes).must_equal [
        ['C', '22222222222', record_line('22222222222', status: 'CAN')],
        ['A', '25000000000', record_line('25000000000')],
        ['R', '55555555555', nil],
      ]
    end
  end

  it "counts what it writes" do
    Dir.mktmpdir do |directory|
      delta = written(directory)
      _([delta.added, delta.changed, delta.removed]).must_equal [1, 1, 1]
    end
  end

  it "stops at a line which is no change" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'delta.zst')
      DataGovAu::ABR::CompressedFile.new(path).write{|file| file << "X 11111111111\n"}
      _(->{DataGovAu::ABR::Delta.new(path).each_change.to_a}).must_raise DataGovAu::ABR::ExtractMalformed
    end
  end
end
