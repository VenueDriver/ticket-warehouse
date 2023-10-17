require 'json'

def lambda_handler(event:, context:)
  puts "Received event: #{JSON.pretty_generate(event)}"
  puts "Lambda context: #{JSON.pretty_generate(context)}"

  { statusCode: 200, body: JSON.generate('💪') }
end
