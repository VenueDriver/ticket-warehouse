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

  def archive_charges
    @successful_charges ||= fetch_successful_stripe_charges

    @successful_charges.each do |charge|
      upload_to_s3(
        date_str: charge[:created].strftime('%Y-%m-%d'),
        data: [charge],
        table_name: 'stripe_charges')
    end
  end

  private

  def fetch_successful_stripe_charges
    one_week_ago = (Time.now - 7 * 24 * 60 * 60).to_i
    charges = []

    payments =
      Stripe::Charge.list(
        limit: 100, created: { gte: one_week_ago })

    payments.auto_paging_each do |charge|
      next if charge.calculated_statement_descriptor =~ /ticket driver/i
      next unless charge.status.eql?('succeeded')
      if charge[:status] == 'succeeded'
        charges <<
          {
            id:             charge[:id],
            created:        Time.at(charge[:created]),
            event_date:     charge['metadata']['event_start'],
            payment_intent: charge['payment_intent'],
            charge_id:      charge['id']
          }
      end
    end

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