# Copyright (c) 2018, MariaDB Corporation Ab.
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
#

# Purpose:
# Read SQL statements from a file and process them via GenTest::Executor.
#
# The code here is based on GenTest::App::Gendata.
#

package GenTest::App::GendataSQL;

@ISA = qw(GenTest);

use strict;
use DBI;
use Carp;
use GenTest;
use GenTest::Constants;
use GenTest::Executor;

use Data::Dumper;

use constant GDS_SQL       => 0;
use constant GDS_DEBUG     => 1;
use constant GDS_DSN       => 2;
use constant GDS_ENGINE    => 3;
use constant GDS_SERVER_ID => 4;
use constant GDS_SQLTRACE  => 5;

sub new {
   my $class = shift;

   my $self = $class->SUPER::new({
      'sql_file'  => GDS_SQL,
      'debug'     => GDS_DEBUG,
      'dsn'       => GDS_DSN,
      'engine'    => GDS_ENGINE,
      'server_id' => GDS_SERVER_ID,
      'sqltrace'  => GDS_SQLTRACE},@_);

   return $self;
}


sub sql_file {
   return $_[0]->[GDS_SQL];
}


sub debug {
   return $_[0]->[GDS_DEBUG];
}


sub dsn {
   return $_[0]->[GDS_DSN];
}


sub engine {
   return $_[0]->[GDS_ENGINE];
}


sub server_id {
   return $_[0]->[GDS_SERVER_ID];
}

sub sqltrace {
   return $_[0]->[GDS_SQLTRACE];
}

sub run {
   my ($self) = @_;

   say("INFO: Starting GenTest::App::GendataSQL");

   my $bad_status =  STATUS_ENVIRONMENT_FAILURE;

   my $sql_file = $self->sql_file();
   if (not -e $sql_file) {
      say("ERROR: GenTest::App::GendataSQL::run : The SQL file '$sql_file' " .
          "does no more exist.");
      say("ERROR: Will return STATUS_ENVIRONMENT_FAILURE.");
      return $bad_status;
   }

   my $executor = GenTest::Executor->newFromDSN($self->dsn());
   # Set the number to which server we will connect.
   # This number is
   # - used for more detailed messages only
   # - not used for to which server to connect etc. There only the dsn rules.
   # Hint:
   # Server id reported: n ----- dsn(n-1) !
   $executor->setId($self->server_id);
   # If sqltrace enabled than trace even the SQL here.
   $executor->sqltrace($self->sqltrace);
   $executor->setRole("GendataSQL");
   $executor->init();

   sub run_sql_cmd {
      my ($sql_cmd) = @_;
      # 1. The execute will write the SQL statement including errors to the output in case SQL
      #    tracing is enabled.
      # 2. EXECUTOR_FLAG_SILENT prevents to get error messages from Perl in case
      #    the SQL statement fails. These messages would have some unfortunate format.
      # 3. In case of failing statements we need to write the corresponding information because
      #    SQL tracing might be not enabled and EXECUTOR_FLAG_SILENT is used anyway.
      my $result = $executor->execute($sql_cmd, EXECUTOR_FLAG_SILENT);
      if(STATUS_OK != $result->status) {
         # Report the SQL command and the error because the tracing might be not enabled.
         say("ERROR: GenTest::App::GendataSQL run_sql_cmd : Executing ->$sql_cmd<- " .
             "failed: " .  $result->err() . " " . $result->errstr());
         say("HINT: A SQL statement in '$sql_file' must not extend over more than one line.");
         say("ERROR: Will return STATUS_ENVIRONMENT_FAILURE.");
         return 1;
      } else {
         return STATUS_OK;
      }
    }

   if($executor->type == DB_MYSQL) {
      my $sql_cmd = "SET SQL_MODE= CONCAT(\@\@sql_mode, ',NO_ENGINE_SUBSTITUTION')";
      my $status = run_sql_cmd($sql_cmd);
      if ($status) {
         return $bad_status;
      }
   }

   if ((defined $self->engine() and $self->engine() ne '') and
       ($executor->type == DB_MYSQL or $executor->type == DB_DRIZZLE)) {
      my $sql_cmd = "SET DEFAULT_STORAGE_ENGINE='" . $self->engine() . "'";
      my $status = run_sql_cmd($sql_cmd);
      if ($status) {
         return $bad_status;
      }
   }

   # For debugging:
   # $sql_file = "Does_not_exist";
   if(not open( CONF, $sql_file )) {
      say("ERROR: Unable to open sql file '$sql_file': $!");
      say("ERROR: Will return STATUS_ENVIRONMENT_FAILURE.");
      return $bad_status;
   }
   while (my $line = <CONF>) {
      chomp $line;
      if( $line =~ m{^ *\#.*$} ) {
         # Do not try to execute comment lines.
         next;
      } else {
         my $status = run_sql_cmd($line);
         if ($status) {
            return $bad_status;
         }
      }
   }

   if ($executor->type == DB_MYSQL or $executor->type == DB_DRIZZLE) {
      $executor->execute("COMMIT");
   }

   # FIXME:
   # This gave weird output in history. Check again
   $executor->disconnect();
   undef $executor;

   # $executor->currentSchema(@schema_perms[0]);
   return STATUS_OK;
}

1;
