# Copyright (C) 2016 MariaDB Corporation Ab
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


########################################################################
#
# The module implements the test described in MDEV-13269.
# The test flow is such:
#
# 1. Start the old version with --innodb-change-buffering=none and run quite a bit of DML
# 2. Kill & restart with --innodb-force-recovery=3 (important, to preserve the undo logs!)
# 3. Restart the new version with --innodb-read-only
#    (this would refuse to start up if the change buffer is not empty),
#    run some DML (say, CHECK TABLE on every InnoDB table)
# 4. Restart the new version normally, and run some more DML workload and CHECK TABLE.
#
#
# For step 1, we rely on the test configuration to start with proper options
# (and maybe it will be later decided that other values innodb-change-buffering
# need to be tried as well). So, step #1 is just a normal test startup,
# it is not present in the module
#
# When half of the test duration has passed, the module will execute
# step 2 -- crash and restart the old server with innodb-force-recovery=3.
#
# If it works, the module will continue operation and execute step 3 --
# shut down the old server normally, and start the new one, blocking users' requests,
# run the same checks that the normal Upgrade.pm does, and execute mysql_upgrade
# if necessary
#
# Note: since read-only was only a part of the scenario to enforce a more
# predictable and controlled environment, instead of using innodb-read-only
# (which disallows the upgrade in some cases), we will block users' requests
# by temporarily changing the server port. 
#
# Then the module will restart the server with initial options and will exit
# to let the test flow continue till the end of the test duration.
# All other periodic invocations will be ignored.
#
# At the end, the module will be triggered again and will run CHECK TABLE
# for all tables.
#
########################################################################

package GenTest::Reporter::UpgradeUndoLogs;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use DBI;
use GenTest;
use GenTest::Constants;
use GenTest::Reporter;
use GenTest::Comparator;
use Data::Dumper;
use IPC::Open2;
use File::Copy;
use POSIX;

use DBServer::MySQL::MySQLd;

my $first_reporter;
my $vardir;
my $version_numeric_old;
my %detected_known_bugs;
my $crash_recovery_done= 0;


my $first_reporter;

sub monitor {
	my $reporter = shift;

    $first_reporter = $reporter if not defined $first_reporter;

	# This module shouldn't be used if there is more than one server
	# running in parallel (e.g. in comparison tests). If it happens,
    # we will consider it a configuration error

    if ($reporter ne $first_reporter) {
        sayError("UpgradeUndoLogs reporter has been called twice, the test run is misconfigured");
        return STATUS_ENVIRONMENT_FAILURE;
    }

	if (not $crash_recovery_done and (time() > ($reporter->testEnd() - $reporter->testDuration()/2))) {
		crash_recovery_and_upgrade($reporter);
	} else {
		return STATUS_OK;
	}
}

