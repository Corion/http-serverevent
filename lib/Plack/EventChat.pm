package Plack::EventChat;
use strict;
use AnyEvent;
use HTTP::ServerEvent;

use vars qw($VERSION);
$VERSION = '0.01';

my $html= join "", <DATA>;

sub broadcast{
    my ($type, $payload, $listeners) = @_;
    my $event= HTTP::ServerEvent->as_string(
        data => $payload,
        event => $type,
        id => time(),
    );

    for (@$listeners) {
        eval {
            $_->write($event);
            1;
        } or undef $_;
    };
    @$listeners= grep { $_ } @$listeners;
};

# Creates a PSGI responder
sub chat_server {
    
    my (%users);
    my @chat;
    my @listeners;
    
    my $app= sub {
      my $env = shift;

      if( $env->{PATH_INFO} eq '/chat' ) {
          my $msg;
          if( $env->{QUERY_STRING}=~ /msg=(.*?)([;&]|$)/ ) {
              $msg= $1;
              push @chat, [time, $msg];
              broadcast( 'chat', $msg, \@listeners );
          };
          
          # prune the chat store:
          my $cutoff= time() - 5*60;
          @chat= grep { $_->[0] > $cutoff } @chat;
          
          # Keep only up to 500 lines, ever
          if( @chat > 500 ) {
              splice @chat, 0, @chat-500;
          };
          
          return [ 302, [], [<<CHAT]];
<html>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<form action="/chat" method="GET">
    <input name="msg" type="text">
    <button name="send">Chat</button>
</form>
</html>
CHAT
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
          
          if (my $last= $env->{HTTP_LAST_EVENT_ID}) {
              # bring client up to date with the current chat
              for( grep { $_->[0] > $last} @chat ) {
                  $writer->write(
                      event => 'chat',
                      id => $_->[0],
                      data => $_->[1],
                  );
              };
          };
          
          warn 0+@listeners;
          push @listeners, $writer;
          broadcast( 'count', 0+@listeners, \@listeners );
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
  // Subscribe to "chat" event
  events.addEventListener('chat', function(event) {
    var out= document.getElementById("chat");
    var msg= document.createElement("div");
    msg.appendChild(document.createTextNode(event.data));
    out.appendChild( msg );
  }, false);
  events.addEventListener('count', function(event) {
    var out= document.getElementById("count");
    var c;
    while (c= out.firstChild) {
        out.removeChild(c);
    };
    out.appendChild(document.createTextNode(event.data));
  }, false);
</script>
</head>
<h1>Chat (<span id="count">0</span> listeners)</h1>
<div id="chat">
</div>
<iframe src="/chat"></iframe>
</html>