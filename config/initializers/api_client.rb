require 'api/open_sea_client'
require 'api/icy_tool_client'
require 'api/discord_client'

OpenSeaClient = API::OpenSeaClient.new('https://api.opensea.io/api/v1')
IcyToolClient = API::IcyToolClient.new('https://graphql.icy.tools/graphql')
DiscordClient = API::DiscordClient.new('https://discord.com/api')