# Real-time data with nginx pushstream module and Ruby

In the world of real-time data, the WebSocket protocol is gaining steam as the preferred implementation. It's baked into event-driven servers like Node.js, and allows for easy bi-directional data transfer. However, there are other equally viable alternatives, such as long polling and server-sent events. Because each of these strategies has benefits in different situations, using an architecture up front that allows for seamlessly switching between them is a great way to reduce headaches down the road. An nginx server with the pushstream module fits this bill to a T. It's a robust server that can handle significant load without breaking a sweat--in fact, [Disqus](https://disqus.com/) runs its service using a relatively small architecture that [utilizes only 5 nginx pushstream servers](http://highscalability.com/blog/2014/4/28/how-disqus-went-realtime-with-165k-messages-per-second-and-l.html)--and getting one up and running isn't a huge undertaking.

In this post, we'll set up an nginx pushstream server and see how we can use it as the real-time layer for a Rails application.

## Part I - What are websockets, longpolling, and server-sent events?

Before we get down to brass tacks and actually set up and use an nginx pushstream server, it'll be useful to understand the differences between the three protocols it supports.

### WebSocket

Technically called the "WebSocket protocol", I'm going to start calling it by its more colloquial name: websockets (phew). To start a websocket connection, the client and the server complete a "handshake" over regular old HTTP. Upon a successful handshake, a TCP connection is opened, and kept open. At this point, both client and server can exchange data with one another whenever it is necessary, and it can be done very efficiently. An additional benefit is that data is encrypted (though, not strongly). Websockets are also natively supported in many browsers. It is possible to connect to the server from another domain.

### Longpolling

Longpolling, or AJAX Long-Polling, is done over HTTP. JavaScript requests some data from the server with a keep-alive header. When new data is available, the server responds with it, closing the connection. Immediately, the client makes another request, and the cycle repeats. A major benefit here is that longpolling is supported by all major browsers. A disadvantage, however, is that you must connect to the server from the same domain.

### Server-Sent Events

Server-Sent Events, also known as EventSource, works similarly to AJAX Long-Polling. Unlike longpolling, however, the client never closes the connection, and data comes in at real time. If the connection is dropped, the client automatically tries connecting again, which is a major advantage over websockets. Since this type of connection is just a persisted HTTP connection, it has wide-range browser support, Internet Explorer being the notable exception. Similarly to websockets, it is possible to connect to the server from a different domain.

This is just a general overview of the different protocols (and others do exist, such as the peer-to-peer WebRTC). Further reading [here](https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events), [here](http://html5doctor.com/server-sent-events/#api), [here](http://www.html5rocks.com/en/tutorials/eventsource/basics/), [here](http://jaxenter.com/tutorial-jsf-2-and-html5-server-sent-events-104548.html), [here](http://www.developerfusion.com/article/143158/an-introduction-to-websockets/), [here](http://stackoverflow.com/questions/11077857/what-are-long-polling-websockets-server-sent-events-sse-and-comet), [here](http://stackoverflow.com/questions/5195452/websockets-vs-server-sent-events-eventsource), and [here](http://stackoverflow.com/questions/10028770/html5-websocket-vs-long-polling-vs-ajax-vs-webrtc-vs-server-sent-events) (in no particular order).

## Part II - Setting up an nginx server with the pushstream module

For this section, I'm assuming you have access to a server (or virtual machine) running Ubuntu 12.04.x. These instructions should work on other versions of Ubuntu, but attempt installation on other versions at your own risk.

### General server setup

#### Dependencies

Before we can actually install pushstream, we'll need to install several dependencies. We'll do this with the apt package manager. To get the most up-to-date list of packages, run the following two commands (responding with `Y` when prompted) on your server:

1. `$ apt-get update`
2. `$ apt-get upgrade`

Next, we'll want to make sure the Ubuntu kernel is up-to-date, which we can do by running (again, responding with `Y` when prompted):

`$ apt-get dist-upgrade`

For the upgrade to take effect, we'll need to reboot the server, which can be done with:

`$ shutdown -r now`

Once your server has restarted, we can install the nginx dependencies. The packages we will need can be installed with:

`$ apt-get -y install build-essential git libpcre3 libpcre3-dev libgcrypt11-dev zlib1g-dev libssl-dev`

And finally, from a dependency standpoint, we'll need to make sure the `insserv` executable is in the correct place (it's a package that allows us to use init scripts), which we can do by creating a symlink:

`$ ln -s /usr/lib/insserv/insserv /sbin/insserv`

#### Adding the nginx user

Nginx needs to be run as a user, and for this I like to create a new user on the server. Running the following command will accomplish this:

`$ useradd nginx --no-create-home`

#### Building nginx with the pushstream module

Normally, we could just install nginx on an Ubuntu server using the apt package manager (`apt-get install nginx`). But in this case, we'll need to build it from source so that we can add the pushstream module. It's a little bit more involved, but not too awfully complex. First, let's make sure we're in our home directory by running:

`$ cd`

Then, we can grab the source for the pushstream  module from github with:

`$ git clone https://github.com/wandenberg/nginx-push-stream-module.git`

And to make our lives easier in a few minutes, let's store the path to that directory in an environment variable:

`$ NGINX_PUSH_STREAM_MODULE_PATH=$PWD/nginx-push-stream-module`

Great, now we need to actually get the source for nginx itself. The easiest way to do this is to download a tar directly from nginx themselves:

`$ wget http://nginx.org/download/nginx-1.2.5.tar.gz`

And unzip it:

`$ tar xzvf nginx-1.2.5.tar.gz`

And move into the source directory:

`$ cd nginx-1.2.5`

And configure the build to use the pushstream module:

`$ ./configure --add-module=../nginx-push-stream-module`

And finally, compile:

`$ make`

And move into place on our system:

`$ make install`

The configure and make steps will take a little while. But once it's all done, we can now check to make sure everything is installed properly. Run the command:

`$ /usr/local/nginx/sbin/nginx -v`

If all's well, you should see something like: `nginx version: nginx/1.2.5`.

Next, we need to check the pushstream configuration file to make sure it's all good to go:

`$ /usr/local/nginx/sbin/nginx -c $NGINX_PUSH_STREAM_MODULE_PATH/misc/nginx.conf -t`

Successful output will look something like:

```
nginx: the configuration file /root/$NGINX_PUSH_STREAM_MODULE_PATH/misc/nginx.conf syntax is ok
nginx: configuration file #NGINX_PUSH_STREAM_MODULE_PATH/misc/nginx/conf test is successful
```

Finally, we can use our handy environment variable to move the configuration file into place (right now, it's in the pustream repo we downloaded, but we'd like it in a more useful place on our system):

`$ cp $NGINX_PUSH_STREAM_MODULE_PATH/misc/nginx.conf /usr/local/nginx/conf/nginx.conf`

The last thing we need to do is make starting and stopping nginx easy. Ideally, we'd like a simple stop/start command, and for the server to start automatically when the system is booted up. A normal nginx installation from apt comes with this baked in. For our installation, we'll need to get a bit fancy. This isn't necessarily the best method of achieving this goal, but using the following upstart file gets the job done. Create a new upstart configuration file with:

`$ vi /etc/init/nginx.conf`

and paste in the following:

```
description "nginx http daemon"

start on (filesystem and net-device-up IFACE=lo)
stop on runlevel [!2345]

env DAEMON=/usr/local/nginx/sbin/nginx
env PID=/usr/local/nginx/logs/nginx.pid

expect fork
respawn
respawn limit 10 5

pre-start script
    $DAEMON -t
    if [ $? -ne 0 ]
            then exit $?
    fi
end script

exec $DAEMON -c /usr/local/nginx/conf/nginx.conf &
```

Now, we can start the nginx server with:

`$ start nginx`

or stop it with:

`$ stop nginx`

Go ahead and start it, and we can move on to the next step.

#### Cleaning up

As a last step, let's get rid of all of the files we downloaded:

`$ rm -rf ~/nginx-1.2.5 && rm ~/nginx-1.2.5.tar.gz && rm -rf ~/nginx-push-stream-module`

And that's it! Now we have an nginx pushstream server set up. Let's put it to some use now!

## Part III - Client-side only

Before we jump into doing anything server-side with a Rails application, let's work on the JavaScript side of things. For this example, we'll use websockets. You'll need two libraries: [jQuery](http://jquery.com) and [Pushstream.js](https://github.com/wandenberg/nginx-push-stream-module/blob/master/misc/js/pushstream.js).

Also, take note of your server's IP Address (you can get it by running `ifconfig`).

### The Project Directory

Go ahead and create a directory and move both of the above JavaScript libararies into it. Then, create an html file called `index.html` and a JavaScript file called `chat.js`.

### The HTML

I'm going to assume you have a directory structure that has one html file in the same location as the two above JS libraries. Paste this code into your HTML file:

```html
<!DOCTYPE html>
<html>
  <head>
    <script src="jquery.js" type="text/javascript"></script>
    <script src="pushstream.js" type="text/javascript"></script>
    <script src="chat.js" type="text/javascript"></script>
  </head>
  <body>
    <div id="chat-messages">
      <ul></ul>
    </div>
    <input id="chat-input" type="text">
    <input id="chat-submit" type="submit" value="Send">
  </body>
</html>
```

### The JavaScript

Ok, now comes the fun part. Let's actually get the pushstream up and running. Open your `chat.js` file and add the following code (comments explain what's going on):

