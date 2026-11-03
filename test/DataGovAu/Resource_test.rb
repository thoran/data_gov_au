# test/DataGovAu/Resource_test.rb

require_relative '../helper'

describe DataGovAu::Resource do
  let(:resource){dataset.resources.last}
  let(:url){resource.url}

  describe "what it reports" do
    it "reports what the catalogue says of it" do
      _(resource.name).must_equal 'ABN Bulk Extract Part 1'
      _(resource.format).must_equal 'ZIP'
      _(resource.size).must_equal 40
    end

    it "reads its last modified time as UTC" do
      _(resource.last_modified).must_equal Time.utc(2026, 10, 27, 21, 39, 23, 580175)
    end

    it "has no last modified time where the catalogue gives none" do
      sizeless = DataGovAu::Resource.new(DataGovAu::Catalogue.new, resource.to_h.merge('last_modified' => nil))
      _(sizeless.last_modified).must_be_nil
    end

    # The resource's own name is prose, and in at least one case carries a trailing space.
    it "takes its file's name from its URL rather than from its own name" do
      _(resource.filename).must_equal 'public_split_1_10.zip'
    end
  end

  describe "a download which succeeds" do
    it "writes the body to the path given" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 200, body: 'x' * 40)
        path = File.join(directory, 'public_split_1_10.zip')
        _(resource.download(path)).must_equal path
        _(File.size(path)).must_equal 40
      end
    end

    it "makes the directory it writes into" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 200, body: 'x' * 40)
        path = File.join(directory, 'releases', '20261027', 'public_split_1_10.zip')
        resource.download(path)
        _(File.exist?(path)).must_equal true
      end
    end

    # The partial file is the means, not an artefact: a directory holding one would be read as a cut-short download.
    it "leaves no partial file behind" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 200, body: 'x' * 40)
        path = File.join(directory, 'public_split_1_10.zip')
        resource.download(path)
        _(File.exist?(path + DataGovAu::Resource::PARTIAL_SUFFIX)).must_equal false
      end
    end

    it "identifies itself as its catalogue does" do
      Dir.mktmpdir do |directory|
        resource = dataset(DataGovAu::Catalogue.new(user_agent: 'mine/1.0')).resources.last
        stub = stub_request(:get, url).with(headers: {'User-Agent' => 'mine/1.0'}).to_return(status: 200, body: 'x' * 40)
        resource.download(File.join(directory, 'f.zip'))
        assert_requested(stub)
      end
    end

    it "takes any length where the catalogue reports none" do
      Dir.mktmpdir do |directory|
        sizeless = DataGovAu::Resource.new(DataGovAu::Catalogue.new, resource.to_h.merge('size' => nil))
        stub_request(:get, url).to_return(status: 200, body: 'x' * 7)
        path = File.join(directory, 'f.zip')
        sizeless.download(path)
        _(File.size(path)).must_equal 7
      end
    end
  end

  describe "a download which fails" do
    it "stops upon a failed response" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 404, body: '')
        path = File.join(directory, 'public_split_1_10.zip')
        _(->{resource.download(path)}).must_raise DataGovAu::DownloadFailed
        _(File.exist?(path)).must_equal false
      end
    end

    # A body short of what the catalogue reported is a truncated download, and is worth stopping for here rather than wherever it is read.
    it "stops where the body is not the length the catalogue reported" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 200, body: 'x' * 39)
        _(->{resource.download(File.join(directory, 'public_split_1_10.zip'))}).must_raise DataGovAu::DownloadFailed
      end
    end

    it "leaves nothing in place where the length is wrong" do
      Dir.mktmpdir do |directory|
        stub_request(:get, url).to_return(status: 200, body: 'x' * 39)
        path = File.join(directory, 'public_split_1_10.zip')
        begin
          resource.download(path)
        rescue DataGovAu::DownloadFailed
        end
        _(File.exist?(path)).must_equal false
        _(File.exist?(path + DataGovAu::Resource::PARTIAL_SUFFIX)).must_equal false
      end
    end
  end

  describe "its first bytes" do
    it "asks by range and returns what came back" do
      stub = stub_request(:get, url).
        with(headers: {'User-Agent' => "data_gov_au/#{DataGovAu::VERSION}", 'Range' => 'bytes=0-255'}).
          to_return(status: 206, body: 'PK')
      _(resource.first_bytes(256)).must_equal 'PK'
      assert_requested(stub)
    end

    # Were the range ignored, the whole body would already be in hand, which is the one thing asking by range is meant to avoid; stopping says so rather than letting it pass unremarked.
    it "stops where the range was ignored" do
      stub_request(:get, url).to_return(status: 200, body: 'x' * 40)
      _(->{resource.first_bytes(256)}).must_raise DataGovAu::DownloadFailed
    end
  end

  describe "whether it is held" do
    it "is not held where the file is absent" do
      Dir.mktmpdir do |directory|
        _(resource.held_at?(File.join(directory, 'public_split_1_10.zip'))).must_equal false
      end
    end

    it "is held where the file is present at the length the catalogue reports" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'public_split_1_10.zip')
        File.binwrite(path, 'x' * 40)
        _(resource.held_at?(path)).must_equal true
      end
    end

    # A download cut short leaves a short file, which must not pass for a held one.
    it "is not held where the file is present at another length" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'public_split_1_10.zip')
        File.binwrite(path, 'x' * 39)
        _(resource.held_at?(path)).must_equal false
      end
    end

    it "is held on presence alone where the catalogue reports no length" do
      Dir.mktmpdir do |directory|
        sizeless = DataGovAu::Resource.new(DataGovAu::Catalogue.new, resource.to_h.merge('size' => nil))
        path = File.join(directory, 'public_split_1_10.zip')
        File.binwrite(path, 'x')
        _(sizeless.held_at?(path)).must_equal true
      end
    end
  end
end
