package SorWeTo::Server::Plugins::TmpBlob;

# This plugin allow to store temporary blobs of data in the database
# It adds the helpers tmp_blob_load and tmp_blob_store.

use Mojo::Base qw(Mojolicious::Plugin);

use SorWeTo::Db::TmpBlob;
use SorWeTo::Utils::Digests qw(
    generate_random_hash
    repeatable_hash
    hash2uuid
  );

use Mojo::JSON;

sub register {
  my ($self, $app, $conf) = @_;

  $app->helper( tmp_blob_load   => \&load_blob );
  $app->helper( tmp_blob_store  => \&store_blob );
  $app->helper( tmp_blob_delete => \&delete_blob );

  return $self;
}

sub load_blob {
  my ($c, $blob_type, $blob_id) = @_;

}

my %multipliers = (
  s => 1,             # s => seconds
  m => 60,            # m => minutes
  h => 60*60,         # h => hours
  d => 24*60*60,      # d => days
  w => 7*24*60*60,    # w => weeks
  m => 30*24*60*60,   # m => months
  y => 365*24*60*60,  # y => years
);
sub store_blob {
  my ($c, $blob_type, $blob_id, $value, $expires) = @_;

  if (ref $value) {
    $value = Mojo::JSON::encode_json( $value );
  }

  if ( !$blob_id ) {
    $blob_id = generate_random_hash( $blob_type );
  } elsif ( $blob_id !~ m{\A[0-9a-f]{30}\z} ) {
    $blob_id = repeatable_hash( $blob_type, $blob_id );
  }
 
  my $blob_uuid = hash2uuid( $blob_id );

  # by default, expire all blobs in 36 hours - not perfect for sessions
  # but a nice default for several of the other use cases.
  $expires ||= '36h';

  if (my ($cnt, $unit) = $expires =~ m{\A(\d+)([smhdwmy])\z}) {
    my $expires = time + $cnt * $multipliers{ $unit };
  } elsif ($expires=~m{\A\d+\z} and $expires< 100_000) {
    $expires += time;
  } elsif ( $expires =~ m{\D} ) {
    warn "not sure what expires '$expires' means, defaulting to 30 minutes";
    $expires = time + 30*60;
  } elsif ( $expires < time ) {
    warn "expires in the past - you can use tmp_blob_delete if you don't want it";
    $expires = time + 1*60; # giving it 1 minute, just in case
  }


  SorWeTo::Db::TmpBlob->insert({
    blob_type    => $blob_type,
    blob_uuid    => $blob_uuid,
    data         => $value,
    expires      => $expires,
  });

  return $blob_id;
}

sub delete_blob {
  my ($c, $blob_type, $blob_id) = @_;

}

1;
