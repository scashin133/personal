require 'rubygems'
require 'ruby-prof'

require File.dirname(__FILE__) + '/../lib/weather/service'
require File.dirname(__FILE__) + '/../lib/weather/forecast'
require File.dirname(__FILE__) + '/../lib/weather/util'

@filename = File.expand_path(File.dirname(__FILE__) + "/test_weather.xml")

puts ""
puts "Loading forecast..."

start = Time.now
RubyProf.start
@forecast = Weather::Service.new.load_forecast(@filename)
@forecast2 = Weather::Service.new.load_forecast(@filename)
@forecast3 = Weather::Service.new.load_forecast(@filename)
@forecast4 = Weather::Service.new.load_forecast(@filename)
@forecast5 = Weather::Service.new.load_forecast(@filename)
load_result = RubyProf.stop

puts "#{Time.now - start} seconds!"

puts ""
puts "Examining forecast..."

start = Time.now
RubyProf.start
@forecast.location_name
@forecast.current.temp
@forecast.day(1).date.month
@forecast.day(3).wind.speed
@forecast.night(2).date.day
@forecast.tomorrow.outlook
@forecast.current.wind.heading
@forecast.tomorrow.temp
@forecast.latest_update
use_result = RubyProf.stop

puts "#{Time.now - start} seconds!"
puts ""

printer = RubyProf::FlatPrinter.new(load_result)
printer.print(STDOUT, 3.0)

printer = RubyProf::FlatPrinter.new(use_result)
printer.print(STDOUT, 1.0)
