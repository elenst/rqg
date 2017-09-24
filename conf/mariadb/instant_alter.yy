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
  create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; create_or_replace ; 
;
 
thread3:
    create_or_replace 
  | create_like
  | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert
  | delete | truncate
  | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert | insert
  | delete | truncate
  | add_column | add_column | add_column
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
;

delete:
  DELETE FROM table_name LIMIT _digit
;

truncate:
  TRUNCATE TABLE table_name
;

table_name:
    { $last_table = 't'.$prng->int(1,20) }
  | { $last_table = 't'.$prng->int(1,20) }
  | { $last_table = 't'.$prng->int(1,20) }
  | _table
;

col_name:
    { $last_column = 'col'.$prng->int(1,20) }
  | { $last_column = 'col'.$prng->int(1,20) }
  | { $last_column = 'col'.$prng->int(1,20) }
  | _field
;

ind_name:
  { $last_index = 'ind'.$prng->int(1,10) }
;

column_definition:
  data_type null default auto_increment key comment compressed
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
  CREATE temporary TABLE table_name LIKE table_name
;

insert:
  insert_select | insert_values
;

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
  ALTER TABLE table_name ADD COLUMN IF NOT EXISTS col_name column_definition algorithm lock
;

drop_column:
  ALTER TABLE table_name DROP COLUMN IF EXISTS col_name algorithm lock
;

add_index:
  ALTER TABLE table_name ADD index ind_name(column_list) algorithm lock
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
  INT | TINYINT | SMALLINT | MEDIUMINT | BIGINT | DECIMAL | FLOAT | DOUBLE | BIT | DATE | TIME | DATETIME | TIMESTAMP | YEAR | CHAR | VARCHAR | BINARY | VARBINARY | BLOB | TEXT | ENUM('foo','bar') | SET('foo','bar') ;

null:
  | NULL | NOT NULL ;
  
default:
  | DEFAULT NULL | DEFAULT '' | DEFAULT 0;

auto_increment:
  | | | | | | AUTO_INCREMENT ;
  
key:
  | | | index ;
  
index:
  KEY | PRIMARY KEY | UNIQUE ;
  
comment:
  | | COMMENT 'comment';
  
compressed:
  | | | | | | COMPRESSED ;

_value:
  NULL | _digit | '' | _char(1)
;
