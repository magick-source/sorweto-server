package SorWeTo::Db::UserLogin;

use parent 'SorWeTo::Db';

__PACKAGE__->table('swt_user_login');

__PACKAGE__->columns( Primary => qw(id) );

__PACKAGE__->columns( All => qw(
    id
    user_id
		login_type
    identifier
    info
    last_updated
    flags
  ));

=for MySQL

CREATE TABLE `swt_user_login` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned DEFAULT NULL,
  `login_type` varchar(20) DEFAULT NULL,
  `identifier` varchar(100) DEFAULT NULL,
  `info` varchar(250) DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `flags` set('active') DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `login_type` (`login_type`,`identifier`),
  KEY `user_id` (`user_id`,`login_type`,`identifier`),
  KEY `last_updated` (`last_updated`,`flags`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4

=cut

1;

__END__


