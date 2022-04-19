require 'api/faraday_client'
module API
  class DiscordClient
    include FaradayClient

    def initialize(endpoint)
      @discord_endpoint = URI.parse(endpoint)
    end

    private

    def connection
      Faraday.new url: @discord_endpoint.to_s, headers: { "Content-Type": "multipart/form-data" } do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end
  end

end
