-- TODO: generate automatically from loaded packages

CREATE TABLE `swt_user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(20) DEFAULT NULL,
  `display_name` varchar(30) DEFAULT NULL,
  `sql_last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `flags` set('active','admin','pending') NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `sql_last_updated` (`sql_last_updated`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `swt_tmp_blob` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `blob_type` varchar(10) DEFAULT NULL,
  `blob_uuid` varchar(36) DEFAULT NULL,
  `data` blob,
  `sql_last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `expires` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `blob_type` (`blob_type`,`blob_uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


