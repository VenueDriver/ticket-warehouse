require 'json'
require 'pry'
require 'date'
require 'rest-client'

class TicketsauceApi
  attr_reader :access_token

  class APIError < StandardError
  end
  class APINoDataError < StandardError
  end

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

  def fetch_api_data(endpoint_url)
    response = RestClient.get(endpoint_url, { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body).tap do |data|
      raise APINoDataError.new(data['error']) if data.is_a?(Hash) && data['error'].eql?('no_data')
      raise APIError.new(data['error']) if data.is_a?(Hash) && data['error']
    end
  end

  def fetch_events(organization_id: nil, start_before: nil, start_after: nil)
    params = {}
    params[:organization_id] = organization_id if organization_id
    params[:start_before] = start_before if start_before
    params[:start_after] = start_after if start_after
    
    query_string = params.empty? ? '' : '?' + URI.encode_www_form(params)
    
    fetch_api_data("https://api.ticketsauce.com/v2/events#{query_string}")
  end

  def fetch_orders(event:)
    event_id = event['Event']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/orders/#{event_id}")
  end

  def fetch_order_details(order:)
    order_id = order['Order']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/order/#{order_id}")
  end

  def fetch_checkin_ids(event:)
    event_id = event['Event']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/tickets/checkin_ids/#{event_id}")
  end

end
