require 'json'
require 'uri'
require 'cgi'

require_relative 'lib/manifest/manifest.rb'

$ses_client = Aws::SES::Client.new(region:'us-east-1')

def lambda_handler(event:, context:)
  puts "Manifest event: #{JSON.pretty_generate(event)}"

  # First, try to get the parameters from the event
  event_id = event['event_id']
  report_variant_in = event['report_variant']

  # If the headers and referer are present, try to get the parameters from the URL
  if event['headers'] && event['headers']['referer']
    referer_url = event['headers']['referer']
    uri = URI.parse(referer_url)
    params = CGI.parse(uri.query)

    event_id ||= params['event_id'].first
    report_variant_in ||= params['report_variant'].first
  end

  # If report_variant is still not found, default to 'preliminary'
  report_variant_in ||= 'preliminary'

  Manifest::Main.perform_report(event_id, report_variant_in, $ses_client)

  { statusCode: 200, body: JSON.generate('ok') }
end
