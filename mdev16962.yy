query_init:
	init_db ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace ; alt_create_or_replace_sequence ; alt_create_or_replace_sequence; CREATE PROCEDURE IF NOT EXISTS { $last_sp= 'sp_grammar' } () BEGIN END 
;

query:
	select | alt_query | sp_create_and_or_execute | bulk_insert_load;

init_db:
	create_tables ; insert_tables ;  cache_index ; load_index ;

create_tables:
	create_10 ; create_10 ; create_10 ; create_10 ; create_10 ; create_10 ; create_nop_4 ;

create_10:
	create ; create ; create ; create ; create ; create ; create ; create ; create ; create ;

create_nop_4:
	create_nop ; create_nop ; create_nop ; create_nop ;

insert_tables:
	insert_part_tables ; insert_part_tables ; insert_part_tables ; insert_part_tables ; insert_nop_tables ;

insert_part_tables:
	insert_part_6 ; insert_part_6 ; insert_part_6 ; insert_part_6 ; insert_part_6 ;

insert_nop_tables:
	insert_nop_6 ; insert_nop_6 ; insert_nop_6 ; insert_nop_6 ; insert_nop_6 ;

insert_part_6:
	insert_part ; insert_part ; insert_part ; insert_part ; insert_part ; insert_part ;

insert_nop_6:
	insert_nop ; insert_nop ; insert_nop ; insert_nop ; insert_nop ; insert_nop ;

create:
        CREATE TABLE if_not_exists table_name_part (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key`)
	) ENGINE = engine partition ;

create_nop:
        CREATE TABLE if_not_exists table_name_nopart (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key`)
	) ENGINE = engine ;

insert_part:
        INSERT INTO table_name_part   ( `col_int_nokey`, `col_int_key` ) VALUES ( value , value ) , ( value , value ) , ( value , value ) , ( value , value ) ;

insert_nop:
        INSERT INTO table_name_nopart ( `col_int_nokey`, `col_int_key` ) VALUES ( value , value ) , ( value , value ) , ( value , value ) , ( value , value ) ;


exec_sql:
	select_explain |
	select | select | select | select | select | select                   |
	select | select | select | select | select | select                   |
	select | select | select | select | select | select                   |
	insert | update | delete | insert | update                            |
	insert | update | delete | insert | update                            |
	alter | alter | alter | alter | alter | alter                         |
	alter | alter | alter | alter | alter | alter                         |
	cache_index | load_index                                              |
	create_sel | create_sel | create_sel | create_sel | create_sel | drop |
	set_key_buffer_size | set_key_cache_block_size                        ;

cache_index:
	CACHE INDEX table_name_letter IN cache_name                                               |
	CACHE INDEX table_name_letter PARTITION ( ALL ) IN cache_name                 |
	CACHE INDEX table_name_letter PARTITION ( partition_name_list ) IN cache_name ;

load_index:
	LOAD INDEX INTO CACHE table_name_letter ignore_leaves                                               |
	LOAD INDEX INTO CACHE table_name_letter PARTITION ( ALL ) ignore_leaves                 |
	LOAD INDEX INTO CACHE table_name_letter PARTITION ( partition_name_list ) ignore_leaves ;

ignore_leaves:
	| IGNORE LEAVES ;

set_key_buffer_size:
	SET GLOBAL cache_name.key_buffer_size = _tinyint_unsigned |
	SET GLOBAL cache_name.key_buffer_size = _smallint_unsigned |
	SET GLOBAL cache_name.key_buffer_size = _mediumint_unsigned ;

set_key_cache_block_size:
	SET GLOBAL cache_name.key_cache_block_size = key_cache_block_size_enum ;

key_cache_block_size_enum:
	512 | 1024 | 2048 | 4096 | 8192 | 16384 ;

cache_name:
	c1 | c2 | c3 | c4;

select_explain:
	EXPLAIN PARTITIONS SELECT _field FROM table_name_letter where ;

create_select:
	SELECT `col_int_nokey` % 10 AS `col_int_nokey` , `col_int_key` % 10 AS `col_int_key` FROM table_name_letter where ;

select:
	SELECT `col_int_nokey` % 10 AS `col_int_nokey` , `col_int_key` % 10 AS `col_int_key` FROM dml_table_name    where ;

