require 'portlet_controller'
require_gem 'rubyweather'
require 'weather/service'

# Simple Rails controller that shows the weather forecast.
class WeatherPortletController < ActionController::Base

  configurable

  def rescue_action_in_public(exception)
    render :text => <<ERROR
      <em>Sorry, this portlet is temporarily out of service.</em>
      
      <!--
        ERROR: #{exception.message}
          #{exception.backtrace.join("\n\t\t\t")}
      -->
ERROR
  end

  def forecast
    if params['locations'] and params['locations'].is_array? and params['locations'].length > 0
      locations = params['locations']
    else
      locations = ["CAXX0504", "CAXX0301", "CAXX0054"]
    end
 
    days = params['days'] || 5

    @forecasts = []
    
    service = Weather::Service.new
    locations.each do |loc|
      @forecasts << service.fetch_forecast(loc, days)
    end
  end
  
  # Normally this would go in the weather_portlet_helper, but to reduce the number of files in this example it is included.
  def outlook_tooltip(d)
    tooltip = d.outlook.to_s
    tooltip += ", PoP: "+d.pop.to_s+"%" if (not d.pop.nil?)
    
    return tooltip
  end
  helper_method :outlook_tooltip
  hidden_actions :outlook_tooltip
  
end

