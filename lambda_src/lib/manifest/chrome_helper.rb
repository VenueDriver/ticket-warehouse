module ChromeHelper
  extend self
  
  class << self
    attr_accessor :run_from_simulate
  end
  self.run_from_simulate = true
  
  def swift_shader_chrome_param
    if self.run_from_simulate
      ''
    else
      '--use-angle=swiftshader'
    end
  end
  
  def pdf_rb_zsh
    if self.run_from_simulate
      'source ~/.rb_zsh'
    else
      ''
    end
  end
  
  def chrome_command
    if self.run_from_simulate
      'headless-chrome '
    else
      '/opt/bin/headless-chromium '
    end
  end
  
  def pdf_base_path
    if self.run_from_simulate
      File.expand_path("~/Desktop")
    else
      File.expand_path("/tmp")
    end
  end
end