package SorWeTo::Utils::Digests;

use Mojo::Base -strict;
use parent 'Exporter';

use Digest::SHA qw(sha256_hex);

our @EXPORT_OK = qw(
  generate_random_id
  generate_random_hash

  make_salted_hash
  check_salted_hash

  repeatable_hash

  hash2uuid
  uuid2hash
);

sub generate_random_id {
  my ($type) = @_;
  $type //= 'session';
  my $digest = Digest::SHA->new( 256 )
          ->add($type)
          ->add( $$, +{}, Time::HiRes::time(), rand(time()) )
          ->hexdigest();

  return substr( $digest, hex(substr($digest, 0, 1)), 12 );
}

sub generate_random_hash {
  my ($type) = @_;
  $type //= 'object';
  my $digest = Digest::SHA->new( 256 )
          ->add($type)
          ->add( $$, +{}, Time::HiRes::time(), rand(time()) )
          ->hexdigest();

  return substr( $digest, hex(substr($digest, 0, 1)), 30 );
}

my @letters = ('a'..'z','0'..'9','A'..'Z');
sub make_salted_hash {
  my ($password) = @_;

  my $salt = $letters[int rand(scalar @letters)]
           . $letters[int rand(scalar @letters)]
           . $letters[int rand(scalar @letters)];

  return __make_salted_hash( $password, $salt );
}

sub check_salted_hash {
  my ($password, $hash) = @_;

  my $salt = substr( $hash, 1, 3 );

  my $tmp_hash = __make_salted_hash( $password, $salt );
  return ($tmp_hash eq $hash);
}

sub __make_salted_hash {
  my ($password, $salt) = @_;

  my $res = sha256_hex( $password.$salt );
  my $start = hex(substr($res, 0, 1));
  $res = substr($res, $start, 15);
  $res = "<$salt>$res";

  return $res;
}

sub repeatable_hash {
  my ($type, $seed) = @_;

  if ($type and not $seed) {
    $seed = $type;
    $type = undef;
  }
  $type //= 'object';

  my $res = sha256_hex("$type:;:$seed");
  $res = substr( $res, hex(substr($res, 0, 1)), 30 );

  return $res;
}

sub hash2uuid {
  my ($hash) = @_;

  substr($hash, 12, 0) = '4';
  substr($hash, 16, 0) = '8';
  
  substr($hash, 8,0) = '-';
  substr($hash, 13,0) = '-';
  substr($hash, 18,0) = '-';
  substr($hash, 23,0) = '-';

  return $hash;
}

sub uuid2hash {
  my ($uuid) = @_;

  substr($uuid, 23,1) = '';
  substr($uuid, 18,1) = '';
  substr($uuid, 13,1) = '';
  substr($uuid, 8, 1) = '';

  substr($uuid, 16, 1) = '';
  substr($uuid, 12, 1) = '';
  
  return $uuid;
}

1;

