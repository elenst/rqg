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

thread3_init:
  create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace
;
 
thread3:
    create_or_replace 
  | create_like
  | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert
  | update | update
  | delete | truncate
  | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert
  | delete | truncate
  | add_column | add_column | add_column | add_column | add_column
  | modify_column | modify_column
  | add_index | add_index | add_index
  | drop_column | drop_column
  | drop_index | drop_index
  | other_alter | other_alter | other_alter
  | flush
  | optimize
  | lock_unlock_table
  | transaction
;

thread4:
  thread3;
  
thread5:
  thread3;
  
transaction:
    BEGIN
  | SAVEPOINT sp
  | ROLLBACK TO SAVEPOINT sp
  | COMMIT
  | ROLLBACK
;

lock_unlock_table:
    FLUSH TABLE table_name FOR EXPORT
  | LOCK TABLE table_name READ
  | LOCK TABLE table_name WRITE
  | SELECT * FROM table_name FOR UPDATE
  | UNLOCK TABLES
;

other_alter:
    ALTER TABLE table_name FORCE lock algorithm
  | ALTER TABLE table_name ENGINE=InnoDB
  | ALTER TABLE table_name row_format
  | alter_partitioning
;

alter_partitioning:
    ALTER TABLE table_name PARTITION BY HASH(col_name)
  | ALTER TABLE table_name PARTITION BY KEY(col_name)
  | ALTER TABLE table_name REMOVE PARTITIONING
;

delete:
  DELETE FROM table_name LIMIT _digit
;

truncate:
  TRUNCATE TABLE table_name
;

table_name:
    { $my_last_table = 't'.$prng->int(1,20) }
  | { $my_last_table = 't'.$prng->int(1,20) }
  | { $my_last_table = 't'.$prng->int(1,20) }
  | _table
;

col_name:
  int_col_name | num_col_name | temporal_col_name | text_col_name | enum_col_name | virt_col_name | _field
;

