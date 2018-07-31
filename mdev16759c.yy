#query_init:
#	CREATE TABLE IF NOT EXISTS `t1` ( `id` INT NOT NULL AUTO_INCREMENT, `b` longtext, `c` varchar(14) DEFAULT NULL, `d` varchar(255) DEFAULT NULL, PRIMARY KEY (`id`), KEY `idx_c` (`c`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ;

create_table:
  CREATE OR REPLACE TABLE `t1` ( `id` INT NOT NULL AUTO_INCREMENT, `b` longtext, `c` varchar(14) DEFAULT NULL, `d` varchar(255) DEFAULT NULL, PRIMARY KEY (`id`), KEY `idx_c` (`c`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ;

query:
    create_table
  ; LOCK TABLES `t1` WRITE 
  ; INSERT INTO `t1` VALUES vals1000
  ; INSERT INTO `t1` VALUES vals1000
  ; INSERT INTO `t1` VALUES vals1000
  ; INSERT INTO `t1` VALUES vals1000
  ; INSERT INTO `t1` VALUES vals1000
  ; UNLOCK TABLES
  ; INSERT INTO `t1` VALUES vals10
  ; REPLACE INTO `t1` SELECT * FROM `t1`
;

text256_or_null:
  _text(256) | NULL;

text64_or_null:
	_text(64) |	NULL;

vals1:
	(NULL, text256_or_null, _english, text64_or_null);

vals10:
	vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1;

vals100:
	vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10;

vals1000:
	vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100;
