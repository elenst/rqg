#  Copyright (c) 2017, MariaDB
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */


# Re-defining grammar for SYSTEM VERSIONING testing

thread2:
  vers_query
;

thread3:
  vers_query
;

vers_query:
    query | query | query
  | vers_ia_query | vers_ia_query | vers_ia_query
  | vers_alter | vers_alter | vers_alter | vers_alter | vers_alter | vers_alter | vers_alter | vers_alter
  | vers_select | vers_select | vers_select | vers_select | vers_select | vers_select | vers_select 
  | vers_select | vers_select | vers_select | vers_select | vers_select | vers_select | vers_select 
  | vers_alter_history
  | vers_truncate | vers_truncate
  | vers_tx_history
  | vers_show_table
;

vers_show_table:
    SHOW CREATE TABLE vers_existing_table
  | DESC vers_existing_table
  | SHOW INDEX IN vers_existing_table
  | SHOW TABLE STATUS LIKE { "'".$last_table."'" }
  | SHOW COLUMNS IN vers_existing_table
  | SHOW FULL COLUMNS IN vers_existing_table
  | SHOW FIELDS IN vers_existing_table
  | SHOW FULL FIELDS IN vers_existing_table
  | SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = { "'".$last_table."'" }
;

vers_engine:
  | | ENGINE=InnoDB | ENGINE=MyISAM | ENGINE=Aria | ENGINE=MEMORY
;

vers_with_system_versioning:
  | WITH SYSTEM VERSIONING
  | WITH SYSTEM VERSIONING
  | WITH SYSTEM VERSIONING
  | WITH SYSTEM VERSIONING
; 

vers_with_without_system_versioning:
  | | | | | | WITH SYSTEM VERSIONING | WITHOUT SYSTEM VERSIONING
;

vers_alter_history:
    SET vers_global `versioning_alter_history`= KEEP
  | SET vers_global `versioning_alter_history`= ERROR
  | SET vers_global `versioning_alter_history`= DEFAULT
;

vers_global:
  | | | GLOBAL
;

vers_alter:
    vers_set_statement_alter_history ALTER TABLE vers_existing_table vers_alter_table_list
  | vers_set_statement_alter_history ALTER TABLE vers_existing_table vers_partitioning
;

vers_set_statement_alter_history:
  | SET STATEMENT versioning_alter_history=KEEP FOR
  | SET STATEMENT versioning_alter_history=KEEP FOR
  | SET STATEMENT versioning_alter_history=KEEP FOR
;

vers_alter_table_list:
    vers_alter_table | vers_alter_table | vers_alter_table 
  | vers_alter_table, vers_alter_table_list
  | vers_alter_table, vers_ia_alter_list
  | vers_ia_alter_list, vers_alter_table_list
;

vers_alter_table:
    DROP SYSTEM VERSIONING
  | ADD SYSTEM VERSIONING | ADD SYSTEM VERSIONING | ADD SYSTEM VERSIONING
  | ADD PERIOD FOR SYSTEM_TIME(vers_col_start, vers_col_start)
  | vers_add_drop_sys_column
;

vers_add_drop_sys_column:
    ADD COLUMN vers_ia_if_not_exists vers_col_start vers_col_type GENERATED ALWAYS AS ROW START
  | ADD COLUMN vers_ia_if_not_exists vers_col_end vers_col_type GENERATED ALWAYS AS ROW END
  | DROP COLUMN vers_col_start
  | DROP COLUMN vers_col_end
  | CHANGE COLUMN vers_ia_if_exists vers_col_start vers_col_start vers_col_type GENERATED ALWAYS AS ROW START
  | CHANGE COLUMN vers_ia_if_exists vers_col_end vers_col_end vers_col_type GENERATED ALWAYS AS ROW END
;

vers_select:
    SELECT * from vers_existing_table FOR system_time vers_system_time_select
  | SELECT * from vers_existing_table WHERE sys_trx_start vers_comparison_operator @trx
  | SELECT * from vers_existing_table WHERE sys_trx_end vers_comparison_operator @trx
  | SELECT * from vers_existing_table WHERE sys_trx_start IN (SELECT sys_trx_start FROM vers_existing_table)
  | SELECT * from vers_existing_table WHERE sys_trx_end IN (SELECT sys_trx_start FROM vers_existing_table)
  | SELECT sys_trx_start FROM vers_existing_table ORDER BY RAND() LIMIT 1 INTO @trx
  | SELECT sys_trx_end FROM vers_existing_table ORDER BY RAND() LIMIT 1 INTO @trx
