require 'dm-core'
require 'dm-serializer'
require 'monkeys'
require 'indextank'

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/whereismybus')

class Stop
  include DataMapper::Resource

  IT_CLIENT = IndexTank::Client.new(ENV['INDEXTANK_API_URL'])
  IT_INDEX  = IT_CLIENT.indexes('stops')

  property :id, String
  property :name, String
  property :number, Integer
  property :latitude, Float
  property :longitude, Float

  def self.nearby(lat, lon, limit = 15)
    query = 'SELECT *, ACOS(SIN(RADIANS(latitude)) * SIN(RADIANS(?)) + COS(RADIANS(latitude)) * COS(RADIANS(?)) * COS(RADIANS(?) - RADIANS(longitude))) * 6371 AS distance FROM stops ORDER BY distance ASC LIMIT ?'
    results = repository(:default).adapter.select(query, lat, lat, lon, limit)
    results.each { |r| r.distance = (r.distance * 1000).round }
  end

  def self.search(q)
    if q =~ /(\d{4})/
      q = "number:#{$1}"
    end

    results = IT_INDEX.search(q, :fetch => 'text,number')['results']
    results.map do |result|
      result['name'] = result.delete('text')
      result['id'] = result.delete('docid')
      result
    end
  end

end

class StopTimes

  def self.next_for(stop_id)
    new.next_for(stop_id)
  end


  def next_for(stop_id)
    query = "SELECT arrival_time, trip_headsign, CAST(route_short_name AS integer)
             FROM stop_times WHERE stop_id = ?
             AND service_id = (SELECT service_id FROM universal_calendar WHERE date = date ? LIMIT 1)
             AND arrival_time > ? AND arrival_time < ?
             ORDER BY arrival_time"
    result = repository(:default).adapter.select(query, stop_id, zone.now.strftime('%Y-%m-%d'), time_in_seconds, time_in_seconds + 172800)
    convert(result)
  end

  def convert(stop_times)
    routes = {}

    stop_times.each do |stop_time|
      route = stop_time.route_short_name
      direction = stop_time.trip_headsign
      routes[route] ||= {}
      routes[route][direction] ||= []

      routes[route][direction] << {
        :status => :scheduled,
        :arrival => seconds_to_time(stop_time.arrival_time).strftime('%H:%M')
      } if routes[route][direction].length < 3
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

  private

  def zone
    ActiveSupport::TimeZone['America/Toronto']
  end

  def seconds_to_time(seconds)
    zone.now.midnight + (seconds.to_i % 86400)
  end

  def time_in_seconds
    zone.now.to_i - zone.now.midnight.to_i
  end
end
