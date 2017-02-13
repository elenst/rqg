# Copyright (C) 2008-2009 Sun Microsystems, Inc. All rights reserved.
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

package GenTest::Reporter::SlaveReset;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenTest;
use GenTest::Reporter;
use GenTest::Constants;

my $previous_verb = 'START';

sub monitor {

	my $reporter = shift;

    my $server = $reporter->properties->servers->[1];
    my $master_port= $reporter->properties->servers->[0]->port();

	my $slave_host = $reporter->serverInfo('slave_host');
	my $slave_port = $reporter->serverInfo('slave_port');

	my $slave_dsn = 'dbi:mysql:host='.$slave_host.':port='.$slave_port.':user=root';
	my $slave_dbh = DBI->connect($server->dsn());


	if (defined $slave_dbh) {
		$slave_dbh->do("STOP SLAVE");
        
        my @slave_status = $slave_dbh->selectrow_array("SHOW SLAVE 'm1' STATUS");
        my ($master_log, $master_pos) = ($slave_status[9], $slave_status[21]);
        say("Slave position before RESET ALL: $master_log:$master_pos");
        
#        $master_log ||= 'mysql-bin.000001';
#        $master_pos ||= 4;
        
		$slave_dbh->do("RESET SLAVE ALL");

		$slave_dbh->do("RESET MASTER");

        $slave_dbh->do("CHANGE MASTER TO ".
                   " MASTER_PORT = $master_port,".
                   " MASTER_HOST = '127.0.0.1',".
                   " MASTER_USER = 'root',".
                   " MASTER_LOG_FILE = '".$master_log."',".
                   " MASTER_LOG_POS = $master_pos,".
                   " MASTER_USE_GTID = slave_pos,".
                   " MASTER_CONNECT_RETRY = 1");

		$slave_dbh->do("START SLAVE");
			return STATUS_OK;
	} else {
		return STATUS_SERVER_CRASHED;
	}
}

sub report {

	my $reporter = shift;
    my $server = $reporter->properties->servers->[1];
	my $slave_dbh = DBI->connect($server->dsn());

	if (defined $slave_dbh) {
		return STATUS_OK;
	} else {
		return STATUS_SERVER_CRASHED;
	}
}

sub type {
	return REPORTER_TYPE_PERIODIC | REPORTER_TYPE_SUCCESS;
}

1;
