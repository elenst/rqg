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
# The module checks that after the test flow has finished, 
# upgrade is performed successfully without losing any data.

# It is supposed to be used with the native server startup,
# i.e. with runall-new.pl rather than runall.pl which is MTR-based, 
# and with --upgrade-test option, which makes runall-new.pl
# treat server1 and server2 differently -- instead of running
# the flow on both servers, it only starts server1 and runs the test
# flow there, while preserving server2 (the version to upgrade to).
#
# If the module is used without --upgrade-test, it won't work well.
#
########################################################################

package GenTest::Reporter::Upgrade;

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

sub report {
    my $reporter = shift;
    
    my $upgrade_mode= $reporter->properties->property('upgrade-test');
    say("The test will perform server upgrade in '".$upgrade_mode."' mode");
    say("-- Old server info: --");
    say($reporter->properties->servers->[0]->version());
    $reporter->properties->servers->[0]->printServerOptions();
    say("-- New server info: --");
    say($reporter->properties->servers->[1]->version());
    $reporter->properties->servers->[1]->printServerOptions();
    say("----------------------");

    # If the test run is not properly configured, the module can be 
    # called more than once. Produce an error if it happens
    
    $first_reporter = $reporter if not defined $first_reporter;
    if ($reporter ne $first_reporter) {
        say("ERROR: Update reporter has been called twice, the test run is misconfigured");
        return STATUS_ENVIRONMENT_FAILURE;
    }

    my $server = $reporter->properties->servers->[0];
    my $dbh = DBI->connect($server->dsn);

    # Sometimes schema can look different before and after restart,
    # e.g. AUTO_INCREMENT value can be recalculated. 
    # We don't care about it in the upgrade test, so we'll restart
    # the old server before getting the dump

    say("Restarting the old server...");

    my $pid= $server->pid();
    kill(15, $pid);

    foreach (1..60) {
        last if not kill(0, $pid);
        sleep 1;
    }
    if (kill(0, $pid)) {
        say("ERROR: could not shut down server with pid $pid; sending SIGBART to get a stack trace");
        kill('ABRT', $pid);
        return STATUS_SERVER_DEADLOCKED;
    } 
    $server->setStartDirty(1);
    if ($server->startServer() != STATUS_OK) {
        say("ERROR: Could not restart the old server");
        return STATUS_CRITICAL_FAILURE;
    }
    $dbh = DBI->connect($server->dsn);
    if (not defined $dbh) {
        say("ERROR: Could not connect to the old server after restart");
        return STATUS_CRITICAL_FAILURE;
    }
    
    dump_database($reporter,$server,$dbh,'old');

#    sleep(10);

    # Save the major version of the old server
    my $major_version_old= $server->majorVersion;
    my $version_numeric_old= $server->versionNumeric();
    
    $pid= $server->pid();

    if ($upgrade_mode eq 'normal')
    {
        say("Shutting down the old server...");
        kill(15, $pid);
        foreach (1..60) {
            last if not kill(0, $pid);
            sleep 1;
        }
    }
    else
    {
        say("Killing the old server...");
        kill(9, $pid);
        foreach (1..60) {
            last if not kill(0, $pid);
            sleep 1;
        }
    }
    if (kill(0, $pid)) {
        say("ERROR: could not shut down/kill the old server with pid $pid; sending SIGBART to get a stack trace");
        kill('ABRT', $pid);
        return STATUS_SERVER_DEADLOCKED;
    } else {
        say("Old server with pid $pid has been shut down/killed");
    }

    my $datadir = $server->datadir;
    $datadir =~ s{[\\/]$}{}sgio;
    my $orig_datadir = $datadir.'_orig';

    say("Copying datadir... (interrupting the copy operation may cause investigation problems later)");
    if (osWindows()) {
        system("xcopy \"$datadir\" \"$orig_datadir\" /E /I /Q");
    } else { 
        system("cp -r $datadir $orig_datadir");
    }
    my $errorlog= $server->errorlog;
    move($errorlog, $server->errorlog.'_orig');
    unlink("$datadir/core*");    # Remove cores from any previous crash

    say("Starting the new server...");

    $server = $reporter->properties->servers->[1];
    $server->setStartDirty(1);
    my $upgrade_status = $server->startServer();

    if ($upgrade_status != STATUS_OK) {
        say("ERROR: New server failed to start");
        return STATUS_UPGRADE_FAILURE;
    }
    
    # If we are here, the new server must have started. For a minor upgrade,
    # it should be enough, and the server should be working properly.
    # For the major upgrade, however, having some errors in the error is
    # normal, until we run mysql_upgrade. So, at this point we'll only
    # check for critical errors in the log (e.g. server crashed or
    # an engine cannot initialize)

    my @errors= ();

    open(UPGRADE, $errorlog);

    while (<UPGRADE>) {
        $_ =~ s{[\r\n]}{}siog;
        if (
            ($_ =~ m{\[ERROR\]}sio) ||
            ($_ =~ m{InnoDB:\s+Error:}sio)
        ) {
            push @errors, $_;
            # InnoDB errors are likely to mean something nasty,
            # so we'll raise the flag;
            # but ignore erros about innodb_table_stats at this point
            if ($_ =~ m{InnoDB}so
                and $_ !~ m{innodb_table_stats}so
                and $_ !~ m{ib_buffer_pool' for reading: No such file or directory}so
            ) {
                $upgrade_status = STATUS_POSSIBLE_FAILURE if $upgrade_status == STATUS_OK;
            }
        }

        if ($_ =~ m{registration as a STORAGE ENGINE failed.}sio) {
            $upgrade_status = STATUS_UPGRADE_FAILURE;
        } elsif ($_ =~ m{ready for connections}sio) {
            last;
        } elsif ($_ =~ m{device full error|no space left on device}sio) {
            $upgrade_status = STATUS_ENVIRONMENT_FAILURE;
            last;
        } elsif (
            ($_ =~ m{got signal}sio) ||
            ($_ =~ m{segfault}sio) ||
            ($_ =~ m{segmentation fault}sio) ||
            ($_ =~ m{exception}sio)
        ) {
            $upgrade_status = STATUS_UPGRADE_FAILURE;
        }
    }

    close(UPGRADE);

    if (@errors) {
        say("-- ERRORS IN THE LOG -------------");
        foreach(@errors) { say($_) };
        say("----------------------------------");
    }

    if ($upgrade_status != STATUS_OK) {
        if ($upgrade_status == STATUS_POSSIBLE_FAILURE) {
            say("WARNING: Upgrade produced suspicious messages (see above), but we will allow it to continue");
        } else {
            say("ERROR: Upgrade has apparently failed.");
            return $upgrade_status;
        }
    }

    $dbh = DBI->connect($server->dsn);
    if (not defined $dbh) {
        say("ERROR: Could not connect to the new server after upgrade");
        return STATUS_UPGRADE_FAILURE;
    }

    if ($server->majorVersion eq $major_version_old) {
        say("New server started successfully after the minor upgrade");
    } elsif ($server->serverVariable('innodb_read_only') and (uc($server->serverVariable('innodb_read_only')) eq 'ON' or $server->serverVariable('innodb_read_only') eq '1') ) {
        say("New server is running with innodb_read_only=1, skipping mysql_upgrade");
    } else {
        my $mysql_upgrade= $server->clientBindir.'/'.(osWindows() ? 'mysql_upgrade.exe' : 'mysql_upgrade');
        say("New server started successfully after the major upgrade, running mysql_upgrade now using the command:");
        my $cmd= "\"$mysql_upgrade\" --host=127.0.0.1 --port=".$server->port." --user=root --password=''";
        say($cmd);
        my $res= system("$cmd");
        if ($res != STATUS_OK) {
            say("ERROR: mysql_upgrade has failed");
            sayFile($errorlog);
            return STATUS_UPGRADE_FAILURE;
        }
        say("mysql_upgrade has finished successfully, now the server should be ready to work");
    }

    # 
    # Phase 2 - server is now running, so we execute various statements in order to verify table consistency
    #

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
            return STATUS_DATABASE_CORRUPTION if $dbh->err() > 0 && $dbh->err() != 1178;
        }
    }
    say("Schema does not look corrupt");

    # 
    # Phase 3 - dump the server again and compare dumps
    #
    dump_database($reporter,$server,$dbh,'new');

    my $version_numeric_new= $server->versionNumeric();
    normalize_dumps($version_numeric_old,$version_numeric_new);

    my $res= compare_dumps();
    return ($upgrade_status > $res ? $upgrade_status : $res);
}
    
    
sub dump_database {
    # Suffix is "old" or "new" (restart)
    my ($reporter, $server, $dbh, $suffix) = @_;
    $vardir = $server->vardir unless defined $vardir;
    my $port= $server->port;
    
	my @all_databases = @{$dbh->selectcol_arrayref("SHOW DATABASES")};
	my $databases_string = join(' ', grep { $_ !~ m{^(mysql|information_schema|performance_schema|sys)$}sgio } @all_databases );
	
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

sub compare_dumps {
	say("Comparing SQL schema dumps between old and new servers...");
    my $status = STATUS_OK;
	my $diff_result = system("diff -u $vardir/server_schema_old.dump $vardir/server_schema_new.dump");
	$diff_result = $diff_result >> 8;

	if ($diff_result != 0) {
		say("ERROR: Server schema has changed");
		$status= STATUS_SCHEMA_MISMATCH;
	}

	$diff_result = system("diff -u $vardir/server_data_old.dump $vardir/server_data_new.dump");
	$diff_result = $diff_result >> 8;

	if ($diff_result != 0) {
		say("ERROR: Server data has changed");
		$status= STATUS_CONTENT_MISMATCH;
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

    # In 10.2 SHOW CREATE TABLE output changed:
    # - blob and text columns got the "DEFAULT" clause;
    # - default numeric values lost single quote marks
    # Let's update pre-10.2 dumps to match it

    say("HERE: old ver: $old_ver new ver: $new_ver");
    if ($old_ver le '100201' and $new_ver ge '100201') {
        move("$vardir/server_schema_old.dump","$vardir/server_schema_old.dump.orig");
        open(DUMP1,"$vardir/server_schema_old.dump.orig");
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

sub type {
    return REPORTER_TYPE_ALWAYS;
}

1;
