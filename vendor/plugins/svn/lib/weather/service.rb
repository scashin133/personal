#
# Author::    Matt Zukowski  (http://blog.roughest.net)
# Copyright:: Copyright (c) 2006 Urbacon Ltd.
# License::   GNU Lesser General Public License v2.1 (LGPL 2.1)
#

require 'net/http'
require 'cgi'

# Use the much faster libxml if available; fall back to REXML otherwise
begin
  begin
    require 'xml/libxml'
  rescue LoadError
    require 'rubygems'
    require 'xml/libxml'
  end
  $USE_LIBXML = true
rescue LoadError
  $USE_LIBXML = false
  require 'rexml/document'
end

require File.dirname(File.expand_path(__FILE__)) + '/../libxml_rexml_compat' if $USE_LIBXML

#puts "Using libxml? #{$USE_LIBXML.inspect}"

require File.dirname(File.expand_path(__FILE__)) + '/forecast'

module Weather

  # Interface for interacting with the weather.com service.
  class Service
    attr_writer :partner_id, :license_key, :imperial
    attr_reader :partner_id, :license_key, :imperial
    
    XOAP_HOST = "xoap.weather.com"
    
    # Returns the forecast data fetched from the weather.com xoap service for the given location and number of days.
    def fetch_forecast(location_id, days = 5)
      
      days = 5 if days.nil? or days == 0 or days == ""
      
      # try to pull the partner_id and license_key from the environment if not already set
      partner_id = ENV['WEATHER_COM_PARTNER_ID'] unless partner_id
      license_key = ENV['WEATHER_COM_LICENSE_KEY'] unless license_key
      
      if imperial or (ENV.has_key? 'USE_IMPERIAL_UNITS' and ENV['USE_IMPERIAL_UNITS'])
        imperial = true
      else
        imperial = false
      end
      
      # NOTE: Strangely enough, weather.com doesn't seem to be enforcing the partner_id/license_key stuff. You can specify blank values for both
      #       and the service will return the data just fine (actually, it will accept any value as valid). I'm commenting out these checks
      #       for now, but we may need to re-enable these once weather.com figures out what's going on.
      #if not partner_id
      #  puts "WARNING: No partner ID has been set. Please obtain a partner ID from weather.com before attempting to fetch a forecast, otherwise the data you requested may not be available."
      #end
      #
      #if not license_key
      #  puts "WARNING: No license key has been set. Please obtain a license key from weather.com before attempting to fetch a forecast, otherwise the data you requested may not be available"
      #end
      
      # default to metric (degrees fahrenheit are just silly :)
      unit = imperial ? "s" : "m"
      url = "/weather/local/#{location_id}?cc=*&dayf=#{days}&par=#{partner_id}&key=#{license_key}&unit=#{unit}"
      
      #puts "Using url: "+url
      
      if cache?
        begin
          xml = cache.get("#{location_id}:#{days}")
        rescue
          # handle things gracefully if memcache chokes
          xml = false
        end
      end
      
      unless xml
        xml = Net::HTTP.get(XOAP_HOST, url)
        
        if cache?
          doc = $USE_LIBXML ? (p = XML::Parser.new; p.string = xml; p.parse) : REXML::Document.new(xml)
          $USE_LIBXML ? doc.root['cached_on'] = Time.now.to_s : doc.root.attributes['cached_on'] = Time.now 
          cache.set("#{location_id}:#{days}", doc.to_s, cache_expiry)
        end
      end
      doc = $USE_LIBXML ? (p = XML::Parser.new; p.string = xml; p.parse) : REXML::Document.new(xml)

      Forecast::Forecast.new(doc)
    end
    
    # Returns the forecast data loaded from a file. This is useful for testing.
    def load_forecast(filename)
      file = File.new(filename)
      doc = $USE_LIBXML ? XML::Document.file(filename) : REXML::Document.new(file)
      
      Forecast::Forecast.new(doc)
    end
    
    # Returns a hash containing location_code => location_name key-value pairs for the given location search string.
    # In other words, you can use this to find a location code based on a city name, ZIP code, etc.
    def find_location(search_string)
      url = "/weather/search/search?where=#{CGI.escape(search_string)}"
      
      xml = Net::HTTP.get(XOAP_HOST, url);
      doc = $USE_LIBXML ? (p = XML::Parser.new; p.string = xml; p.parse) : REXML::Document.new(xml)
      
      locations = {}
      
      ($USE_LIBXML ? doc.find('//loc') : REXML::XPath.match(doc.root, "//loc")).each do 
        |loc| locations[loc.attributes['id']] = loc.text
      end
      
      return locations
    end
    
    
    @cache = false
    
    # Turns on weather forecast caching.
    # See Weather::Service::Cache
    def enable_cache(enable = true)
      if enable
        extend Cache
        @cache = true
      else
        @cache = false
      end
    end
    
    # True if caching is enabled and at least one memcached server is alive, false otherwise.
    def cache?
      @cache and cache.active? and 
        servers = cache.instance_variable_get(:@servers) and 
        servers.collect{|s| s.alive?}.include?(true)
    end
    
    # Turns off weather forecast caching.
    # See Weather::Service::Cache
    def disable_cache
      enable_cache false
    end
    
    # Memcache functionality for Weather::Service.
    # This is automatically mixed in when you call Weather::Service#enable_cache
    module Cache
  
      # The MemCache client instance currently being used.
      # To set the memcache servers, use:
      # 
      #   service.cache.servers = ["127.0.0.1:11211"]
      def cache
        @memcache ||= MemCache.new(:namespace => 'RubyWeather')
      end
      
      # Sets how long forecast data should be cached (in seconds).
      def cache_expiry=(seconds)
        @cache_expiry = seconds
      end
      # The current cache_expiry setting, in seconds.
      def cache_expiry
        @cache_expiry || 60 * 10
      end
      
      private
        def self.extend_object(o)
          begin
            require 'memcache'
          rescue LoadError
            require 'rubygems'
            # The rc-tools memcache client is waaaay faster than Ruby-MemCache,
            # so try to use that if possible. However, I tried it a few months
            # ago and couldn't get it to work. Version 1.2.1 seems to work though
            # (and in all likelyhood some previous versions would have worked too,
            # but better not take chances).
            begin
              gem 'memcache-client', '~> 1.2.1'
            rescue Gem::LoadError
              gem 'Ruby-MemCache'
            end          
            require 'memcache'
          end
          super
        end
    end
  end
end