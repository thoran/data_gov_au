# DataGovAu/AbnBulkExtract/Config.rb
# DataGovAu::AbnBulkExtract::Config

require_relative '../Catalogue'

module DataGovAu
  module AbnBulkExtract
    class Config
      DEFAULTS = {
        api_url: Catalogue::API_URL,
        user_agent: Catalogue::USER_AGENT,
      }

      attr_accessor :api_url, :user_agent
      attr_writer :directory

      # The extract's own directory, named by the caller.
      def directory
        validate_args(directory: @directory)
        File.expand_path(@directory)
      end

      # One directory per weekly release, named for the date it was published, holding the zips as data.gov.au serves them along with the catalogue entry they were found through.
      def releases_directory
        File.join(directory, 'releases')
      end

      private

      def initialize(directory: nil, api_url: DEFAULTS[:api_url], user_agent: DEFAULTS[:user_agent])
        @directory = directory
        @api_url = api_url
        @user_agent = user_agent
        yield(self) if block_given?
      end

      def validate_args(args)
        missing_args = []
        args.each do |arg_name, value|
          missing_args << arg_name unless value
        end
        return if missing_args.empty?
        aggregate_error = missing_args.join(', ')
        copula = missing_args.count > 1 ? 'are' : 'is'
        raise ArgumentError, "#{aggregate_error} #{copula} missing."
      end
    end
  end
end