int_col_name:
    { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | { $last_column = 'icol'.$prng->int(1,10) }
  | _field_int
;

num_col_name:
    { $last_column = 'ncol'.$prng->int(1,10) }
;

virt_col_name:
    { $last_column = 'vcol'.$prng->int(1,10) }
;

temporal_col_name:
    { $last_column = 'tcol'.$prng->int(1,10) }
;

geo_col_name:
    { $last_column = 'geocol'.$prng->int(1,10) }
;

text_col_name:
    { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | { $last_column = 'scol'.$prng->int(1,10) }
  | _field_char
;

enum_col_name:
    { $last_column = 'ecol'.$prng->int(1,20) }
;

ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

col_name_and_definition:
    int_col_name int_type unsigned zerofill null default_or_auto_increment
  | int_col_name int_type unsigned zerofill null default_or_auto_increment
  | int_col_name int_type unsigned zerofill null default_or_auto_increment
  | num_col_name num_type unsigned zerofill null default
  | temporal_col_name temporal_type null default_or_current_timestamp
  | temporal_col_name temporal_type null default_or_current_timestamp
  | text_col_name text_type null default
  | text_col_name text_type null default
  | text_col_name text_type null default
  | enum_col_name enum_type null default
  | virt_col_name virt_col_definition virt_type
  | geo_col_name geo_type null geo_default
;

virt_col_definition:
    int_type AS ( int_col_name + _digit )
  | num_type AS ( num_col_name + _digit )
  | temporal_type AS ( temporal_col_name )
  | text_type AS ( SUBSTR(text_col_name, _digit, _digit )
  | enum_type AS ( enum_col_name )
  | geo_type AS ( geo_col_name )
;

virt_type:
  STORED | VIRTUAL
;

default_or_current_timestamp:
    DEFAULT '1970-01-01'
  | DEFAULT CURRENT_TIMESTAMP
  | DEFAULT CURRENT_TIESTAMP ON UPDATE CURRENT_TIMESTAMP
  | DEFAULT 0
;


unsigned:
  | | UNSIGNED
;

zerofill:
  | | | | ZEROFILL
;

default_or_auto_increment:
  default | default | default | auto_increment
;

column_definition:
  data_type null default auto_increment inline_key comment compressed
;

create_or_replace:
  CREATE OR REPLACE temporary TABLE table_name (col_name column_definition) table_flags
;

table_flags:
  row_format encryption compression
;

encryption:
;

compression:
;

row_format:
  | ROW_FORMAT=COMPACT | ROW_FORMAT=COMPRESSED | ROW_FORMAT=DYNAMIC | ROW_FORMAT=REDUNDANT
;

create_like:
  CREATE temporary TABLE table_name LIKE _table
;

insert:
  insert_select | insert_values
;

update:
  UPDATE table_name SET col_name = DEFAULT LIMIT 1;

insert_select:
  INSERT INTO table_name ( col_name ) SELECT col_name FROM table_name
;

insert_values:
    INSERT INTO table_name () VALUES empty_value_list
  | INSERT INTO table_name (col_name) VALUES non_empty_value_list
;

non_empty_value_list:
  (_value) | (_value),non_empty_value_list
;
 
empty_value_list:
  () | (),empty_value_list
;

add_column:
  ALTER TABLE table_name ADD COLUMN if_not_exists col_name_and_definition algorithm lock
;

modify_column:
  ALTER TABLE table_name MODIFY COLUMN if_exists col_name_and_definition algorithm lock
;

if_exists:
  | IF EXISTS | IF EXISTS
;

if_not_exists:
  | IF NOT EXISTS | IF NOT EXISTS
;

drop_column:
  ALTER TABLE table_name DROP COLUMN if_exists col_name algorithm lock
;

add_index:
  ALTER TABLE table_name ADD any_key ind_name(column_list) algorithm lock
;


drop_index:
  ALTER TABLE table_name DROP INDEX ind_name | ALTER TABLE table_name DROP PRIMARY KEY
;

column_list:
  col_name | col_name, column_list
;

temporary:
  | | | | TEMPORARY
;

flush:
  FLUSH TABLES
;

optimize:
  OPTIMIZE TABLE table_name
;

algorithm:
  | | , ALGORITHM=INPLACE | , ALGORITHM=COPY
;

lock:
  | | , LOCK=NONE | , LOCK=SHARED
;
  
data_type:
    int_type
  | int_type
  | int_type
  | num_type
  | temporal_type
  | temporal_type
  | text_type
  | text_type
  | text_type
  | enum_type
  | geo_type
;

int_type:
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT | BIT
;

num_type:
  DECIMAL | FLOAT | DOUBLE
;

temporal_type:
  DATE | TIME | DATETIME | TIMESTAMP | YEAR
;

enum_type:
  ENUM('foo','bar') | SET('foo','bar')
;

text_type:
  BLOB | TEXT | CHAR | VARCHAR(_smallint_unsigned) | BINARY | VARBINARY(_smallint_unsigned)
;

geo_type:
  POINT | LINESTRING | POLYGON | MULTIPOINT | MULTILINESTRING | MULTIPOLYGON | GEOMETRYCOLLECTION | GEOMETRY
;

null:
  | NULL | NOT NULL ;
  
default:
  | DEFAULT NULL | DEFAULT '' | DEFAULT 0 ;

geo_default:
  | DEFAULT ST_GEOMFROMTEXT('Point(1 1)') ;

auto_increment:
  | | | | | | AUTO_INCREMENT ;
  
inline_key:
  | | | index ;
  
index:
  KEY | PRIMARY KEY | UNIQUE ;
  
key_column:
  int_col_name | int_col_name | num_col_name | enum_col_name | temporal_col_name | text_col_name(_tinyint_unsigned) | text_col_name(_smallint_unsigned)
;

key_column_list:
  key_column | key_column, key_column_list
;

any_key:
    index(key_column)
  | index(key_column)
  | index(key_column)
  | index(key_column)
  | index(key_column_list)
  | index(key_column_list)
  | FULLTEXT KEY(text_col_name)
  | SPATIAL INDEX(geo_col_name)
;

comment:
  | | COMMENT 'comment';
  
compressed:
  | | | | | | COMPRESSED ;

_value:
  NULL | _digit | '' | _char(1)
;
