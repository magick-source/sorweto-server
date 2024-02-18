package SorWeTo::Utils::Recaptcha;

use parent 'Exporter';
our @EXPORT_OK = qw(check_recaptcha);

use LWP::UserAgent;
use JSON qw(from_json);

sub check_recaptcha {
  my ($secret_key, $remote_ip, $response) = @_;

  my $ua = LWP::UserAgent->new();

  my $result = $ua->post(
    'https://www.google.com/recaptcha/api/siteverify',
    {
      secret      => $secret_key,
      remoteip    => $remote_ip,
      response    => $response,
    }
  );

  if ($result->is_success) {
    my $data = from_json( $result->content );
    if ($data->{success}) {
      return 1;
    } else {
      return (0, $data->{'error-codes'}[0]);
    }
    print STDERR "Recaptcha Result: ", $result->content,"\n\n";
  } else {
    return (0, 'request-failed');
  }
}

1;
