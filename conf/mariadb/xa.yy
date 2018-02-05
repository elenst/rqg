query_init_add:
  { %active_xa = (); %idle_xa = (); %prepared_xa = (); '' }
;

query_add:
  xa_query
;

xa_query:
    XA xa_start_begin xa_xid xa_opt_join_resume { $active_xa{$last_xid}= 1 ; '' }
  | XA END xa_xid_active xa_opt_suspend_opt_for_migrate { $idle_xa{$last_xid}= 1; delete $active_xa{$last_xid}; '' }
  | XA PREPARE xa_xid_idle { $prepared_xa{$last_xid}= 1; delete $idle_xa{$last_xid}; '' }
  | XA COMMIT xa_xid_idle ONE PHASE { delete $idle_xa{$last_xid}; '' }
  | XA COMMIT xa_xid_prepared { delete $idle_xa{$last_xid}; '' }
  | XA ROLLBACK xa_xid_prepared { delete $prepared_xa{$last_xid}; '' }
  | XA RECOVER
;

# Not supported
xa_opt_suspend_opt_for_migrate:
#  | SUSPEND xa_opt_for_migrade
;

xa_opt_for_migrade:
  | FOR MIGRATE
;

xa_start_begin:
  START | BEGIN
;

# Not supported
xa_opt_join_resume:
#  | JOIN | RESUME
;

xa_xid:
  { $last_xid= "'xid".$prng->int(1,200)."'" }
;

xa_xid_active:
  { $last_xid= (scalar(keys %active_xa) ? $prng->arrayElement([keys %active_xa]) : "'inactive_xid'"); $last_xid }
;

xa_xid_idle:
  { $last_xid= (scalar(keys %idle_xa) ? $prng->arrayElement([keys %idle_xa]) : "'non_idle_xid'"); $last_xid }
;

xa_xid_prepared:
  { $last_xid= (scalar(keys %prepared_xa) ? $prng->arrayElement([keys %prepared_xa]) : "'non_prepared_xid'"); $last_xid }
;
