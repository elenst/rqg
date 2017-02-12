
$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=8
		--duration=400
		--queries=100M
		--reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock,Restart,SlaveReset
		--redefine=conf/mariadb/general-workarounds.yy
		--mysqld=--log_output=FILE
		--mysqld=--log_bin_trust_function_creators=1
        --mysqld=--max-binlog-size=4096
        --mysqld2=--log-slave-updates
        --mysqld2=--log-bin=slave-bin
        --mysqld2=--binlog-format=ROW
	'], 
	[
        '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/oltp.zz',
		'--views --grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--views --grammar=conf/runtime/performance_schema.yy',
		'--views --grammar=conf/runtime/information_schema.yy',
		'--views --grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
		'--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
		'--views --grammar=conf/partitioning/partitions.yy',
		'--views --grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
		'--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
		'--views --grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
		'--views --grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
		'--views --grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz'
	],
	[
		'--engine=InnoDB',
	],
# slave-skip-errors: 
# 1054: MySQL:67878 (LOAD DATA in views)
# 1317: Query partially completed on the master (MDEV-368 which won't be fixed)
# 1049, 1305, 1539: MySQL:65428 (Unknown database) - fixed in 5.7.0
# 1505: MySQL:64041 (Partition management on a not partitioned table) 
#		'--rpl_mode=row --mysqld=--slave-skip-errors=1049,1305,1539,1505',
	[
		'--rpl_mode=mixed --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317',
	],
	[	'',
		'--use-gtid=current_pos --mysqld=--slave_parallel_threads=8'
	],
#        '--basedir1=/data/src/bb-10.0-monty --basedir2=/data/bld/10.0'
    [
        '--basedir1=/data/bld/10.0 --basedir2=/data/src/bb-10.0-monty-rel',
        '--basedir1=/data/src/bb-10.0-monty-rel --basedir2=/data/bld/10.0'
    ]
];

