class UploaderBase
  EventDetails = Struct.new(:location,:start,:year,:month_name,:day_number,:event_name, keyword_init: true)

  def url_safe_name(name)
    name.gsub(/[^0-9A-Za-z]/, '-').squeeze('-').downcase
  end

  def to_ndjson(data)
    data.map { |item| JSON.generate(item) }.join("\n")
  end

  def create_event_details(event: )
    event_Event = event['Event']
    start = DateTime.parse(event['Event']['start'])

    EventDetails.new(
      location: url_safe_name(event_Event['organization_name']),
      start: start,
      year: start.year.to_s,
      month_name: Date::MONTHNAMES[start.month],
      day_number: start.day.to_s.rjust(2, '0'),
      event_name: url_safe_name(event_Event['name']),
    )
  end
end

class S3Uploader < UploaderBase
  def initialize(s3, bucket_name)
    @s3 = s3
    @bucket_name = bucket_name
  end

  def upload_to_s3(event: nil, data: , table_name: , date_str: nil)
    puts "Uploading #{data.length} records to #{table_name} on S3..." if ENV['DEBUG']
    puts "Records: #{data}" if ENV['DEBUG']

    if data.length == 0
      puts "No data to upload for #{table_name}" if ENV['DEBUG']
      return
    end
  
    if event
      event_name = url_safe_name(event['Event']['name'])
      file_path =
        generate_file_path(event: event, table_name: table_name) +
        "#{url_safe_name(event_name)}.json"
      puts "Archiving #{table_name} for event #{event_name} to S3 at file path: #{file_path}"
    elsif date_str
      file_path =
        generate_file_path(date_str: date_str, table_name: table_name) +
        "#{url_safe_name(data.first[:id])}.json"
      puts "Archiving #{table_name} for date #{date_str} to S3 at file path: #{file_path}"
    else
      raise ArgumentError, 'Invalid arguments'
    end
  
    s3_object = @s3.bucket(@bucket_name).object(file_path)
    s3_object.put(body: to_ndjson(data))
  end

  def generate_file_path(event: nil, table_name: nil, date_str: nil)
    if event && table_name
      puts "Generating file path for event #{event['Event']['name']} and table #{table_name}" if ENV['DEBUG']
      event_details = create_event_details(event: event)
      "#{table_name}/venue=#{event_details.location}/year=#{event_details.year}/month=#{event_details.month_name}/day=#{event_details.day_number}/"
    elsif date_str
      date = Date.parse(date_str)
      "#{table_name}/venue=unknown/year=#{date.year}/month=#{date.strftime('%B')}/day=#{date.day}/"
    else
      raise ArgumentError, 'Invalid arguments'
    end
  end

end

class LocalUploader < UploaderBase
  def initialize
    @fp_base = File.expand_path("~/Desktop/ts_examples/")
  end

  def upload_to_s3(event:, data: , table_name:)
    file_path = generate_file_path(event:event, table_name:table_name)

    File.write(file_path, to_ndjson(data))
  end

  def generate_file_path(event:, table_name:)
    ed = create_event_details(event:event)

    rest = "#{table_name}_#{ed.location}_#{ed.year}_#{ed.month_name}_#{ed.event_name}.json"
    File.join(@fp_base,rest)
  end
end