# WHERE clauses suitable for partition pruning
where:
	|                                      |
	WHERE _field comparison_operator value |
	WHERE _field BETWEEN value AND value   ;

comparison_operator:
        > | < | = | <> | != | >= | <= ;

insert:
        insert_replace INTO dml_table_name ( `col_int_nokey`, `col_int_key` ) VALUES ( value , value ) , ( value , value )                     |
        insert_replace INTO dml_table_name ( `col_int_nokey`, `col_int_key` ) select ORDER BY `col_int_key` , `col_int_nokey` LIMIT limit_rows ;

insert_replace:
        INSERT | REPLACE ;

update:
        UPDATE dml_table_name SET _field = value WHERE _field = value ;

delete:
        DELETE FROM dml_table_name WHERE _field = value ORDER BY `col_int_key` , `col_int_nokey` LIMIT limit_rows ;

dml_table_name:
	table_name_part_ext | table_name_part_ext | table_name_part_ext | table_name_part_ext |
	table_name_part_ext | table_name_part_ext | table_name_part_ext | table_name_part_ext |
	table_name_nopart                                                                     ;

table_name_part_ext:
	table_name_part /*!50610 PARTITION (partition_name_list) */ ;

table_name_nopart:
	a | b ;

table_name_part:
	c | d | e | f | g | h | i | j | k | l | m | n | o | p | q | r | s | t | u | v | w | x | y | z ;

value:
        _digit ;

_field:
        `col_int_nokey` | `col_int_nokey` ;

create_sel:
        create_part | create_part | create_part | create_nopart | create_nopart ;

create_part:
	CREATE TABLE if_not_exists table_name_part (
		`col_int_nokey` INTEGER,
		`col_int_key` INTEGER NOT NULL,
		KEY (`col_int_key`)
	) ENGINE = engine partition create_select ;

create_nopart:
        CREATE TABLE if_not_exists table_name_nopart (
                `col_int_nokey` INTEGER,
                `col_int_key` INTEGER NOT NULL,
                KEY (`col_int_key`)
        ) ENGINE = engine create_select ;

table_name_letter:
	table_name_part   |
	table_name_nopart ;

drop:
	DROP TABLE if_exists table_name_letter ;

alter:
	ALTER TABLE table_name_letter alter_operation;

alter_operation:
	partition                                                           |
	enable_disable KEYS                                                 |
	ADD PARTITION (PARTITION partition_name VALUES LESS THAN MAXVALUE)  |
	ADD PARTITION (PARTITION p3 VALUES LESS THAN MAXVALUE)              |
	DROP PARTITION partition_name                                       |
	COALESCE PARTITION one_two                                          |
  /*!50610 EXCHANGE PARTITION partition_name WITH TABLE table_name_nopart */ |
	ANALYZE PARTITION partition_name_list                               |
	CHECK PARTITION partition_name_list                                 |
	REBUILD PARTITION partition_name_list                               |
	REPAIR PARTITION partition_name_list                                |
	REMOVE PARTITIONING                                                 |
	OPTIMIZE PARTITION partition_name_list                              |
	REORGANIZE PARTITION partition_name_list INTO partition_by_range_or_list_definition |
	ENGINE = engine                                                     |
	ORDER BY _field                                                     |
	TRUNCATE PARTITION partition_name_list		# can not be used in comparison tests against 5.0
;

one_two:
	1 | 2;

partition_name_list:
	partition_name_comb                 |
	partition_name_comb                 |
	partition_name_comb                 |
	partition_name                      |
	partition_name                      |
	partition_name                      |
	partition_name                      |
	partition_name                      |
	partition_name, partition_name_list ;

partition_name_comb:
	p0,p1       |
	p0,p1,p2    |
	p0,p1,p2,p3 |
	p1,p2       |
	p1,p2,p3    |
	p2,p3       |
	p2,p3,p1    |
	p3,p1       |
	p0,p2       |
	p0,p3       ;

partition_name:
	p0 | p1 | p2 | p3 ;

enable_disable:
	ENABLE | DISABLE ;

# Give preference to MyISAM because key caching is specific to MyISAM

engine:
	MYISAM | MYISAM | MYISAM |
	INNODB | MEMORY          ;

partition:
	partition_by_range |
	partition_by_list  |
	partition_by_hash  |
	partition_by_key   ;

