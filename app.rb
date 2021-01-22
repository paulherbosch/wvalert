require 'sinatra'
require 'sinatra/multi_route'
require 'sinatra/logger'
require 'json'
require 'dotenv/load'
require 'curb'
require 'icalendar'
require 'date'
require 'nokogiri'
require 'httparty'

include ERB::Util

##############################
# Initialize
# Read app config files etc

# begin sinatra configure block
configure do

  use Rack::Session::Pool

  # enable logging
  set :root, Dir.pwd
  set :logger, Logger.new(STDERR)

  # bind
  set :bind, '0.0.0.0'

  # populate appconfig hash via environment vars or read from the .env config file
  $appconfig = Hash.new

  #
  # Global Variables
  #

  # Notifications
  $appconfig['notifications'] = ENV['NOTIFICATIONS']  || nil

  # Timezone
  $appconfig['timezone'] = ENV['TIMEZONE']  || nil

end

############################
# Start Function Definitions
#

helpers do
  
  # def fetch_sales_dates()
  
  #   sales_moments = Array.new
  #   year = 2021
    
  #   url = "https://www.trappistwestvleteren.be/en/beer-sales"
    
  #   doc = HTTParty.get(url)
  #   parsed ||= Nokogiri::HTML(doc.body)

  #   shipping_divs = parsed.css('div[data-eventtype="sale-shipping"]')

  #   shipping_divs.each do |i|

  #     ancestor_td = i.ancestors.css('td').first  
  #     month = ancestor_td.css('span.day__date__month').text
  #     day = ancestor_td.css('span.day__date > text()').text.to_i 
  #     hours = i.css('.day__action__range').text.split("-").map(&:strip)

  #     start_datetime = Time.parse "#{day} #{month} #{year} #{hours[0]}"
  #     end_datetime = Time.parse "#{day} #{month} #{year} #{hours[1]}"

      
  #       sales_moment = Hash.new
  #       sales_moment['timestamp']          = item['timestamp']
  #       sales_moment['formattedtimestamp'] = Date.parse(item['timestamp']).strftime("%A %d-%m-%Y")
  #       sales_moment['fraction']           = item['fraction']['name']['nl'] 
  #       sales_moment['color']              = item['fraction']['color']
  #       sales_moments.push(sales_moment)
      
  #   end

  #   return sales_moments

  # end
  # create an ICS object based on the events we scraped
  #
  def generate_ics(timezone)
    # create calendar object
    cal = Icalendar::Calendar.new

    # set calendar timezone
    cal.timezone do |t|
      t.tzid = timezone
    end

    year = 2021
    
    url = "https://www.trappistwestvleteren.be/en/beer-sales"
    
    doc = HTTParty.get(url)
    parsed ||= Nokogiri::HTML(doc.body)

    shipping_divs = parsed.css('div[data-eventtype="sale-shipping"]')

    shipping_divs.each do |i|

      ancestor_td = i.ancestors.css('td').first  
      month = ancestor_td.css('span.day__date__month').text
      day = ancestor_td.css('span.day__date > text()').text.to_i 
      hours = i.css('.day__action__range').text.split("-").map(&:strip)

      start_datetime = Time.parse "#{day} #{month} #{year} #{hours[0]}"
      end_datetime = Time.parse "#{day} #{month} #{year} #{hours[1]}"
      
      event = Icalendar::Event.new
      event.dtstart = start_datetime
      event.dtend   = end_datetime
      event.summary = 'Home delivery'
      event.transp = 'TRANSPARENT'

      cal.add_event(event)

    end

    ical_string = cal
    return ical_string
  end
end

#
# End function definitions
##########################

#######################
# Start URI Definitions
#

# info
route :get, '/info' do
  erb :info
end

# main page
route :get, :post, '/' do
  timezone      = params['timezone']      || $appconfig['timezone']
  # generate_ics(timezone)
  @sales_moments = generate_ics(timezone)
  @ics_formatted_url = "#{request.scheme}://#{request.host}/?format=ics"
  if params['format'] == 'ics'
    # render ICS format and halt
    halt @sales_moments.to_ical
  else
    # or render html and halt
    halt erb :ics
  end
end
