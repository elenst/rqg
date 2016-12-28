$combinations = [
    ['
        --no-mask
        --seed=time
        --threads=4
        --duration=300
        --queries=100M
        --reporters=Backtrace,ErrorLog,Deadlock
        --views
        --mysqld=--max-statement-time=30
        --mysqld=--log-bin
    '],
    [ 
        '--engine=MyISAM',
        '--engine=InnoDB'
    ],
    [
        '--grammar=conf/partitioning/partition_pruning.yy --gendata=conf/partitioning/partition_pruning.zz',
        '--grammar=conf/partitioning/partitions-ddl.yy',
        '--grammar=conf/partitioning/partitions_list_less_rand.yy',
        '--grammar=conf/partitioning/partitions-wl4571.yy',
        '--grammar=conf/partitioning/partitions.yy',
    ],
]
