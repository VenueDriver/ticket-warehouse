require 'aws-sdk-ssm'
require 'stripe'

class StripeArchiver
  def initialize
    ssm_client = Aws::SSM::Client.new(region: 'us-east-1')
    environment = ENV['ENV'] || 'development'
    param_name = "stripe_api_key-#{environment}"
    Stripe.api_key =
      ssm_client.get_parameter(
        name: param_name, with_decryption: true).parameter.value
    @s3 = Aws::S3::Resource.new(region: 'us-east-1')
    @bucket_name = ENV['BUCKET_NAME']
    @s3_uploader = S3Uploader.new(@s3, @bucket_name)
  end

  def archive_charges(time_range:)
    @successful_charges ||= fetch_successful_stripe_charges(time_range: time_range)
  end

  private

  def fetch_successful_stripe_charges(time_range:)
    print "Fetching successful Stripe charges for #{time_range}..."

    cutoff =
      case time_range
      when 'current'
        # Now minus one day.
        (Time.now - 1 * 24 * 60 * 60).to_i
      when 'upcoming'
        # Now minus one day.
        (Time.now - 1 * 24 * 60 * 60).to_i
      when 'recent'
        # Now minus 30 days.
        (Time.now - 90 * 24 * 60 * 60).to_i
      else
        # The previous year.
        (Time.now - 365 * 24 * 60 * 60).to_i
      end

    # Format the cutoff as a date.
    cutoff_date = Time.at(cutoff).strftime('%Y-%m-%d')
    puts "cutoff_date: #{cutoff_date}"

    charges = []

    payments =
      Stripe::Charge.list(
        limit: 100, created: { gte: cutoff })

    payments.auto_paging_each do |charge|
      # puts Time.at(charge.created).strftime('%Y-%m-%d')
      if charge.calculated_statement_descriptor =~ /ticket driver/i
        # puts "skipping, statement descriptor: #{charge.calculated_statement_descriptor}"
        next
      end
      unless charge.status.eql?('succeeded')
        # puts "skipping, status: #{charge.status}"
        next
      end
      if charge[:status] == 'succeeded'
        upload_to_s3(
          date_str: Time.at(charge[:created]).strftime('%Y-%m-%d'),
          data: [
            {
              id:                   charge[:id],
              created:              Time.at(charge[:created]),
              event_date:           charge['metadata']['event_start'],
              payment_intent:       charge['payment_intent'],
              ticketsauce_order_id: charge['metadata']['order_id']
            }
          ],
          table_name: 'stripe_charges')

      end
    end
    puts ''

    charges
  end

  private

  def upload_to_s3(date_str:, data:, table_name:)
    @s3_uploader.upload_to_s3(
      date_str:   date_str,
      data:       data,
      table_name: table_name)
  end

  def generate_file_path(date_str:, table_name:)
    @s3_uploader.generate_file_path(
      date_str:date_str,
      table_name:table_name)
  end

end