# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Copyright (c) 2017, MariaDB Corporation Ab.
# Use is subject to license terms.
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

package DBServer::MySQL::ReplMySQLd;

@ISA = qw(DBServer::DBServer);

use DBI;
use DBServer::DBServer;
use DBServer::MySQL::MySQLd;
use if osWindows(), Win32::Process;
use Time::HiRes;

use strict;

use Carp;
use Data::Dumper;

use constant REPLMYSQLD_TOPOLOGY => 1;
use constant REPLMYSQLD_SERVER_SETTINGS => 2;
use constant REPLMYSQLD_SERVERS => 3;
use constant REPLMYSQLD_START_DIRTY => 4;
use constant REPLMYSQLD_VALGRIND => 5;
use constant REPLMYSQLD_VALGRIND_OPTIONS => 6;
use constant REPLMYSQLD_GENERAL_LOG => 7;
use constant REPLMYSQLD_USE_GTID => 8;
use constant REPLMYSQLD_CONFIG_CONTENTS => 9;
use constant REPLMYSQLD_USER => 10;

sub new {
    my $class = shift;

    my $self = $class->SUPER::new({'servers' => REPLMYSQLD_SERVER_SETTINGS,
                                   'topology' => REPLMYSQLD_TOPOLOGY,
                                   'general_log' => REPLMYSQLD_GENERAL_LOG,
                                   'start_dirty' => REPLMYSQLD_START_DIRTY,
                                   'valgrind' => REPLMYSQLD_VALGRIND,
                                   'valgrind_options' => REPLMYSQLD_VALGRIND_OPTIONS,
                                   'use_gtid' => REPLMYSQLD_USE_GTID,
                                   'config' => REPLMYSQLD_CONFIG_CONTENTS,
                                   'user' => REPLMYSQLD_USER},@_);

    if (defined $self->[REPLMYSQLD_USE_GTID] 
        and lc($self->[REPLMYSQLD_USE_GTID] ne 'no')
        and lc($self->[REPLMYSQLD_USE_GTID] ne 'current_pos')
        and lc($self->[REPLMYSQLD_USE_GTID] ne 'slave_pos')
    ) {
        croak("FATAL ERROR: Invalid value $self->[REPLMYSQLD_USE_GTID] for use_gtid option");
    }

    # TODO: make sure we can just say --rpl for the default M->S topology
    if (not defined $self->[REPLMYSQLD_TOPOLOGY]) {
        croak("FATAL ERROR: Replication topology is not defined");
    }
    # TODO: compare it with the topology, not with the constant
    if (scalar @{$self->[REPLMYSQLD_SERVER_SETTINGS]}<2) {
        croak("FATAL ERROR: Not enough servers defined for replication");
    }
    
    @{$self->[REPLMYSQLD_SERVERS]} = ();
    
    # TODO: Add log-bin for every master and server-id for every server
    foreach my $n (0..$#{$self->[REPLMYSQLD_SERVER_SETTINGS]}) {
        # Hash of server settings (basedir, vardir etc.)
        my %s= ${$self->[REPLMYSQLD_SERVER_SETTINGS]}[$n];
        $self->[REPLMYSQLD_SERVERS]->[$n] = 
            DBServer::MySQL::MySQLd->new(
                basedir => $s{basedir},
                vardir => $s{vardir},
                debug_server => $s{debug},                
                port => $s{port},
                server_options => $s{mysqld_options},
                general_log => $self->[REPLMYSQLD_GENERAL_LOG],
                start_dirty => $self->[REPLMYSQLD_START_DIRTY],
                valgrind => $self->[REPLMYSQLD_VALGRIND],
                valgrind_options => $self->[REPLMYSQLD_VALGRIND_OPTIONS],
                config => $self->[REPLMYSQLD_CONFIG_CONTENTS],
                user => $self->[REPLMYSQLD_USER]
            );
        if (not defined $self->[REPLMYSQLD_SERVERS]->[$n]) {
#            foreach (0..$n-1) {
#                $self->server->[$_]->stopServer;
#            }
            croak("FATAL ERROR: Could not create server #".$n);
        }
        $self->startAll();
    }
}

sub server {
    return $_[0]->[REPLMYSQLD_SERVERS];
}

sub startAll {
    my $self= shift;

    foreach my $s (@{$self->[REPLMYSQLD_SERVERS]}) {
        $s->startServer;
    }

#	my ($foo, $master_version) = $master_dbh->selectrow_array("SHOW VARIABLES LIKE 'version'");

#	if (($master_version !~ m{^5\.0}sio) && ($self->mode ne 'default')) {
#		$master_dbh->do("SET GLOBAL BINLOG_FORMAT = '".$self->mode."'");
#		$slave_dbh->do("SET GLOBAL BINLOG_FORMAT = '".$self->mode."'");
#	}
    
#	$slave_dbh->do("STOP SLAVE");

#	$slave_dbh->do("SET GLOBAL storage_engine = '$engine'") if defined $engine;

#    $self->configureSlave($slave_dbh);
#	$slave_dbh->do("START SLAVE");
    
    return DBSTATUS_OK;
}

sub configureSlave {
    my ($self,$dbh) = @_;
    my $master_use_gtid = ( 
        defined $self->[REPLMYSQLD_USE_GTID] 
        ? ', MASTER_USE_GTID = ' . $self->[REPLMYSQLD_USE_GTID] 
        : '' 
    );
    $dbh->do("CHANGE MASTER 'm1' TO ".
               " MASTER_PORT = ".$self->master->port.",".
               " MASTER_HOST = '127.0.0.1',".
               " MASTER_USER = 'root',".
               " MASTER_USE_GTID = slave_pos,".
               " MASTER_CONNECT_RETRY = 1" . $master_use_gtid);
}

sub waitForSlaveSync {
    my ($self) = @_;
    if (! $self->master->dbh) {
        say("ERROR: Could not connect to master");
        return DBSTATUS_FAILURE;
    }
    if (! $self->slave->dbh) {
        say("ERROR: Could not connect to slave");
        return DBSTATUS_FAILURE;
    }

    my ($file, $pos) = $self->master->dbh->selectrow_array("SHOW MASTER STATUS");
    say("Master status $file/$pos. Waiting for slave to catch up...");
    my $wait_result = $self->slave->dbh->selectrow_array("SELECT MASTER_POS_WAIT('$file',$pos)");
    if (not defined $wait_result) {
        if ($self->slave->dbh) {
            my @slave_status = $self->slave->dbh->selectrow_array("SHOW SLAVE STATUS /* ReplMySQLd::waitForSlaveSync */");
            say("ERROR: Slave SQL thread has stopped with error: ".$slave_status[37]);
        } else {
            say("ERROR: Lost connection to the slave");
        }
        return DBSTATUS_FAILURE;
    } else {
        return DBSTATUS_OK;
    }
}

sub stopServer {
    my ($self, $status) = @_;

    if ($status == DBSTATUS_OK) {
#        $self->waitForSlaveSync();
    }
    if ($self->slave->dbh) {
        $self->slave->dbh->do("STOP SLAVE");
    }
    
    $self->slave->stopServer;
    $self->master->stopServer;

    return DBSTATUS_OK;
}

1;
