date_or_null:
	CURDATE() |
	NULL |
	{ $prng->int(2015,2018).'-0'.$prng->int(1,9).'-0'.$prng->int(1,9) };

dml:
  insert_values | insert_select | insert_on_dup_key_update
;

insert_values:
	ins_rpl INTO my_table VALUES vals1000 
;

insert_select:
	ins_rpl INTO my_table SELECT * FROM my_table
;
 
insert_on_dup_key_update:
	INSERT INTO my_table VALUES vals100 ON DUPLICATE KEY UPDATE `PDNoteContent` = _int
;

dump:
	TRUNCATE TABLE my_table ; SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' ; SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 ; LOCK TABLES { $mtable } WRITE ; ALTER TABLE { $mtable } DISABLE KEYS ; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; INSERT INTO { $mtable } VALUES vals1000; ALTER TABLE { $mtable } ENABLE KEYS ; UNLOCK TABLES ; SET SQL_MODE=@OLD_SQL_MODE ; SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;

ins_rpl:
	REPLACE;

int_or_null:
	_smallint_unsigned |
	NULL;

my_table:
	{ $mtable = '`notes`' } |
	{ $mtable = 't'.$prng->int(1,9) };

query:
	dml |
	dump;

query_init:
	CREATE TABLE IF NOT EXISTS `notes` ( `id` int(255) NOT NULL AUTO_INCREMENT, `accid` int(255) DEFAULT NULL, `ndesc` longtext, `ndate` varchar(14) DEFAULT NULL, `nbycsr` varchar(255) DEFAULT NULL, `permanent` tinyint(1) DEFAULT '0', `PDNoteContent` int(11) DEFAULT NULL, PRIMARY KEY (`id`), KEY `idx_notes_ndate` (`ndate`), KEY `idx_notes_permanent` (`permanent`), KEY `idx_notes_accidpermanent` (`accid`,`permanent`), KEY `PDNoteContent` (`PDNoteContent`) ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ; CREATE TABLE IF NOT EXISTS `t1` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t2` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t3` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t4` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t5` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t6` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t7` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t8` LIKE `notes` ; CREATE TABLE IF NOT EXISTS `t9` LIKE `notes`;

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
