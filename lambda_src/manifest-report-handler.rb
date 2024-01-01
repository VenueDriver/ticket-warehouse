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
  print "From Lambda event:"
  print "  event_id: #{event_id}\n"
  print "  report_variant_in: #{report_variant_in}\n"

  # If rawQueryString is present, try to get the parameters from it
  if event['rawQueryString']
    print "Checking rawQueryString:"

    params = CGI.parse(event['rawQueryString'])

    event_id ||= params['event_id'].first
    report_variant_in ||= params['report_variant'].first

    print "  event_id: #{event_id}\n"
    print "  report_variant_in: #{report_variant_in}\n"
  end

  # If report_variant is still not found, default to 'preliminary'
  report_variant_in ||= 'preliminary'

  print "Final values:"
  print "  event_id: #{event_id}\n"
  print "  report_variant_in: #{report_variant_in}\n"

  Manifest::Main.perform_report(event_id, report_variant_in, $ses_client)

  { statusCode: 200, body: JSON.generate('ok') }
end
