class OpenSeaService < ApplicationService

  class << self

    # method to get collection by slug name
    def fetch_collection_by_slug(slug_name)
      request_with_retry("/collection/#{slug_name}") rescue nil
    end

    # method to get collection stats by slug name
    def fetch_collection_stats_by_slug(slug_name)
      request_with_retry("/collection/#{slug_name}/stats") rescue nil
    end

    def fetch_events(job_type, start, event_type = "created", limit = 300)
      last_event_date = Kredis.datetime("last_#{event_type}_event_date")
      @until_date = last_event_date.value if job_type == "delta"

      records_counter = 0, job_activity_log = { start: start, next: "", until: @until_date }
      job_activity = JobsActivity.create!(job_name: "#{event_type}_events", job_type: job_type, log: job_activity_log)
      failed = 0
      begin
        response = request_with_retry("/events?event_type=#{event_type}&limit=#{limit}&occurred_before=#{start}")
      rescue => ex
        failed += 1
        retry if failed < 5
        error_messages = "Request failed: #{ex.to_s}"
        job_activity.update!(status: :failed, end_time: Time.now, failed_reason: error_messages, records_count: records_counter)
        raise ex
      end

      if response[:asset_events].present?
        save_events_data(response)
        job_activity.log[:last_event_time] = response[:asset_events][0][:created_date] if job_type == "delta"
        last_event_date.value = response[:asset_events][0][:created_date] if job_type == "past_data"
        records_counter = response[:asset_events].count
      else
        job_activity.update!(status: :completed, end_time: Time.now, records_count: 0)
        return
      end

      if response[:next].present? && (!@until_date || @until_date.to_datetime.utc < response[:asset_events][0][:created_date])
        records_counter = event_back_file(start, @until_date, job_activity, event_type, response[:next], records_counter.to_i)
      end
      job_activity.update!(status: :completed, end_time: Time.now, records_count: records_counter)
      last_event_date.value = response[:asset_events][0][:created_date] if job_type == "delta"
    end

    def retry_events(job_activity)
      unless job_activity.log["next"].present?
        job_activity.rejected!
      end
      return false if %w[completed active rejected].include?(job_activity.status)
      job_activity.active!
      event_type = job_activity.job_name.gsub("_events", "")
      log = job_activity.log
      until_time = nil
      if job_activity.job_type === 'delta'
        until_time = Kredis.datetime("last_#{event_type}_event_date").value
        until_time ||= (log["until"] && log["until"].to_datetime)
        until_time ||= JobsActivity.last_event_time(event_type)
      end

      records_counter = event_back_file(log["start"], until_time, job_activity, event_type, log["next"], job_activity.records_count.to_i)
      job_activity.update!(status: :completed, end_time: Time.now, records_count: records_counter)

      # set last_event_time
      if job_activity.job_type == 'delta'
        last_event_date = Kredis.datetime("last_#{event_type}_event_date")
        if log["last_event_time"] && (!last_event_date.value || (last_event_date.value.to_datetime < log["last_event_time"].to_datetime))
          last_event_date.value = log["last_event_time"].to_datetime
        end
      end
      true
    end

    private

    def event_back_file(start, until_date, job_activity, event_type = "created", cursor = nil, records_counter = 0, limit = 300)
      begin
        job_activity.records_count = records_counter
        job_activity.log[:next] = cursor
        job_activity.save!
        response = request_with_retry("/events?event_type=#{event_type}&limit=#{limit}&occurred_before=#{start}&cursor=#{cursor}")
      rescue => ex
        error_messages = "Request failed: #{ex.to_s}"
        job_activity.log[:last_paused_counter] = records_counter
        job_activity.update!(status: :failed, end_time: Time.now, failed_reason: error_messages, records_count: records_counter)
        raise ex
      end

      if records_counter.to_i > ((ENV['PAUSED_REQUEST_COUNT'] || 15000).to_i + job_activity.log["last_paused_counter"].to_i)
         job_activity.log[:last_paused_counter] = records_counter
         error_messages = "paused request because of reach limit of maximum records"
         job_activity.update!(status: :paused, end_time: Time.now, records_count: records_counter, failed_reason: error_messages)
         raise error_messages
      end

      return records_counter unless response[:asset_events].present?

      begin
        save_events_data(response) # save event data
      rescue => ex
        error_messages = "Request failed: #{ex.to_s}"
        job_activity.update!(status: :failed, end_time: Time.now, failed_reason: error_messages)
        raise ex
      end

      if job_activity.job_type === 'delta'
        until_date = Kredis.datetime("last_#{event_type}_event_date").value || until_date
      end

      if response[:next].present? && (!until_date || until_date.to_datetime.utc < response[:asset_events][0][:created_date])
        records_counter += response[:asset_events].count.to_i
        records_counter = event_back_file(start, until_date, job_activity, event_type, response[:next], records_counter)
      end
      records_counter
    end

    def save_events_data(response)
      response = HashWithIndifferentAccess.new(response)
      return unless response[:asset_events].present?
      assets_data = []
      collections_data = []

      response[:asset_events].map do |event|
        next unless event[:asset].present?

        asset = event[:asset]
        collections_data << {
          slug: asset[:collection][:slug],
          name: asset[:collection][:name],
          description: asset[:collection][:description],
          url: asset[:collection][:external_url],
          details: asset[:collection]
        }

        asset_filter_data = asset.except(:token_id, :name, :description, :permalink, :image_url, :duration, :created_date, :collection, :ending_price)
        assets_data << {
          token_id: asset[:token_id],
          name: asset[:name],
          description: asset[:description],
          asset_contract_date: asset[:asset_contract][:created_date],
          asset_contract_address: asset[:asset_contract][:address],
          url: asset[:permalink],
          img_url: asset[:image_url],
          current_price: event[:ending_price],
          last_event_type: event[:event_type],
          duration: event[:duration],
          price_updated_timestamp: event[:created_date],
          details: asset_filter_data,
          collection_id: asset[:collection][:slug],
        }
      end

      collections_data.uniq! {|e| e[:slug] }

      collection_hash = Collection.select(:id, :slug).where(slug: collections_data.pluck(:slug).uniq).pluck(:slug, :id).to_h
      remaining_keys = collections_data.pluck(:slug) - collection_hash.keys
      collections_data.select! {|e| remaining_keys.include?(e[:slug]) }
      if collections_data.present?
        collection_records = Collection.upsert_all(collections_data, unique_by: :slug)
        collection_hash.merge!(Collection.select(:id, :slug).where(id: collection_records.rows.flatten.compact.uniq).pluck(:slug, :id).to_h)
      end
      asset_urls =  assets_data.pluck(:url).uniq
      assets_price_timestamp_hash = Asset.select(:id, :url, :price_updated_timestamp).where(url: asset_urls).pluck(:url,:price_updated_timestamp).to_h
      assets_data.select! {|asset| assets_price_timestamp_hash[asset[:url]].to_i < asset[:price_updated_timestamp].to_datetime.to_i}
      return unless assets_data.present?
      assets_data = assets_data.sort_by { |asset| asset[:price_updated_timestamp].to_datetime.to_i }.reverse.uniq { |asset| asset[:url] }
      assets_data.map { |asset| asset[:collection_id] = collection_hash[asset[:collection_id]] }
      Asset.upsert_all(assets_data.uniq, unique_by: :url)
    end

    def request_with_retry(url, failed = 0)
      begin
        get_request(url)
      rescue => ex
        failed += 1
        retry if failed < 5
        raise ex
      end
    end

    def get_request(url, delay = 0.5)
      sleep(delay)
      response = OpenSeaClient.rest_api(:get, url)
      HashWithIndifferentAccess.new(response)
    end

  end

end