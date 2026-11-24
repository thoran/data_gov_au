require_relative './helper'

Dir[File.join(__dir__, '..', 'lib', 'DataGovAu', '*.rb')].each{|path| require path}

def dataset_modules
  DataGovAu.constants.collect{|name| DataGovAu.const_get(name)}.select{|constant| constant.is_a?(Module) && constant.const_defined?(:DATASET, false)}
end

def camel_cased(catalogue_name)
  catalogue_name.split(/[-_]/).collect(&:capitalize).join
end

describe DataGovAu do
  it "names each dataset's module for the dataset's name in the catalogue" do
    _(dataset_modules).wont_be_empty
    dataset_modules.each do |dataset_module|
      _(dataset_module.name).must_equal "DataGovAu::#{camel_cased(dataset_module::DATASET)}"
    end
  end
end
