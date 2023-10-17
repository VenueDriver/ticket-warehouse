require 'json'
require 'pry'
require 'date'
require 'rest-client'
require 'aws-sdk-s3'

RestClient.log = STDOUT

require 'dotenv'
Dotenv.load('../.env')

class TicketWarehouse
  attr_reader :access_token

  def initialize(client_id:, client_secret:)
    @client_id = client_id
    @client_secret = client_secret
    @access_token = nil
    @s3 = Aws::S3::Resource.new(region: 'us-east-1')
  end

  def authenticate!
    response = RestClient.post('https://api.ticketsauce.com/v2/oauth/token', {
      grant_type: 'client_credentials',
      client_id: @client_id,
      client_secret: @client_secret
    })
    @access_token = JSON.parse(response.body)['access_token']
  end

  def fetch_events(organization_id: nil, start_before: nil, start_after: nil)
    params = {}
    params[:organization_id] = organization_id if organization_id
    params[:start_before] = start_before if start_before
    params[:start_after] = start_after if start_after
    
    query_string = params.empty? ? '' : '?' + URI.encode_www_form(params)
    
    url = "https://api.ticketsauce.com/v2/events#{query_string}"
    response = RestClient.get(url, { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def fetch_orders(event:)
    event_id = event['Event']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/orders/#{event_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def fetch_order_details(order:)
    order_id = order['Order']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/order/#{order_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def fetch_checkin_ids(event:)
    event_id = event['Event']['id']
    response = RestClient.get("https://api.ticketsauce.com/v2/tickets/checkin_ids/#{event_id}", { Authorization: "Bearer #{@access_token}" })
    JSON.parse(response.body)
  end

  def archive_events(time_range:nil)
    start_before = nil
    start_after = nil
    case time_range
    when :current
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
      start_before =
        # Now plus two days.
        (Time.now + 86400 * 2).strftime('%Y-%m-%d')
    when :upcoming
      start_after =
        # Now minus one day.
        (Time.now - 86400).strftime('%Y-%m-%d')
    end

    events = fetch_events(
      start_before: start_before,
      start_after: start_after)
    events.each do |event|
      upload_event_to_s3(event)
    end
  end
  
  def generate_file_path(event)
    location = url_safe_name(event['Event']['location'])
    event_name = url_safe_name(event['Event']['name'])
    start = DateTime.parse(event['Event']['start'])
    
    year = start.year.to_s
    month_name = Date::MONTHNAMES[start.month]
    day_number = start.day.to_s.rjust(2, '0')
    
    "/events/#{location}/#{year}/#{month_name}/#{day_number}/#{event_name}.json"
  end
  
  private
  
  def url_safe_name(name)
    name.gsub(/[^0-9A-Za-z]/, '-').squeeze('-').downcase
  end

  def upload_event_to_s3(event)
    file_path = generate_file_path(event)
    puts "Archiving event to S3 at file path: #{file_path}" +
      "\n#{JSON.pretty_generate(event)}"
    bucket_name = ENV['BUCKET_NAME']
    
    s3_object = @s3.bucket(bucket_name).object(file_path)
    
    s3_object.put(body: event.to_json)
  end

end
