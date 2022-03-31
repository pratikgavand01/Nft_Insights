class DiscordRequests < ApplicationServices
  HEADERS = {"Content-Type": "multipart/form-data"}
  URL = ENV["DISCORD_WEBHOOK"]

  # Collect data from redis and posted to Discord
  def self.post_message
    result = self.collect_data_to_post
    rows_content= ""
    result.each_with_index do |data, i|
      pricing_string = ""
      data[:pricing].each_with_index do |(key, value), index|
        if index >= 5
          break
        end 
        pricing_string += "<div class='pricing'>
                              <span style='float: left;'>#{(key.to_f/1000000000000000000).round(4)}</span>
                              <span>=></span>
                              <span style='float: right;'>#{value}</span>
                            </div>"
      end
      rows_content = rows_content +
        "<tr>
          <td><span>#{data[:collection_name]}</span><br/><span>(#{data[:number_of_supply]})</span><br/> <span class='text-grey'>(#{data[:holder_ratio].round(2)}%)</span> </td>
          <td>#{data[:floor_price]} <br/><span class=#{select_color_class(data[:floor_price_change])}>(#{data[:floor_price_change]}%)</span></td>
          <td>#{data[:number_of_sales]}<br/><span class=#{select_color_class(data[:number_of_sales_change])}>(#{data[:number_of_sales_change]}%)</span></td>
          <td><div class='pricing_row'>#{pricing_string}</div></td>
        </tr>"
    end

    
    kit = IMGKit.new(prepare_html(rows_content))
    file = kit.to_file("public/nft_reports/stats.jpg")

    # body = {
    #   "username" => "Testing NFT Analytics",
    #   "avatar_url" => "https://i.imgur.com/4M34hi2.png",
    #   "embeds" => [{
    #     "title" => "Top 5 NFTs",
    #     "color" => 15258703,
    #     "image" => {
    #       "url"=> "http://efa8-210-89-62-14.ngrok.io/nft_reports/#{file.path.split("/")[-1]}"
    #     }
    #     }]
    #   }
    body = {
      "username": "Testing NFT Analytics",
      "avatar_url": "https://i.imgur.com/4M34hi2.png",
      "content": "**Top 5 NFTs**",
      # "embeds": [{
      #   "title": "Top 5 NFTs",
      #   "color": 15258703,
      #   "image": {
      #     "url": "attachment://#{file.path.split("/")[-1]}}"
      #   }
      #   }], 
      "attachments": [{
          "id": 0,
          "description": "Image of a cute little cat",
          "filename": file
      }]
      }
  
    response = HTTParty.post(URL, headers: HEADERS, body: body)
  end

  def self.collect_data_to_post
    aa = Kredis.json "recent_top_collections"
    previous_key = aa.value.keys[-2]
    latest_key = aa.value.keys[-1]
    previous_data = DiscordRequests.get_collection_data(previous_key)
    latest_data = DiscordRequests.get_collection_data(latest_key)
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
        pricing: data["pricing"].sort_by{|k,v| k.to_i}.to_h
      }
    end
    result
  end

  def self.select_color_class(data)
    class_name = data.to_f > 0 ? 'text-green' : (data.to_f < 0 ? 'text-red' : '')
  end

  def self.prepare_html(rows_content)
    contect = "<!DOCTYPE html>
                <html>
                  <head>
                    <style>
                      table {
                        font-family: arial, sans-serif;
                        border-collapse: collapse;
                        width: 100%;
                        font-size: 12;
                      }

                      body {
                        background-color: #000000;
                        color: #fb8b1e;
                      }

                      td, th {
                        border: 1px solid #1A2128;
                        text-align: left;
                        padding: 8px;
                        font-size: 20px;
                        color: #fb8b1e;
                      }

                      .pricing{
                        text-align: center
                      }

                      .text-red{
                        color: #ff433d;
                      }

                      .text-green{
                        color: #4af6c3;
                      }
                      .text-grey{
                        color: #a6b5c5
                      }
                    
                    </style>
                  </head>
                  <body>
                    <h2>Top NFT Collections</h2>
                    <table>
                      <tr>
                        <th>NFT collections <br>(# of supply)<br>(Holder Ratio)</th>
                        <th>Floor price<br>(%Change)</th>
                        <th># of sales<br>(%Change)</th>
                        <th>Pricing</th>
                      </tr>
                      #{rows_content}
                    </table>
                  </body>
                </html>"
  end
end