subpartition:
	|
	SUBPARTITION BY linear HASH ( _field ) SUBPARTITIONS partition_count ;

partition_by_range:
	PARTITION BY RANGE ( _field ) subpartition partition_by_range_definition
;

partition_by_range_definition:
  ( populate_ranges
		PARTITION p0 VALUES LESS THAN ( shift_range ),
		PARTITION p1 VALUES LESS THAN ( shift_range ),
		PARTITION p2 VALUES LESS THAN ( shift_range ),
		PARTITION p3 VALUES LESS THAN MAXVALUE
	)
;

populate_ranges:
	{ @ranges = ($prng->digit(), $prng->int(10,255), $prng->int(256,65535)) ; return undef } ;

shift_range:
	{ shift @ranges };

partition_by_list:
	PARTITION BY LIST ( _field ) subpartition partition_by_list_definition
;

partition_by_list_definition:  
  ( populate_digits
		PARTITION p0 VALUES IN ( shift_digit, NULL ),
		PARTITION p1 VALUES IN ( shift_digit, shift_digit, shift_digit ),
		PARTITION p2 VALUES IN ( shift_digit, shift_digit, shift_digit ),
		PARTITION p3 VALUES IN ( shift_digit, shift_digit, shift_digit )
		default_list_partition
	)
;

partition_by_range_or_list_definition:
    partition_by_range_definition
  | partition_by_list_definition
;

default_list_partition:
	| { '/*!100202 , PARTITION pdef DEFAULT */' }
;

populate_digits:
	{ @digits = @{$prng->shuffleArray([0..9])} ; return undef };

shift_digit:
	{ shift @digits };

partition_by_hash:
	PARTITION BY linear HASH ( _field ) PARTITIONS partition_count;

linear:
	| LINEAR;

partition_by_key:
	PARTITION BY KEY(`col_int_key`) PARTITIONS partition_count ;

partition_hash_or_key:
	HASH ( field_name ) PARTITIONS partition_count |
	KEY  ( field_name ) PARTITIONS partition_count ;

limit_rows:
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 ;

partition_count:
	1 | 2 | 3 | 3 | 3 | 4 | 4 | 4 | 4 ;

if_exists:
	IF EXISTS ;

if_not_exists:
	IF NOT EXISTS ;

#---------------------------------------------------------

alt_query:
    alt_create
  | alt_dml | alt_dml | alt_dml
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
  | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter | alt_alter
  | alt_rename_multi
  | alt_alter_partitioning
  | alt_flush
  | alt_optimize
  | alt_lock_unlock_table
  | alt_transaction
;

alt_create:
    alt_create_or_replace
  | alt_create_like
;

alt_rename_multi:
    DROP TABLE IF EXISTS { $tmp_tbl= 'tmp_rename_'.abs($$) } ; RENAME TABLE alt_table_name TO $tmp_tbl, $tmp_tbl TO { $my_last_table }
;

alt_dml:
    alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert | alt_insert
  | alt_update | alt_update
  | alt_delete | alt_truncate
;  

alt_alter:
  ALTER alt_online_optional alt_ignore_optional TABLE alt_table_name alt_wait_optional alt_alter_list_with_optional_order_by
;

alt_wait_optional:
  | | | /*!100301 WAIT _digit */ | /*!100301 NOWAIT */
;

alt_ignore_optional:
  | | IGNORE
;

alt_online_optional:
  | | | ONLINE
;

alt_alter_list_with_optional_order_by:
  alt_alter_list alt_optional_order_by
;

alt_alter_list:
  alt_alter_item | alt_alter_item | alt_alter_item, alt_alter_list
;

alt_alter_item:
    alt_table_option
  | alt_add_column
  | alt_modify_column
  | alt_change_column
  | alt_alter_column
  | alt_add_index | alt_add_index | alt_add_index
  | alt_add_foreign_key | alt_add_foreign_key
  | alt_drop_foreign_key
#  | alt_add_check_constraint | alt_add_check_constraint
#  | alt_drop_check_constraint
  | alt_drop_column | alt_drop_column
  | alt_drop_index | alt_drop_index
  | FORCE alt_lock alt_algorithm
  | RENAME TO alt_table_name
;

# Can't put it on the list, as ORDER BY should always go last
alt_optional_order_by:
  | | | | | | | | | | , ORDER BY alt_column_list
;

