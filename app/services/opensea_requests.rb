class OpenseaRequests < ApplicationServices
  BASE_URL = 'https://api.opensea.io/api/v1'
  HEADERS = { "Content-Type": "application/json", 'x-api-key': ENV['opensea_api_key'] }

  class << self
    # method to get all collections data
    def fetch_collections(offset = 0, limit = 50)
      url = "#{BASE_URL}/collections?offset=#{offset}&limit=#{limit}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      aa = Kredis.json "collection"
      aa.value = body
    end

    # method to get first limited asset by slug name
    def fetch_assets_by_slug(slug, limit = 50)
      url = "#{BASE_URL}/assets?collection_slug=#{slug}&order_by=pk&order_direction=desc&include_orders=true&limit=#{limit}"
      response = HTTParty.get(url, headers: HEADERS)
      HashWithIndifferentAccess.new(response)
    end

    # method to get collection by slug name
    def fetch_collection_by_slug(slug_name)
      url = "#{BASE_URL}/collection/#{slug_name}"
      response = HTTParty.get(url, headers: HEADERS)
      HashWithIndifferentAccess.new(response)
    end

    # method to get collection stats by slug name
    def fetch_collection_stats_by_slug(slug_name)
      url = "#{BASE_URL}/collection/#{slug_name}/stats"
      response = HTTParty.get(url, headers: HEADERS)
      HashWithIndifferentAccess.new(response)
    end

    # method to set collection listed stats by slug name for limited time
    def set_collection_limited_events_by_type(slug, type = "created", interval = 5.minutes, limit = 50)
      timestamp = Time.now
      filtered_time = ((timestamp - interval)..timestamp)
      url = "#{BASE_URL}/events?event_type=#{type}&collection_slug=#{slug}&limit=#{limit}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      assets = check_and_fetch_remaining_assets(slug, type, response, filtered_time, [], limit)
      assets_data = assets.flatten.uniq.compact.group_by { |assetData| parse_to_string(assetData[:listing_time]) }
      save_assets_data(assets_data, "#{slug}_#{type}")
      response
    end

    # method to set collection listed stats by slug name for limited all time
    def set_collection_events_by_type(slug, type = "created", limit = 300)
      url = "#{BASE_URL}/events?event_type=#{type}&collection_slug=#{slug}&limit=#{limit}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      assets = fetch_remaining_events_by_type(slug, response, type, [], limit)
      assets = assets.flatten.uniq.compact
      save_all_assets_data(assets, "#{slug}_#{type}")
      assets
    end

    private

    def fetch_remaining_events_by_type(slug, response, type, assets = [], limit = 10)
      filter_data = response[:asset_events].map { |data| filter_asset_values(data) } rescue []
      assets << filter_data
      return assets unless response[:next].present?
      url = "#{BASE_URL}/events?event_type=#{type}&collection_slug=#{slug}&limit=#{limit}&cursor=#{response[:next]}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      fetch_remaining_events_by_type(slug, response, type, assets, limit)
    end

    def check_and_fetch_remaining_assets(slug, type,  response, filtered_time, assets, limit = 50)
      filter_data = response[:asset_events].select { |data| data[:listing_time].present? && filtered_time.include?(parse_time(data[:listing_time])) }
      assets << filter_data
      return assets unless filter_data.count == response[:asset_events].count && response[:next].present?
      url = "#{BASE_URL}/events?event_type=#{type}&collection_slug=#{slug}&limit=#{limit}&cursor=#{response[:next]}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      check_and_fetch_remaining_assets(slug, type, response, filtered_time, assets, limit)
    end

    def filter_asset_values(asset)
      asset[:permalink] = asset[:asset][:permalink]
      asset.slice!(:id, :starting_price, :listing_time, :collection_slug, :event_type, :permalink)
      asset
    end

  end

end