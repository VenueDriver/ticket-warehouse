require 'json'
require 'pry'
require 'date'
require 'rest-client'
require_relative 'api_errors.rb'

class TicketsauceApi
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

  def fetch_api_data(endpoint_url)
    puts "Fetching data from #{endpoint_url}"
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
    
    query_string = convert_to_query_string(params)
    
    fetch_api_data("https://api.ticketsauce.com/v2/events#{query_string}")
  end

  def fetch_orders(event:, return_line_item_fees: true)
    event_id = event['Event']['id']
    orders = []
    per_page = 100
    page = 1
  
    loop do
      params = {
        return_line_item_fees: return_line_item_fees,
        per_page: per_page,
        page: page
      }
      query_string = convert_to_query_string(params)

      puts "Fetching page #{page} of orders for event #{event['Event']['name']}"
  
      response = fetch_api_data("https://api.ticketsauce.com/v2/orders/#{event_id}#{query_string}")
      orders.concat(response)

      puts "Found #{response.length} orders for page #{page}"
      break if response.length < per_page
  
      page += 1
    end

    puts "Found #{orders.length} orders for event #{event['Event']['name']}"
  
    orders
  end

  def fetch_order_details(order:)
    order_id = order['Order']['id']
    fetch_api_data("https://api.ticketsauce.com/v2/order/#{order_id}")
  end

  def fetch_checkin_ids(event:)
    event_id = event['Event']['id']
    checkin_ids = []
    per_page = 5000
    page = 1
  
    loop do
      params = {
        per_page: per_page,
        page: page
      }
      query_string = convert_to_query_string(params)
  
      puts "Fetching page #{page} of check-in IDs for event #{event['Event']['name']}"

      puts "Query string: #{query_string}"
  
      response = fetch_api_data("https://api.ticketsauce.com/v2/tickets/checkin_ids/#{event_id}#{query_string}")
      checkin_ids.concat(response)
  
      puts "Found #{response.length} check-in IDs for page #{page}"
      break if response.length < per_page
  
      page += 1
    end
  
    puts "Found a total of #{checkin_ids.length} check-in IDs for event #{event['Event']['name']}"
  
    checkin_ids
  end  

  private

  def convert_to_query_string(params)
    query_string = params.empty? ? '' : '?' + URI.encode_www_form(params)
    query_string
  end

end
