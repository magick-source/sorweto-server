package SorWeTo::Db::TmpBlob;

use parent 'SorWeTo::Db';

__PACKAGE__->table('swt_tmp_blob');

__PACKAGE__->columns( Primary => qw(id) );

__PACKAGE__->columns( All => qw(
    id
		type
    data
    created
    expires
  ));

=for MySQL

CREATE TABLE `swt_tmp_blob` (
  `id` char(40) NOT NULL,
  `type` varchar(10) NOT NULL,
  `data` binary(1) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `expires` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`,`type`),
	KEY `expires` (`expires`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4

=cut

1;

__END__


