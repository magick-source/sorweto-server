package SorWeTo::Db;

use Mojo::Base 'Class::DBI';

# TODO: create an insert_or_update method that will use UDKU

sub init {
  my ($class, $dbinfo) = @_;

  my $dsn = "dbi:mysql:$dbinfo->{dbname}";
  if ($dbinfo->{hostname}) {
    $dsn.=";host=$dbinfo->{hostname}";
  }

  $class->connection(
    $dsn,
    $dbinfo->{dbuser},
    $dbinfo->{dbpass},
  );

  if ( $dbinfo->{trace} ) {
    DBI->trace('3|SQL');
  } else {
    DBI->trace(0);
  }
}

1;
