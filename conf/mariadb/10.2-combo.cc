$combinations = [
  [
  '
    --no-mask
    --queries=100M
    --duration=350
    --threads=6
    --seed=time
    --reporters=Backtrace,ErrorLog,Deadlock
    --validators=TransformerNoComparator
    --transformers=ExecuteAsCTE,ExecuteAsDeleteReturning,ExecuteAsExecuteImmediate,ExecuteAsInsertSelect,ExecuteAsUnion,ExecuteAsUpdateDelete,ExecuteAsView,ExecuteAsPreparedTwice,ExecuteAsSPTwice
    --redefine=conf/mariadb/general-workarounds.yy
    --mysqld=--log_output=FILE
    --views
    --redefine=conf/mariadb/alter_table.yy
    --redefine=conf/mariadb/bulk_insert.yy
    --redefine=conf/mariadb/xa.yy
    --mysqld=--log_bin_trust_function_creators=1
    --mysqld=--log-bin
    --mysqld=--loose-max-statement-time=30
    --mysqld=--loose-debug_assert_on_not_freed_memory=0
  '], 
  [
    '--grammar=conf/runtime/metadata_stability.yy --gendata=conf/runtime/metadata_stability.zz',
    '--grammar=conf/runtime/performance_schema.yy  --mysqld=--performance-schema --gendata-advanced --skip-gendata',
    '--grammar=conf/runtime/information_schema.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/engines/many_indexes.yy --gendata=conf/engines/many_indexes.zz',
    '--grammar=conf/partitioning/partitions.yy',
    '--grammar=conf/partitioning/partitions.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
    '--grammar=conf/replication/replication.yy --gendata=conf/replication/replication-5.1.zz',
    '--grammar=conf/replication/replication-ddl_sql.yy --gendata=conf/replication/replication-ddl_data.zz',
    '--grammar=conf/replication/replication-dml_sql.yy --gendata=conf/replication/replication-dml_data.zz',
    '--grammar=conf/runtime/connect_kill_sql.yy --gendata=conf/runtime/connect_kill_data.zz',
    '--grammar=conf/runtime/WL5004_sql.yy --gendata=conf/runtime/WL5004_data.zz',
    '--grammar=conf/mariadb/optimizer.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/optimizer/updateable_views.yy --mysqld=--init-file='.$ENV{RQG_HOME}.'/conf/optimizer/updateable_views.init',
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata=conf/mariadb/oltp.zz',
    '--grammar=conf/mariadb/oltp-transactional.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/mariadb/oltp.yy --gendata=conf/mariadb/oltp.zz',
    '--grammar=conf/mariadb/functions.yy --gendata-advanced --skip-gendata',
    '--grammar=conf/runtime/alter_online.yy --gendata=conf/runtime/alter_online.zz',
  ],
  [
    '--engine=InnoDB',
    '--mysqld=--default-storage-engine=MyISAM --engine=MyISAM',
    '--mysqld=--plugin-load-add=ha_rocksdb --mysqld=--binlog-format=ROW --mysqld=--default-storage-engine=RocksDB --engine=RocksDB',
  ]
];

