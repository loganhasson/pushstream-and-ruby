require 'faraday'

class FaradayAdapter
  attr_reader :conn, :url

  def initialize(url)
    # Accept a url on initialization
    @url = url
    
    # Set up a default Faraday connection. This comes directly from the Faraday documentation...total boilerplate
    @conn = Faraday.new(:url => @url) do |faraday|
      faraday.request  :url_encoded
      faraday.adapter  Faraday.default_adapter
    end
  end

  # This post method will take a path, a query_string, and some arbitrary data...
  def post(path, query_string, data)
    # ...and delegate to the Faraday connection we created on initilization
    @conn.post "#{path}?#{query_string}", data
  end
end