puts "=========================================" 
puts "GoogleGeocodeAPIRuby"
puts "=========================================" 
puts "2016-08-08"
puts
puts "This application uses Google's Geocode API Library to geocode a table in PostgreSQL."
puts
puts "Ruby - ruby 2.2.0p0 (2014-12-25 revision 49005) [x86_64-darwin14]"
puts "PostgreSQL - PostgreSQL 9.4.5 on x86_64-unknown-linux-gnu, compiled by gcc (GCC) 4.8.2 20140120 (Red Hat 4.8.2-16), 64-bit"
puts "=========================================" 
puts "Database Assumptions:"
puts
puts "Input Columns  - street, city, state, zip"
puts "Output Columns - latitude_y, longitude_x, google_place_id, geocode_results"
puts "=========================================" 
puts
puts

require 'pg'
require 'net/http'
require 'json'

GOOGLE_GEOCODER_API_KEY = ENV["TPSMTTA_GOOGLE_GEOCODER_API_KEY"]

PG_USER_NAME  = ENV["TPSMTTA_PG_USER_NAME"]
PG_PASSWORD   = ENV["TPSMTTA_PG_PASSWORD"]
PG_DBNAME     = ENV["TPSMTTA_PG_DBNAME"]
PG_TABLENAME  = ENV["TPSMTTA_PG_TABLENAME"]
PG_HOST_NAME  = ENV["TPSMTTA_PG_HOST_NAME"]
PG_PORT       = ENV["TPSMTTA_PG_PORT"]

MAX_RECORDS_TO_GEOCODE = 2500

puts GOOGLE_GEOCODER_API_KEY

puts PG_PASSWORD
puts PG_DBNAME
puts PG_TABLENAME
puts PG_HOST_NAME
puts PG_PORT

begin

  # make connection to db
  conn = PG.connect(:dbname => PG_DBNAME, :user => PG_USER_NAME, :password => PG_PASSWORD, :port => PG_PORT,
                    :host => PG_HOST_NAME)

  conn.exec("select * from students where geocode_results = 'needs_geocoding' limit " + MAX_RECORDS_TO_GEOCODE.to_s + ";") do |results|

    count = 1
    results.each do |row|

      # console geocoding counter
      puts count.to_s + " / " + MAX_RECORDS_TO_GEOCODE.to_s

      studentNumber = row['student_number']
      geocodeCandidate = row['street'] + ", " + row['city'] + ", " + row['state'] + "  " + row['zip']


      if !geocodeCandidate.index('#').nil? then
        geocodeCandidate = geocodeCandidate.gsub('#', '%23')
      end

      url = "https://maps.googleapis.com/maps/api/geocode/json?address=" + geocodeCandidate + "&key=" + GOOGLE_GEOCODER_API_KEY
      puts url

      response      = Net::HTTP.get_response(URI.parse(url))
      responseJSON  = JSON.parse(response.body)

      locationType  = responseJSON['results'][0]['geometry']['location_type']
      locationX     = responseJSON['results'][0]['geometry']['location']['lng']
      locationY     = responseJSON['results'][0]['geometry']['location']['lat']
      placeID       = responseJSON['results'][0]['place_id']

      updateString = "update students set latitude_y=" + locationY.to_s + ", longitude_x=" + locationX.to_s + ", google_place_id='" \
        + placeID.to_s + "', geocode_results='" + locationType.to_s + "' where student_number=" + studentNumber + ";"
      puts updateString
      puts

      conn.exec(updateString)

      count += 1
    end
  end


  # close db connection
  conn.close
  puts "fini..."

end 