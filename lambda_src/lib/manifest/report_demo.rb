require_relative 'event_data_fetcher.rb'
require_relative 'ticket_rows.rb'

module Manifest
  class ReportDemo
    attr_reader :event_id, :athena_manager, :query_builder, :last_query_result
    def initialize(event_id = '65529868-6a84-4963-8bba-52e892144192')
      @event_id = event_id

      @event_data_fetcher = EventDataFetcher.new('production')
    end

    attr_reader :from_athena_step, :ticket_rows_step
    attr_reader :render_step, :output_structs_step
    def process
      @from_athena_step = fetch_data_from_athena

      @ticket_rows_step = TicketRows.new(@from_athena_step)

      @output_structs_step = @ticket_rows_step.output_struct

      @render_step = render!(@output_structs_step).tap do |str|
        #write results to file based on event date, venue, event title
        file_name = @output_structs_step.dev_file_name_full
        File.write(file_name, str)
      end
    end

    def render!(output_structs)
      template_file_path = File.join( File.dirname(__FILE__), 'template.html.erb' )
      template = File.read( template_file_path )
      erb_template = ERB.new(template)

      str = erb_template.result(output_structs.get_binding)
    end

    def fetch_data_from_athena
      @event_data_fetcher.fetch_data_from_athena(@event_id)
    end

    class << self
      def r_omnia_event_ids
        ['654da5d9-4740-4b01-ad17-4eef92144192',
       '654dab01-cb64-4ac0-805b-564892144192',
        '654da651-b7a4-43ac-a772-4e9c92144192',
        '655299d0-8500-402e-a1bb-572492144192',
        '655297f0-7e68-4e36-9911-515c92144192',
        '65529598-5810-4684-81c5-443492144192',
        '65529868-6a84-4963-8bba-52e892144192',
        '6552982d-5120-4e96-a0a4-4f7892144192',
        '655293f5-1160-40da-8544-443b92144192',
        '655293b9-089c-4451-8cf2-417f92144192',
        '65529959-8988-4c57-b35a-52e892144192',
        '655298e0-d3b0-4b33-9826-546192144192',]
      end

      def render_all_omnia_events
        r_omnia_event_ids.map do |event_id|
          puts "Processing event_id: #{event_id}"
          demo = ReportDemo.new(event_id)
          demo.tap{ |d| d.process}
        end
      end

    end
  end
end