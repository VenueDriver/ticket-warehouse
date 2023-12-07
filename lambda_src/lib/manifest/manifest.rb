require_relative '../../athena-manager.rb'
require_relative 'dev_query.rb'
require_relative 'omnia_data_rows_example.rb'
require_relative 'ticket_rows.rb'
require 'erb'

module Manifest
  class << self

    def test_rendering
      template_file_path = File.join( File.dirname(__FILE__), 'template.html.erb' )
      template = File.read( template_file_path )
      erb_template = ERB.new(template)

      output_data = self.transform_all_omnia_events

      single_event = output_data[1]

      str = erb_template.result(single_event.get_binding)
      outpath = File.expand_path "~/Desktop/manifest.html"
      File.write(outpath, str)

      str
    end 

    def run_query_on_event_id(event_id)
      query_builder = DevQuery.new
      query_string = query_builder.on_event_id(event_id)
      #puts "Query string: #{query_string}"

      athena_manager = AthenaManager.new('production')
      athena_manager.use_array_of_hashes_formatter!

      results = athena_manager.start_query(query_string: query_string)
    end

    def transform_all_omnia_events
      OmniaExamples.examples.map do |ticket_rows|
        t_row = TicketRows.new(ticket_rows)
        #t_row.transformed_json
        t_row.output_struct
      end
    end

  end
end
