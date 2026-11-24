# test/DataGovAu/ABR/Frame_test.rb

require_relative '../../helper'

describe DataGovAu::ABR::Frame do
  let(:member){DataGovAu::ABR::Frame::Member.new('20261104_Public01.xml', "<Transfer>  \r\n".b, "\r\r\n</Transfer>\r\n".b, 250, {"\r\r\n".b => [100, 200]}, 'a' * 64)}

  it "gives back what was written" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'frame.json.zst')
      (DataGovAu::ABR::Frame.new('20261028') << member).write(path)
      frame = DataGovAu::ABR::Frame.read(path)
      _(frame.against).must_equal '20261028'
      _(frame.members).must_equal [member]
    end
  end

  it "gives back the framing as bytes, as it was read" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'frame.json.zst')
      (DataGovAu::ABR::Frame.new('20261028') << member).write(path)
      _(DataGovAu::ABR::Frame.read(path).members.first.before.encoding).must_equal Encoding::BINARY
    end
  end

  # A gap falling every hundred records is then a run of one number repeated.
  it "holds each gap's positions as the distance from one to the next" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'frame.json.zst')
      (DataGovAu::ABR::Frame.new('20261028') << member).write(path)
      _(JSON.parse(Zstd.decompress(File.binread(path)))['members'].first['gaps']).must_equal({"\r\r\n" => [100, 100]})
    end
  end

  it "stops at framing which is not text, rather than storing it mangled" do
    Dir.mktmpdir do |directory|
      member.before = "\xFF\xFE".b
      _(->{(DataGovAu::ABR::Frame.new('20261028') << member).write(File.join(directory, 'frame.json.zst'))}).must_raise DataGovAu::ABR::ExtractMalformed
    end
  end
end
