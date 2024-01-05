require 'json'
require 'uri'
require 'cgi'

require_relative 'lib/manifest/manifest.rb'

$ses_client = Aws::SES::Client.new(region:'us-east-1')

def send_report_lambda_handler(event:, context:)
  puts "Event: #{JSON.pretty_generate(event)}"

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

# report_scheduling_lambda_handler(event: event, context: context)
def report_scheduling_lambda_handler(event:, context:)
  puts "Event: #{JSON.pretty_generate(event)}"

  # Global setting to switch on distro lists example
  #Manifest::Scheduling.use_distribution_list = true
  puts "Manifest::Scheduling.use_distribution_list: #{Manifest::Scheduling.use_distribution_list}"

  #env_in = 'production' #;ENV['ENV']
  env_in = ENV['ENV']
  manager = Manifest::Scheduling::Manager.create_from_lambda_input_event(event,env_in, ses_client:$ses_client)
  run_options = Manifest::Scheduling::Manager.create_run_options(event)

  r = manager.process_reports_using_now

  # if run_options.try_send_summary_email?
  #   manager.send_demo_email_summary_soft_launch
  # end
  # tbd: return value
  r
end

def simulate_report_handler
  report_scheduling_lambda_handler(event: {}, context: nil)
  #report_scheduling_lambda_handler(event: {'try_send_summary_email' => 'try_send_summary_email'}, context: nil)
end

# def self.create_from_lambda_input_event(event,env_in = ENV['ENV'], ses_client:)
