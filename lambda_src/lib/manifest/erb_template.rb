module Manifest

  class ErbTemplate
    def initialize
      template_file_path = File.join( File.dirname(__FILE__), 'template.html.erb' )
      @template = File.read( template_file_path )
    end

    def render(data)
      erb_template = ERB.new(@template)
      erb_template.result(data.get_binding)
    end
  end
end