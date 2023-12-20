require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require_relative 'omnia_data_rows_example.rb'
require_relative 'ticket_rows.rb'
require_relative 'chrome_helper.rb'
require_relative 'render_pdf.rb'
require_relative 'surcharge_csv.rb'

require 'aws-sdk-ses'

require_relative 'ses_test.rb'

require 'erb'

module Manifest
  class << self

    def report_demo
      ReportDemo.render_all_omnia_events
    end

  end
end