alt_table_option:
    alt_storage_optional ENGINE alt_eq_optional alt_engine
  | alt_storage_optional ENGINE alt_eq_optional alt_engine
  | AUTO_INCREMENT alt_eq_optional _int_unsigned
  | AUTO_INCREMENT alt_eq_optional _int_unsigned
  | AVG_ROW_LENGTH alt_eq_optional _tinyint_unsigned
  | alt_default_optional CHARACTER SET alt_eq_optional alt_character_set
  | alt_default_optional CHARACTER SET alt_eq_optional alt_character_set
  | CHECKSUM alt_eq_optional alt_zero_or_one
  | CHECKSUM alt_eq_optional alt_zero_or_one
  | alt_default_optional COLLATE alt_eq_optional alt_collation
  | alt_comment
  | alt_comment
#  | CONNECTION [=] 'connect_string'
#  | DATA DIRECTORY [=] 'absolute path to directory'
  | DELAY_KEY_WRITE alt_eq_optional alt_zero_or_one
# alt_eq_optional disabled due to MDEV-14859
#  | ENCRYPTED alt_eq_optional alt_yes_or_no_no_no
  | /*!100104 ENCRYPTED = alt_yes_or_no_no_no */
# alt_eq_optional disabled due to MDEV-14861
#  | ENCRYPTION_KEY_ID alt_eq_optional _digit
  | /*!100104 ENCRYPTION_KEY_ID = _digit */
# alt_eq_optional disabled due to MDEV-14859
#  | IETF_QUOTES alt_eq_optional alt_yes_or_no_no_no
  | /*!100108 IETF_QUOTES = alt_yes_or_no_no_no */
#  | INDEX DIRECTORY [=] 'absolute path to directory'
#  | INSERT_METHOD [=] { NO | FIRST | LAST }
  | KEY_BLOCK_SIZE alt_eq_optional alt_key_block_size
  | MAX_ROWS alt_eq_optional _int_unsigned
  | MIN_ROWS alt_eq_optional _tinyint_unsigned
  | PACK_KEYS alt_eq_optional alt_zero_or_one_or_default
  | PAGE_CHECKSUM alt_eq_optional alt_zero_or_one
  | PASSWORD alt_eq_optional _english
  | alt_change_row_format
  | alt_change_row_format
  | STATS_AUTO_RECALC alt_eq_optional alt_zero_or_one_or_default
  | STATS_PERSISTENT alt_eq_optional alt_zero_or_one_or_default
  | STATS_SAMPLE_PAGES alt_eq_optional alt_stats_sample_pages
#  | TABLESPACE tablespace_name
  | TRANSACTIONAL alt_eq_optional alt_zero_or_one
#  | UNION [=] (tbl_name[,tbl_name]...)
;

alt_stats_sample_pages:
  DEFAULT | _smallint_unsigned
;

alt_zero_or_one_or_default:
  0 | 1 | DEFAULT
;

alt_key_block_size:
  0 | 1024 | 2048 | 4096 | 8192 | 16384 | 32768 | 65536
;

alt_yes_or_no_no_no:
  YES | NO | NO | NO
;

alt_zero_or_one:
  0 | 1
;

alt_character_set:
  utf8 | latin1 | utf8mb4
;

alt_collation:
    latin1_bin
  | latin1_general_cs
  | latin1_general_ci
  | utf8_bin
  | /*!100202 utf8_nopad_bin */ /*!!100202 utf8_bin */
  | utf8_general_ci
  | utf8mb4_bin
  | /*!100202 utf8mb4_nopad_bin */ /*!!100202 utf8mb4_bin */
  | /*!100202 utf8mb4_general_nopad_ci */ /*!!100202 utf8mb4_general_ci */
  | utf8mb4_general_ci
;

alt_eq_optional:
  | =
;

alt_engine:
  InnoDB | InnoDB | InnoDB | InnoDB | MyISAM | MyISAM | Aria | Memory
;

alt_default_optional:
  | | DEFAULT
;

alt_storage_optional:
# Disabled due to MDEV-14860
#  | | STORAGE
;
  

alt_transaction:
    BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

alt_lock_unlock_table:
    FLUSH TABLE alt_table_name FOR EXPORT
  | LOCK TABLE alt_table_name READ
  | LOCK TABLE alt_table_name WRITE
  | SELECT * FROM alt_table_name FOR UPDATE
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
  | UNLOCK TABLES