sub crash_recovery_and_upgrade {
    my $reporter = shift;

    say("===============================================================");
    say("= Crash-recovery of the old server with innodb-force-recovery =");
    say("===============================================================");

    # We will attempt it only once
    $crash_recovery_done= 1;
    
    say("-- Old server info: --");
    say($reporter->properties->servers->[0]->version());
    $reporter->properties->servers->[0]->printServerOptions();
    say("-- New server info: --");
    say($reporter->properties->servers->[1]->version());
    $reporter->properties->servers->[1]->printServerOptions();
    say("----------------------");

    my $server = $reporter->properties->servers->[0];
    my $dbh = DBI->connect($server->dsn);

    my $major_version_old= $server->majorVersion;
    $version_numeric_old= $server->versionNumeric();
    my $pid= $server->pid();
    my $errorlog= $server->errorlog;
    my $datadir = $server->datadir;
    $datadir =~ s{[\\/]$}{}sgio;

    say("Killing the old server...");
    kill(9, $pid);
    foreach (1..60) {
        last if not kill(0, $pid);
        sleep 1;
    }

    if (kill(0, $pid)) {
        sayError("Could not kill the old server with pid $pid; sending SIGBART to get a stack trace");
        kill('ABRT', $pid);
        return report_and_return(STATUS_SERVER_DEADLOCKED);
    } else {
        say("Old server with pid $pid has been killed");
    }

    say("Starting the old server with innodb-force-recovery...");

    $server->setStartDirty(1);
    $server->addServerOptions(['--innodb-force-recovery=3']);
    my $upgrade_status = $server->startServer();
    if ($upgrade_status != STATUS_OK) {
        sayError("Old server failed to start with innodb-force-recovery");
    }
    check_start_log(\$upgrade_status, $errorlog);
    $pid= $server->pid();

    say("Shutting down the old server after innodb-force-recovery...");

    kill(15, $pid);
    foreach (1..60) {
        last if not kill(0, $pid);
        sleep 1;
    }

    if (kill(0, $pid)) {
        sayError("Could not shut down the old server with pid $pid; sending SIGBART to get a stack trace");
        kill('ABRT', $pid);
        return report_and_return(STATUS_SERVER_DEADLOCKED);
    } else {
        say("Old server with pid $pid has been shut down/killed");
    }

    say("=============================");
    say("= Upgrade to the new server =");
    say("=============================");

    my $orig_datadir = $datadir.'_orig';

    say("Copying datadir... (interrupting the copy operation may cause investigation problems later)");
    if (osWindows()) {
        system("xcopy \"$datadir\" \"$orig_datadir\" /E /I /Q");
    } else { 
        system("cp -r $datadir $orig_datadir");
    }

    move($errorlog, $server->errorlog.'_orig');
    unlink("$datadir/core*");    # Remove cores from any previous crash

    say("Starting the new server with innodb-read-only...");

    $server = $reporter->properties->servers->[1];
    $server->setStartDirty(1);
    my $port= $server->port();

    # Change the port temporarily to avoid the inflow
    my $tmp_port= $port + 6;
    $server->setPort($tmp_port);
    my $tmp_dsn= $server->dsn;
    $tmp_dsn =~ s/port=$port/port=$tmp_port/;
#   ,'--tc-heuristic-recover=ROLLBACK'

#    $server->addServerOptions(['--innodb-read-only']);
    my $upgrade_status = $server->startServer();
    if ($upgrade_status != STATUS_OK) {
        sayError("New server failed to start");
    }
    check_start_log(\$upgrade_status, $errorlog);
    $pid= $server->pid();

    if ($upgrade_status != STATUS_OK) {
        $upgrade_status = STATUS_UPGRADE_FAILURE if $upgrade_status == STATUS_POSSIBLE_FAILURE;
        sayError("Upgrade has apparently failed.");
        return report_and_return($upgrade_status);
    }

    # If we are here, the new server must have started and no critical errors occurred so far.

    $dbh = DBI->connect($server->dsn);
    if (not defined $dbh) {
        sayError("Could not connect to the new server after upgrade");
        return report_and_return(STATUS_UPGRADE_FAILURE);
    }

    my $res= check_database_consistency($dbh);
    $upgrade_status= $res unless $res == STATUS_OK;

    if ($server->majorVersion eq $major_version_old) {
        say("New server started successfully after the minor upgrade");
    } else {
        my $mysql_upgrade= $server->clientBindir.'/'.(osWindows() ? 'mysql_upgrade.exe' : 'mysql_upgrade');
        say("New server started successfully after the major upgrade, running mysql_upgrade now using the command:");
        my $cmd= "\"$mysql_upgrade\" --host=127.0.0.1 --port=".$server->port." --user=root --password=''";
        say($cmd);
        my $res= system("$cmd > $datadir/mysql_upgrade.log");
        if ($res == STATUS_OK) {
            # mysql_upgrade can return exit code 0 even if user tables are corrupt,
            # so we don't trust the exit code, we should also check the actual output
            if (open(UPGRADE_LOG, "$datadir/mysql_upgrade.log")) {
                OUTER_READ:
                while (<UPGRADE_LOG>) {
                    # For now we will only check 'Repairing tables' section,
                    # and if there are any errors, we'll consider it a failure
                    next unless /Repairing tables/;
                    while (<UPGRADE_LOG>) {
                        if (/^\s*Error/) {
                            $res= STATUS_UPGRADE_FAILURE;
                            sayError("Found errors in mysql_upgrade output");
                            sayFile("$datadir/mysql_upgrade.log");
                            last OUTER_READ;
                        }
                    }
                }
                close (UPGRADE_LOG);
            } else {
                sayError("Could not find mysql_upgrade.log");
                $res= STATUS_UPGRADE_FAILURE;
            }
        }
        if ($res != STATUS_OK) {
            sayError("mysql_upgrade has failed");
            sayFile($errorlog);
            return report_and_return(STATUS_UPGRADE_FAILURE);
        }
        say("mysql_upgrade has finished successfully, now the server should be ready to work");
    }

    say("Shutting down the new server after first start...");

    kill(15, $pid);
    foreach (1..60) {
        last if not kill(0, $pid);
        sleep 1;
    }

    if (kill(0, $pid)) {
        sayError("Could not shut down the new server with pid $pid; sending SIGBART to get a stack trace");
        kill('ABRT', $pid);
        return report_and_return(STATUS_SERVER_DEADLOCKED);
    } else {
        say("Old server with pid $pid has been shut down/killed");
    }

    # Restore the normal port
    $server->setPort($port);

    say("========================================");
    say("= Normal operation with the new server =");
    say("========================================");

    $server->setStartDirty(1);
#    $server->addServerOptions(['--innodb-read-only=0']);
    my $upgrade_status = $server->startServer();
    if ($upgrade_status != STATUS_OK) {
        sayError("New server failed to start");
    }
    check_start_log(\$upgrade_status, $errorlog);
    $pid= $server->pid();

    if ($upgrade_status != STATUS_OK) {
        $upgrade_status = STATUS_UPGRADE_FAILURE if $upgrade_status == STATUS_POSSIBLE_FAILURE;
        sayError("Upgrade has apparently failed.");
        return report_and_return($upgrade_status);
    }

   return STATUS_OK;
}

