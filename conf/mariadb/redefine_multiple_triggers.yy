# Copyright (C) 2016 MariaDB Corporation.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

#
# MDEV-6112 - multiple triggers per table
# Introduced in 10.2.3
#

query_init_add:
    CREATE OR REPLACE TABLE tlog (
      pk INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
      dt TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), 
      tbl VARCHAR(16), 
      tp ENUM('BEFORE','AFTER'), 
      op ENUM('INSERT','UPDATE','DELETE')
);

mdev6112_create_trigger:
    mdev6112_create_clause _letter mdev6112_before_after mdev6112_ins_upd_del ON /* ERROR_1361 */ _table FOR EACH ROW mdev6112_precedes_follows INSERT INTO tlog (tbl,tp,op) VALUES ( { "'$last_table','$tp','$op'" } );

mdev6112_drop_trigger:
      DROP TRIGGER _letter
    | DROP TRIGGER IF EXISTS _letter 
;
    
mdev6112_create_clause:
      /* ERROR_1359 */ CREATE TRIGGER 
    # We are only adding error 1360 because of MDEV-10912.
    # It's a bug, it shouldn't happen here
    | /* ERROR_1360 */ CREATE OR REPLACE TRIGGER
    | /* ERROR_1360 */ CREATE OR REPLACE TRIGGER
    | CREATE TRIGGER IF NOT EXISTS
;
    
mdev6112_precedes_follows:
    | | | | /* ERROR_4031 */ /*!100202 PRECEDES _letter */ | /* ERROR_4031 */ /*!100202 FOLLOWS _letter */ ;
    
mdev6112_before_after:
    { $tp = ($prng->int(0,1) ? 'BEFORE' : 'AFTER' ) };

mdev6112_ins_upd_del:
    { $r = $prng->int(1,3); $op = ($r == 1 ? 'INSERT' : ( $r == 2 ? 'UPDATE' : 'DELETE' ) ) };

query_add:
      mdev6112_create_trigger | mdev6112_create_trigger | mdev6112_create_trigger | mdev6112_create_trigger
    | mdev6112_drop_trigger
    | query | query | query | query | query | query | query | query | query | query
;