;

vers_comparison_operator:
  > | < | = | <= | >= | !=
;

vers_truncate:
  TRUNCATE vers_existing_table TO system_time vers_system_time
;

vers_tx_history:
  SELECT * FROM mysql.transaction_registry
;

vers_system_time_select:
    ALL | ALL | ALL
  | AS OF vers_timestamp_trx vers_system_time
  | BETWEEN vers_timestamp_trx vers_system_time AND vers_timestamp_trx vers_system_time
  | FROM vers_timestamp_trx vers_system_time TO vers_timestamp_trx vers_system_time
;

vers_timestamp_trx:
  | | | | TIMESTAMP | TIMESTAMP | TRANSACTION
;

vers_system_time:
    _timestamp 
  | CURRENT_TIMESTAMP 
  | NOW() | NOW(6)
  | _tinyint_unsigned 
  | @trx | @trx | @trx | @trx 
  | DATE_ADD(_timestamp, INTERVAL _positive_digit vers_interval)
  | DATE_SUB(_timestamp, INTERVAL _positive_digit vers_interval)
  | DATE_SUB(NOW(), INTERVAL _positive_digit vers_interval)
;

vers_col:
  vers_col_start | vers_col_end
;

vers_col_start:
  `vers_start` | `sys_trx_start`
;

vers_col_end:
  `vers_end` | `sys_trx_end`
;

vers_or_replace_if_not_exists:
  | OR REPLACE | IF NOT EXISTS
;

vers_partitioning:
    vers_partitioning_definition
  | vers_partitioning_definition
  | REMOVE PARTITIONING
  | DROP PARTITION vers_ia_if_exists { 'ver_p'.$prng->int(1,5) }
  | ADD PARTITION vers_ia_if_not_exists (PARTITION { 'ver_p'.++$parts } VERSIONING)
;

vers_partitioning_optional:
  | | vers_partitioning_definition
;

vers_partitioning_definition:
  { $parts=0 ; '' } 
  PARTITION BY system_time INTERVAL _positive_digit vers_interval vers_subpartitioning_optional (
    vers_partition_list ,
    PARTITION ver_pn AS OF CURRENT_TIMESTAMP
  )
;
    
vers_subpartitioning_optional:
  | | | | SUBPARTITION BY vers_hash_key(vers_ia_col_name) SUBPARTITIONS _positive_digit
;

vers_hash_key:
  KEY | HASH
;

vers_partition_list:
    PARTITION { 'ver_p'.++$parts } VERSIONING
  | PARTITION { 'ver_p'.++$parts } VERSIONING, 
    vers_partition_list
;

vers_interval:
  SECOND | MINUTE | HOUR | DAY | WEEK | MONTH | YEAR
;

####################################################

vers_ia_query:
    vers_ia_create
  | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert
  | vers_ia_update | vers_ia_update
  | vers_ia_delete | vers_ia_truncate
  | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert | vers_ia_insert
  | vers_ia_delete | vers_ia_truncate
  | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter
  | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter | vers_ia_alter
  | vers_ia_alter_partitioning
  | vers_ia_flush
  | vers_ia_optimize
  | vers_ia_lock_unlock_table
  | vers_ia_transaction
  | vers_ia_select
;

vers_ia_select:
  SELECT * FROM vers_existing_table
;

vers_ia_systime:
  ALL | NOW(6) | NOW() | CURRENT_TIMESTAMP | DATE(NOW())
;

vers_ia_alter:
  ALTER TABLE vers_existing_table vers_ia_alter_list
;

vers_ia_alter_list:
  vers_ia_alter_item | vers_ia_alter_item, vers_ia_alter_list
;

