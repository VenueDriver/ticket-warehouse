# lambda_src/handler.rb

def lambda_handler(event:, context:)
  # Your Ruby code here
  { statusCode: 200, body: JSON.generate('Hello from Ruby Lambda!') }
end
