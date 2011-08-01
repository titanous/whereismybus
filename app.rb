$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'models'
require 'octranspo_gps'
require 'active_support/core_ext/object/blank'

enable :raise_errors
set :haml, :format => :html5

configure :development do |c|
  require 'sinatra/reloader'
  c.also_reload '*.rb'
end

get '/' do
  headers['Cache-Control'] = 'public, max-age=86400'
  haml :index
end

get '/stops' do
  Stop.nearby(params[:lat], params[:lon]).to_json
end

get '/search' do
  Stop.search(params[:q]).to_json
end

#get '/stops/:number' do
  #stop_name = Stop.first(:number => params[:number]).name
  #OCTranspo::GPSData.new(params[:number]).trips.merge(:stop_name => stop_name).to_json
#end

get '/stop/:id' do
  stop_name = Stop.first(:id => params[:id]).name
  StopTimes.next_for(params[:id]).merge(:stop_name => stop_name).to_json
end
