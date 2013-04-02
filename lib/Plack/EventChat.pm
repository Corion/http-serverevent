package Plack::EventChat;
use strict;
use AnyEvent;
use HTTP::ServerEvent;

my $html= join "", <DATA>;

# Creates a PSGI responder
sub chat_server {
    
    my (%users);
    my @chat;
    
    my $app= sub {
      my $env = shift;

      if( $env->{PATH_INFO} eq '/join' ) {
          # If we don't have a user name, assign a random username
          # 
          return [ 302, ['Location' => '//localhost:5000/'], []];
      };

      if( $env->{PATH_INFO} ne '/events' ) {
          # Send the JS+HTML
          return [ 200, ['Content-Type', 'text/html'], [$html] ]
      };

      if( ! $env->{"psgi.streaming"}) {
          my $err= "Server does not support streaming responses";
          warn $err;
          return [ 500, ['Content-Type', 'text/plain'], [$err] ]
      };

      # immediately starts the response and stream the content
      return sub {
          my $responder = shift;
          my $writer = $responder->(
              [ 200, [ 'Content-Type', 'text/event-stream' ]]);
          my $countdown= 10;
          
          my $w; $w= AnyEvent->timer(
              after => 1,
              interval => 1,
              cb => sub {
                  $countdown--;
                  if (0 < $countdown) {
                      my $event= HTTP::ServerEvent->as_string(
                              data => $countdown,
                              event => 'tick',
                          );

                      $writer->write($event);
                  } else {
                      warn "Boom";
                      undef $w;
                      $writer->close;
                  }
              }
          );
      };
  };

};

1;

__DATA__
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<script language="javascript">
  var events = new EventSource('/events');
  // Subscribe to "tick" event
  events.addEventListener('tick', function(event) {
    var out= document.getElementById("my_console");
    out.appendChild(document.createTextNode(event.data));
  }, false);
</script>
</head>
<h1>Countdown</h1>
<div id="my_console">
</div>
<h2>...</h2>
</html>