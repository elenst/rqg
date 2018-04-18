query_init:
    CREATE TEMPORARY TABLE t1 (a INT, key (a)); INSERT INTO t1 VALUES (1),(2)
  ; CREATE TEMPORARY TABLE t2 (a INT, key (a)); INSERT INTO t2 VALUES (1),(2)
;

query:
	transaction |
	UPDATE table_name SET a = _digit |
;

table_name:
  t1 | t2
;

transaction:
	START TRANSACTION |
	ROLLBACK
;