;

alt_alter_partitioning:
    ALTER TABLE alt_table_name PARTITION BY HASH(alt_col_name)
  | ALTER TABLE alt_table_name PARTITION BY KEY(alt_col_name)
  | ALTER TABLE alt_table_name REMOVE PARTITIONING
;

alt_delete:
  DELETE FROM alt_table_name LIMIT _digit
;

alt_truncate:
  TRUNCATE TABLE alt_table_name
;

alt_table_name:
    { $my_last_table = 't'.$prng->int(1,10) }
  | { $my_last_table = 't'.$prng->int(1,10) }
  | _table { $my_last_table = $last_table; '' }
;

alt_col_name:
    alt_int_col_name
  | alt_num_col_name
  | alt_temporal_col_name
  | alt_timestamp_col_name
  | alt_text_col_name
  | alt_enum_col_name
  | alt_virt_col_name
  | _field
;

alt_bit_col_name:
  { $last_column = 'bcol'.$prng->int(1,10) }
;


alt_int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

alt_num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

alt_virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

alt_temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

alt_timestamp_col_name:
    { $last_column = 'tscol'.$prng->int(1,10) }
;

alt_geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

alt_text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

alt_enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,10) }
;

alt_ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

alt_col_name_and_definition:
    alt_bit_col_name alt_bit_type alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_int_col_name alt_int_type alt_unsigned alt_zerofill alt_null alt_default_optional_int_or_auto_increment alt_invisible_optional alt_check_optional
  | alt_num_col_name alt_num_type alt_unsigned alt_zerofill alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_temporal_col_name alt_temporal_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_timestamp_col_name alt_timestamp_type alt_null alt_optional_default_or_current_timestamp alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_text_col_name alt_text_type alt_null alt_optional_default_char alt_invisible_optional alt_check_optional
  | alt_enum_col_name alt_enum_type alt_null alt_optional_default alt_invisible_optional alt_check_optional
  | alt_virt_col_name alt_virt_col_definition alt_virt_type alt_invisible_optional alt_check_optional
  | alt_geo_col_name alt_geo_type alt_null alt_geo_optional_default alt_invisible_optional alt_check_optional
;


alt_check_optional:
#  | | | | /*!100201 CHECK (alt_check_constraint_expression) */
;

alt_invisible_optional:
  | | | | /*!100303 INVISIBLE */
;

alt_col_versioning_optional:
 | | | | | /*!100304 alt_with_without SYSTEM VERSIONING */
;

alt_with_without:
  WITH | WITHOUT
;

alt_virt_col_definition:
    alt_int_type AS ( alt_int_col_name + _digit )
  | alt_num_type AS ( alt_num_col_name + _digit )
  | alt_temporal_type AS ( alt_temporal_col_name )
  | alt_timestamp_type AS ( alt_timestamp_col_name )
  | alt_text_type AS ( SUBSTR(alt_text_col_name, _digit, _digit ) )
  | alt_enum_type AS ( alt_enum_col_name )
  | alt_geo_type AS ( alt_geo_col_name )
;

alt_virt_type:
  /*!100201 STORED */ /*!!100201 PERSISTENT */ | VIRTUAL
;

alt_optional_default_or_current_timestamp:
  | DEFAULT alt_default_or_current_timestamp_val
;

alt_default_or_current_timestamp_val:
    '1970-01-01'
  | CURRENT_TIMESTAMP
  | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  | 0
;


alt_unsigned:
  | | UNSIGNED
;

alt_zerofill:
  | | | | ZEROFILL
;

alt_default_optional_int_or_auto_increment:
  alt_optional_default_int | alt_optional_default_int | alt_optional_default_int | alt_optional_auto_increment
;

alt_create_or_replace:
  CREATE OR REPLACE alt_temporary TABLE alt_table_name (alt_col_name_and_definition_list) alt_table_flags
;

alt_create_or_replace_sequence:
  /*!100303 CREATE OR REPLACE SEQUENCE alt_table_name */
;

alt_col_name_and_definition_list:
  alt_col_name_and_definition | alt_col_name_and_definition | alt_col_name_and_definition, alt_col_name_and_definition_list
;

alt_table_flags:
  alt_row_format_optional alt_encryption alt_compression
;

alt_encryption:
;

alt_compression:
;

