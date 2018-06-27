# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2018 MariaDB Coporration Ab.
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

package GenTest::Reporter::ErrorLog;

require Exporter;
@ISA = qw(GenTest::Reporter);

use strict;
use GenTest;
use GenTest::Reporter;
use GenTest::Constants;
use GenTest::CallbackPlugin;

sub report {
    if (defined $ENV{RQG_CALLBACK}) {
        return callbackReport(@_);
    } else {
        return nativeReport(@_);
    }
}


sub nativeReport {

   my $reporter = shift;

   # master.err-old is created when logs are rotated due to SIGHUP

   my $main_log = $reporter->serverVariable('log_error');
   if ($main_log eq '') {
      foreach my $errlog ('../log/master.err', '../mysql.err') {
         if (-f $reporter->serverVariable('datadir').'/'.$errlog) {
            $main_log = $reporter->serverVariable('datadir').'/'.$errlog;
            last;
         }
      }
   }

	foreach my $log ( $main_log, $main_log.'-old' ) {
		if ((-e $log) && (-s $log > 0)) {
      open(ERRLOG, $log) || sayError("Could not open the error log $log");
      my @errlog= ();
      my $maxsize= 200;
      while (<ERRLOG>) {
        shift @errlog if scalar(@errlog) >= $maxsize;
        push @errlog, $_;
      }
			say("The last 200 lines from $log :");
			print(@errlog);
		}
	}
	
   return STATUS_OK;
}

sub callbackReport {
    my $output = GenTest::CallbackPlugin::run("lastLogLines");
    say("$output");
    ## Need some incident interface here in the output from
    ## javaPluginRunner
    return STATUS_OK, undef;
}

sub type {
	return REPORTER_TYPE_CRASH | REPORTER_TYPE_DEADLOCK ;
}

1;
