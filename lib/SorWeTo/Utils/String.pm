package SorWeTo::Utils::String;

use Mojo::Base -strict;
use parent 'Exporter';

use Text::Unidecode qw(unidecode);

our @EXPORT_OK = qw(
    urify
  );

sub urify {
  my ($text) = @_;

  my $url = unidecode( $text );

  $url =~ s{\W}{-}g;
  $url =~ s{\-+}{-}g;
  $url =~ s{\-+\z}{};

  $url = lc( $url );

  return $url;
}

1;
