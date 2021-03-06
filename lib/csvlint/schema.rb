module Csvlint
  
  class Schema
    
    include Csvlint::ErrorCollector
    
    attr_reader :uri, :fields, :title, :description, :uses_index, :validate_header_name
    
    def initialize(uri, fields=[], title=nil, description=nil, uses_index=false, validate_header_name=false)
      @uri = uri
      @fields = fields
      @title = title
      @description = description
      @uses_index = uses_index
      @validate_header_name = validate_header_name
      reset
    end

    def validate_header(header)
      reset
      if @uses_index
        validate_header_by_index header
      else
        validate_header_by_order header
      end
      return valid?
    end

    def validate_header_by_order header
      fields.each_with_index do |field,i|
        required = field.constraints["required"] || false
        name = header[i]
        build_errors(:header_name, :schema, nil, i+1, name) if required && (name.nil? || name.downcase != field.name.downcase)
      end
    end

    def validate_header_by_index header
      fields.each_with_index do |field,i|
        index = i + 1

        index = field.constraints["index"] unless field.constraints["index"].nil?
        
        name = header[index-1]

        if  name.nil? 
          build_errors(:missing_value, :schema, nil, index, name)
        else
          if @validate_header_name && (field.name.downcase != name.downcase)
            build_errors(:header_name, :schema, nil, index, name)
          end
        end

      end
    end
        
    def validate_row(values, row=nil)
      reset
    
      if @uses_index
        validate_row_by_index(values, row)
      else
        validate_row_by_order(values, row)
      end

      return valid?
    end

    def validate_row_by_index(values, row=nil)
      verify_columns_by_index(values, row)


      fields.each_with_index do |field,i|

        index = i + 1

        index = field.constraints["index"] unless field.constraints["index"].nil?

        value = values[index-1] || ""
        
        result = field.validate_column(value, row, index)

        @errors += fields[i].errors
        @warnings += fields[i].warnings        
      end
    end

    def validate_row_by_order(values, row=nil)
      verify_columns_by_order(values, row)

      fields.each_with_index do |field,i|
        value = values[i] || ""
        result = field.validate_column(value, row, i+1)
        @errors += fields[i].errors
        @warnings += fields[i].warnings        
      end
    end

    def verify_columns_by_order(values, row=nil)
      if values.length < fields.length
        fields[values.size..-1].each_with_index do |field, i|
          build_warnings(:missing_column, :schema, row, values.size+i+1)
        end
      end
      if values.length > fields.length
        values[fields.size..-1].each_with_index do |data_column, i|
          build_warnings(:extra_column, :schema, row, fields.size+i+1)
        end
      end
    end

    def verify_columns_by_index(values, row=nil)
      fields.each do |field|
        index = field.constraints["index"] || 1
        build_warnings(:missing_column, :schema, row, index) if values[index-1].nil?
      end
    end
    
    def Schema.from_json_table(uri, json)
      fields = []
      json["fields"].each do |field_desc|
        fields << Csvlint::Field.new( field_desc["name"] , field_desc["constraints"], 
          field_desc["title"], field_desc["description"] )
      end if json["fields"]
      return Schema.new( uri , fields, json["title"], json["description"] , json["uses_index"])
    end
    
    def Schema.load_from_json_table(uri)
      begin
        json = JSON.parse( open(uri).read )
        return Schema.from_json_table(uri,json)
      rescue
        return nil
      end
    end
    
  end
end