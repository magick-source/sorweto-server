package SorWeTo::Server::htmlHooks;

use Mojo::Base qw(Mojo::EventEmitter);

use Mojo::ByteStream;

has 'app';

sub init {
  my ($self) = @_;

  $self->app->helper( html_hook => sub { $self->_html_hook_handler( @_ ) });

  return;
}

sub _html_hook_handler {
  my ($self, $c, $html_hook, @params) = @_;

  my $result = '';
  for my $cb (reverse @{$self->subscribers( $html_hook )} ) {
    my @prms = @params;
    my $res = $cb->( $c, @prms );
    if (defined $res and $res ne '') {
      $result .= $res;
      $result .= "\n" unless $result =~ m{\n\z}sm;
    }
  }

  # TODO: remove this - just for debug for a bit
  $result ||= "<!-- html_hook( $html_hook ) handled -->";

  return Mojo::ByteStream->new( $result );
}

1;