alt_change_row_format:
  ROW_FORMAT alt_eq_optional alt_row_format
;

alt_row_format:
    DEFAULT | DEFAULT | DEFAULT
  | DYNAMIC | DYNAMIC | DYNAMIC | DYNAMIC
  | FIXED | FIXED
  | COMPRESSED | COMPRESSED | COMPRESSED | COMPRESSED
  | REDUNDANT | REDUNDANT | REDUNDANT
  | COMPACT | COMPACT | COMPACT
  | PAGE
;

alt_row_format_optional:
  | alt_change_row_format | alt_change_row_format
;

alt_create_like:
  CREATE alt_temporary TABLE alt_table_name LIKE _table
;

alt_insert:
  alt_insert_select | alt_insert_values
;

alt_update:
  UPDATE alt_table_name SET alt_col_name = DEFAULT LIMIT 1;

alt_insert_select:
  INSERT INTO alt_table_name ( alt_col_name ) SELECT alt_col_name FROM alt_table_name
;

alt_insert_values:
    INSERT INTO alt_table_name () VALUES alt_empty_value_list
  | INSERT INTO alt_table_name (alt_col_name) VALUES alt_non_empty_value_list
;

alt_non_empty_value_list:
  (_alt_value) | (_alt_value),alt_non_empty_value_list
;
 
alt_empty_value_list:
  () | (),alt_empty_value_list
;

alt_add_column:
    ADD alt_column_optional alt_if_not_exists alt_col_name_and_definition alt_col_location alt_algorithm alt_lock
  | ADD alt_column_optional alt_if_not_exists ( alt_col_name_and_definition_list ) alt_algorithm alt_lock
;

alt_column_optional:
  | | COLUMN
;

alt_col_location:
  | | | | | FIRST | AFTER alt_col_name
;

alt_modify_column:
  MODIFY COLUMN alt_if_exists alt_col_name_and_definition alt_col_location alt_algorithm alt_lock
;

alt_change_column:
  CHANGE COLUMN alt_if_exists alt_col_name alt_col_name_and_definition alt_algorithm alt_lock
;

alt_alter_column:
    ALTER COLUMN /*!100305 alt_if_exists */ alt_col_name SET DEFAULT alt_default_val
  | ALTER COLUMN alt_col_name DROP DEFAULT
;

alt_if_exists:
  | IF EXISTS | IF EXISTS
;

alt_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS
;

alt_drop_column:
  DROP COLUMN alt_if_exists alt_col_name alt_algorithm alt_lock
;

alt_add_index:
  ADD alt_any_key alt_algorithm alt_lock
;


alt_drop_index:
  DROP INDEX alt_ind_name | DROP PRIMARY KEY
;

alt_column_list:
  alt_col_name | alt_col_name, alt_column_list
;

alt_temporary:
  | | | | TEMPORARY
;

alt_flush:
  FLUSH TABLES
;

alt_optimize:
  OPTIMIZE TABLE alt_table_name
;

alt_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY | , ALGORITHM=DEFAULT
;

alt_lock:
  | | , LOCK=NONE | , LOCK=SHARED | , LOCK=EXCLUSIVE | , LOCK=DEFAULT
;
  
alt_data_type:
    alt_bit_type
  | alt_enum_type
  | alt_geo_type
  | alt_int_type
  | alt_int_type
  | alt_int_type
  | alt_int_type
  | alt_num_type
  | alt_temporal_type
  | alt_timestamp_type
  | alt_text_type
  | alt_text_type
  | alt_text_type
  | alt_text_type
;

alt_bit_type:
  BIT
;

alt_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

alt_num_type:
  DECIMAL | FLOAT | DOUBLE
;

alt_temporal_type:
  DATE | TIME | YEAR
;

alt_timestamp_type:
  DATETIME | TIMESTAMP
;

alt_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

alt_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

alt_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

alt_null:
  | NULL | NOT NULL ;
  
alt_optional_default:
  | DEFAULT alt_default_val
;

alt_default_val:
  NULL | alt_default_char_val | alt_default_int_val
;

alt_optional_default_char:
  | DEFAULT alt_default_char_val
;

alt_default_char_val:
  NULL | ''
;

alt_optional_default_int:
  | DEFAULT alt_default_int_val
;

alt_default_int_val:
  NULL | 0 | _digit
;

