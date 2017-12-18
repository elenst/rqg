
$combinations = [
	[
	'
		--no-mask
		--seed=time
		--threads=6
		--duration=600
		--queries=100M
		--reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ConvertSubqueriesToViews,ConvertTablesToDerived,ConvertTablesToViews,Count,DisableIndexes,DisableOptimizations,Distinct,EnableOptimizations,ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsDerived,ExecuteAsExcept,ExecuteAsExecuteImmediate,ExecuteAsFunctionTwice,ExecuteAsInsertSelect,ExecuteAsIntersect,ExecuteAsPreparedThrice,ExecuteAsSelectItem,ExecuteAsSPTwice,ExecuteAsTrigger,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsWhereSubquery,Having,InlineSubqueries,InlineVirtualColumns,LimitRowsExamined,OrderBy,StraightJoin
		--redefine=conf/mariadb/general-workarounds.yy
		--mysqld=--log_output=FILE
		--mysqld=--log_bin_trust_function_creators=1
    --mysqld=--max-statement-time=30
	'], 
	[
		'--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
		'--grammar=conf/runtime/performance_schema.yy --mysqld=--performance-schema',
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
    '--grammar=conf/mariadb/optimizer.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/mariadb/optimizer.yy --gendata',
    '--grammar=conf/optimizer/updateable_views.yy --mysqld=--init-file='.getcwd().'/conf/optimizer/updateable_views.init',
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata=conf/mariadb/oltp.zz',
    '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/oltp.zz',
    '--grammar=conf/mariadb/functions.yy',
    '--grammar=conf/runtime/alter_online.yy --gendata=conf/runtime/alter_online.zz',
    '--grammar=conf/optimizer/range_access.yy --gendata=conf/optimizer/range_access.zz',
	],
	[
		'--engine=InnoDB',
		'--engine=MyISAM',
		'--engine=Aria',
		'',
		'--engine=InnoDB --mysqld=--ignore-builtin-innodb --mysqld=--plugin-load=ha_innodb.so'
	],
# slave-skip-errors: 
# 1054: MySQL:67878 (LOAD DATA in views)
# 1317: Query partially completed on the master (MDEV-368 which won't be fixed)
# 1049, 1305, 1539: MySQL:65428 (Unknown database) - fixed in 5.7.0
# 1505: MySQL:64041 (Partition management on a not partitioned table) 
	[
		'--rpl_mode=row --mysqld=--slave-skip-errors=1049,1305,1539,1505',
		'--rpl_mode=mixed --mysqld=--slave-skip-errors=1049,1305,1539,1505,1317',
	],
];

