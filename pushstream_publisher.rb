module Pushstream
  class Publisher
    attr_reader :conn

    def initialize(conn)
      # Accept an HTTP connection adapter on initilization
      @conn = conn
    end

    def self.publish(channel_name, data, conn = FaradayAdapter.new("http://#{ENV['NGINX_IP']}:9080"))
      # Use the constructor pattern to initialize a new Pushstream::Publisher, and call the publish method with a channel
      # and some data. You'll notice, this also expects an environmental variable to be set with the IP Address of our
      # nginx pushstream server
      new(conn).publish(channel_name, data)
    end

    def publish(channel_name, data)
      # This follows the default pushstream behavior. The publish path looks like "http://someaddress:9080/pub?id=channel_name"
      conn.post 'pub', "id=#{channel_name}", data
    end
  end
end