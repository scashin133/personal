class SiteController < ApplicationController
  require 'weather/service'
  include GeoKit::Geocoders

  def index    
  end
  
  def find_address

      service = Weather::Service.new

      service.partner_id = "1077495283"
      service.license_key = "193871af075cd39b"
      service.imperial = true
      
      @address = params[:address]

      @weather_locations = service.find_location(@address)

      @forecasts = service.fetch_forecast(@weather_locations.keys[0])

      render :partial => 'site/find_address',:layout => false
        
  end

end
