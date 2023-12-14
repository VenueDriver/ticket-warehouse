module AthenaOutput
  class Base

    def extract_arrays_list_from_response(response)
      arrays_list = []
  
      # Iterate through each row in the result set
      response.result_set.rows.each do |row|
        # Iterate through each data item in the row (though there appears to be only one data item per row in your example)
        row_strings = extract_strings_list_from_row(row)
        arrays_list << row_strings
      end
      arrays_list
    end
  
    def extract_strings_list_from_row(row)
      strings_list = []
  
      row.data.each do |datum|
        # Extract the var_char_value from the datum and add it to the strings_list
        strings_list << datum.var_char_value
      end
      strings_list
    end
  end

  class Original < Base
    def process(response)
      # Initialize an empty array to hold the strings
      strings_list = []
  
      # Iterate through each row in the result set
      response.result_set.rows.each do |row|
        # Iterate through each data item in the row (though there appears to be only one data item per row in your example)
        row_strings = extract_strings_list_from_row(row)
        strings_list.concat(row_strings)
      end
      strings_list
    end
  end

  class ArrayOfArray < Base
    def process(response)
      arrays_list = extract_arrays_list_from_response(response)
    end
  end

  class ArrayOfHashes < Base
    def process(response)
      arrays_list = extract_arrays_list_from_response(response)
  
      column_names =  arrays_list.first
      data_rows = arrays_list[1..-1]
  
      hashes_list = []
  
      data_rows.each do |data_row|
        hash = {}
        column_names.each_with_index do |column_name, index|
          hash[column_name] = data_row[index]
        end
        hashes_list << hash
      end
  
      hashes_list
    end
  end

  module FormatSwitchable
    def use_original_formatter!
      @formatter = AthenaOutput::Original.new
    end
  
    def use_array_of_array_formatter!
      @formatter = AthenaOutput::ArrayOfArray.new
    end
  
    def use_array_of_hashes_formatter!
      @formatter = AthenaOutput::ArrayOfHashes.new
    end
  end
end
