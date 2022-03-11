class IcyRequest < ApplicationServices

  class << self

    # method to get top collection data
   def fetch_top_collections(record_time = 7.days, records = 100, sort_by = 'VOLUME', limit = 10)
        data = fetch(record_time, records, sort_by)
        collections = []
        data.first(limit).each do |node|
            collections << OpenseaRequests.fetch_collection_by_slug(node[:node][:unsafeOpenseaSlug])
        end
        collections
    end

    # method to get collection data and save data to redis server
    def get_and_set_top_collections(record_time = 7.days, records = 100, sort_by = 'VOLUME', limit = 10)
        current_time = parse_to_string(Time.now.utc-2.minutes)
        top_collections = fetch_top_collections(record_time, records, sort_by, limit)
        save_top_collections(top_collections, current_time)  # set top collections to redis database
        top_collections.each do |collection|
          OpenseaRequests.set_collection_limited_events_by_type(collection[:collection][:slug], "created")
        end  
    end

    private

    # method to get collection data from icy tools api
    def fetch(record_time = 7.days, records = 100, sort_by = 'VOLUME')
      url = "https://graphql.icy.tools/graphql"
      data = {"query":"query TrendingCollections($filter: ContractsFilterInput, $first: Int, $timeRange: DateInputType) {\n    contracts(orderBy: SALES, orderDirection: DESC, filter: $filter, first: $first) {\n      edges {\n        node {\n          address\n          ... on ERC721Contract {\n            name\n            stats(timeRange: $timeRange) {\n              totalSales\n              average\n              ceiling\n              floor\n              volume\n            }\n            symbol\n            unsafeOpenseaSlug\n            isVerified\n          }\n        }\n      }\n    }\n  }","variables":{"first": records,"timeRange":{"gte": "#{(Time.now - record_time).utc.strftime('%Y-%m-%dT%H:%M:%SZ')}"}}}
      headers = {"Content-Type": "application/json", 'x-api-key': ENV['icy-x-api-key']}
      response = HTTParty.post(url, headers: headers, body: data.to_json)
      response_data = HashWithIndifferentAccess.new(response)
      node_list = response_data[:data][:contracts][:edges]
      node_list.sort_by! { |node| -node[:node][:stats][:volume] } if sort_by == 'VOLUME'
      node_list
    end

  end

end
