
$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=8
		--duration=600
		--queries=100M
		--reporters=QueryTimeout,Backtrace,ErrorLog,Deadlock
		--redefine=conf/mariadb/general-workarounds.yy
		--mysqld=--log_output=FILE
		--mysqld=--log_bin_trust_function_creators=1
	'], 
	[
		'--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--grammar=conf/runtime/performance_schema.yy',
		'--grammar=conf/runtime/information_schema.yy',
		'--grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
		'--grammar=conf/engines/engine_stress.yy --gendata=conf/engines/engine_stress.zz',
		'--grammar=conf/partitioning/partitions.yy',
		'--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
		'--grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
		'--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
		'--grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
		'--grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
		'--grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz',
        '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/oltp.zz'
	],
	[
		'--rpl_mode=row --mysqld=--slave-skip-errors=1049,1305,1539,1505',
		'--rpl_mode=mixed --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317',
	],
	['','--use-gtid=current_pos','--use-gtid=slave_pos'],
    ['','--mysqld=--slave-parallel-threads=8'],
    ['','--mysqld=--slave-parallel-mode=optimistic'],
    ['','--mysqld=--slave-domain-parallel-threads=4']
];

