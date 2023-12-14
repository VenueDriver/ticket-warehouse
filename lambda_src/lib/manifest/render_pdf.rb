require_relative 'chrome_helper.rb'
require 'base64'

module ChromeHelper
  
  class RenderPdf
    def self.generate_encoded(html_content)
      self.new.generate_encoded(html_content)
    end
    
    def self.generate_pdf(html_content)
      self.new.generate_pdf(html_content)
    end
    
    def initialize
      @base_path = ChromeHelper.pdf_base_path
    end

    def generate_encoded(html_content)
      pdf_data = generate_pdf(html_content)
  
      Base64.encode64(pdf_data)
    end
    
    def generate_pdf(html_content)
      puts "Entered generate_pdf"
      write_path = using_base_path("chrome_input.html")

      output_pdf_filename = using_base_path("output-manifest.pdf")

      File.write(write_path , html_content)
      puts "After File.write"
      
      re_read = File.read(write_path)
      puts "After re_read"
              
      Dir.chdir("/tmp")
      command = create_command(write_path,output_pdf_filename)
      
      puts 'Generating PDF from HTML content with headless Chrome:'
      puts '  $ ' + command
      
      unless system(command)
        raise 'Failed to generate PDF with Chrome.'
      end
      
      pdf_data = File.open(output_pdf_filename, 'rb') { |file| file.read }
      
      puts 'exit_success3'
      pdf_data
    end
    
    def show_command
      puts create_command('input_file.html','output_file.txt')
    end

    private
    
    def using_base_path(filename)
      File.join(@base_path,filename)
    end
    
    def create_command(input_filename,pdf_out_name)
      command = "#{ChromeHelper.pdf_rb_zsh}
      #{ChromeHelper.chrome_command} \
      --allow-running-insecure-content \
      --autoplay-policy=user-gesture-required \
      --disable-component-update \
      --disable-domain-reliability \
      --disable-features=AudioServiceOutOfProcess,IsolateOrigins,site-per-process \
      --disable-print-preview \
      --disable-setuid-sandbox \
      --disable-site-isolation-trials \
      --disable-speech-api \
      --disable-web-security \
      --disk-cache-size=33554432 \
      --enable-features=SharedArrayBuffer \
      --ignore-gpu-blocklist \
      --in-process-gpu \
      --mute-audio \
      --no-default-browser-check \
      --no-pings \
      --no-sandbox \
      --no-zygote \
      --use-gl=angle \
      #{ChromeHelper.swift_shader_chrome_param} \
      --window-size=1920,1080 \
      --single-process \
      --disable-translate \
      --disable-extensions \
      --disable-background-networking \
      --safebrowsing-disable-auto-update \
      --metrics-recording-only \
      --disable-default-apps \
      --mute-audio \
      --no-first-run  \
      --headless \
      --v=1 \
      --disable-dev-shm-usage \
      --disable-dev-profile \
      --disable-software-rasterizer \
      --noerrdialogs \
      --print-to-pdf=#{pdf_out_name} \
      --print-to-pdf-no-header \
      --data-path=/tmp \
      --homedir=/tmp \
      --disk-cache-dir=/tmp \
      --user-data-dir=/tmp \
      --virtual-time-budget=100000  \
      file://#{input_filename}"
    end
    
  end
end

