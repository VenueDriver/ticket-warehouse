require 'aws-sdk-ses'
require_relative 'lib/report'

def lambda_handler(event:, context:)
  puts "Event: #{JSON.pretty_generate(event)}"

  daily_report = Report::Daily.new
  daily_report.send_email(daily_report.generate)

  { statusCode: 200, body: JSON.generate('💪') }
end