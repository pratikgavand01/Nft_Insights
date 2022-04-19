require 'api/faraday_client'
module API
  class OpenSeaClient
    include FaradayClient

    def initialize(endpoint)
      @open_sea_endpoint = URI.parse(endpoint)
    end

    private

    def connection
      Faraday.new url: @open_sea_endpoint.to_s, headers: headers do |f|
        f.request  :json
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def headers
      @keys ||= ENV['OPENSEA_API_KEY'].to_s.delete(" ").split(",") rescue []
      api_key = @keys.pop
      @keys = [api_key, @keys].flatten
      { "content-type": "application/json", 'x-api-key': api_key }
    end
  end

end