```javascript
$(function(){
  // Initialize the pushstream connection with the correct IP Address, on the default port of 9080, and with websockets
  var pushstream = new PushStream({
    host: 'YOUR_IP_ADDRESS_HERE',
    port: 9080,
    modes: 'websocket'
  });
  
  // Specify callback method that will be triggered when a message is received
  pushstream.onmessage = updateChatLog;
  
  // Specify the channel...this is arbitrary. The default configuration file allows for any channel name.
  pushstream.addChannel('my-channel');
  
  // Connect to the pushstream server
  pushstream.connect();
  
  // Write our onmessage callback method. It will be called with the text of the message, the id of the message, and the channel
  function updateChatLog(text, id, channel) {
    // Append the message to the div we created
    $('#chat-messages ul').append('<li>' + text + '</li>');
  }
  
  // Setup a listener on the Submit button to send the message typed into the text input
  $('#chat-submit').click(function(){
    // Send the message (this 'sendMessage' function comes from the Pushstream.js library)
    pushstream.sendMessage($('#chat-input').val());
    
    // Clear the text input, and focus, ready for next message
    $('#chat-input').val('');
    $('#chat-input').focus();
  });
});
```

Open `index.html` in your browser, and send away! When you enter text in the input and click send, you should see the message get appended to the DOM.

