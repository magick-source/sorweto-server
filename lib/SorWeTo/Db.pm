package SorWeTo::Db;

use Mojo::Base 'Class::DBI';
use SQL::Abstract::Limit;

__PACKAGE__->set_sql(retrieve_single => <<EoQ );
SELECT  %s
FROM    __TABLE__
WHERE   %s
EoQ

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

sub search_where {
  my $class = shift;

  my ($phrase, @bind) = $class->_where( @_ );

  return $class->retrieve_from_sql( $phrase, @bind );
}

sub search_where_count {
  my $class = shift;

  my ($phrase, @bind) = $class->_where( @_ );

  my ($count) = $class->sql_retrieve_single( 'COUNT(*)', $phrase )
                      ->select_val( @bind );

  return $count;
}

sub _where {
  my $class = shift;
  my $where = (ref $_[0]) ? $_[0]          : { @_ };
  my $attr  = (ref $_[0]) ? $_[1]          : undef;
  my $order = ($attr)     ? delete($attr->{order_by}) : undef;
  my $limit  = ($attr)    ? delete($attr->{limit})    : undef;
  my $offset = ($attr)    ? delete($attr->{offset})   : undef;

  my $sql = SQL::Abstract::Limit->new(%$attr);
  my($phrase, @bind) = $sql->where($where, $order, $limit, $offset);
  $phrase =~ s/^\s*WHERE\s*//i;
  
  return ($phrase, @bind);
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