sub check_database_consistency {
    my $dbh= shift;

    say("Testing database consistency");

    my $databases = $dbh->selectcol_arrayref("SHOW DATABASES");
    foreach my $database (@$databases) {
        next if $database =~ m{^(mysql|information_schema|pbxt|performance_schema)$}sio;
        $dbh->do("USE $database");
        my $tabl_ref = $dbh->selectcol_arrayref("SHOW FULL TABLES", { Columns=>[1,2] });
        my %tables = @$tabl_ref;
        foreach my $table (keys %tables) {
            # Should not do CHECK etc., and especially ALTER, on a view
            next if $tables{$table} eq 'VIEW';
            say("Verifying table: $table; database: $database");
            $dbh->do("CHECK TABLE `$database`.`$table` EXTENDED");
            # 1178 is ER_CHECK_NOT_IMPLEMENTED
            return report_and_return(STATUS_DATABASE_CORRUPTION) if $dbh->err() > 0 && $dbh->err() != 1178;
        }
    }
    say("Schema does not look corrupt");
    return STATUS_OK;
}

sub report_and_return {
    my $res= shift;
    my @detected_known_bugs = map { $_ . '('.$detected_known_bugs{$_}.')' } keys %detected_known_bugs;
    say("Detected possible appearance of known bugs: @detected_known_bugs") if scalar(@detected_known_bugs);
    return $res;
}