vers_ia_alter_item:
    vers_ia_add_column | vers_ia_add_column | vers_ia_add_column | vers_ia_add_column | vers_ia_add_column
  | vers_ia_modify_column | vers_ia_modify_column
  | vers_ia_add_index | vers_ia_add_index | vers_ia_add_index
  | vers_ia_drop_column | vers_ia_drop_column
  | vers_ia_drop_index | vers_ia_drop_index
  | vers_ia_change_row_format
  | FORCE vers_ia_lock vers_ia_algorithm
  | ENGINE=InnoDB
;

vers_ia_transaction:
    BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

vers_ia_lock_unlock_table:
    FLUSH TABLE vers_existing_table FOR EXPORT
  | LOCK TABLE vers_existing_table READ
  | LOCK TABLE vers_existing_table WRITE
  | SELECT * FROM vers_existing_table FOR UPDATE
  | UNLOCK TABLES
;

vers_ia_alter_partitioning:
    ALTER TABLE vers_existing_table PARTITION BY HASH(vers_ia_col_name)
  | ALTER TABLE vers_existing_table PARTITION BY KEY(vers_ia_col_name)
  | ALTER TABLE vers_existing_table REMOVE PARTITIONING
;

vers_ia_delete:
  DELETE FROM vers_existing_table LIMIT _digit
;

vers_ia_truncate:
  TRUNCATE TABLE vers_existing_table
;

vers_ia_table_name:
    { $my_last_table = 't'.$prng->int(1,10) }
;

vers_existing_table:
  vers_ia_table_name | _table
;

vers_ia_col_name:
    vers_ia_int_col_name
  | vers_ia_num_col_name
  | vers_ia_temporal_col_name
  | vers_ia_timestamp_col_name
  | vers_ia_text_col_name
  | vers_ia_enum_col_name
  | vers_ia_virt_col_name
  | _field
  | vers_col
;

vers_ia_bit_col_name:
  { $last_column = 'bcol'.$prng->int(1,10) }
;


vers_ia_int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

vers_ia_num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

vers_ia_virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

vers_ia_temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

vers_ia_timestamp_col_name:
    { $last_column = 'tscol'.$prng->int(1,10) }
;

vers_ia_geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

vers_ia_text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

vers_ia_enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,10) }
;

vers_ia_ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

vers_ia_col_name_and_definition:
    vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_real_col_name_and_definition
  | vers_ia_virt_col_name_and_definition
;

vers_ia_virt_col_name_and_definition:
  vers_ia_virt_col_name vers_ia_virt_col_definition vers_ia_virt_type
;

vers_ia_real_col_name_and_definition:
    vers_ia_bit_col_name vers_ia_bit_type vers_ia_null vers_ia_default_int_or_auto_increment
  | vers_ia_int_col_name vers_ia_int_type vers_ia_unsigned vers_ia_zerofill vers_ia_null vers_ia_default_int_or_auto_increment
  | vers_ia_int_col_name vers_ia_int_type vers_ia_unsigned vers_ia_zerofill vers_ia_null vers_ia_default_int_or_auto_increment
  | vers_ia_int_col_name vers_ia_int_type vers_ia_unsigned vers_ia_zerofill vers_ia_null vers_ia_default_int_or_auto_increment
  | vers_ia_num_col_name vers_ia_num_type vers_ia_unsigned vers_ia_zerofill vers_ia_null vers_ia_default
  | vers_ia_temporal_col_name vers_ia_temporal_type vers_ia_null vers_ia_default
  | vers_ia_timestamp_col_name vers_ia_timestamp_type vers_ia_null vers_ia_default_or_current_timestamp
  | vers_ia_text_col_name vers_ia_text_type vers_ia_null vers_ia_default_char
  | vers_ia_text_col_name vers_ia_text_type vers_ia_null vers_ia_default_char
  | vers_ia_text_col_name vers_ia_text_type vers_ia_null vers_ia_default_char
  | vers_ia_enum_col_name vers_ia_enum_type vers_ia_null vers_ia_default
  | vers_ia_geo_col_name vers_ia_geo_type vers_ia_null vers_ia_geo_default
;

