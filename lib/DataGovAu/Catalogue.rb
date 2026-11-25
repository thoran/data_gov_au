# DataGovAu/Catalogue.rb
# DataGovAu::Catalogue

require 'json'

require 'http.rb'

require_relative './Dataset'
require_relative './Error'
require_relative './VERSION'

module DataGovAu
  # data.gov.au's CKAN action API, through which a dataset and its resources are found.
  class Catalogue
    API_URL = 'https://data.gov.au/data/api/3/action'
    USER_AGENT = "data_gov_au/#{VERSION}"

    attr_accessor :api_url, :user_agent

    # A dataset by its name or its id, CKAN taking either. Asked for each time rather than held, its resources being the catalogue's to change.
    def dataset(name_or_id)
      Dataset.new(self, action('package_show', 'id' => name_or_id))
    end

    private

    def initialize(api_url: API_URL, user_agent: USER_AGENT)
      @api_url = api_url
      @user_agent = user_agent
      yield(self) if block_given?
    end

    # One call to the action API, returning its result where the answer reports success.
    def action(name, parameters = {})
      url = "#{@api_url}/#{name}"
      response = HTTP.get(url, parameters, {'User-Agent' => @user_agent})
      raise CatalogueUnavailable, "#{url} answered #{response.code}" unless response.success?
      body = JSON.parse(response.body)
      raise CatalogueUnavailable, "#{url} reported no result" unless body['success'] && body['result']
      body['result']
    end
  end
end
