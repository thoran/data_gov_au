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
end
