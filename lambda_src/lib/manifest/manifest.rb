require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require_relative 'omnia_data_rows_example.rb'
require_relative 'ticket_rows.rb'
require_relative 'report_demo.rb'
require 'erb'

module Manifest
  class << self

    def report_demo
      ReportDemo.render_all_omnia_events
    end

  end
end
