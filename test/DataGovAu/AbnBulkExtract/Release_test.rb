# test/DataGovAu/AbnBulkExtract/Release_test.rb

require_relative '../../helper'

describe DataGovAu::AbnBulkExtract::Release do
  let(:resource){resource_from(extract_resource('ABN Bulk Extract Part 1', 'public_split_1_10.zip', '2026-10-27T21:39:23', 40))}

  describe "where it puts a release" do
    it "names the directory for the date the release was published" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [resource])
        _(release.directory).must_equal File.join(directory, 'releases', '20261027')
      end
    end

    it "prints as the release date" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), []).to_s).must_equal '20261027'
      end
    end
  end

  describe "what it counts as held" do
    it "is not held where the file is absent" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [resource])
        _(release.held?(resource)).must_equal false
        _(release.complete?).must_equal false
        _(release.missing).must_equal [resource]
      end
    end

    it "is held where the file is present at the length the catalogue reports" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [resource])
        release.create_directory
        File.binwrite(release.path_for(resource), 'x' * 40)
        _(release.held?(resource)).must_equal true
        _(release.complete?).must_equal true
        _(release.missing).must_equal []
      end
    end

    # A download cut short leaves a short file, which must not pass for a held one.
    it "is not held where the file is present at another length" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [resource])
        release.create_directory
        File.binwrite(release.path_for(resource), 'x' * 39)
        _(release.held?(resource)).must_equal false
      end
    end

    it "is held on presence alone where the catalogue reports no length" do
      Dir.mktmpdir do |directory|
        sizeless = resource_from(resource.to_h.merge('size' => nil))
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [sizeless])
        release.create_directory
        File.binwrite(release.path_for(sizeless), 'x')
        _(release.held?(sizeless)).must_equal true
      end
    end
  end

  describe "the catalogue entry it records" do
    it "writes the package beside the files" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AbnBulkExtract::Release.new(config_in(directory), Date.new(2026, 10, 27), [resource])
        release.record_catalogue(package)
        _(File.exist?(release.catalogue_path)).must_equal true
        _(JSON.parse(File.read(release.catalogue_path))['name']).must_equal 'abn-bulk-extract'
      end
    end
  end

  describe "whether it is held whole" do
    it "is where every zip its recorded catalogue entry lists is present at its length" do
      Dir.mktmpdir do |directory|
        _(whole_release(directory, Date.new(2026, 10, 28), older_files).whole?).must_equal true
      end
    end

    it "is not where a zip is short" do
      Dir.mktmpdir do |directory|
        release = whole_release(directory, Date.new(2026, 10, 28), older_files)
        File.truncate(File.join(release.directory, 'public_split_1_10.zip'), 10)
        _(release.whole?).must_equal false
      end
    end

    it "is not where no catalogue entry is recorded" do
      Dir.mktmpdir do |directory|
        release = whole_release(directory, Date.new(2026, 10, 28), older_files)
        File.delete(release.catalogue_path)
        _(release.whole?).must_equal false
      end
    end
  end

  describe "whether it has its delta" do
    it "has not where only one of the delta and frame is present" do
      Dir.mktmpdir do |directory|
        release = whole_release(directory, Date.new(2026, 10, 28), older_files)
        File.write(release.delta_path, '')
        _(release.delta?).must_equal false
        File.write(release.frame_path, '')
        _(release.delta?).must_equal true
      end
    end
  end

  describe "the releases already on disk" do
    it "reports none where nothing has been retrieved" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AbnBulkExtract::Release.dates_held(config_in(directory))).must_equal []
      end
    end

    it "reads the dates from the directory names, newest first" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        ['20261013', '20261027', '20261020'].each{|name| FileUtils.mkdir_p(File.join(config.releases_directory, name))}
        _(DataGovAu::AbnBulkExtract::Release.dates_held(config)).must_equal [Date.new(2026, 10, 27), Date.new(2026, 10, 20), Date.new(2026, 10, 13)]
      end
    end

    it "ignores a directory which is not a date" do
      Dir.mktmpdir do |directory|
        config = config_in(directory)
        ['20261027', 'scratch'].each{|name| FileUtils.mkdir_p(File.join(config.releases_directory, name))}
        _(DataGovAu::AbnBulkExtract::Release.dates_held(config)).must_equal [Date.new(2026, 10, 27)]
      end
    end
  end
end
