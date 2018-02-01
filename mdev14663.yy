query_init:
	SET AUTOCOMMIT = 0; CREATE TABLE IF NOT EXISTS t1 (col1 INT, col2 INT, col3 INT, col4 TEXT) ENGINE = InnoDB
; 

query:
	ddl | dml;

ddl:
    ALTER TABLE t1 DROP KEY unknown_key
  | ALTER TABLE t1 ADD COLUMN extra INT; UPDATE t1 SET extra = col1 ; ALTER TABLE t1 DROP COLUMN col1 ; ALTER TABLE t1 CHANGE COLUMN extra col1 INT
;

dml:
    INSERT INTO t1 (col1,col2,col3,col4) VALUES (2,2,2,REPEAT('a',8193)) , (2,2,2,REPEAT('b',8193)) ; commit_rollback 
  | UPDATE t1 SET col1 = _digit LIMIT 2 ; commit_rollback
;

commit_rollback:
	COMMIT | ROLLBACK;
