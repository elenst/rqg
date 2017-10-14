# Copyright (C) 2016, 2017 MariaDB Corporation Ab
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
# The module implements a normal upgrade scenario.
#
# This is the simplest form of upgrade. The test starts the old server,
# executes some flow on it, shuts down the server, starts the new one
# on the same datadir, runs mysql_upgrade if necessary, performs a basic
# data check and executes some more flow.
#
########################################################################

package GenTest::Scenario::Upgrade;

require Exporter;
@ISA = qw(GenTest::Scenario);

use strict;
use DBI;
use GenTest;
use GenTest::App::GenTest;
use GenTest::Properties;
use GenTest::Constants;
use GenTest::Scenario;
#use GenTest::Scenario;
#use GenTest::Reporter;
#use GenTest::Comparator;
use Data::Dumper;
#use IPC::Open2;
use File::Copy;
use File::Compare;
#use POSIX;

use DBServer::MySQL::MySQLd;

sub new {
  my $class= shift;
  my $scenario= $class->SUPER::new(@_);

  $scenario->printTitle('Normal upgrade');

  if (not defined $scenario->getTestType) {
    $scenario->setTestType('normal');
  }

  if (not defined $scenario->getProperty('grammar')) {
    $scenario->setProperty('grammar', 'conf/mariadb/oltp.yy');
  }
  if (not defined $scenario->getProperty('gendata')) {
    $scenario->setProperty('gendata', 'conf/mariadb/innodb_upgrade.zz');
  }
  if (not defined $scenario->getProperty('gendata1')) {
    $scenario->setProperty('gendata1', $scenario->getProperty('gendata'));
  }
  if (not defined $scenario->getProperty('gendata-advanced1')) {
    $scenario->setProperty('gendata-advanced1', $scenario->getProperty('gendata-advanced'));
  }
  if (not defined $scenario->getProperty('threads')) {
    $scenario->setProperty('threads', 4);
  }
  
  return $scenario;
}

sub run {
  my $scenario= shift;
  my ($status, $old_server, $new_server, $gentest, $databases, %table_autoinc);

  $status= STATUS_OK;

  # We can initialize both servers right away, because the second one
  # runs with start_dirty, so it won't bootstrap
  
  $old_server= $scenario->prepareServer(1,
    {
      vardir => $scenario->getProperty('vardir'),
      port => $scenario->getProperty('port'),
      valgrind => 0,
    }
  );
  $new_server= $scenario->prepareServer(2, 
    {
      vardir => $scenario->getProperty('vardir'),
      port => $scenario->getProperty('port'),
      start_dirty => 1
    }
  );

  say("-- Old server info: --");
  say($old_server->version());
  $old_server->printServerOptions();
  say("-- New server info: --");
  say($new_server->version());
  $new_server->printServerOptions();
  say("----------------------");

  #####
  $scenario->printStep("Starting the old server");

  $status= $old_server->startServer;

  if ($status != STATUS_OK) {
    sayError("Old server failed to start");
    return $scenario->finalize($status,[]);
  }
  
  #####
  $scenario->printStep("Running test flow on the old server");

  $gentest= $scenario->prepareGentest(1,
    {
      duration => int($scenario->getTestDuration * 2 / 3),
      dsn => [$old_server->dsn($scenario->getProperty('database'))],
      servers => [$old_server],
      gendata => $scenario->getProperty('gendata'),
    }
  );
  $status= $gentest->run();
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the old server failed");
    return $scenario->finalize($status,[$old_server]);
  }

  #####
  $scenario->printStep("Dumping databases from the old server");
  
  $databases= join ' ', $old_server->nonSystemDatabases();
  $old_server->dumpSchema($databases, $old_server->vardir.'/server_schema_old.dump');
  $old_server->normalizeDump($old_server->vardir.'/server_schema_old.dump', 'remove_autoincs');
  $old_server->dumpdb($databases, $old_server->vardir.'/server_data_old.dump');
  $table_autoinc{'old'} = $old_server->collectAutoincrements();
   
  $scenario->printStep("Stopping the old server");

  $status= $old_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the old server failed");
    return $scenario->finalize($status,[$old_server]);
  }

  #####
  $scenario->printStep("Backing up data from the old server");

  $old_server->backupDatadir($old_server->datadir."_orig");
  move($old_server->errorlog, $old_server->errorlog.'_orig');

  #####
  $scenario->printStep("Starting the new server");

  $status= $new_server->startServer;

  if ($status != STATUS_OK) {
    sayError("New server failed to start");
    return $scenario->finalize($status,[$new_server]);
  }

  #####
  $scenario->printStep("Checking the server error log for errors after upgrade");

  $status= $scenario->checkErrorLog($new_server);

  if ($status != STATUS_OK) {
    sayError("Found errors in the log, upgrade has apparently failed");
    return $scenario->finalize($status,[$new_server]);
  }
  
  #####
  $scenario->printStep("Checking the database state after upgrade");

  $status= $new_server->checkDatabaseIntegrity;

  if ($status != STATUS_OK) {
    sayError("Database appears to be corrupt after upgrade");
    return $scenario->finalize($status,[$new_server]);
  }
  
  #####
  $scenario->printStep("Dumping databases from the new server");
  
  $new_server->dumpSchema($databases, $new_server->vardir.'/server_schema_new.dump');
  $new_server->normalizeDump($new_server->vardir.'/server_schema_new.dump', 'remove_autoincs');
  $new_server->dumpdb($databases, $new_server->vardir.'/server_data_new.dump');
  $table_autoinc{'new'} = $new_server->collectAutoincrements();

  #####
  $scenario->printStep("Comparing databases");
  
  $status= compare($new_server->vardir.'/server_schema_old.dump', $new_server->vardir.'/server_schema_new.dump');
  if ($status != STATUS_OK) {
    sayError("Database structures differ after upgrade");
    return $scenario->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  else {
    say("Structure dumps appear to be identical");
  }
  
  $status= compare($new_server->vardir.'/server_data_old.dump', $new_server->vardir.'/server_data_new.dump');
  if ($status != STATUS_OK) {
    sayError("Data differs after upgrade");
    return $scenario->finalize(STATUS_UPGRADE_FAILURE,[$new_server]);
  }
  else {
    say("Data dumps appear to be identical");
  }
  
  $status= $scenario->_compare_autoincrements($table_autoinc{old}, $table_autoinc{new});
  if ($status != STATUS_OK) {
    sayError("Auto-increment data differs after upgrade");
    return $scenario->finalize($status,[$new_server]);
  }
  else {
    say("Auto-increment data appears to be identical");
  }

  #####
  $scenario->printStep("Running test flow on the new server");

  $gentest= $scenario->prepareGentest(2,
    {
      duration => int($scenario->getTestDuration / 3),
      dsn => [$new_server->dsn($scenario->getProperty('database'))],
      servers => [$new_server],
    }
  );
  $status= $gentest->run();
  
  if ($status != STATUS_OK) {
    sayError("Test flow on the new server failed");
    return $scenario->finalize($status,[$new_server])
  }

  #####
  $scenario->printStep("Stopping the new server");

  $status= $new_server->stopServer;

  if ($status != STATUS_OK) {
    sayError("Shutdown of the new server failed");
    return $scenario->finalize($status,[$new_server]);
  }

  return $scenario->finalize($status,[]);
}

