package SorWeTo::Db::UserSetting;

use parent 'SorWeTo::Db';

__PACKAGE__->table('swt_user_setting');

__PACKAGE__->columns( Primary => qw(id) );

__PACKAGE__->columns( All => qw(
    id
    user_id
    name
    value_num
    value_blob
    sql_last_updated
  ));

__PACKAGE__->set_sql( increment => <<EoQ );
UPDATE __TABLE__
  SET value_num = value_num + ?
  WHERE id = ?
EoQ

sub increment_setting {
  my ($self, $inc) = @_;

  $self->increment_sql->execute( $self->id, $inc );

  return;
}

=for MySQL

CREATE TABLE `swt_user_setting` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `name` varchar(75) DEFAULT NULL,
  `value_num` decimal(15,3) DEFAULT NULL,
  `value_blob` blob DEFAULT NULL,
  `sql_last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`,`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

=cut

1;

