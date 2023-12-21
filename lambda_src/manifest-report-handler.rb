require_relative 'lib/manifest/manifest.rb'

require 'json'

$ses_client = Aws::SES::Client.new(region:'us-east-1')

def lambda_handler(event:, context:)
  puts "Manifest event: #{JSON.pretty_generate(event)}"

  # report_variant param
  # event_id param
  event_id = event['event_id']
  #report_variant_in = event['report_variant']
  report_variant_in = 'preliminary'
  Manifest::Main.perform_report(event_id, report_variant_in, $ses_client)

  { statusCode: 200, body: JSON.generate('ok') }
end
