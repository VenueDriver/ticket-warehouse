require 'rest-client'
require 'json'
require 'pry'

RestClient.log = STDOUT

require 'dotenv'
Dotenv.load('../.env')

class TicketWarehouse
  attr_reader :access_token

  def initialize(client_id:, client_secret:)
    @client_id = client_id
    @client_secret = client_secret
    @access_token = nil
  end

  def authenticate!
    response = RestClient.post('https://api.ticketsauce.com/v2/oauth/token', {
      grant_type: 'client_credentials',
      client_id: @client_id,
      client_secret: @client_secret
    })
    @access_token = JSON.parse(response.body)['access_token']
  end

  def fetch_events
    response = RestClient.get('https://api.ticketsauce.com/v2/events', { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

end