sub check_start_log {
    my ($upgrade_status_ref, $errorlog) = @_;

    my @errors= ();
    open(UPGRADE, $errorlog);

    while (<UPGRADE>) {
        $_ =~ s{[\r\n]}{}siog;
        if (
            ($_ =~ m{\[ERROR\]\s+InnoDB}sio) ||
            ($_ =~ m{InnoDB:\s+Error:}sio) ||
            ($_ =~ m{Assertion\s}sio) ||
            ($_ =~ m{registration as a STORAGE ENGINE failed.}sio) ||
            ($_ =~ m{got signal}sio) ||
            ($_ =~ m{segmentation fault}sio) ||
            ($_ =~ m{segfault}sio) ||
            ($_ =~ m{exception}sio)
        ) {
            push @errors, $_;
            # InnoDB errors are likely to mean something nasty,
            # so we'll raise the flag;
            # but ignore erros about innodb_table_stats at this point
            if ( $_ !~ m{innodb_table_stats}so
                   and $_ !~ m{ib_buffer_pool' for reading: No such file or directory}so
            ) {
                if (m{\[ERROR\] InnoDB: Corruption: Page is marked as compressed but uncompress failed with error}so) 
                {
                    $detected_known_bugs{'MDEV-13112'}= (defined $detected_known_bugs{'MDEV-13112'} ? $detected_known_bugs{'MDEV-13112'}+1 : 1);
                    $$upgrade_status_ref = STATUS_CUSTOM_OUTCOME if $$upgrade_status_ref < STATUS_CUSTOM_OUTCOME;
                }
                elsif (m{void fil_decompress_page.*: Assertion `0' failed}so)
                {
                    $detected_known_bugs{'MDEV-13103'}= (defined $detected_known_bugs{'MDEV-13103'} ? $detected_known_bugs{'MDEV-13103'}+1 : 1);
                    # We will only set the status to CUSTOM_OUTCOME if it was previously set to POSSIBLE_FAILURE
                    $$upgrade_status_ref = STATUS_CUSTOM_OUTCOME if $$upgrade_status_ref == STATUS_POSSIBLE_FAILURE;
                    last;
                }
                elsif (m{InnoDB: Corruption: Page is marked as compressed space:}so)
                {
                    # Most likely it is an indication of MDEV-13103, but to make sure, we still need to find the assertion failure.
                    # If we find it later, we will set result to STATUS_CUSTOM_OUTCOME.
                    # If we don't find it later, we will raise it to STATUS_UPGRADE_FAILURE
                    $$upgrade_status_ref = STATUS_POSSIBLE_FAILURE if $$upgrade_status_ref < STATUS_POSSIBLE_FAILURE;
                }
                else {
                    $$upgrade_status_ref = STATUS_UPGRADE_FAILURE if $$upgrade_status_ref < STATUS_UPGRADE_FAILURE;
                }
            }
        }
        elsif ($_ =~ m{ready for connections}sio) {
            last;
        }
        elsif ($_ =~ m{device full error|no space left on device}sio) {
            $$upgrade_status_ref = STATUS_ENVIRONMENT_FAILURE;
            last;
        }
    }

    close(UPGRADE);

    if (@errors) {
        say("-- ERRORS IN THE LOG -------------");
        foreach(@errors) { say($_) };
        say("----------------------------------");
    }
}


sub dump_database {
    # Suffix is "old" or "new" (restart)
    my ($reporter, $server, $dbh, $suffix) = @_;
    $vardir = $server->vardir unless defined $vardir;
    my $port= $server->port;

    my @all_databases = @{$dbh->selectcol_arrayref("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE LOWER(SCHEMA_NAME) NOT IN ('mysql','information_schema','performance_schema','sys')")};
    my $databases_string = join(' ', @all_databases );

    my $dump_file = "$vardir/server_schema_$suffix.dump";
    my $mysqldump= $server->dumper;

    my $cmd= "\"$mysqldump\" --hex-blob --no-tablespaces --compact --order-by-primary --skip-extended-insert --host=127.0.0.1 --port=$port --user=root --password='' --no-data --databases $databases_string";
    say("Dumping $suffix server structures to the dump file $dump_file using the command:");
    say($cmd);
    my $dump_result = system("$cmd > $dump_file");

    return STATUS_ENVIRONMENT_FAILURE if $dump_result;

    $dump_file = "$vardir/server_data_$suffix.dump";
    $cmd= "\"$mysqldump\" --hex-blob --no-tablespaces --compact --order-by-primary --skip-extended-insert --host=127.0.0.1 --port=$port --user=root --password='' --no-create-info --databases $databases_string";
    say("Dumping $suffix server data to the dump file $dump_file using the command:");
    say($cmd);
    $dump_result = system("$cmd > $dump_file");

    return ($dump_result ? STATUS_ENVIRONMENT_FAILURE : STATUS_OK);
}

# Table AUTO_INCREMENT can be re-calculated upon restart,
# in which case the dumps will be different. We will ignore possible
# AUTO_INCREMENT differences in the dumps, but instead will check
# separately that the new value is either equal to the old one, or
# has been recalculated as MAX(column)+1.

sub collect_autoincrements {
    my ($dbh, $suffix) = @_;
    say("Storing auto-increment data for the $suffix server...");
    my $autoinc_tables = $dbh->selectall_arrayref("SELECT CONCAT(ist.TABLE_SCHEMA,'.',ist.TABLE_NAME), ist.AUTO_INCREMENT, isc.COLUMN_NAME, '' FROM INFORMATION_SCHEMA.TABLES ist JOIN INFORMATION_SCHEMA.COLUMNS isc ON (ist.TABLE_SCHEMA = isc.TABLE_SCHEMA AND ist.TABLE_NAME = isc.TABLE_NAME) WHERE ist.TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema','sys') AND ist.AUTO_INCREMENT IS NOT NULL AND isc.EXTRA LIKE '%auto_increment%' ORDER BY ist.TABLE_SCHEMA, ist.TABLE_NAME, isc.COLUMN_NAME");

    foreach my $t (@$autoinc_tables) {
        $t->[3] = $dbh->selectrow_arrayref("SELECT IFNULL(MAX($t->[2]),0) FROM $t->[0]")->[0];
    }

    return $autoinc_tables;
}

sub compare_all {
    my $table_autoinc= shift;

    say("Comparing SQL schema dumps between old and new servers...");
    my $status = STATUS_OK;
    my $diff_result = system("diff -u $vardir/server_schema_old.dump $vardir/server_schema_new.dump");
    $diff_result = $diff_result >> 8;

    if ($diff_result != 0) {
        sayError("Server schema has changed");
        $status= STATUS_SCHEMA_MISMATCH;
    }

    $diff_result = system("diff -u $vardir/server_data_old.dump $vardir/server_data_new.dump");
    $diff_result = $diff_result >> 8;

    if ($diff_result != 0) {
        sayError("Server data has changed");
        $status= STATUS_CONTENT_MISMATCH;
    }

    say("Comparing auto-increment data between old and new servers...");

    my $old_autoinc= $table_autoinc->{'old'};
    my $new_autoinc= $table_autoinc->{'new'};

    if (not $old_autoinc and not $new_autoinc) {
        say("No auto-inc data for old and new servers, skipping the check");
    }
    elsif ($old_autoinc and ref $old_autoinc eq 'ARRAY' and (not $new_autoinc or ref $new_autoinc ne 'ARRAY')) {
        sayError("Auto-increment data for the new server is not available");
        $status = STATUS_CONTENT_MISMATCH;
    }
    elsif ($new_autoinc and ref $new_autoinc eq 'ARRAY' and (not $old_autoinc or ref $old_autoinc ne 'ARRAY')) {
        sayError("Auto-increment data for the old server is not available");
        $status = STATUS_CONTENT_MISMATCH;
    }
    elsif (scalar @$old_autoinc != scalar @$new_autoinc) {
        sayError("Different number of tables in auto-incement data. Old server: ".scalar(@$old_autoinc)." ; new server: ".scalar(@$new_autoinc));
        $status= STATUS_CONTENT_MISMATCH;
    }
    else {
        foreach my $i (0..$#$old_autoinc) {
            my $to = $old_autoinc->[$i];
            my $tn = $new_autoinc->[$i];
            say("Comparing auto-increment data. Old server: @$to ; new server: @$tn");

            # 0: table name; 1: table auto-inc; 2: column name; 3: max(column)
            if ($to->[0] ne $tn->[0] or $to->[2] ne $tn->[2] or $to->[3] != $tn->[3] or ($tn->[1] != $to->[1] and $tn->[1] != $tn->[3]+1))
            {
                $detected_known_bugs{'MDEV-13094'}= (defined $detected_known_bugs{'MDEV-13094'} ? $detected_known_bugs{'MDEV-13094'}+1 : 1);
                sayError("Auto-increment data differs. Old server: @$to ; new server: @$tn");
                $status= STATUS_CUSTOM_OUTCOME if $status < STATUS_CUSTOM_OUTCOME;
            }
        }
    }

    if ($status == STATUS_OK) {
        say("No differences were found between old and new server contents.");
    }
    return $status;
}

# There are some known expected differences in dump structure between versions.
# We need to normalize the dumps to avoid false positives
sub normalize_dumps {
    my ($old_ver,$new_ver) = @_;

    move("$vardir/server_schema_old.dump","$vardir/server_schema_old.dump.orig");
    move("$vardir/server_schema_new.dump","$vardir/server_schema_new.dump.orig");

    open(DUMP1,"$vardir/server_schema_old.dump.orig");
    open(DUMP2,">$vardir/server_schema_old.dump");
    while (<DUMP1>) {
        if (s/AUTO_INCREMENT=\d+//) {};
        print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);
    open(DUMP1,"$vardir/server_schema_new.dump.orig");
    open(DUMP2,">$vardir/server_schema_new.dump");
    while (<DUMP1>) {
        if (s/AUTO_INCREMENT=\d+//) {};
        print DUMP2 $_;
    }
    close(DUMP1);
    close(DUMP2);

    # In 10.2 SHOW CREATE TABLE output changed:
    # - blob and text columns got the "DEFAULT" clause;
    # - default numeric values lost single quote marks
    # Let's update pre-10.2 dumps to match it

    if ($old_ver le '100201' and $new_ver ge '100201') {
        move("$vardir/server_schema_old.dump","$vardir/server_schema_old.dump.tmp");
        open(DUMP1,"$vardir/server_schema_old.dump.tmp");
        open(DUMP2,">$vardir/server_schema_old.dump");
        while (<DUMP1>) {
            # `k` int(10) unsigned NOT NULL DEFAULT '0' => `k` int(10) unsigned NOT NULL DEFAULT 0
            s/(DEFAULT\s+)\'(\d+)\'(,?)$/${1}${2}${3}/;

            # `col_blob` blob NOT NULL => `col_blob` blob NOT NULL DEFAULT '',
            # This part is conditional, see MDEV-12006. For upgrade from 10.1, a text column does not get a default value
            if ($old_ver lt '100101') {
                s/(\s+(?:blob|text|mediumblob|mediumtext|longblob|longtext|tinyblob|tinytext)(\s+)NOT\sNULL)(,)?$/${1}${2}DEFAULT${2}\'\'${3}/;
            }
            # `col_blob` text => `col_blob` text DEFAULT NULL,
            s/(\s)(blob|text|mediumblob|mediumtext|longblob|longtext|tinyblob|tinytext)(,)?$/${1}${2}${1}DEFAULT${1}NULL${3}/;
            print DUMP2 $_;
        }
        close(DUMP1);
        close(DUMP2);
    }
}

sub report {
    my $reporter= shift;
    my $dbh= DBI->connect($reporter->properties->servers->[1]->dsn);
    if (not defined $dbh) {
        sayError("Could not connect to the server at the end of the test");
        return report_and_return(STATUS_UPGRADE_FAILURE);
    }
    check_database_consistency($dbh);
}

sub type {
    return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_SUCCESS;
}

1;