alt_geo_optional_default:
  | /*!100201 DEFAULT ST_GEOMFROMTEXT('Point(1 1)') */ ;

alt_optional_auto_increment:
  | | | | | | AUTO_INCREMENT
;
  
alt_inline_key:
  | | | alt_index ;
  
alt_index:
    alt_index_or_key
  | alt_constraint_optional PRIMARY KEY
  | alt_constraint_optional UNIQUE alt_optional_index_or_key
;

alt_add_foreign_key:
  ADD alt_constraint_optional FOREIGN KEY alt_index_name_optional (alt_column_or_list) REFERENCES alt_table_name (alt_column_or_list) alt_optional_on_delete alt_optional_on_update
;

alt_add_check_constraint:
  ADD CONSTRAINT alt_index_name_optional CHECK (alt_check_constraint_expression)
;

alt_drop_check_constraint:
  /*!100200 DROP CONSTRAINT alt_if_exists _letter */ /*!!100200 COMMENT 'Skipped DROP CONSTRAINT' */
;

# TODO: extend
alt_check_constraint_expression:
    alt_col_name alt_operator alt_col_name
  | alt_col_name alt_operator _digit
;

alt_operator:
  = | != | LIKE | NOT LIKE | < | <= | > | >=
;

alt_drop_foreign_key:
  DROP FOREIGN KEY alt_if_exists _letter
;

alt_column_or_list:
  alt_col_name | alt_col_name | alt_col_name | alt_column_list
;

alt_optional_on_delete:
  | | ON DELETE alt_reference_option
;

alt_optional_on_update:
  | | ON UPDATE alt_reference_option
;

alt_reference_option:
  RESTRICT | CASCADE | SET NULL | NO ACTION | SET DEFAULT
;

alt_constraint_optional:
  | CONSTRAINT alt_index_name_optional
;

alt_index_name_optional:
  | _letter
;

alt_index_or_key:
  KEY | INDEX
;

alt_optional_index_or_key:
  | alt_index_or_key
;
  
alt_key_column:
    alt_bit_col_name
  | alt_int_col_name
  | alt_int_col_name
  | alt_int_col_name
  | alt_num_col_name
  | alt_enum_col_name
  | alt_temporal_col_name
  | alt_timestamp_col_name
  | alt_text_col_name(_tinyint_positive)
  | alt_text_col_name(_smallint_positive)
;

alt_key_column_list:
  alt_key_column | alt_key_column, alt_key_column_list
;

alt_any_key:
    alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column)
  | alt_index(alt_key_column_list)
  | alt_index(alt_key_column_list)
  | FULLTEXT KEY(alt_text_col_name)
  | FULLTEXT KEY(alt_text_col_name)
#  | SPATIAL INDEX(alt_geo_col_name)
;

alt_comment:
  COMMENT alt_eq_optional _english
;
  
alt_compressed:
  | | | | | | COMPRESSED ;

_alt_value:
  NULL | _digit | '' | _char(1)
;

#-----------------------------------------------------------------------

sp_name:
    # This one is to be dealt with only in this thread
    { $last_sp= 'sp_'.abs($$) } 
    # This one is to be dealt with concurrently
  | { $last_sp= 'sp_grammar' }
  | { $last_sp= 'sp_grammar1' }
  | { $last_sp= 'sp_grammar2' }
;

sp_create_and_or_execute:
    sp_drop ; sp_create
  | sp_create_or_replace
  | sp_call | sp_call | sp_call | sp_call
;

sp_drop:
  DROP PROCEDURE IF EXISTS sp_name
;

sp_create:
  CREATE PROCEDURE IF NOT EXISTS sp_name () BEGIN sp_body ; END
;
sp_create_or_replace:
  CREATE OR REPLACE PROCEDURE sp_name () BEGIN sp_body ; END
;

sp_call:
    CALL $last_sp
  | CALL sp_name
;

sp_body:
  query | query | query ; sp_body
;

#-----------------------------------------------------------------------

bulk_insert_load:
    INSERT INTO _table SELECT * FROM _table
  | SELECT * FROM _table INTO OUTFILE { "'load_$last_table'" } ; LOAD DATA INFILE { "'load_$last_table'" } bulk_replace_ignore INTO TABLE { $last_table }
;

bulk_replace_ignore:
  REPLACE | IGNORE
;
