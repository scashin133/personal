class SiteController < ApplicationController
  require 'weather/service'
  include GeoKit::Geocoders

  def index    
    @user_ip_address = request.env['REMOTE_HOST']
    
    @geocoded_location = IpGeocoder.geocode(@user_ip_address)
    
    service = Weather::Service.new
    
    service.partner_id = "1077495283"
    service.license_key = "193871af075cd39b"
    service.imperial = true
    
    if !@geocoded_location.success || @geocoded_location.city == "(Unknown City)"
      @unmapped = true
      @weather_locations = service.find_location("Lake Forest, Ca")
    else
      @unmapped = false
      @weather_locations = service.find_location("#{@geocoded_location.city}, #{@geocoded_location.state}")
    end
      
    @forecasts = service.fetch_forecast(@weather_locations.keys[0])


  end

end
