class OpenseaRequests

  BASE_URL = 'https://api.opensea.io/api/v1'
  HEADERS = {'Accept': "application/json", "X-Api-Key": ENV["opensea_api_key"]}

  def self.get_collections
    response = HTTParty.get("#{BASE_URL}/collections?offset=10&limit=10", headers: HEADERS)
    body = JSON.parse(response.body)
    aa = Kredis.json "collection" 
    aa.value = body
  end

end