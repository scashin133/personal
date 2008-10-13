#
# Author::    Matt Zukowski  (http://blog.roughest.net)
# Copyright:: Copyright (c) 2006 Urbacon Ltd.
# License::   GNU Lesser General Public License v2.1 (LGPL 2.1)
#

require 'test/unit'
require 'time'
require File.dirname(__FILE__) + '/../lib/weather/service'
require File.dirname(__FILE__) + '/../lib/weather/forecast'
require File.dirname(__FILE__) + '/../lib/weather/util'

class ForecastTest < Test::Unit::TestCase

  def setup
    @filename = File.expand_path(File.dirname(__FILE__) + "/test_weather.xml")
    #puts "Test file exists? "+(FileTest.exists? @filename).to_s
    @forecast = Weather::Service.new.load_forecast(@filename)
  end

  def test_iteration   
    assert_equal(5, @forecast.entries.size)
    
    @forecast.each do |f|
      assert_kind_of(Weather::Forecast::Conditions, f)
    end
  end
  
  def test_attributes
    assert_equal("Toronto, Canada", @forecast.location_name)
    assert_equal("Toronto", @forecast.location_city)
    assert_equal("CAXX0504", @forecast.location_code)
  end
  
  def test_current_conditions
    cur = @forecast.current
    
    assert_equal(84, cur.temp)
    assert_not_equal(85, cur.temp) # just to make sure there isn't something funny going on
    assert_equal(28, cur.icon)
    assert_equal("Mostly Cloudy", cur.outlook)
    
    # test implicit attribute
    assert_equal("Unlimited", cur.vis)
    
    # test complex attribute
    assert_equal("13", cur.wind.s)
    assert_equal(13, cur.wind.speed)
  end
  
  def test_future_conditions
    today = @forecast.day(0)
    tomorrow = @forecast.day(1)
    tomorrow_night = @forecast.night(1)
    
    assert_equal(14, today.date.day)
    assert_equal(7, today.date.mon)
    #assert_equal(2006, today.date.year)
    assert_equal(today.date.day + 1, tomorrow.date.day)
    assert_equal(87, tomorrow.high)
    assert_equal(87, tomorrow.hi)
    assert_equal(69, tomorrow.low)
    assert_equal(69, tomorrow.lo)
    assert_equal(37, tomorrow.icon)
    
    assert_equal(33, tomorrow_night.icon)
    assert_equal("Mostly Clear", tomorrow_night.outlook)
    
    # test implicit attribute
    assert_equal("M Clear", tomorrow_night.bt)
    
    # test complex attribute
    assert_equal(314, tomorrow_night.wind.direction)
    assert_equal("NW", tomorrow_night.wind.heading)
    assert_equal(8, tomorrow_night.wind.speed)
  end
  
  def test_latest_update
    assert_equal Time.parse("2006-07-14 14:15"), @forecast.latest_update
    assert_equal Time.parse("2006-07-14 15:00"), @forecast.current.latest_update
    assert_equal Time.parse("2006-07-14 14:15"), @forecast.tomorrow.latest_update
  end
end