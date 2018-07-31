date_or_null:
	NULL | _english;

dump:
	TRUNCATE TABLE my_table ; LOCK TABLES { $mtable } WRITE ; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; UNLOCK TABLES; INSERT INTO { $mtable } VALUES vals100 ON DUPLICATE KEY UPDATE `f` = _int ; REPLACE INTO { $mtable } SELECT * FROM my_table
;

int_or_null:
	_smallint_unsigned |
	NULL;

my_table:
	{ $mtable = 't0' };

query:
	TRUNCATE TABLE my_table ; LOCK TABLES { $mtable } WRITE ; INSERT INTO $mtable VALUES vals1000; INSERT INTO $mtable VALUES vals1000; INSERT INTO $mtable VALUES vals1000; INSERT INTO $mtable VALUES vals1000; UNLOCK TABLES; INSERT INTO { $mtable } VALUES vals100 ON DUPLICATE KEY UPDATE `f` = _int ; REPLACE INTO { $mtable } SELECT * FROM $mtable
;

query_init:
	CREATE TABLE IF NOT EXISTS `t0` ( `id` INT NOT NULL AUTO_INCREMENT, `a` INT DEFAULT NULL, `b` longtext, `c` varchar(14) DEFAULT NULL, `d` varchar(255) DEFAULT NULL, `e` tinyint(1) DEFAULT '0', `f` int(11) DEFAULT NULL, PRIMARY KEY (`id`), KEY `idx_c` (`c`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ;

text256_or_null:
	_text(256) |
	NULL;

text64_or_null:
	_text(64) |
	NULL;

truncate:
	TRUNCATE TABLE my_table;

vals1:
	(NULL, _smallint, text256_or_null, date_or_null, text64_or_null, { $prng->int(0,1) }, int_or_null);

vals10:
	vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1, vals1;

vals100:
	vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10, vals10;

vals1000:
	vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100, vals100;

vals5000:
	vals1000, vals1000, vals1000, vals1000, vals1000;
