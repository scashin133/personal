#
# Author::    Matt Zukowski  (http://blog.roughest.net)
# Copyright:: Copyright (c) 2006 Urbacon Ltd.
# License::   GNU Lesser General Public License v2.1 (LGPL 2.1)
#
# This test ensures that the examples in the README run without errors.
#

require 'test/unit'
require File.dirname(__FILE__) + '/../lib/weather/service'

if not ENV['WEATHER_COM_PARTNER_ID']
  puts "WARNING: You should set the WEATHER_COM_PARTNER_ID env variable (i.e. export WEATHER_COM_PARTNER_ID=<your weather.com partner id>) before running this test."
end

if not ENV['WEATHER_COM_LICENSE_KEY']
  puts "WARNING: You should set the WEATHER_COM_LICENSE_KEY env variable (i.e. export WEATHER_COM_LICENSE_KEY=<your weather.com license key>) before running this test."
end

class ServiceTest < Test::Unit::TestCase
  TORONTO = "CAXX0504"
  
  # Note that for this test to work the WEATHER.COM_PARTNER_ID and WEATHER.COM_LICENSE_KEY
  # environment variables must be set!
  
  def setup
    @service = Weather::Service.new
  end
  
  def test_find_location_example
    assert_nothing_raised do
      #require 'weather/service'
  
      service = Weather::Service.new
      service.partner_id = ""
      service.license_key = ""
    
      locations = service.find_location('Toronto')
      "Matching Locations: " + locations.inspect
    end
  end
  
  def test_forecast_example
    assert_nothing_raised do
      forecast = @service.fetch_forecast("CAXX0504", 5)
  
      "Location: %s" % forecast.location_name
    
      "Current Temperature: %s" % forecast.current.temperature
      "Current Windspeed: %s" % forecast.current.wind.speed
    
      "Tomorrow's High: %s" % forecast.tomorrow.high
      "Tomorrow's Outlook: %s" % forecast.tomorrow.outlook
      "Tomorrow's Wind Direction: %s" % forecast.tomorrow.wind.direction
      
      "High 3 days from now: %s" % forecast.day(3).high
      "Probability of precipitation 4 days from now: %s" % forecast.day(4).pop
      
      "Probability of precipitation three nights from now: %s" % forecast.night(3).pop
    end
  end
    
  def test_caching_example
    assert_nothing_raised do
      s = Weather::Service.new
      s.enable_cache
      s.cache_expiry = 60  # cached data will expire after 60 seconds; if omitted, the default is 10 minutes
      s.cache.servers = ['127.0.0.1:11211']
    end
  end
end