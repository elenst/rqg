query_init:
  { $my_table= 't'.$generator->threadId(); '' }
#  { $my_table= 't5'; '' }
;

abc:
  CREATE TABLE my_table (
    pk INT AUTO_INCREMENT PRIMARY KEY,
    f1 INT,
    f2 INT NOT NULL,
    f3 BIGINT,
    f4 BIGINT NOT NULL,
    f5 VARCHAR(1024),
    f6 VARCHAR(2048) NOT NULL,
    f7 CHAR(255),
    f8 CHAR(128) NOT NULL,
    UNIQUE(f1),
    UNIQUE(f7),
    KEY(f2,f5),
    KEY(f3,f6),
    KEY(f4,f7),
    KEY(f1,f8)
  ) ENGINE=INNODB ROW_FORMAT = row_format_type
  ; INSERT INTO my_table SELECT NULL, seq, seq%1000, seq%10, seq%10000, CONCAT('f5_',(seq%1000)), CONCAT('f6_',(seq%100)), CONCAT('f7_',seq), CONCAT('f8_',(seq%10)) FROM seq_1_to_200000
;

row_format_type:
  REDUNDANT | DYNAMIC | COMPRESSED | COMPACT
;
  
my_table:
  { $my_table }
;

query:
    select |
    update | update | update | update | update | update | update | update |
    delete | delete | delete |
    truncate |
    insert | insert | insert | insert | insert | insert |
    alter_tablespace
#    | alter_check_table
;

truncate:
  TRUNCATE TABLE my_table
;

alter_check_table:
    CHECK TABLE my_table
#  | ALTER TABLE my_table FORCE
#  | ALTER TABLE my_table ROW_FORMAT=row_format_type
;

alter_tablespace:
#    ALTER TABLE my_table DISCARD TABLESPACE
#  ; restore_tablespace ALTER TABLE my_table IMPORT TABLESPACE
    { $executors->[0]->import_tablespace($my_table, "$ENV{DATADIR}/test/$my_table.ibd.empty", "$ENV{DATADIR}/test/$my_table.ibd"); '' }
  | { $executors->[0]->import_tablespace($my_table, "$ENV{DATADIR}/test/$my_table.ibd.backup", "$ENV{DATADIR}/test/$my_table.ibd"); '' }
;

alter_tablespace_comparison:
#    ALTER TABLE my_table DISCARD TABLESPACE
#  ; restore_tablespace ALTER TABLE my_table IMPORT TABLESPACE
    /*executor1 { $executors->[0]->import_tablespace($my_table, "$ENV{DATADIR}/test/$my_table.ibd.empty", "$ENV{DATADIR}/test/$my_table.ibd"); '' } */
    /*executor2 { $executors->[1]->import_tablespace($my_table, "$ENV{DATADIR2}/test/$my_table.ibd.empty", "$ENV{DATADIR2}/test/$my_table.ibd"); '' } */
  | 
    /*executor1 { $executors->[0]->import_tablespace($my_table, "$ENV{DATADIR}/test/$my_table.ibd.backup", "$ENV{DATADIR}/test/$my_table.ibd"); '' } */
    /*executor2 { $executors->[1]->import_tablespace($my_table, "$ENV{DATADIR2}/test/$my_table.ibd.backup", "$ENV{DATADIR2}/test/$my_table.ibd"); '' } */
;

restore_tablespace:
    { $file="$ENV{DATADIR}/test/$my_table.ibd.empty"; "SELECT '".$file."' AS filename;"; system("cp $file $ENV{DATADIR}/test/$my_table.ibd"); '' } 
  | { $file="$ENV{DATADIR}/test/$my_table.ibd.backup"; "SELECT '".$file."' AS filename;"; system("cp $file $ENV{DATADIR}/test/$my_table.ibd"); '' } 
;

my_field_int:
  f1 | f2 | f3 | f4
;

my_field_char:
  f5 | f6 | f7 | f8
;

my_field_int_indexed:
  my_field_int
;

my_field_char_indexed:
  my_field_char
;

my_field:
  f1 | f2 | f3 | f4 | f5 | f6 | f7 | f8
;

insert:
    INSERT IGNORE INTO my_table ( `pk` ) VALUES ( NULL ) |
    INSERT IGNORE INTO my_table ( my_field_int ) VALUES ( _smallint_unsigned ) |
    INSERT IGNORE INTO my_table ( my_field_char ) VALUES ( _string ) |
    INSERT IGNORE INTO my_table ( `pk`, my_field_int)  VALUES ( NULL, _int ) |
    INSERT IGNORE INTO my_table ( `pk`, my_field_char ) VALUES ( NULL, _string ) 
;

update:
    index_update |
    non_index_update
;

delete:
    DELETE FROM my_table WHERE `pk` = _smallint_unsigned ;

index_update:
    UPDATE IGNORE my_table SET my_field_int_indexed = my_field_int_indexed + 1 WHERE `pk` = _smallint_unsigned ;

# It relies on char fields being unindexed. 
# If char fields happen to be indexed in the table spec, then this update can be indexed as well. No big harm though. 
non_index_update:
    UPDATE my_table SET my_field_char = _string WHERE `pk` = _smallint_unsigned ;

select:
    point_select |
    simple_range |
    sum_range |
    order_range |
    distinct_range 
;

point_select:
    SELECT my_field FROM my_table WHERE `pk` = _smallint_unsigned ;

simple_range:
    SELECT my_field FROM my_table WHERE `pk` BETWEEN _smallint_unsigned AND _smallint_unsigned ;

sum_range:
    SELECT SUM(_field) FROM my_table WHERE `pk` BETWEEN _smallint_unsigned AND _smallint_unsigned ;

order_range:
    SELECT my_field FROM my_table WHERE `pk` BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY my_field ;

distinct_range:
    SELECT DISTINCT my_field FROM my_table WHERE `pk` BETWEEN _smallint_unsigned AND _smallint_unsigned ORDER BY my_field ;

