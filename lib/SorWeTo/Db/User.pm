package SorWeTo::Db::User;

use parent 'SorWeTo::Db';

use SorWeTo::User;

__PACKAGE__->table('swt_user');

__PACKAGE__->columns( Primary => qw(id) );

__PACKAGE__->columns( All => qw(
    id
    username
		display_name
    sql_last_updated
    flags
  ));

sub from_id {
  my ($class, $id) = @_;

  my $user = $class->retrieve( $id );

  if ($user) {
    return SorWeTo::User->from_dbuser( $user );
  }

  return;
}

=for MySQL

CREATE TABLE `swt_user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(20) DEFAULT NULL,
  `display_name` varchar(30) DEFAULT NULL,
  `sql_last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `flags` set('active','admin','pending') NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `sql_last_updated` (`sql_last_updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4

=cut

1;

__END__