## Part IV - Rails/Server-Side

Instead of building an entire Rails application, we'll create a PORO that can easily be dropped into an existing Rails application and used to send events to the pushstream server. This library code can then be dropped into a Sinatra application, or used as a standalone Ruby executable.

### Server-Sent Events

Just to demonstrate the flexibility of the pushstream module, let's modify our JavaScript slightly and add 'eventsource' as a connection mode. To do this, change the line `modes: 'websocket'` to `modes: 'websocket|eventsource'`. Also, go ahead and grab the lovely [jquery-deparam](https://github.com/chrissrogers/jquery-deparam) plugin from [Christopher Rogers](https://github.com/chrissrogers). It'll allow us to send more useful data as HTTP params, rather than as just text, and easily deal with it on the client side. Put it in the same directory as your other files, and add it to the head of your HTML file: `<script src="jquery-deparm.js" type="text/javascript"></script>`. Just make sure to add it after you've included jQuery!

And now, for the Ruby side of things. To handle sending the events, we'll use the [Faraday](https://github.com/lostisland/faraday) gem. It's a great, flexible HTTP client library. You are free to use another one, but you'll have to alter the example code.

Install the gem with `gem install faraday`, and then create two Ruby files, one called `faraday_adapter.rb` and another called `pushstream_publisher.rb`. Let's deal with the `FaradayAdapter` first. This isn't a totally necessary step, but it'll be nice later on if you choose to use a different HTTP library. Inside that file, paste the following code (comments explain what's going on):

```ruby
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
    conn.post "#{path}?#{query_string}", data
  end
end
```

Now, in the `pushstream_publisher.rb` file, paste the following:

```ruby
module Pushstream
  class Publisher
    attr_reader :conn

    def initialize(conn)
      # Accept an HTTP connection adapter on initilization
      @conn = conn
    end

    def self.publish(channel_name, data, conn = FaradayAdapter.new("http://#{ENV['NGINX_IP']}:9080"))
      # Use the constructor pattern to initialize a new Pushstream::Publisher, and call the publish method with a channel
      # and some data. You'll notice, this also expects an environment variable to be set with the IP Address of our
      # nginx pushstream server
      new(conn).publish(channel_name, data)
    end

    def publish(channel_name, data)
      # This follows the default pushstream behavior. The publish path looks like "http://someaddress:9080/pub?id=channel_name"
      conn.post 'pub', "id=#{channel_name}", data
    end
  end
end
```

Before we use this, let's eplore that default pushstream publish path briefly. Earlier when we set up our pushtream server, we moved a default config file into place, and told nginx to use it when it runs. That file does a whole bunch of things (including defining what types of connections to support), perhaps the most important of which is to define the publish and subscribe paths for the server. Here are the relevant lines from that config file:

