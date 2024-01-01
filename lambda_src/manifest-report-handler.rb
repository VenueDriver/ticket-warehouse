require 'json'
require 'uri'
require 'cgi'

require_relative 'lib/manifest/manifest.rb'

$ses_client = Aws::SES::Client.new(region:'us-east-1')

def lambda_handler(event:, context:)
  puts "Manifest event: #{JSON.pretty_generate(event)}"

  referer_url = event['headers']['referer']
  uri = URI.parse(referer_url)
  params = CGI.parse(uri.query)

  # If the parameters are not present in the event, extract them from the URL parameters
  event_id = event['event_id'] || params['event_id'].first
  report_variant_in = event['report_variant'] || params['report_variant'].first || 'preliminary'  

  Manifest::Main.perform_report(event_id, report_variant_in, $ses_client)

  { statusCode: 200, body: JSON.generate('ok') }
end
