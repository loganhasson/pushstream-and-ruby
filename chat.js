$(function(){
  // Initialize the pushstream connection with the correct IP Address, on the default port of 9080, and with websockets
  var pushstream = new PushStream({
    host: '107.170.181.229',
    port: 9080,
    modes: 'websocket|eventsource'
  });

  // Specify callback method that will be triggered when a message is received
  pushstream.onmessage = updateChatLog;

  // Specify the channel...this is arbitrary. The default configuration file allows for any channel name.
  pushstream.addChannel('my-channel');

  // Connect to the pushstream server
  pushstream.connect();

  // Write our onmessage callback method. It will be called with the text of the message, the id of the message, and the channel
  function updateChatLog(text, id, channel) {
    // Use the jquery-deparam plugin to parse our incoming text into an object we can use more easily
    var data = $.deparam(text);
    
    // Append the data to the div we created
    $('#chat-messages ul').append('<li><strong>' + data.username + '</strong>: ' + data.text + '</li>');
  }

  // Setup a listener to the Submit button to send the message typed into the text input
  $('#chat-submit').click(function(){
    pushstream.sendMessage($('#chat-input').val());

    // Clear the text input, and focus, ready for next message
    $('#chat-input').val('');
    $('#chat-input').focus();
  });
});
