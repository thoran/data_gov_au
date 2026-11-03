# test/exe/data_gov_au_test.rb

require_relative '../helper'

require 'open3'
require 'rbconfig'

EXE_PATH = File.expand_path(File.join(__dir__, '..', '..', 'exe', 'data_gov_au'))

def run_under(home, *arguments, data_home: nil)
  Open3.capture3({'HOME' => home, 'XDG_DATA_HOME' => data_home}, RbConfig.ruby, EXE_PATH, 'abr', *arguments)
end

def write_config(home, text)
  path = File.join(home, '.config', 'data_gov_au', 'config.yaml')
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, text)
end

describe "exe/data_gov_au" do
  describe "the config file" do
    it "stops the run where it does not hold a mapping" do
      Dir.mktmpdir do |home|
        write_config(home, "- one\n- two\n")
        _, error, status = run_under(home, '-n')
        _(status.exitstatus).must_equal 1
        _(error).must_include 'does not hold a mapping'
      end
    end

    it "gives the library the settings it holds" do
      Dir.mktmpdir do |home|
        write_config(home, "api_url: http://127.0.0.1:9/api/3/action\n")
        _(run_under(home, '-n')[1]).must_include '127.0.0.1:9'
      end
    end
  end

  describe "parsing" do
    def release_under(home, text = File.read(fixture_path('20261020Public01.xml')))
      release = DataGovAu::ABR::Release.new(config_in(File.join(home, '.local', 'share', 'data_gov_au')), Date.new(2026, 10, 20))
      release.create_directory
      Zip::File.open(File.join(release.directory, 'public_split_1_10.zip'), create: true){|zip| zip.get_output_stream('20261020Public01.xml'){|io| io.write(text)}}
      release
    end

    it "reports each file against the count it carries, and the whole" do
      Dir.mktmpdir do |home|
        release_under(home)
        output, _, status = run_under(home, '-p')
        _(status.exitstatus).must_equal 0
        _(output).must_include '20261020Public01.xml  9 of 9'
        _(output).must_match(/total:     9 records in \d+ s/)
      end
    end

    it "stops naming a file which reports an error" do
      Dir.mktmpdir do |home|
        release_under(home, File.read(fixture_path('20261020Public01.xml')).sub('error="none"', 'error="partial"'))
        output, error, status = run_under(home, '-p')
        _(status.exitstatus).must_equal 1
        _(output).must_include '9 of 9  error: partial'
        _(error).must_include 'or an error reported, in 20261020Public01.xml'
      end
    end

    it "says so where a file names no error at all" do
      Dir.mktmpdir do |home|
        release_under(home, File.read(fixture_path('20261020Public01.xml')).sub(' error="none"', ''))
        output, _, status = run_under(home, '-p')
        _(status.exitstatus).must_equal 1
        _(output).must_include '9 of 9  error: not given'
      end
    end
  end

  # Parsing with nothing held fails naming the releases directory, and so shows where the settings put it without going to the catalogue.
  describe "the data directory" do
    def releases_under(directory)
      File.join(directory, 'abr', 'releases')
    end

    it "is beneath XDG_DATA_HOME where nothing else names one" do
      Dir.mktmpdir do |home|
        _, error, status = run_under(home, '-p', data_home: File.join(home, 'share'))
        _(status.exitstatus).must_equal 1
        _(error).must_include releases_under(File.join(home, 'share', 'data_gov_au'))
      end
    end

    it "is beneath ~/.local/share where XDG_DATA_HOME is unset" do
      Dir.mktmpdir do |home|
        _(run_under(home, '-p')[1]).must_include releases_under(File.join(home, '.local', 'share', 'data_gov_au'))
      end
    end

    it "is the config file's over the default" do
      Dir.mktmpdir do |home|
        write_config(home, "data_directory: #{home}/stored\n")
        _(run_under(home, '-p')[1]).must_include releases_under(File.join(home, 'stored'))
      end
    end

    it "is the switch's over the config file" do
      Dir.mktmpdir do |home|
        write_config(home, "data_directory: #{home}/stored\n")
        _(run_under(home, '-p', '-d', File.join(home, 'switched'))[1]).must_include releases_under(File.join(home, 'switched'))
      end
    end

    it "stays the default where the config file leaves it blank" do
      Dir.mktmpdir do |home|
        write_config(home, "data_directory:\n")
        _(run_under(home, '-p')[1]).must_include releases_under(File.join(home, '.local', 'share', 'data_gov_au'))
      end
    end

    it "stays the default where the config file is empty" do
      Dir.mktmpdir do |home|
        write_config(home, '')
        _(run_under(home, '-p')[1]).must_include releases_under(File.join(home, '.local', 'share', 'data_gov_au'))
      end
    end

    it "is the config file's where the file also holds a setting the library does not take" do
      Dir.mktmpdir do |home|
        write_config(home, "keep_releases: 6\ndata_directory: #{home}/stored\n")
        _(run_under(home, '-p')[1]).must_include releases_under(File.join(home, 'stored'))
      end
    end
  end
end
