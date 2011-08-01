require 'open-uri'
require 'nokogiri'
require 'active_support/time'

module OCTranspo
  class GPSData

    API_URL = 'http://octranspo.opendataottawa.ca'
    API_KEY = ''

    def initialize(stop)
      @stop = stop
    end

    def trips(count = 3)
      url = "#{API_URL}/stop/#{@stop}/trips?count=#{count}&key=#{API_KEY}"
      @doc = Nokogiri::XML(open(url))

      routes = {}

      @doc.xpath('//xmlns:StopNextTripData', 'xmlns' => 'http://tempuri.org/').each do |trip|
        route = get_el(trip, 'ROUTE_NO').to_i
        direction = get_el(trip, 'DIRECTION')
        description = get_el(trip, 'ROUTE_DESCRIPTION').gsub(/\s?[\/\\-]+\s?/, '/')
        routes[route] ||= {}
        routes[route][direction] ||= []

        scheduled_arrival = seconds_to_time(get_el(trip, 'SCHEDULED_SECONDS').to_i)

        trip_details = {
          :description => description,
          :last_trip => get_el(trip, 'LAST_TRIP') == 'true',
          :live      => get_el(trip, 'GPS_AVAILABLE') == 'true',
          :status    => :scheduled,
          :arrival => scheduled_arrival.strftime('%H:%M'),
          :arrival_epoch => scheduled_arrival.to_i
        }

        if trip_details[:live]
          adherence_seconds = get_el(trip, 'ADHERENCE_SECONDS').to_i
          trip_details.merge!({
            #:latitude  => get_el(trip, 'LATITUDE').to_f,
            #:longitude => get_el(trip, 'LONGITUDE').to_f,
            :arrival => (scheduled_arrival + adherence_seconds).strftime('%H:%M'),
            :arrival_epoch => (scheduled_arrival + adherence_seconds).to_i,
            :adherence_seconds => adherence_seconds,
          })
          if adherence_seconds > 60
            trip_details[:status] = :late
          elsif adherence_seconds < -60
            trip_details[:status] = :early
          else
            trip_details[:status] = :ontime
          end
        end

        routes[route][direction] << trip_details
      end

      result = routes.map do |n,d|
        directions = d.map do |direction, trips|
          {
            :direction => direction,
            :trips => trips
          }
        end

        {
          :number => n,
          :directions => directions
        }
      end

      result.sort! { |a,b| a[:number] <=> b[:number] }

      { :routes => result }
    end

    def route_trips(route, count = 3)
      trips(count)[route.to_i]
    end

    def next_route_trip(route, direction = nil)
      trips = route_trips(route, 1)
      flattened_trips = direction ? trips[direction.upcase] : trips.to_a.flatten.select { |e| e.is_a?(Hash) }
      sort_trips(flattened_trips).first
    end

    def sorted_route_trips(route, direction = nil)
      trips = route_trips(route)
      sorted_trips = {}
      trips.each { |d, t| sorted_trips[d] = sort_trips(t) }
      direction ? sorted_trips[direction] : sorted_trips
    end

    private

    def seconds_to_time(seconds)
      ActiveSupport::TimeZone['America/Toronto'].now.midnight + (seconds.to_i % 86400)
    end

    def get_el(node, el)
      node.at_xpath('xmlns:' + el, 'xmlns' => 'http://tempuri.org/').content
    end

    def sort_trips(trips)
      trips.sort do |a,b|
          (a[:estimated_arrival] || a[:scheduled_arrival]) <=>
          (b[:estimated_arrival] || b[:scheduled_arrival])
      end
    end

  end
end
