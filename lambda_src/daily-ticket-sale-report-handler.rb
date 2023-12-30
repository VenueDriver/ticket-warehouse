require 'aws-sdk-ses'
def lambda_handler(event:, context:)
  puts "Event: #{JSON.pretty_generate(event)}"



  { statusCode: 200, body: JSON.generate('💪') }
end