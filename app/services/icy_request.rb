class IcyRequest < ApplicationServices

  class << self

    # Method to get top collection data
   def fetch_top_collections(record_time = 1.hour, records = 100, sort_by = 'VOLUME', limit = 5)
      data = fetch(record_time, records, sort_by)
      collections = []
      data.first(limit).each do |node|
        collections << OpenseaRequests.fetch_collection_by_slug(node[:node][:unsafeOpenseaSlug])
      end
      collections
    end

    # Method to get collection data and save data to database and redis server
    def get_and_set_top_collections(record_time = 1.hour, records = 100, sort_by = 'VOLUME', limit = 5)
      current_time = parse_to_string(Time.now.utc)
      top_collections = fetch_top_collections(record_time, records, sort_by, limit)
      top_collection_ids = []
      if top_collections.present?
        collection = save_top_collections(top_collections)  # set top collections to redis database
        top_collection_ids = collection.map{|x|x["id"]} rescue []
      end
      stats = Collection.includes(:assets).where(id: top_collection_ids).map do |x|
        { name: x.name,
          total_supply: x.stats["total_supply"].to_i,
          total_sales: x.stats["total_sales"].to_i,
          holder_ratio: self.send(:holder_ratio, x.stats),
          floor_price: x.stats["floor_price"],
          total_listed: ((x.assets.listed.count / x.stats["total_supply"].to_f)*100).round(2),
          pricing: x.assets.listed.group('current_price').count
        }
      end
      top_collections = Kredis.json("recent_top_collections")
      data = HashWithIndifferentAccess.new(top_collections.value)
      data[current_time] = stats
      top_collections.value = data
    end

    def fetch_collections_and_post_to_discord(record_time = 1.hour, records = 100, sort_by = 'VOLUME', limit = 5)
      data = get_and_set_top_collections
      DiscordRequests.post_message
    end

    private

    # method to get collection data from icy tools api
    def fetch(record_time = 1.hour, records = 100, sort_by = 'VOLUME')
      url = "https://graphql.icy.tools/graphql"
      data = {"query":"query TrendingCollections($filter: ContractsFilterInput, $first: Int, $timeRange: DateInputType) {\n    contracts(orderBy: SALES, orderDirection: DESC, filter: $filter, first: $first) {\n      edges {\n        node {\n          address\n          ... on ERC721Contract {\n            name\n            stats(timeRange: $timeRange) {\n              totalSales\n              average\n              ceiling\n              floor\n              volume\n            }\n            symbol\n            unsafeOpenseaSlug\n            isVerified\n          }\n        }\n      }\n    }\n  }","variables":{"first": records,"timeRange":{"gte": "#{(Time.now - record_time).utc.strftime('%Y-%m-%dT%H:%M:%SZ')}"}}}
      headers = {"Content-Type": "application/json", 'x-api-key': ENV['ICY_X_API_KEY']}
      response = HTTParty.post(url, headers: headers, body: data.to_json)
      response_data = HashWithIndifferentAccess.new(response)
      node_list = response_data[:data][:contracts][:edges]
      node_list.sort_by! { |node| -node[:node][:stats][:volume] } if sort_by == 'VOLUME'
      node_list
    end

  end

end
