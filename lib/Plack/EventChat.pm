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
              warn "chat>$msg\n";
              broadcast( 'chat', $msg, \@listeners );
          };
          return [ 302, [], [<<CHAT]];
<html>
<form action="/chat" method="GET" enctype="multipart/form-data">
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
          push @listeners, $writer;
          broadcast( 'count', 0+@listeners );
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
    out.deleteChildren();
    out.appendChild(document.createTextNode(event.data));
  }, false);
</script>
</head>
<h1>Chat (<span id="count">0</span> listeners)</h1>
<div id="chat">
</div>
<iframe src="/chat"></iframe>
</html>