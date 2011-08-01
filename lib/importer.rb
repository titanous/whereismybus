require 'indextank'
require 'fastercsv'

def import_stops(stops_file)
  client = IndexTank::Client.new(ENV['INDEXTANK_API_URL'])
  index = client.indexes('stops')

  FasterCSV.foreach(stops_file, :headers => true) do |stop|
    index.document(stop[0]).add({ :text => stop[2],
                                  :number => stop[1],
                                  :latitude => stop[4],
                                  :longitude => stop[5] })
  end
end

import_stops(ARGV[0])