```bash
location /pub {
    # activate publisher mode for this location, with admin support
    push_stream_publisher admin;

    # query string based channel id
    push_stream_channels_path               $arg_id;

    # store messages in memory
    push_stream_store_messages              on;

    # Message size limit
    # client_max_body_size MUST be equal to client_body_buffer_size or
    # you will be sorry.
    client_max_body_size                    32k;
    client_body_buffer_size                 32k;
}

location ~ /sub/(.*) {
    # activate subscriber mode for this location
    push_stream_subscriber;

    # positional channel path
    push_stream_channels_path                   $1;
    if ($arg_tests = "on") {
      push_stream_channels_path                 "test_$1";
    }

    # header to be sent when receiving new subscriber connection
    push_stream_header_template                 "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\r\n<meta http-equiv=\"Cache-Control\" content=\"no-store\">\r\n<meta http-equiv=\"Cache-Control\" content=\"no-cache\">\r\n<meta http-equiv=\"Pragma\" content=\"no-cache\">\r\n<meta http-equiv=\"Expires\" content=\"Thu, 1 Jan 1970 00:00:00 GMT\">\r\n<script type=\"text/javascript\">\r\nwindow.onError = null;\r\ntry{ document.domain = (window.location.hostname.match(/^(\d{1,3}\.){3}\d{1,3}$/)) ? window.location.hostname : window.location.hostname.split('.').slice(-1 * Math.max(window.location.hostname.split('.').length - 1, (window.location.hostname.match(/(\w{4,}\.\w{2}|\.\w{3,})$/) ? 2 : 3))).join('.');}catch(e){}\r\nparent.PushStream.register(this);\r\n</script>\r\n</head>\r\n<body>";

    # message template
    push_stream_message_template                "<script>p(~id~,'~channel~','~text~','~event-id~', '~time~', '~tag~');</script>";
    # footer to be sent when finishing subscriber connection
    push_stream_footer_template                 "</body></html>";
    # content-type
    default_type                                "text/html; charset=utf-8";

    if ($arg_qs = "on") {
      push_stream_last_received_message_time "$arg_time";
      push_stream_last_received_message_tag  "$arg_tag";
      push_stream_last_event_id              "$arg_eventid";
    }
}
```

The comments are included in the config file by default...they are not my own. Most important to notice here is that we are given two endpoints, `/pub` and `/sub/`. The `/pub` enpoint expects a query string parameter called `id` and the `/sub/` endpoint expects a path parameter with the name/id of the channel to which we wish to subscribe or publish. We can see an example of this in action by hopping over to our terminal. Open up two windows and place them side by side. In one of them, run the following

`curl -s -v 'http://NGINX_SERVER_IP_ADDRESS_HERE:9080/sub/test_channel_1'`

It will output some headers and then sit and wait. Now in the other window, run:

`curl -s -v -X POST 'http://NGINX_SERVER_IP_ADDRESS_HERE:9080/pub?id=test_channel_1' -d 'Hello World!'`

After a short period of time (perhaps even almost instantly), you'll see a message pop up in the first window. There will be some script tags, but somewhere in the response, you'll see 'Hello World!'. This post request is exactly what our Ruby code is doing, while the client side is handling the `/sub` endpoint using the `Pushstream.js` library.

And now, finally, let's put our Ruby code to the test! Pop open an irb session (run `irb` in your terminal) from within your current working directory, and type:

`load 'faraday_adapter.rb'`

and

`load 'pushstream_publisher.rb'`

(The return value of both of those lines should be `true`. If not, ensure you are in the correct directory and that both the `faraday_adapter.rb` and `pushstream_publisher.rb` files are present.)

Let's also go ahead and set an environment variable for our server IP Address:

`ENV['NGINX_IP'] = 'NGINX_SERVER_IP_ADDRESS_HERE'`

Make sure your `index.html` file is still open in your browser, and let's do a quick test. Run the following code, and you should see 'Hello World!' pop up:

`Pushstream::Publisher.publish('my-channel', 'Hello World!')`

But remember that `jquery-deparam` plugin we downloaded? Let's go ahead and put that to use. Pop open `chat.js` again, and modify the `updateChatLog` function so that it looks like this:

```javascript
function updateChatLog(text, id, channel) {
  // Use the jquery-deparam plugin to parse our incoming text into an object we can use more easily
  var data = $.deparam(text);
  
  // Append the data to the div we created
  $('#chat-messages ul').append('<li><strong>' + data.username + '</strong>: ' + data.text + '</li>');
}
```

Refresh `index.html` in your browser, and now, let's try using our `Pushstream::Publisher` again. This time, let's be a bit fancier, and pass some JSON data around like this:

`Pushstream::Publisher.publish('my-channel', {username: 'rando', text: 'hello world!'})`

You should see that pop up in your browser looking something like: **rando**: hello world!

## Part V - Conclusion

And that's all there is to it! You can drop those Ruby classes we wrote into any Rails application, and trigger the `.publish` method anytime something of interest happens on the server. Any client that is connected to the published-to channel will receive the data.

You can grab the sample code from this post from my [pushstream-and-ruby repo on GitHub](http://github.com/loganhasson/pushstream-and-ruby). And for further reading, head over to the [nginx pushstream](http://wiki.nginx.org/HttpPushStreamModule) documentation.
