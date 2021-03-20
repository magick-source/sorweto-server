package SorWeTo::Db;

use Mojo::Base 'Class::DBI';
use Class::DBI::AbstractSearch;

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
    { mysql_enable_utf8 => 1 },
  );

  if ( $dbinfo->{trace} ) {
    DBI->trace('SQL');
  } else {
    DBI->trace(0);
  }
}

sub flagged {
  my ($obj, @flags) = @_;

  return unless $obj->can('flags');

  my $flags = $obj->flags;
  return unless $flags;

  my %flags = map { $_ => 1 } split /,/, $flags;

  my @flagged = ();
  for my $flag (@flags) {
    push @flagged, $flag
      if $flags{ $flag };
  }
  return @flagged;
}

sub do_transaction {
  my ($class, $code) = @_;

  local $class->db_Main->{ AutoCommit };

  eval {
    $code->( );
    $class->dbi_commit;
    1;
  } or do {
    my $commit_error = $@ || 'invisierror?';
    eval { $class->dbi_rollback };
    die $commit_error;
  };
}

1;
