class OpenseaRequests < ApplicationServices
  BASE_URL = 'https://api.opensea.io/api/v1'
  HEADERS = { "Content-Type": "application/json", 'x-api-key': ENV['OPENSEA_API_KEY'] }

  class << self

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
    
    def event_backfile(start, until_date, event_type = "created", cursor = nil, records_counter = 0, limit = 300)
      records_counter = records_counter
      url = "#{BASE_URL}/events?event_type=#{event_type}&limit=#{limit}&occurred_before=#{start}&cursor=#{cursor}"
      response = HTTParty.get(url, headers: HEADERS)
      unless response.success?
        raise "Request failed"
      end
      next_page = response["next"]
      return 0 unless response["asset_events"].present?
      if next_page.present? && (!until_date || until_date.to_datetime.utc < response["asset_events"][0]["created_date"])
        save_events_data(response)
        records_counter += response["asset_events"].count
        records_counter = event_backfile(start, until_date, event_type, next_page, records_counter)
      end
      # @until_date_utc = until_date.to_datetime.utc if until_date.present?
      # time_field = response["asset_events"][0]["created_date"]
      # time_field_utc = time_field.to_datetime.utc if cursor.present?
      # if time_field_utc < until_date_utc
        # save_events_data(response)
        # event_backfile(start, until_date, event_type, next_page)
      # end
      records_counter
    end

    def save_events_data(response)
      response = HashWithIndifferentAccess.new(response)
        records_counter = response[:asset_events].count
        response[:asset_events].map do |event|
          unless event[:asset].present?
            next
          end
          puts "*******************Saving asset => #{event[:asset][:name]}##{event[:asset][:token_id]}***********"
          asset = Asset.find_by(url: event[:asset][:permalink])
          if asset.present?
            if asset.price_updated_timestamp < event[:created_date]
              asset.update!(details: event[:asset], current_price: event[:ending_price], last_event_type: event[:event_type], duration: event[:duration], price_updated_timestamp: event[:created_date])
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
              puts "*******************New Collection added => #{collection_attributes[:slug]}***********"
            end
            attributes = {
              token_id: asset[:token_id],
              name: asset[:name],
              description: asset[:description],
              asset_contract_date: asset[:asset_contract][:created_date],
              asset_contract_address: asset[:asset_contract]["address"],
              url: asset[:permalink],
              img_url: asset[:image_url],
              current_price: event[:ending_price],
              last_event_type: event[:event_type],
              duration: event[:duration],
              price_updated_timestamp: event[:created_date],
              details: asset,
              collection_id: collection.id,
            } 
            Asset.create!(attributes)
            puts "*******************New Asset Added => #{event[:asset][:name]}##{event[:asset][:token_id]}***********"
          end
        end
    end

    def fetch_events(job_type, start, until_date, event_type = "created", limit = 300)
      last_event_date = Kredis.datetime "last_#{event_type}_event_date"
      @until_date = last_event_date.value
      records_counter = 0
      job_activity = JobsActivity.create!(job_name: "#{event_type}_events", job_type: job_type, start_time: Time.now, status: 0)
      url = "#{BASE_URL}/events?event_type=#{event_type}&limit=#{limit}&occurred_before=#{start}"
      response = HTTParty.get(url, headers: HEADERS)
      unless response.success?
        raise "Request failed"
        job_activity.update!(status: 2, end_time: Time.now, failed_reason: "Request failed", records_count: 0)
        return
      end
      next_page = response["next"]
      if response["asset_events"].present?
       save_events_data(response)
       last_event_date.value = response["asset_events"][0]["created_date"]
       records_counter += response["asset_events"].count
      else
        job_activity.update!(status: 1, end_time: Time.now, records_count: 0)
        return 
      end

      if next_page.present? && (!@until_date || @until_date.to_datetime.utc < response["asset_events"][0]["created_date"])
      
        # @until_date = last_event_date.value || until_date
        # @until_date = until_date
        # job_activity = JobsActivity.create!(job_name: "#{event_type}_events", job_type: job_type,start_time: Time.now, status: 0)
        begin
          @records_counter = event_backfile(start, @until_date, event_type, next_page, records_counter)
          job_activity.update!(status: 1, end_time: Time.now, records_count: @records_counter)
          # records_counter = @records_counter
        rescue => e
          job_activity.update!(status: 2, end_time: Time.now, failed_reason: e.message, records_count: 300)
        end
      else
        job_activity.update!(status: 1, end_time: Time.now, records_count: records_counter)
      end
    end
  end

end