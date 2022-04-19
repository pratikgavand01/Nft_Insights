class DiscordService < ApplicationService
  # Collect data from redis and posted to Discord
  class << self
    def post_message
      result = collect_data_to_post("recent_top_collections")
      rows_content = ""
      result.each_with_index do |data, i|
        pricing_string = ""
        data[:pricing].each_with_index do |(key, value), index|
          if index >= 5
            break
          end
          price_key = (key.to_f / 1000000000000000000).round(4)
          number_of_nfts_change = data[:last_fetched_pricing][key].present? ? value - data[:last_fetched_pricing][key] : "N/A"
          pricing_string += "<div class='pricing'>
                                <span style='float: left;'>#{price_key}</span>
                                <span>=></span>
                                <span style='float: right;'>#{value} <span class=#{select_color_class(number_of_nfts_change)}>(#{number_of_nfts_change})</span>
                              </div>"
        end
        rows_content =
          "<tr>
            <td><span>#{data[:collection_name]}</span><br/><span>(#{data[:number_of_supply]})</span><br/> <span class='text-grey'>(#{data[:holder_ratio].round(2)}%)</span> </td>
            <td>#{data[:floor_price]} <br/><span class=#{select_color_class(data[:floor_price_change])}>(#{check_exist(data[:floor_price_change])})</span></td>
            <td>#{data[:number_of_sales]}<br/><span class=#{select_color_class(data[:number_of_sales_change])}>(#{check_exist(data[:number_of_sales_change])})</span></td>
            <td>#{data[:total_listed]}<br/><span class=#{select_color_class(data[:total_listed_change])}>(#{check_exist(data[:total_listed_change])})</span></td>
            <td><div class='pricing_row'>#{pricing_string}</div></td>
          </tr>"
      end
      #convert HTML to Image file and save it to public folder
      kit = IMGKit.new(prepare_html(rows_content))
      file = kit.to_file("public/nft_reports/stats.jpg")

      body = {
        "username": "Testing NFT Analytics",
        "avatar_url": "https://i.imgur.com/4M34hi2.png",
        "content": "**Top 5 NFTs**",
        "attachments": [{
                          "id": 0,
                          "description": "Top 5 nfts",
                          "filename": Faraday::UploadIO.new(file, 'image/png')
                        }]
      }
      DiscordClient.rest_api(:post,ENV["DISCORD_WEBHOOK"],body)
    end

    private

    def collect_data_to_post(key_name = "recent_top_collections")
      aa = Kredis.json(key_name)
      previous_key = aa.value.keys[-2]
      latest_key = aa.value.keys[-1]
      previous_data = DiscordService.get_collection_data(previous_key)
      latest_data = DiscordService.get_collection_data(latest_key)
      result = []
      latest_data.each do |data|
        last_record = previous_data.select { |a| a["name"] == data["name"] }
        result << { collection_name: data["name"],
                    number_of_supply: data["total_supply"],
                    holder_ratio: data["holder_ratio"],
                    floor_price: data["floor_price"].to_f.round(4),
                    floor_price_change: last_record.present? ? get_change_in_percentage(data["floor_price"], last_record[0]["floor_price"]) : "N/A",
                    number_of_sales: data["total_sales"],
                    number_of_sales_change: last_record.present? ? get_change_in_percentage(data["total_sales"], last_record[0]["total_sales"]) : "N/A",
                    total_listed: data["total_listed"],
                    total_listed_change: last_record.present? ? (data["total_listed"] - last_record[0]["total_listed"]).round(2) : "N/A",
                    pricing: data["pricing"].sort_by { |k, v| k.to_i }.to_h,
                    last_fetched_pricing: last_record.present? ? last_record[0]["pricing"].sort_by { |k, v| k.to_i }.to_h : {}
        }
      end
      result
    end

    def select_color_class(data)
      if data.to_f > 0.0
        'text-green'
      else
        data.to_f < 0.0 ? 'text-red' : 'text-grey'
      end
    end

    def prepare_html(rows_content)
      "<!DOCTYPE html>
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

                        tr {
                          vertical-align: top;
                        }

                        th {
                          width: 20%;
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
                        h2 {
                          float: left;
                        }
                        h4 {
                          float: right;
                        }
                      </style>
                    </head>
                    <body>
                      <div class='header-div'>
                       <h2>Top NFT Collections</h2>
                       <h4>#{Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')} UTC</h4>
                      </div>
                      <table>
                        <tr>
                          <th>NFT collections <br>(# of supply)<br><span class='text-grey'>(Holder Ratio)</span></th>
                          <th>Floor price<br><span class='text-grey'>(%Change)</span</th>
                          <th># of Sales<br><span class='text-grey'>(%Change)</span></th>
                          <th>% Total Listed<br><span class='text-grey'>(%Change)</span></th>
                          <th>Listing <br/><span class='text-grey'>(Price => #NFTs)</th>
                        </tr>
                        #{rows_content}
                      </table>
                    </body>
                  </html>"
    end

    def check_exist(value)
      value = "N/A" if value.nan?
      return value if value == "N/A"
      "#{value}%"
    end
  end

end

