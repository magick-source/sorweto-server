package SorWeTo::Db::TmpBlob;

use parent 'SorWeTo::Db';

__PACKAGE__->table('swt_tmp_blob');

__PACKAGE__->columns( Primary => qw(id) );

__PACKAGE__->columns( All => qw(
    id
		blob_type
	  blob_uuid
    data
    sql_last_updated
    expires
  ));

=for MySQL

CREATE TABLE `swt_tmp_blob` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blob_type` varchar(10) DEFAULT NULL,
  `blob_uuid` varchar(36) DEFAULT NULL,
  `data` blob,
  `sql_last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `expires` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `blob_type` (`blob_type`,`blob_uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4


=cut

1;

__END__