sub _compare_autoincrements {
  my ($self, $old_autoinc, $new_autoinc)= @_;
#	say("Comparing auto-increment data between old and new servers...");

  if (not $old_autoinc and not $new_autoinc) {
      say("No auto-inc data for old and new servers, skipping the check");
      return STATUS_OK;
  }
  elsif ($old_autoinc and ref $old_autoinc eq 'ARRAY' and (not $new_autoinc or ref $new_autoinc ne 'ARRAY')) {
      sayError("Auto-increment data for the new server is not available");
      return STATUS_CONTENT_MISMATCH;
  }
  elsif ($new_autoinc and ref $new_autoinc eq 'ARRAY' and (not $old_autoinc or ref $old_autoinc ne 'ARRAY')) {
      sayError("Auto-increment data for the old server is not available");
      return STATUS_CONTENT_MISMATCH;
  }
  elsif (scalar @$old_autoinc != scalar @$new_autoinc) {
      sayError("Different number of tables in auto-incement data. Old server: ".scalar(@$old_autoinc)." ; new server: ".scalar(@$new_autoinc));
      return STATUS_CONTENT_MISMATCH;
  }
  else {
    foreach my $i (0..$#$old_autoinc) {
      my $to = $old_autoinc->[$i];
      my $tn = $new_autoinc->[$i];
#      say("Comparing auto-increment data. Old server: @$to ; new server: @$tn");

      # 0: table name; 1: table auto-inc; 2: column name; 3: max(column)
      if ($to->[0] ne $tn->[0] or $to->[2] ne $tn->[2] or $to->[3] != $tn->[3] or ($tn->[1] != $to->[1] and $tn->[1] != $tn->[3]+1))
      {
        $self->addDetectedBug(13094);
        sayError("Difference found:\n  old server: table $to->[0]; autoinc $to->[1]; MAX($to->[2])=$to->[3]\n  new server: table $tn->[0]; autoinc $tn->[1]; MAX($tn->[2])=$tn->[3]");
        return STATUS_CUSTOM_OUTCOME;
      }
    }
  }
}

1;
