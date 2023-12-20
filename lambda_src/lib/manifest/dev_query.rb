module Manifest
  class DevQuery
    def initialize( data = nil )
      @file_path = File.join( File.dirname(__FILE__), 'cte_query_by_event_id.sql' )
    end

    def on_event_id(event_id)
      text = File.read( @file_path )
      replacement = event_id
      text.gsub!( 'YOUR_EVENT_ID_HERE', replacement )
    end

  end
end