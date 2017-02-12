query:
    show | show | show | show | show | show | show | 
    show | show | show | show | show | show | show | 
    change 
;

change:
    CHANGE MASTER master_name TO MASTER_HOST='127.0.0.1', MASTER_PORT=master_port, MASTER_USER='foo', MASTER_USE_GTID=use_gtid |
    RESET SLAVE master_name all_or_not |
#    RESET SLAVE ALL |
    RESET MASTER |
    STOP SLAVE master_name_or_empty |
    START SLAVE master_name_or_empty |
    STOP ALL SLAVES |
    START ALL SLAVES |
    FLUSH BINARY LOGS |
    FLUSH LOGS 
;

use_gtid:
    current_pos | slave_pos | no
;

master_port:
    3333 | 3334 | 13000 ;

master_name:
    'test1' | 'm1'
;

master_name_or_empty:
  ''  | master_name
;

all_or_not:
    | | ALL 
;

show:
    FLUSH TABLES WITH READ LOCK ; UNLOCK TABLES |
    SHOW STATUS |
    SHOW STATUS LIKE '%slave%' |
    SHOW GLOBAL STATUS |
    SHOW SLAVE STATUS | 
    SHOW SLAVE master_name_or_empty STATUS |
#    SHOW SLAVE 'm1' STATUS |
    SHOW ALL SLAVES STATUS | 
    SET @@default_master_connection= master_name_or_empty
#    SHOW MASTER STATUS
;

#master_name2:
#    master_name | 'm1'
#;
