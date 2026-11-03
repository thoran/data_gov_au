# DataGovAu/Dataset.rb
# DataGovAu::Dataset

require 'time'

require_relative './Resource'

module DataGovAu
  # A dataset's entry in the catalogue, as package_show gave it.
  class Dataset
    def name
      @package['name']
    end

    def title
      @package['title']
    end

    def organisation
      @package.dig('organization', 'title')
    end

    def licence
      @package['license_title']
    end

    # CKAN gives its times without a zone, and they are UTC.
    def modified_at
      @modified_at ||= @package['metadata_modified'] && Time.parse("#{@package['metadata_modified']}Z")
    end

    # In the catalogue's order.
    def resources
      @resources ||= (@package['resources'] || []).collect{|resource| Resource.new(@catalogue, resource)}
    end

    # The entry exactly as the catalogue gave it, so that what was found can be kept beside what was downloaded.
    def to_h
      @package
    end

    private

    def initialize(catalogue, package)
      @catalogue = catalogue
      @package = package
    end
  end
end
