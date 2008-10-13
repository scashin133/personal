#
# Author::    Matt Zukowski  (http://blog.roughest.net)
# Copyright:: Copyright (c) 2006 Urbacon Ltd.
# License::   GNU Lesser General Public License v2.1 (LGPL 2.1)
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
  TEST_LOCATION = "CAXX0504"
  
  # Note that for this test to work the WEATHER.COM_PARTNER_ID and WEATHER.COM_LICENSE_KEY
  # environment variables must be set!
  
  def setup
    @filename = File.expand_path(File.dirname(__FILE__) + "/test_weather.xml")
    @service = Weather::Service.new
  end
  
  def test_load_forecast
    forecast = @service.load_forecast(@filename)
    assert_kind_of(Weather::Forecast::Forecast, forecast)
  end
  
  def test_fetch_forecast
    forecast = @service.fetch_forecast(TEST_LOCATION, 8)
    
    assert_kind_of(Weather::Forecast::Forecast, forecast)
    assert_equal("CAXX0504", forecast.location_code)
    assert_equal("Toronto", forecast.location_city)
    assert_equal(8, forecast.entries.size)
  end
  
  def test_imperial_metric_choice
    @service.imperial = true
    forecast = @service.fetch_forecast(TEST_LOCATION, 2)
    assert(!forecast.metric?)

    @service.imperial = false
    forecast = @service.fetch_forecast(TEST_LOCATION, 2)
    assert(forecast.metric?)
    
    ENV['USE_IMPERIAL_UNITS'] = "yes"
    @service.imperial = true
    forecast = @service.fetch_forecast(TEST_LOCATION, 2)
    assert(!forecast.metric?)
  end
  
  def test_find_location
    locations = @service.find_location("Toronto")
    assert(locations.has_key?(TEST_LOCATION))
    
    # test for spaces and other characters that need to be URL-encoded
    locations = @service.find_location("London, United Kingdom")
    assert(locations.has_key?("UKXX0085"))
  end
  
  def test_caching
    # This assumes that we have a memcache server running on localhost:11211!
    @service.enable_cache
    @service.cache.servers = "localhost:11211"
    
    raise "Memcache server must be up and running at localhost:11211 for this test to run." unless @service.cache?
    
    @service.cache.delete("#{TEST_LOCATION}:5")
    
    assert_equal @service.fetch_forecast(TEST_LOCATION, 5).xml.to_s, @service.fetch_forecast(TEST_LOCATION, 5).xml.to_s.gsub(/ cached_on=['"].*?['"]/, '')
    
    assert @service.fetch_forecast(TEST_LOCATION, 5).from_cache?
    
    xml = @service.cache.get("#{TEST_LOCATION}:5")
    assert xml and !xml.empty?
    
    @service.cache_expiry = 1
    
    @service.fetch_forecast(TEST_LOCATION, 2)
    sleep(2)
    assert_nil @service.cache.get("#{TEST_LOCATION}:2")
    
    assert !@service.fetch_forecast(TEST_LOCATION, 2).from_cache?
  end
end