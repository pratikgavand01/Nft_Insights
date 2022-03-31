class ApplicationServices

    class << self

      def get_collection_data(time = Time.now)
        top_collections = Kredis.json("recent_top_collections")
        top_collections = HashWithIndifferentAccess.new(top_collections.value)
        collections = top_collections[parse_to_string(time)]

        puts collections.count
        collections_data = [] 
        collections && collections.map do |collection|
          collections_data << collection_formated_data(collection)
        end
        collections_data
      end
      
      # def asset_events_data(slug = "", time = Time.now-2.minutes)
      #   events_data = Kredis.json("asset_events")
      #   events_data = HashWithIndifferentAccess.new(events_data.value)
      #   collection_events = events_data[slug]
      #   puts collection_events.keys
      #   [collection_events[parse_to_string(time.utc)], collection_events[parse_to_string((time - 1.minutes).utc)]]
      # end

      # def fetch_event_required_data(event)
      #   event ||= [] 
      #   prices_list =  event.map {|data| (data[:starting_price]).to_f/1000000000000000000 } 
      #   HashWithIndifferentAccess.new({
      #     total_listed: event.count,
      #     prices_list: prices_list
      #   })    
      # end  

      private

      # def get_difference_event_data(first_data, second_data)
      #     first_event_data = fetch_event_required_data(first_data)
      #     second_event_data = fetch_event_required_data(second_data)

      #     ((first_event_data[:total_listed] - second_event_data[:total_listed])/first_event_data[:total_listed])

      #     HashWithIndifferentAccess.new({
      #       listed_change: event.count,
      #       prices_list: prices_list
      #     })
      # end  

      def collection_formated_data(data)
        HashWithIndifferentAccess.new({ 
          name: data[:name], 
          total_supply: data[:total_supply],
          holder_ratio: data[:holder_ratio],
          floor_price: data[:floor_price],
          total_sales: data[:total_sales],
          pricing: data[:pricing]
         }) 
      end

      def holder_ratio(stats)  
        ratio = (stats["num_owners"]/stats["total_supply"].to_f)*100
        return 0 if ratio.nan? 
        ratio.round(2)
      end
     
      # def parse_time(time)
      #   return Time.parse(time) if time.include?("Z")
      #   Time.parse("#{time}Z")
      # end 
         
      def save_assets_data(assets, slug)
        asset_events = Kredis.json("asset_events")
        data = HashWithIndifferentAccess.new(asset_events.value)
        if data[slug].present?
          assets.each do |name, values|
            data[slug][name] = values
          end
        else
          data[slug] = assets
        end  
        asset_events.value = data    
      end

      def save_top_collections(collections)
        attributes = []
        collections.each do |collection|
          attributes << {
            slug: collection["collection"]["slug"],
            name: collection["collection"]["name"],
            description: collection["collection"]["description"],
            url: collection["collection"]["external_url"],
            stats: collection["collection"]["stats"],
            details: collection["collection"],
          }
        end
        if attributes.count > 0
          collection = Collection.upsert_all(attributes, unique_by: :slug)
        end
        collection
      end

      def parse_to_string(time)
        Time.parse(time.to_s).strftime('%Y-%m-%dT%H:%M')
      end  

     # def save_all_assets_data(assets, slug)
     #   asset_events = Kredis.json("fetch_all_events")
     #   asset_event_data = HashWithIndifferentAccess.new(asset_events.value)
     #   asset_event_data[slug] = assets
     #   asset_events.value = asset_event_data       
     # end

     # def save_all_asset_time_data(time_difference, slug)
     #   asset_event_time = Kredis.json("fetch_all_event_time")
     #   asset_event_time_data = HashWithIndifferentAccess.new(asset_event_time.value)
     #   asset_event_time_data[slug] = time_difference
     #   asset_event_time.value = asset_event_time_data       
     # end

  end    
    
end    
