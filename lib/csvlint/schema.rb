module Csvlint
  
  class Schema
    
    include Csvlint::ErrorCollector
    
    attr_reader :uri, :fields, :title, :description, :uses_index
    
    def initialize(uri, fields=[], title=nil, description=nil, uses_index=false)
      @uri = uri
      @fields = fields
      @title = title
      @description = description
      @uses_index = uses_index
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
      header.each_with_index do |name,i|     
        build_warnings(:header_name, :schema, nil, i+1, name) if fields[i].nil? || fields[i].name != name
      end
    end

    def validate_header_by_index header
      header.each_with_index do |name,i|
        current_field = fields.find{|a| a.constraints["index"] == i+1}
        build_warnings(:header_name, :schema, nil, i+1, name) if  current_field.nil? || current_field.name != name
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
        index = field.constraints["index"]-1
        value = values[index] || ""
        result = field.validate_column(value, row, index+1)
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
        index = field.constraints["index"]
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