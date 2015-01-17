require 'spec_helper'

describe Csvlint::Schema do
  
  it "should tolerate missing fields" do
    schema = Csvlint::Schema.from_json_table("http://example.org", {})
    expect( schema ).to_not be(nil)
    expect( schema.fields.empty? ).to eql(true)
  end

  it "should tolerate fields with no constraints" do
    schema = Csvlint::Schema.from_json_table("http://example.org", {
      "fields" => [ { "name" => "test" } ]
    })
    expect( schema ).to_not be(nil)
    expect( schema.fields[0].name ).to eql("test")
    expect( schema.fields[0].constraints ).to eql({})
  end
      
  it "should validate against the schema" do
    field = Csvlint::Field.new("test", { "required" => true } )
    field2 = Csvlint::Field.new("test", { "minLength" => 3 } )
    schema = Csvlint::Schema.new("http://example.org", [field, field2] )
    
    expect( schema.validate_row( ["", "x"] ) ).to eql(false)
    expect( schema.errors.size ).to eql(2)
    expect( schema.errors.first.type).to eql(:missing_value)
    expect( schema.errors.first.category).to eql(:schema)
    expect( schema.errors.first.column).to eql(1)
    expect( schema.validate_row( ["abc", "1234"] ) ).to eql(true)
      
  end
  
  it "should include validations for missing columns" do
    minimum = Csvlint::Field.new("test", { "minLength" => 3 } )
    required = Csvlint::Field.new("test2", { "required" => true } )
    schema = Csvlint::Schema.new("http://example.org", [minimum, required] )
    
    expect( schema.validate_row( ["abc", "x"] ) ).to eql(true)
      
    expect( schema.validate_row( ["abc"] ) ).to eql(false)
    expect( schema.errors.size ).to eql(1)
    expect( schema.errors.first.type).to eql(:missing_value)

    schema = Csvlint::Schema.new("http://example.org", [required, minimum] )
    expect( schema.validate_row( ["abc"] ) ).to eql(false)
    expect( schema.errors.size ).to eql(1)
    expect( schema.errors.first.type).to eql(:min_length)    
  end
  
  it "should warn if the data has fewer columns" do
    minimum = Csvlint::Field.new("test", { "minLength" => 3 } )
    required = Csvlint::Field.new("test2", { "maxLength" => 5 } )
    schema = Csvlint::Schema.new("http://example.org", [minimum, required] )

    expect( schema.validate_row( ["abc"], 1 ) ).to eql(true)
    expect( schema.warnings.size ).to eql(1)
    expect( schema.warnings.first.type).to eql(:missing_column)
    expect( schema.warnings.first.category).to eql(:schema)
    expect( schema.warnings.first.row).to eql(1)
    expect( schema.warnings.first.column).to eql(2)

    #no ragged row error    
    expect( schema.errors.size ).to eql(0)
  end
  
  it "should warn if the data has additional columns" do
    minimum = Csvlint::Field.new("test", { "minLength" => 3 } )
    required = Csvlint::Field.new("test2", { "required" => true } )
    schema = Csvlint::Schema.new("http://example.org", [minimum, required] )

    expect( schema.validate_row( ["abc", "x", "more", "columns"], 1 ) ).to eql(true)
    expect( schema.warnings.size ).to eql(2)
    expect( schema.warnings.first.type).to eql(:extra_column)
    expect( schema.warnings.first.category).to eql(:schema)
    expect( schema.warnings.first.row).to eql(1)
    expect( schema.warnings.first.column).to eql(3)

    expect( schema.warnings[1].type).to eql(:extra_column)
    expect( schema.warnings[1].column).to eql(4)

    #no ragged row error    
    expect( schema.errors.size ).to eql(0)        
  end 

  context "when using index for columns" do 
    it "should validate rows using the index defined order of columns" do
      uses_index = true

      first = Csvlint::Field.new("first", { "index" => 1 } )
      second = Csvlint::Field.new("second" )
      third = Csvlint::Field.new("third", { "index" => 3, "required" => true } )
      schema = Csvlint::Schema.new("http://example.org", [third,second,first], "", "", uses_index)

      expect( schema.validate_row( ["none", "none", "", "none"], 1 ) ).to eql(false)
      expect( schema.errors.size ).to eql(1)
    end 

    it "should warn if the data has fewer columns" do
      uses_index = true

      first = Csvlint::Field.new("first", { "index" => 1 } )
      second = Csvlint::Field.new("second", { "index" => 2 } )
      third = Csvlint::Field.new("third", { "index" => 5 })
      schema = Csvlint::Schema.new("http://example.org", [third,second,first], "", "", uses_index)

      expect( schema.validate_row( ["none", "none", "none"], 1 ) ).to eql(true)
      expect( schema.warnings.size ).to eql(1)
    end
  end

  context "when validating header" do
    it "should show error if column names are different to field names" do
      minimum = Csvlint::Field.new("minimum", { "minLength" => 3, "required" => true } )
      required = Csvlint::Field.new("required", { "rquired" => true} )
      schema = Csvlint::Schema.new("http://example.org", [minimum, required] )
  
      expect( schema.validate_header(["minimum", "required"]) ).to eql(true)
      expect( schema.errors.size ).to eql(0)
      
      expect( schema.validate_header(["wrong", "required"]) ).to eql(false)
      expect( schema.errors.size ).to eql(1)
      expect( schema.errors.first.type).to eql(:header_name)
      expect( schema.errors.first.content).to eql("wrong")
      expect( schema.errors.first.column).to eql(1)
      expect( schema.errors.first.category).to eql(:schema)
    end   

    it "should not be case sensitive to header names" do
      minimum = Csvlint::Field.new("minimum", { "minLength" => 3, "required" => true } )
      required = Csvlint::Field.new("rEqUirEd", { "required" => true} )
      schema = Csvlint::Schema.new("http://example.org", [minimum, required] ) 

      expect( schema.validate_header(["minimum", "Required"]) ).to eql(true)
    end

    it "should not validate extra header columns" do
      minimum = Csvlint::Field.new("minimum", { "minLength" => 3 } )
      required = Csvlint::Field.new("required", { "required" => true } )
      schema = Csvlint::Schema.new("http://example.org", [minimum, required] )
  
      expect( schema.validate_header(["minimum", "required", "extra"]) ).to eql(true)
    end        

    context "that uses index" do
      it "should warn if the index of the column in file is different form schema" do

        uses_index = true
        validate_header_name = true
        
        minimum = Csvlint::Field.new("extra", { "index" => 3 } )
        required = Csvlint::Field.new("required", { "index" => 1 } )
        schema = Csvlint::Schema.new("http://example.org", [minimum, required], "", "", uses_index, validate_header_name)

        expect( schema.uses_index).to eql true
    
        expect( schema.validate_header(["required", "ignored", "wrong"]) ).to eql(false)
        expect( schema.errors.size).to eql(1)

        expect( schema.errors[0].type).to eql(:header_name)
        expect( schema.errors[0].content).to eql("wrong")
        expect( schema.errors[0].column).to eql(3)
        expect( schema.errors[0].category).to eql(:schema)
      end        
    end
  end  
  
  context "when parsing JSON Tables" do
    
    before(:each) do 
      @example=<<-EOL
      {
          "title": "Schema title",
          "description": "schema", 
          "uses_index": "true", 
          "fields": [
              { "name": "ID", "constraints": { "required": true }, "title": "id", "description": "house identifier" },
              { "name": "Price", "constraints": { "required": true, "minLength": 1 } },
              { "name": "Postcode", "constraints": { "required": true, "pattern": "[A-Z]{1,2}[0-9][0-9A-Z]? ?[0-9][A-Z]{2}" } }
          ]
      }
  EOL
      stub_request(:get, "http://example.com/example.json").to_return(:status => 200, :body => @example)
    end
    
    it "should create a schema from a pre-parsed JSON table" do
      json = JSON.parse( @example )
      schema = Csvlint::Schema.from_json_table("http://example.org", json)
      
      expect( schema.uri ).to eql("http://example.org")
      expect( schema.title ).to eql("Schema title")
      expect( schema.description ).to eql("schema")
      expect( schema.uses_index ).to eql("true")
      expect( schema.fields.length ).to eql(3)
      expect( schema.fields[0].name ).to eql("ID")
      expect( schema.fields[0].constraints["required"] ).to eql(true)
      expect( schema.fields[0].title ).to eql("id")
      expect( schema.fields[0].description ).to eql("house identifier")
    end
    
    it "should create a schema from a JSON Table URL" do
      schema = Csvlint::Schema.load_from_json_table("http://example.com/example.json")
      expect( schema.uri ).to eql("http://example.com/example.json")
      expect( schema.fields.length ).to eql(3)
      expect( schema.fields[0].name ).to eql("ID")
      expect( schema.fields[0].constraints["required"] ).to eql(true)
      
    end
  end  
  
end