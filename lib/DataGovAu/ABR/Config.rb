# DataGovAu/ABR/Config.rb
# DataGovAu::ABR::Config

require_relative '../Catalogue'

module DataGovAu
  module ABR
    class Config
      DEFAULTS = {
        api_url: Catalogue::API_URL,
        user_agent: Catalogue::USER_AGENT,
      }

      attr_accessor :api_url, :user_agent
      attr_writer :data_directory

      def data_directory
        validate_args(data_directory: @data_directory)
        File.expand_path(@data_directory)
      end

      # The extract's own directory beneath the data directory, which other datasets may come to share.
      def directory
        File.join(data_directory, 'abr')
      end

      # One directory per weekly release, named for the date it was published, holding the zips as data.gov.au serves them along with the catalogue entry they were found through.
      def releases_directory
        File.join(directory, 'releases')
      end

      private

      def initialize(data_directory: nil, api_url: DEFAULTS[:api_url], user_agent: DEFAULTS[:user_agent])
        @data_directory = data_directory
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