vers_ia_virt_col_definition:
    vers_ia_int_type AS ( vers_ia_int_col_name + _digit )
  | vers_ia_num_type AS ( vers_ia_num_col_name + _digit )
  | vers_ia_temporal_type AS ( vers_ia_temporal_col_name )
  | vers_ia_timestamp_type AS ( vers_ia_timestamp_col_name )
  | vers_ia_text_type AS ( SUBSTR(vers_ia_text_col_name, _digit, _digit ) )
  | vers_ia_enum_type AS ( vers_ia_enum_col_name )
  | vers_ia_geo_type AS ( vers_ia_geo_col_name )
;

vers_ia_virt_type:
  STORED | VIRTUAL
;

vers_ia_default_or_current_timestamp:
    DEFAULT '1970-01-01'
  | DEFAULT CURRENT_TIMESTAMP
  | DEFAULT CURRENT_TIESTAMP ON UPDATE CURRENT_TIMESTAMP
  | DEFAULT 0
;


vers_ia_unsigned:
  | | UNSIGNED
;

vers_ia_zerofill:
  | | | | ZEROFILL
;

vers_ia_default_int_or_auto_increment:
  vers_ia_default_int | vers_ia_default_int | vers_ia_default_int | vers_ia_auto_increment
;

#vers_ia_column_definition:
#  vers_ia_data_type vers_ia_null vers_ia_default vers_ia_auto_increment vers_ia_inline_key vers_ia_comment vers_ia_compressed
#;

vers_ia_create:
    CREATE vers_ia_replace_or_if_not_exists vers_ia_table_name (vers_col_list) vers_engine vers_ia_table_flags vers_partitioning_optional
  | CREATE vers_ia_replace_or_if_not_exists vers_ia_table_name (vers_col_list_with_period , PERIOD FOR SYSTEM_TIME ( vers_col_start, vers_col_end )) vers_engine vers_ia_table_flags vers_partitioning_optional
  | CREATE vers_ia_replace_or_if_not_exists vers_ia_table_name LIKE vers_existing_table
;

# MDEV-14669 -- cannot use virtual columns with/without system versioning

vers_col_list:
    vers_ia_real_col_name_and_definition vers_with_without_system_versioning 
  | vers_ia_real_col_name_and_definition vers_with_without_system_versioning, vers_col_list
;

vers_col_type:
    BIGINT UNSIGNED | BIGINT UNSIGNED | BIGINT UNSIGNED
  | TIMESTAMP(6) | TIMESTAMP(6) | TIMESTAMP(6)
  | vers_ia_data_type
;

vers_col_list_with_period:
    vers_ia_real_col_name_and_definition vers_with_without_system_versioning, vers_col_list_with_period
  | vers_col_start vers_col_type GENERATED ALWAYS AS ROW START, vers_col_end vers_ia_data_type GENERATED ALWAYS AS ROW END
;  

vers_ia_replace_or_if_not_exists:
  vers_ia_temporary TABLE | OR REPLACE vers_ia_temporary TABLE | vers_ia_temporary TABLE IF NOT EXISTS
;

vers_ia_table_flags:
  vers_ia_row_format vers_ia_encryption vers_ia_compression vers_with_system_versioning
;

vers_ia_encryption:
;

vers_ia_compression:
;

vers_ia_change_row_format:
  ROW_FORMAT=COMPACT | ROW_FORMAT=COMPRESSED | ROW_FORMAT=DYNAMIC | ROW_FORMAT=REDUNDANT
;

vers_ia_row_format:
  | vers_ia_change_row_format | vers_ia_change_row_format
;

vers_ia_insert:
  vers_ia_insert_select | vers_ia_insert_values
;

vers_ia_update:
  UPDATE vers_existing_table SET vers_ia_col_name = DEFAULT LIMIT 1;

vers_ia_insert_select:
  INSERT INTO vers_existing_table ( vers_ia_col_name ) SELECT vers_ia_col_name FROM vers_existing_table
;

vers_ia_insert_values:
    INSERT INTO vers_existing_table () VALUES vers_ia_empty_value_list
  | INSERT INTO vers_existing_table (vers_ia_col_name) VALUES vers_ia_non_empty_value_list
;

vers_ia_non_empty_value_list:
  (_vers_ia_value) | (_vers_ia_value),vers_ia_non_empty_value_list
;
 
