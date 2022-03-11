class DiscordRequests < ApplicationServices
  HEADERS = {"Content-Type": "application/json"}
  URL = ENV["discord_webhook"]

  def self.post_message
    redis_collection = Kredis.json "collection"
    fields = []
    #format 1
    redis_collection.value["collections"].each_with_index do |data, i|
      fields << {
        "name" => data["name"],
        "value" => "#{data["stats"]["one_day_volume"].round(2)} | #{data["stats"]["seven_day_volume"].round(2)} | #{data["stats"]["thirty_day_volume"].round(2)} | #{data["stats"]["one_day_change"]*100}% | #{data["stats"]["seven_day_change"]*100}% | #{data["stats"]["floor_price"]} | #{data["stats"]["num_owners"]} | #{data["stats"]["count"]}"
      }
    end

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

    body = {
      "username" => "Testing NFT Analytics",
      "avatar_url" => "https://i.imgur.com/4M34hi2.png",
      "content" => "Testing New Updates",
      # "embeds" => embeds #format 3

      "embeds" => [{
        "title" => "New Updates",
        "description" => "Following is list of top 10 NFTs along with details like 24h Volumn, 7d Volumn, 30d Volumn, 1d Change(%), 7d Change(%), Floor price, Owners, Items.",
        "color": 15258703,
        "fields" => fields
      }]

    }
    response = HTTParty.post(URL, headers: HEADERS, body: body.to_json)
  end
end


