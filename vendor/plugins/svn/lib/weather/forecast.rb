#
# Author::    Matt Zukowski  (http://blog.roughest.net)
# Copyright:: Copyright (c) 2006 Urbacon Ltd.
# License::   GNU Lesser General Public License v2.1 (LGPL 2.1)
#

require 'time'
require 'ostruct'
require File.dirname(File.expand_path(__FILE__)) + '/util'

module Weather
  
  # Namespace module for weather data objects.
  module Forecast
    
    # Contains several days of weather data.
    # The forecast object includes the Enumerable mixin, so that you can iterate
    # over all of the days in the forecast using the standard ruby mechanisms as follows:
    #   
    #   myforecast.each do |d|
    #     print d.outlook
    #   end
    class Forecast
      include Enumerable
      
      attr_reader :xml
      
      # Instantiate a Forecast object from the specified Weather.com REXML::Document.
      def initialize(weather_xmldoc)
        if (not weather_xmldoc.kind_of?($USE_LIBXML ? XML::Document : REXML::Document))
          raise "The xml document given to the Forecast constructor must be a valid REXML::Document or XML::Document"
        end
        
        @xml = weather_xmldoc
        
        # add the lsup (latest update) and cached_on elements to individual days to make parsing easier later on
        # FIXME: I can't seem to add the lsup as an element (which would be the consistent way to do it)... adding it as an attribute seems to work though
        dayf = $USE_LIBXML ? @xml.root.find('dayf').first : @xml.root.elements['dayf']
        lsup = $USE_LIBXML ? dayf.find_first('//dayf/lsup') : dayf.elements['lsup'] if dayf
        
        if dayf and lsup
          latest_update = lsup.text
          
          ($USE_LIBXML ? @xml.find('//dayf/day') : REXML::XPath.match(@xml, "//dayf/day")).each do |dxml|
            dxml.add_attribute "lsup", latest_update
          end
        end
      end
      
      # The current conditions as a Conditions object.
      def current
        CurrentConditions.new(xml.root.elements['cc'])
      end
      
      # Alias for day(1)
      def tomorrow
        day(1)
      end
      
      # The conditions for the given day (0 = today, 1 = tomorrow, etc.)
      # The maximum day number depends on the data available in the xml that was used to create this Forecast.
      def day(num)
        element = xml.root.elements['dayf'].elements["day[@d='#{num.to_s}']"]
        if not element
          case num
          when 0 then daydisplay = "today"
          when 1 then daydisplay = "tomorrow"
          else daydisplay = "#{num} days from now"
          end
          raise "Sorry, there is no data available for #{daydisplay}"
        else
          Day.new(element)
        end
      end
      
      # The conditions for the given night (0 = tonight, 1 = tomorrow night, etc.)
      # The maximum day number depends on the data available in the xml that was used to create this Forecast.
      def night(num)
        element = xml.root.elements['dayf'].elements["day[@d='#{num.to_s}']"]
        Night.new(element)
      end
      
      # Iterates over all of the days in this Forecast.
      def each(&block)
        first = true
        ($USE_LIBXML ? @xml.find('//dayf/day') : REXML::XPath.match(@xml, "//dayf/day")).each do |dxml|
          d = Day.new(dxml)
          
          # if it is after 3 PM, use current conditions
          if Time.now > Time.local(d.date.year, d.date.month, d.date.day, 15)
            d = current
          end
          
          yield d
          
          first = false if first
        end
      end
      
      # The full human-readable name of the place that this Forecast is for.
      def location_name
        xml.root.elements['loc'].elements['dnam'].text
      end
      
      # The name of the city that this Forecast is for.
      def location_city
        xml.root.elements['loc'].elements['dnam'].text.split(",").first
      end
      
      # The location code of the weather station that this Forecast is for.
      def location_code
        xml.root.elements['loc'].attributes['id']
      end
      
      # True if the units returned by this Forecast will be in the metric system (i.e. Celcius).
      def metric?              
        xml.root.elements['head'].elements['ut'].text == "C"
      end
      
      # The date and time when the conditions were last measured/forecast.
      # Returned as a Time object.
      # 
      # Note that this is a bit misleading, because the Forecast actually contains
      # two "latest update" times -- one for the current conditions and the other
      # for the future forecast. This method will return the latest update time
      # of the <em>future forecast</em>. If you want the latest update time of the current
      # conditions, you should do:
      # 
      #   forecast.current.latest_update
      #   
      def latest_update
        Time.parse(xml.root.elements['dayf'].elements['lsup'].text)
      end
      
      # The date and time when this forecast was last locally cached.
      # This attribute will be nil when the forecast comes directly from the weather.com
      # server or when you do not have the local cache enabled.
      # See Weather::Service#enable_cache and also the README for instructions on
      # how to enable local caching using memcached.
      def cached_on
        cached_on = xml.root.attributes['cached_on']
        Time.parse(cached_on) if cached_on 
      end
      
      # True if this forecast came from the local cache; false otherwise.
      # See Weather::Forecast.cached_on and Weather::Service#enable_cache.
      def from_cache?
        not cached_on.nil?
      end
    end
    
    # Abstract class that all Forecast entities are based on.
    class Conditions
      
      # For elements in the forecast that we have not defined an explicit accessor,
      # this allows accessing the raw underlying data in the forecast xml.
      def method_missing(symbol)
        begin
          return @xml.elements[symbol.to_s].text
        rescue NoMethodError
          return "N/A"
        end
      end
      
      # The wind conditions as an anonymous object (i.e. wind.d or wind.direction for 
      # wind direction, wind.s or wind.speed for wind speed, wind.h or wind.heading for
      # heading, etc.) See the <wind> element in the weather.com XML data spec for 
      # more info.
      def wind
        fix_wind(complex_attribute(@xml.elements['wind']))
      end
      
      # The date and time when the conditions were last measured/forecast.
      # Returned as a Time object.
      def latest_update
        Time.parse(self.lsup)
      end
      
      
      private
      # The element specified by name as a cleaned-up temperature value.
      # That is, if the temperature is "N/A", then nil is returned; otherwise
      # the value is converted to an integer.
      def clean_temp(name)
        temp = @xml.elements[name].text
        
        if (temp == "N/A")
          return nil
        else
          return temp.to_i
        end
      end
      
      # The given xml element as an anonymous object, with the text nodes of the element's
      # immediate children available as accessor methods.
      # This allows for accessing attributes that have child elements (i.e. wind, bar, etc.)
      # as anonymous objects (i.e. wind.d for wind direction, wind.s for wind speed, etc.)
      def complex_attribute(objxml)
        obj = {}
        
        objxml.elements.each do |element|
          obj[element.name] = element.text
        end
        
        return OpenStruct.new(obj)
      end
      
      # Adds more verbose names for wind properties. For example, "speed" for wind speed
      # rather than just "s".
      def fix_wind(obj)
        obj.heading = obj.t
        obj.direction = obj.d.to_i
        obj.speed = obj.s.to_i
        
        return obj
      end
    end
    
    # Represents the current weather conditions.
    class CurrentConditions < Conditions
      attr_reader :xml
      
      @xml
      
      def initialize(element)
        if (not element.kind_of?($USE_LIBXML ? XML::Node : REXML::Element))
          raise "The xml element given to the Day/Night constructor must be a valid REXML::Element or XML::Node"
        end
        @xml = element
      end
      
      # The numeric ID for the icon representing current conditions.
      # You can find the corresponding icons packaged with RubyWeather in the example/weather_32 directory.
      def icon
        xml.elements['icon'].text.to_i
      end
      
      def temp
        clean_temp('tmp')
      end
      alias tmp temp
      alias temperature temp
      
      def outlook
        xml.elements['t'].text
      end
      
      def outlook_brief
        xml.elements['bt'].text
      end
      
      def pop
        nil
      end
      alias ppcp pop
      
      def date
        Time.now
      end
    end
    
    # Abstract class representing either a day or night in the daily forecast (note that "future" can include today).
    class FutureConditions < Conditions
      attr_reader :xml
      
      @xml
      
      def initialize(element)
        if (not element.kind_of?($USE_LIBXML ? XML::Node : REXML::Element))
          raise "The xml element given to the Day/Night constructor must be a valid REXML::Element"
        end
        @xml = element
      end
      
      def method_missing(name)
        begin
          return mypart.elements[name.to_s].text
        rescue NoMethodError
          return "N/A"
        end
      end
      
      # The date and time when the conditions were last measured/forecast.
      # Returned as a Time object.
      def latest_update
        Time.parse(@xml.attributes['lsup'])
      end
      
      def wind
        fix_wind(complex_attribute(mypart.elements['wind']))
      end
      
      def date
        # FIXME: this will break if rolling over to next year (i.e. fetched 5 days into the future on Dec 30), since today's year is assumed
        mon, day = @xml.attributes['dt'].split(" ")
        Time.local(Time.now.year, mon, day)
      end
      
      # The numeric ID for the icon representing these forecast conditions.
      # You can find the corresponding icons packaged with RubyWeather in the example/weather_32 directory.
      def icon
        mypart.elements['icon'].text.to_i
      end
      
      def high
        clean_temp('hi')
      end
      alias hi high
      
      def low
        clean_temp('low')
      end
      alias lo low
      
      
      def outlook
        mypart.elements['t'].text
      end
      
      def outlook_brief
        mypart.elements['bt'].text
      end
      
      def pop
        mypart.elements['ppcp'].text.to_i
      end
      alias ppcp pop
      
      def sunrise
        hour,minute = @xml.elements['sunr'].text.split(" ").first.split(":")
        hour = hour.to_i
        minute = minute.to_i
        Time.local(date.year, date.month, date.day, hour, minute)
      end
      
      def sunset
        hour,minute = @xml.elements['suns'].text.split(" ").first.split(":")
        hour = hour.to_i + 12 # add 12 since we need 24 hour clock and sunset is always (?) in the PM
        minute = minute.to_i
        Time.local(date.year, date.month, date.day, hour, minute)
      end
      
    end
    
    # The daytime part of the forecast for a given day.
    class Day < FutureConditions
      def initialize(element)
        super(element)
      end
      
      def temp
        high
      end
      alias tmp temp
      alias temperature temp
      
      private 
      def mypart
        @xml.elements['part[@p="d"]']
      end
    end
    
    # The nighttime part of a forecast for a given day.
    class Night < FutureConditions
      def initialize(element)
        super(element)
      end
      
      def temp
        low
      end
      alias tmp temp
      alias temperature temp
      
      private
      def mypart
        @xml.elements['part[@p="n"]']
      end
    end
  end
  
end