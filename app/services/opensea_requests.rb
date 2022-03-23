class OpenseaRequests < ApplicationServices
  BASE_URL = 'https://api.opensea.io/api/v1'
  HEADERS = { "Content-Type": "application/json", 'x-api-key': ENV['opensea_api_key'] }

  class << self
    # method to get all collections data
    def fetch_collections(offset = 0, limit = 50)
      url = "#{BASE_URL}/collections?offset=#{offset}&limit=#{limit}"
      response = HTTParty.get(url, headers: HEADERS)
      response = HashWithIndifferentAccess.new(response)
      # aa = Kredis.json "collection"
      # aa.value = body
      response[:collections]
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

   
    # def get_asserts(slug)
    #    @aa = []
    #    fetch_asserts(nil, slug)
    # end
    
    def event_backfile(start, until_date, event_type, cursor = nil, limit = 300)
      url = "#{BASE_URL}/events?event_type=#{event_type}&limit=#{limit}&occurred_before=#{start}&cursor=#{cursor}"
      response = HTTParty.get(url, headers: HEADERS)
      unless response.success?
        raise "Request failed"
      end
      next_page = response["next"]
      time_field = response["asset_events"][0]["created_date"]
      until_date_utc = until_date.to_datetime.utc
      time_field_utc = time_field.to_datetime.utc
      unless until_date_utc > time_field_utc
        response = HashWithIndifferentAccess.new(response)
        @records_counter += response[:asset_events].count
        response[:asset_events].map do |event| 
          puts "@@@@@@@@@@@@@@@@@@@@@--event-- #{event} @@@@@@@@@@@@@"
          unless event[:asset].present?
            next
          end
          asset = Asset.find_by(token_id: event[:asset][:token_id])
          if asset.present?
            if asset.price_updated_timestamp < event[:created_date]
              asset.update!(details: event[:asset], current_price: event[:ending_price], price_updated_timestamp: event[:created_date])
            end
          else
            asset = event[:asset]
            collection = Collection.find_by(slug: asset[:collection][:slug])
            unless collection.present?

              collection_attributes = {
                slug: asset[:collection][:slug],
                name: asset[:collection][:name],
                description: asset[:collection][:description],
                url:asset[:collection][:external_url],
                details: asset[:collection]
              }
              collection = Collection.create!(collection_attributes)
            end
            attributes = {
              token_id: asset[:token_id],
              name: asset[:name],
              description: asset[:description],
              contract_date: asset[:asset_contract][:created_date],
              url: asset[:permalink],
              img_url: asset[:image_url],
              current_price: event[:ending_price],
              price_updated_timestamp: event[:created_date],
              details: asset,
              collection_id: collection.id,
            } 
            Asset.create!(attributes)
          end
          
        end
        event_backfile(start, until_date, event_type, next_page)
      end
      @records_counter, @time_field_utc  = @records_counter, time_field_utc
    end

    def fetch_events(start, until_date, event_type = "created")
      last_event_date = Kredis.datetime "last_event_date"
      if JobsActivity.last.present? && JobsActivity.last.failed?
        @until_date = last_event_date.value || until_date
      else
        @until_date = until_date
      end
      job_activity = JobsActivity.create!(job_type: 0, start_time: Time.now, status: 0)
      @records_counter = 0
      begin
        @records_counter, @time_field_utc = event_backfile(start, @until_date, event_type)
        last_event_date.value = @time_field_utc
        job_activity.update!(status: 1, end_time: Time.now, records_count: @records_counter)
      rescue => e
        job_activity.update!(status: 2, end_time: Time.now, failed_reason: e.message, records_count: @records_counter)
      end
    end

    private

    def fetch_asserts(cursor = nil, slug)
      url = "https://api.opensea.io/api/v1/assets?limit=50&include_orders=true&collection_slug=#{slug}&cursor=#{cursor}"
      response = HTTParty.get(url, headers: HEADERS)
      # response = HashWithIndifferentAccess.new(response)
      @aa << response["assets"]
      if response["next"].present?
        puts "#{ response["next"]}"
        fetch_asserts(response["next"])
      end
      # list = Kredis.json "asserts_list1"
      # list.value = {assets: @aa.flatten}
      @aa
    end

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