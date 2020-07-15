package SorWeTo::Db;

use Mojo::Base 'Class::DBI';

# TODO: create an insert_or_update method that will use UDKU

sub init {
  my ($class, $dbinfo) = @_;

  $class->connection(
    "dbi:mysql:$dbinfo->{dbname}",
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
