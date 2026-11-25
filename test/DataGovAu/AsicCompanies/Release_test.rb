# test/DataGovAu/AsicCompanies/Release_test.rb

require_relative './helper'

describe DataGovAu::AsicCompanies::Release do
  let(:resource){resource_from(asic_zip_resource)}

  describe "where it puts a release" do
    it "names the directory for the date the register was extracted" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
        _(release.directory).must_equal File.join(directory, 'releases', '20261124')
      end
    end

    it "prints as the release date" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24)).to_s).must_equal '20261124'
      end
    end

    it "keeps a file under the name data.gov.au serves it as" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
        _(File.basename(release.path_for(resource))).must_equal 'company_202611.zip'
      end
    end
  end

  describe "what it counts as held" do
    it "is not held where the file is absent" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
        _(release.complete?).must_equal false
        _(release.missing).must_equal [resource]
      end
    end

    it "is held where the file is present at the length the catalogue reports" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
        release.create_directory
        File.binwrite(release.path_for(resource), 'x' * 40)
        _(release.complete?).must_equal true
      end
    end

    # A download cut short leaves a short file, which must not pass for a held one.
    it "is not held where the file is present at another length" do
      Dir.mktmpdir do |directory|
        release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
        release.create_directory
        File.binwrite(release.path_for(resource), 'x' * 39)
        _(release.held?(resource)).must_equal false
      end
    end
  end

  it "finds its zips in its directory" do
    Dir.mktmpdir do |directory|
      release = asic_release_holding(directory)
      _(release.zip_paths).must_equal [File.join(release.directory, 'company_202611.zip')]
    end
  end

  describe "the releases held" do
    it "are none where nothing has been fetched" do
      Dir.mktmpdir do |directory|
        _(DataGovAu::AsicCompanies::Release.dates_held(asic_config_in(directory))).must_equal []
      end
    end

    it "are read from the directories named for dates, newest first" do
      Dir.mktmpdir do |directory|
        config = asic_config_in(directory)
        ['20261117', '20261124', 'notes'].each{|name| FileUtils.mkdir_p(File.join(config.releases_directory, name))}
        _(DataGovAu::AsicCompanies::Release.dates_held(config)).must_equal [Date.new(2026, 11, 24), Date.new(2026, 11, 17)]
      end
    end
  end

  it "records the catalogue entry it was found through" do
    Dir.mktmpdir do |directory|
      release = DataGovAu::AsicCompanies::Release.new(asic_config_in(directory), Date.new(2026, 11, 24), [resource])
      release.record_catalogue(asic_package)
      _(JSON.parse(File.read(release.catalogue_path))['name']).must_equal 'asic-companies'
    end
  end
end
