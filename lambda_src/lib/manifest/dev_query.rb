module Manifest
  class DevQuery
    def initialize( data = nil )
      @file_path = File.join( File.dirname(__FILE__), 'cte_query_by_event_id.sql' )
    end

    def on_event_id(event_id)
      text = File.read( @file_path )
      replacement = "event_id ='#{event_id}'"
      text.gsub!( '(((true and true and true)))', replacement )
    end

    def full_query
      text = File.read( @file_path )
    end

  end
end