require 'api/faraday_client'
module API
  class IcyToolClient
    include FaradayClient

    def initialize(endpoint)
      @icy_tool_endpoint = URI.parse(endpoint)
    end

    private

    def connection
      Faraday.new url: @icy_tool_endpoint.to_s, headers: headers do |f|
        f.request  :json
        f.response :json
        f.adapter Faraday.default_adapter
      end
    end

    def headers
      @keys ||= ENV['ICY_X_API_KEY'].to_s.delete(" ").split(",") rescue []
      api_key = @keys.pop
      @keys = [api_key, @keys].flatten
      { "content-type": "application/json", 'x-api-key': api_key }
    end
  end

end
