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

    # Save the major version of the old server
    my $major_version_old= $server->majorVersion;
    
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

    my @errors = ();
    open(UPGRADE, $errorlog);

    while (<UPGRADE>) {
        $_ =~ s{[\r\n]}{}siog;
        say($_) if ($_ =~ m{\[ERROR\]}sio);
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
        } elsif (
            ($_ =~ m{[ERROR] InnoDB:}sio)
        ) {
            $upgrade_status = STATUS_POSSIBLE_FAILURE if $upgrade_status == STATUS_OK;
            push @errors, $_;
        }
    }

    close(UPGRADE);

    if ($upgrade_status == STATUS_OK) {
        $dbh = DBI->connect($server->dsn);
        if (not defined $dbh) {
            say("ERROR: Could not connect to the new server after upgrade");
            $upgrade_status= STATUS_UPGRADE_FAILURE;
        }
    }

    if ($upgrade_status == STATUS_POSSIBLE_FAILURE) {
        say("WARNING: Upgrade produced suspicious messages (see below), but we will allow it to continue");
        say("---ERRORS-------------------------");
        foreach(@errors) { say($_) };
        say("----------------------------------");
    } elsif ($upgrade_status != STATUS_OK) {
        say("ERROR: Upgrade has apparently failed.");
        return $upgrade_status;
    } elsif ($server->majorVersion eq $major_version_old) {
        say("New server started successfully after the minor upgrade");
    } elsif ($reporter->serverVariable('innodb_read_only')) {
        say("New server is running with innodb_read_only=1, skipping mysql_upgrade");
    } else {
        my $mysql_upgrade= $server->clientBindir.'/'.(osWindows() ? 'mysql_upgrade.exe' : 'mysql_upgrade');
        say("New server started successfully after the major upgrade, running mysql_upgrade now using the command:");
        my $cmd= "\"$mysql_upgrade\" --host=127.0.0.1 --port=".$server->port." --user=root --password=''";
        say($cmd);
        $upgrade_status = system("$cmd");
        if ($upgrade_status != STATUS_OK) {
            say("ERROR: mysql_upgrade has failed");
            sayFile($errorlog);
            return $upgrade_status;
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
    return compare_dumps();
}
    
    
sub dump_database {
    # Suffix is "old" or "new" (restart)
    my ($reporter, $server, $dbh, $suffix) = @_;
    $vardir = $server->vardir unless defined $vardir;
    my $port= $server->port;
    
	my @all_databases = @{$dbh->selectcol_arrayref("SHOW DATABASES")};
	my $databases_string = join(' ', grep { $_ !~ m{^(mysql|information_schema|performance_schema)$}sgio } @all_databases );
	
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

sub type {
    return REPORTER_TYPE_ALWAYS;
}

1;
