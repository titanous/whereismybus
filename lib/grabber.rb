require 'nokogiri'
require 'open-uri'
require 'zip/zip'
require 'fileutils'
require 'csv'

module Grabber

  class OCTranspo
    def initialize
      @base_url = 'http://www.gtfs-data-exchange.com/agency/oc-transpo'
      @doc = Nokogiri::XML( open("#{@base_url}/feed") )

      parse_locations.each do |url|
        open( url, "Referer" => @base_url ) do |zip|
          basename = File.basename(url, '.zip')
          dirname = "tmp/OCTranspo/#{basename}"
          FileUtils.mkdir_p(dirname)
          Zip::ZipFile.open(zip.path, Zip::ZipFile::CREATE) do |file|
            file.each { |entry|
              puts entry.inspect
              file.extract(entry, File.join(dirname, entry.inspect)){ true }
            }
          end
          FileUtils.rm zip.path
        end
      end
    end

    private
    def parse_locations
      @doc.css("entry").collect do |entry|
        entry.css("link").last[:href]
      end
    end
  end 

end
