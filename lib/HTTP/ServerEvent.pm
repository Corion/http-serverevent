package HTTP::ServerEvent;
use strict;
use Carp qw( croak );

=head1 NAME

HTTP::ServerEvent - create strings for HTTP Server Sent Events

=cut

=head2 C<< ->as_string( %options ) >>

  return HTTP::ServerEvent->as_string(
    type => "ping",
    data => time(),
    retry => 5000, # retry in 5 seconds
    id => $counter++,
  );

=cut

    use Data::Dumper;
sub as_string {
    my ($self, %options) = @_;
    
    # Better be on the safe side
    croak "Newline or null detected in event type '$options{ event }'. Possible event injection."
        if $options{ event } =~ /[\x0D\x0A\x00]/;
    
    if( !$options{ data }) {
        $options{ data }= [];
    };
    $options{ data } = [ $options{ data }]
        unless 'ARRAY' eq ref $options{ data };
    
    my @result;
    if( defined $options{ event }) {
        push @result, "event: $options{ event }";
    };
    if(defined $options{ id }) {
        push @result, "id: $options{ id }";
    };
    
    if( defined $options{ retry }) {
        push @result, "retry: $options{ retry }";
    };
    
    push @result, map {"data: $_" }
                  map { split /(?:\x0D\x0A?|\x0A)/ }
                  @{ $options{ data } || [] };
    
    return ((join "\x0D\x0A", @result) . "\x0D\x0A\x0D\x0A")
};

1;

=head1 SEE ALSO

L<https://developer.mozilla.org/en-US/docs/Server-sent_events/Using_server-sent_events>

L<https://hacks.mozilla.org/2011/06/a-wall-powered-by-eventsource-and-server-sent-events/>

L<http://www.html5rocks.com/en/tutorials/eventsource/basics/?ModPagespeed=noscript>

=head1 REPOSITORY

The public repository of this module is 
L<http://github.com/Corion/http-serverevent>.

=head1 SUPPORT

The public support forum of this module is
L<http://perlmonks.org/>.

=head1 BUG TRACKER

Please report bugs in this module via the RT CPAN bug queue at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=HTTP-ServerEvent>
or via mail to L<http-serverevent-Bugs@rt.cpan.org>.

=head1 AUTHOR

Max Maischein C<corion@cpan.org>

=head1 COPYRIGHT (c)

Copyright 2013-2013 by Max Maischein C<corion@cpan.org>.

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut