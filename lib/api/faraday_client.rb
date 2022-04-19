require 'faraday'
module API
  module FaradayClient
    Error = Class.new(StandardError)
    ConnectionError = Class.new(Error)

    class ResponseError < Error
      def initialize(msg)
        super "#{msg}"
      end
    end

    def rest_api(verb, path, data = nil)
      response = case verb
                 when :get
                   connection.get path, data
                 when :post
                   connection.post path, data
                 when :put
                   connection.put path, data
                 when :delete
                   connection.delete path, data
                 when :patch
                   connection.patch path, data
                 else
                   raise StandardError 'Unknown verb'
                 end

      raise response.body.to_s unless response.success?
      response = response.body
      (response['errors'] || response['error']).tap do |error|
        if error
          raise ResponseError, error.last['detail'] || error
        end
      end
      response
    rescue Faraday::Error => e
      if e.is_a?(Faraday::ConnectionFailed) || e.is_a?(Faraday::TimeoutError)
        raise ConnectionError, e
      else
        raise ConnectionError, JSON.parse(e.response.body)['message']
      end
    rescue => error
      raise ConnectionError, error.to_s
    end

  end

end
