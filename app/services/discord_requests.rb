
class DiscordRequests < ApplicationServices
  HEADERS = {"Content-Type": "application/json"}
  URL = ENV["discord_webhook"]

  def self.post_message
    # redis_collection = Kredis.json "collection"
    result = self.collect_data_to_post
    fields = []
    # result.each_with_index do |data, i|
    #   fields << {
    #      "name" => "#{i+1} \n #{data[:collection_name]}", 
    #      "value" => "#{data[:number_of_supply]} | #{data[:holder_ratio]} | #{data[:floor_price]} | #{data[:floor_price_change].round(2)}% | #{data[:number_of_sales]} | #{data[:number_of_sales_change].round(2)}%"
    #   }
    # end
    # result.each_with_index do |data, i|
    #   fields << {
    #      "name" => "NFT Collection | # of supply | Holder Ratio | Current Floor price (%Change) | # of sales(% Chnage)", 
    #      "value" => "#{data[:collection_name]} | #{data[:number_of_supply]} | #{data[:holder_ratio]} | #{data[:floor_price]}(#{data[:floor_price_change].round(2)}%) | #{data[:number_of_sales]}(#{data[:number_of_sales_change].round(2)}%)"
    #   }
    # end
    rows = []
    result.each_with_index do |data, i|
      pricing_string = ""
      data[:pricing].each_with_index do |(key, value), index|
        if index >=2
          break
        end 
        pricing_string +=  "\n#{key.to_f/1000000000000000000} => #{value}"
      end
      rows << ["#{data[:collection_name].truncate(10)}\n(#{data[:number_of_supply]})\n(#{data[:holder_ratio].round(2)}%)", "#{data[:floor_price]}\n(#{data[:floor_price_change]}%)", "#{data[:number_of_sales]}\n(#{data[:number_of_sales_change]}%)"]
      fields << "**#{data[:collection_name]}** (#{data[:number_of_supply]}) (#{data[:holder_ratio]}%) **|** #{data[:floor_price]}(#{data[:floor_price_change]}%) **|** #{data[:number_of_sales]}(#{data[:number_of_sales_change]}%) | #{pricing_string}"
    end

    #format 1
    # redis_collection.value["collections"].each_with_index do |data, i|
    #   fields discord_webhook<< {
    #     "name" => data["name"],
    #     "value" => "#{data["stats"]["one_day_volume"].round(2)} | #{data["stats"]["seven_day_volume"].round(2)} | #{data["stats"]["thirty_day_volume"].round(2)} | #{data["stats"]["one_day_change"]*100}% | #{data["stats"]["seven_day_change"]*100}% | #{data["stats"]["floor_price"]} | #{data["stats"]["num_owners"]} | #{data["stats"]["count"]}"
    #   }
    # end

    #format 2
    # redis_collection.value["collections"].each_with_index do |data, i|
    #   fields << { 
    #     "name" => "#{i+1} - #{data["name"]}", 
    #     "value" => "1d Vol: #{data["stats"]["one_day_volume"].round(2)},  7d Vol: #{data["stats"]["seven_day_volume"].round(2)}, 30d Vol: 
    #{data["stats"]["thirty_day_volume"].round(2)}, 1d%: #{data["stats"]["one_day_change"]*100}%,  7d%: #{data["stats"]["seven_day_change"]*100}%,  Floor Price: #{data["stats"]["floor_price"]},  Owners: #{data["stats"]["num_owners"]},  Items: #{data["stats"]["count"]}"
    #   }
    # end

    #format 3
    # embeds = []
    # redis_collection.value["collections"].each_with_index do |data, i|
    #   embeds << {
    #     "title" => data["name"],
    #     "color" => 15258703,
    #     "fields" => [{
    #       "name" => "24h Volume", 
    #       "value" => "#{data["stats"]["one_day_volume"].round(2)}",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "7d Volume", 
    #       "value" => "#{data["stats"]["seven_day_volume"].round(2)}",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "30h Volume", 
    #       "value" => "#{data["stats"]["thirty_day_volume"].round(2)}",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "1d Change", 
    #       "value" => "#{data["stats"]["one_day_change"]*100}%",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "1d Change", 
    #       "value" => "#{data["stats"]["seven_day_change"]*100}%",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "Floor Price", 
    #       "value" => "#{data["stats"]["floor_price"]}",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "Owners", 
    #       "value" => "#{data["stats"]["num_owners"]}",
    #       "inline" => true
    #     },
    #     {
    #       "name" => "Items", 
    #       "value" => "#{data["stats"]["count"]}",
    #       "inline" => true
    #     }]
    #   }
    # end

    # rows = []
    
    table = ::Terminal::Table.new
    # table.headings = ["NFT\nsupply\nholder ratio", "Current\nfloor price\n(change)",  "# of sales\n(%change)"]

    table.headings = ["NFT\n#supply\nHR", "FP\nchange","# of sales(%)"]
    table.rows = rows


    body = {
      "username" => "Testing NFT Analytics",
      "avatar_url" => "https://i.imgur.com/4M34hi2.png",
      "content" => "Testing New Updates",
      # "embeds" => embeds #format 3

      "embeds" => [{
        "title" => "New Updates",
        "color" => 15258703,
        "fields" => [{
           "name" => "NFT Collection (# of supply)(Holder Ratio) | Current Floor price (%Change) | # of sales(% Change)",
           "value" => "```\n#{table}\n```"
        }]
      }]

    }
    response = HTTParty.post(URL, headers: HEADERS, body: body.to_json)
  end

  def self.collect_data_to_post
    aa = Kredis.json "recent_top_collections"
    previous_key = aa.value.keys[-2]
    latest_key = aa.value.keys[-1]
    previous_data = DiscordRequests.get_collection_data(previous_key)
    latest_data = DiscordRequests.get_collection_data(latest_key)
    debugger
    result = []
    latest_data.each do |data|
     last_record = previous_data.select{|a| a["name"] == data["name"]}
     result << { collection_name: data["name"],
        number_of_supply: data["total_supply"],
        holder_ratio: data["holder_ratio"],
        floor_price: data["floor_price"].round(2),
        floor_price_change: last_record.present? ? (data["floor_price"] - last_record[0]["floor_price"]).round(2) : "N/A",
        number_of_sales: data["total_sales"].round(2) ,
        number_of_sales_change: last_record.present? ? (data["total_sales"] - last_record[0]["total_sales"]).round(2) : "N/A",
        pricing: data["pricing"]
      }
    end
    result
  end
end