vers_ia_empty_value_list:
  () | (),vers_ia_empty_value_list
;

vers_ia_add_column:
  ADD COLUMN vers_ia_if_not_exists vers_ia_col_name_and_definition vers_ia_algorithm vers_ia_lock
;

vers_ia_modify_column:
  MODIFY COLUMN vers_ia_if_exists vers_ia_col_name_and_definition vers_ia_algorithm vers_ia_lock
;

vers_ia_if_exists:
  | IF EXISTS | IF EXISTS | IF EXISTS
;

vers_ia_if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS | IF NOT EXISTS 
;

vers_ia_drop_column:
  DROP COLUMN vers_ia_if_exists vers_ia_col_name vers_ia_algorithm vers_ia_lock
;

vers_ia_add_index:
  ADD vers_ia_any_key vers_ia_algorithm vers_ia_lock
;


vers_ia_drop_index:
  DROP INDEX vers_ia_ind_name | DROP PRIMARY KEY
;

vers_ia_column_list:
  vers_ia_col_name | vers_ia_col_name, vers_ia_column_list
;

# Disabled due to MDEV-11071
vers_ia_temporary:
#  | | | | TEMPORARY
;

vers_ia_flush:
  FLUSH TABLES
;

vers_ia_optimize:
  OPTIMIZE TABLE vers_existing_table
;

vers_ia_algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY
;

vers_ia_lock:
  | | , LOCK=NONE | , LOCK=SHARED
;
  
vers_ia_data_type:
    vers_ia_bit_type
  | vers_ia_enum_type
  | vers_ia_geo_type
  | vers_ia_int_type
  | vers_ia_int_type
  | vers_ia_int_type
  | vers_ia_int_type
  | vers_ia_num_type
  | vers_ia_temporal_type
  | vers_ia_timestamp_type
  | vers_ia_text_type
  | vers_ia_text_type
  | vers_ia_text_type
  | vers_ia_text_type
;

vers_ia_bit_type:
  BIT
;

vers_ia_int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT
;

vers_ia_num_type:
  DECIMAL | FLOAT | DOUBLE
;

vers_ia_temporal_type:
  DATE | TIME | YEAR
;

vers_ia_timestamp_type:
  DATETIME | TIMESTAMP
;

vers_ia_enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

vers_ia_text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

vers_ia_geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

vers_ia_null:
  | NULL | NOT NULL ;
  
vers_ia_default:
  | DEFAULT NULL | vers_ia_default_char | vers_ia_default_int
;

vers_ia_default_char:
  | DEFAULT NULL | DEFAULT ''
;

vers_ia_default_int:
  | DEFAULT NULL | DEFAULT 0
;

vers_ia_geo_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

vers_ia_auto_increment:
  | | | | | | AUTO_INCREMENT ;
  
vers_ia_inline_key:
  | | | vers_ia_index ;
  
vers_ia_index:
  KEY | PRIMARY KEY | UNIQUE ;
  
vers_ia_key_column:
    vers_ia_bit_col_name
  | vers_ia_int_col_name
  | vers_ia_int_col_name
  | vers_ia_int_col_name
  | vers_ia_num_col_name
  | vers_ia_enum_col_name
  | vers_ia_temporal_col_name
  | vers_ia_timestamp_col_name
  | vers_ia_text_col_name(_tinyint_positive)
  | vers_ia_text_col_name(_smallint_positive)
;

vers_ia_key_column_list:
  vers_ia_key_column | vers_ia_key_column, vers_ia_key_column_list
;

vers_ia_any_key:
    vers_ia_index(vers_ia_key_column)
  | vers_ia_index(vers_ia_key_column)
  | vers_ia_index(vers_ia_key_column)
  | vers_ia_index(vers_ia_key_column)
  | vers_ia_index(vers_ia_key_column_list)
  | vers_ia_index(vers_ia_key_column_list)
  | FULLTEXT KEY(vers_ia_text_col_name)
  | SPATIAL INDEX(vers_ia_geo_col_name)
;

vers_ia_comment:
  | | COMMENT 'comment';
  
vers_ia_compressed:
  | | | | | | COMPRESSED ;

_vers_ia_value:
  NULL | _digit | '' | _char(1)
;
