# Copyright (c) 2008,2011 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Mixer;

require Exporter;
@ISA = qw(GenTest);

use strict;
use Carp;
use Data::Dumper;
use GenTest;
use GenTest::Constants;
use GenTest::Result;
use GenTest::Validator;
use GenTest::Executor;

use constant MIXER_GENERATOR       => 0;
use constant MIXER_EXECUTORS       => 1;
use constant MIXER_VALIDATORS      => 2;
use constant MIXER_FILTERS         => 3;
use constant MIXER_PROPERTIES      => 4;
use constant MIXER_END_TIME        => 5;
use constant MIXER_RESTART_TIMEOUT => 6;
use constant MIXER_ROLE            => 7;

my %rule_status;

1;

sub new {
   my $class = shift;

   my $mixer = $class->SUPER::new({
         'generator'       => MIXER_GENERATOR,
         'executors'       => MIXER_EXECUTORS,
         'validators'      => MIXER_VALIDATORS,
         'properties'      => MIXER_PROPERTIES,
         'filters'         => MIXER_FILTERS,
         'end_time'        => MIXER_END_TIME,
         'restart_timeout' => MIXER_RESTART_TIMEOUT,
         'role'            => MIXER_ROLE
   }, @_);

   foreach my $executor (@{$mixer->executors()}) {
      if ($mixer->end_time()) {
         return undef if time() > $mixer->end_time();
         $executor->set_end_time($mixer->end_time());
      }
      my $init_result = $executor->init();
      return undef if $init_result > STATUS_OK;
      # FIXME: Could what follows fail?
      $executor->cacheMetaData();
   }

   my @validators;
   my %validators;

   # If a Validator was specified by name, load the class and create an object.
   # none is a special word to use when no validators are needed
   # (and we don't want any to be added automatically which happens when we don't provide any)

   my @v = @{$mixer->validators()};
   foreach my $i (0..$#v) {
      next if $v[$i] =~ /^none$/i;
      my $validator = $v[$i];
      if (ref($validator) eq '') {
         $validator = "GenTest::Validator::".$validator;
         say("INFO: Mixer for " . $mixer->role() . " Loading Validator $validator.");
         eval "use $validator" or print $@;
         push @validators, $validator->new();

         $validators[$i]->configure($mixer->properties);
      }
      $validators{ref($validators[$#validators])}++;
   }

   # Query every object for its prerequisites. If one is not loaded, load it and place it
   # in front of the Validators array.

   my @prerequisites;
   foreach my $validator (@validators) {
      my $prerequisites = $validator->prerequisites();
      next if not defined $prerequisites;
      foreach my $prerequisite (@$prerequisites) {
         next if exists $validators{$prerequisite};
         $prerequisite = "GenTest::Validator::" . $prerequisite;
#        say("DEBUG: Mixer for " . $mixer->role() . " : Loading Prerequisite $prerequisite, required by $validator.");
         eval "use $prerequisite" or print $@;
         push @prerequisites, $prerequisite->new();
      }
   }

   my @validators = (@prerequisites, @validators);
   $mixer->setValidators(\@validators);

   foreach my $validator (@validators) {
      return undef if not defined $validator->init($mixer->executors());
   }

   say("INFO: Mixer for " . $mixer->role() . " created.");
   return $mixer;
}

sub next {

   my $mixer = shift;

   my $executors = $mixer->executors();
   my $filters =   $mixer->filters();
   my $mixer_role= $mixer->role();


# For experimenting
#  if (1) {
   if ($mixer->properties->freeze_time) {
      foreach my $ex (@$executors) {
# For experimenting
#        if (0) {
         if ($ex->type == DB_MYSQL) {
            # FIXME:
            # The SQL could fail because of good and bad reasons.
            # Therefore we need to handle that.
            $ex->execute("SET TIMESTAMP = 0");
            $ex->execute("SET TIMESTAMP = UNIX_TIMESTAMP(NOW())");
         } else {
            Carp::cluck "ERROR: Don't know how to freeze time for " . $ex->getName;
            say("ERROR:        Will return STATUS_ENVIRONMENT_FAILURE");
            return STATUS_ENVIRONMENT_FAILURE;
         }
      }
   }

   my $queries = $mixer->generator()->next($executors);
   # For experimenting
   # $queries = undef;
   if (not defined $queries) {
      say("ERROR: Mixer for $mixer_role : Internal grammar problem(\$queries is not defined).\n" .
          "ERROR:        Will return STATUS_ENVIRONMENT_FAILURE");
      return STATUS_ENVIRONMENT_FAILURE;
   } elsif ($queries->[0] eq '') {
#     Disabled because tests are sometimes forced to generate empty queries
#     from good reason.
#     say("Mixer: Your grammar generated an empty query.");
#     return STATUS_ENVIRONMENT_FAILURE;
   }

   my $max_status = STATUS_OK;

   query: foreach my $query (@$queries) {
      # Omit to execute queries consisting of white spaces only.
      next if $query =~ m{^\s*$}o;

      if ($mixer->end_time() && (time() > $mixer->end_time())) {
         say("INFO: Mixer for $mixer_role : We have already exceeded time specified by " .
             "--duration=x; exiting now.");
         last;
      }

      if (defined $filters) {
         foreach my $filter (@$filters) {
            # FIXME:
            # The SQL could fail because of good (KILL CONNECTION/QUERY)
            # and bad (server crash) reasons. So handle that.
            my $explain = Dumper $executors->[0]->execute("EXPLAIN $query") if $query =~ m{^\s*SELECT}sio;
            my $filter_result = $filter->filter($query . " " . $explain);
            next query if $filter_result == STATUS_SKIP;
         }
      }

      my @execution_results;
      my $restart_timeout = $mixer->restart_timeout();

      EXECUTE_QUERY: foreach my $executor (@$executors) {
         my $execution_result = $executor->execute($query);

         # If the server has crashed but we expect server restarts during the test, we will wait and retry
         if ((   $execution_result->status() == STATUS_SERVER_CRASHED
              or $execution_result->status() == STATUS_SERVER_KILLED
              or $execution_result->status() == STATUS_REPLICATION_FAILURE) and $restart_timeout) {
            say("INFO: Mixer for $mixer_role : Server has gone away, waiting up till " .
                "\$restart_timeout(" . $restart_timeout . ") seconds to see if it gets back.")
                  if $restart_timeout == $mixer->restart_timeout() or $restart_timeout == 1;
            while ($restart_timeout) {
               sleep 1;
               $restart_timeout--;
               # 1. The execute will fail all time in case there is nowhere an automatic reconnect.
               #    There is now one in $executor->execute but I assume it will not work well
               #    in the situation given.
               # 2. Repeating the last query is expected to fail often because of natural reason.
               #    Example:
               #    Loss of connection --> reconnect works
               #    But any previous open transactions rolled back + content of user and session
               #    variables might be wrong.
               # 3. Going with $restart_timeout number of 1s sleeps does not work accurate on VM's.
               # 4. $restart_timeout == 1 is somehow strange because we only wait one second.
               # 5. What happens at test runtime if that server does not come up at all?
               # Thinkable solution:
               # 1. Use a while loop with
               #       as long as current time < maximum time
               # 2. Make the attempts to connect and run SQL here but for some other dbh
               # 3. When the server is up again disconnect all executors and omit the remaing
               #    queries (solution like for STATUS 99 got).
               # 4. Report if the server did not come up.
               if ($executor->execute("SELECT 'Heartbeat'", EXECUTOR_FLAG_SILENT)->status() == STATUS_OK) {
                  say("INFO: Mixer for $mixer_role : Server is back, repeating the last query");
                  redo EXECUTE_QUERY;
               }
            }
         } elsif ($execution_result->status() == STATUS_SKIP_RELOOP ) {
            # Just assume the following sample situation
            # -  We go with the RQG builtin statement based replication.
            # -  QUERY == the group of queries provided by the generator.
            #    QUERY = q1 ; q2 ; q3 ; q4 ;
            # -  The state of connection/session on all servers should be equal or at least
            #    compatible before starting to execute q1.
            # -  And this state is influenced by the
            #    history since connect. The important properties of that state are
            #    - Is there already an open transaction havin modified data
            #    - Which content have user defined and session variables?
            # -  Lets assume
            #    - q1 setting a session variable
            #    - q2 opening or extending a transaction by updating a row
            #    were executed with success on all servers
            # -  Assume q3 fails on the first server with session loss
            # 1. There is no guarantee that q3 fails in the same way on the other servers.
            #    Example: A KILL CONNECTION issued by some controlled (ensures determinism)
            #    concurrent session or maybe Reporter like "Querytimeout" might hit the wrong
            #    session because session id's between the servers might differ.
            #    Solution: Either make the code causing the KILL very sophisticated or
            #              do not execute q3 on the other servers too. I take the latter.
            # 2. Lets assume our connection to the first server just reconnects
            #    (example: reconnect option in previous connect).
            #    But now the states of the connections to the servers differ:
            #    server 1: Old transaction rolled back during connection loss.
            #              Setting of user defined and session variables is X.
            #    servers > 1: Old transaction is open.
            #              Setting of user defined and session variables is Y.
            #    In case we would now execute whatever query (q4 or maybe a new QUERY group)
            #    than different outcomes on the servers are to be expected.
            #    Solution: Make the states of the connections to the servers again equal or
            #              compatible. Reconstruction that for the first server is not feasable.
            #              Hence we need to run ROLLBACK and disconnect/reconnect on the other
            #              servers.
            # 3. Lets assume all executors to other servers issue ROLLBACK, disconnect and
            #    make a simple reconnect via reconnect option in previous connect.
            #    Running now whatever queries coming from a top-level rule
            #    "query" "thread*" might violate the test design like maybe
            #    - When running the main share of queries (top-level rules "query" "thread*")
            #      we should stick to certain SQL related settings like low timouts.
            #    - Assume some @aux NOT NULL is required.
            #    Such settings are made in the top-level rules "query_connect" and
            #    "thread*_connect" but we have not rerun them here.
            #    Solution: Force the generator to pick such rules as starting rule when being
            #              asked for the next query.
            # 4. Lets assume the solution described in 3. is implemented.
            #    As soon as the generator is asked for the next QUERY the starting rules
            #    "*_connect" get picked. After that follows the huge amount of QUERYs which get
            #    generated from the rules "query" and "thread*". And they run in the right
            #    environment. Looks good.
            #    But what about the few remaining queries (q4) from the current QUERY?
            #    Can we run them now?
            #    - In case there would be some violate the test design like described in 3.
            #      than this will last till we have run  "*_connect" again.
            #      And that will only happen after asking the generator for the next QUERY.
            #      So running any remaining queries like q4 must not happen.
            #    - In case we run all remaining queries than at end some validator might
            #      kick in. There is some significant risk that such a valditor is not
            #      prepared for a query failing because of connection loss or a few
            #      queries running in some maybe wrong environment.
            #   Solution:
            #   Omit all remaining queries from QUERY. This will than force to ask the Generator
            #   for the next QUERY and than we will get "*_connect" etc.
            #
            say("INFO: Mixer for $mixer_role : STATUS_SKIP_RELOOP got.");
            # Disconnect all executors (one per server).
            # The next $executor->execute will than do a reconnect.
            foreach my $executor (@{$mixer->executors()}) {
               $executor->execute("ROLLBACK"); # I prefer to be sure.
               $executor->disconnect();
            }
            # Set GENERATOR_RECONNECT to 1 so that the generator looks first for the "*_connect"
            # rules if being asked for the next QUERY.
            $mixer->generator()->setReconnect(1);
            # Take care that
            # - the current query does not get executed on other servers
            # - no remaining queries from QUERY or some validator get executed
            # - the environments of the executors get made comparable by throwing the remaining
            #   queries away -> ask generator for new QUERY -> get QUERY generated out of
            #   "*_connect" if that exists
            last query;


            # By what follows we can figure out which generator we use.
            # But is not needed here.
            # if (ref($mixer->generator()) eq 'GenTest::Generator::FromGrammar') {
            #    say("MLML: Mixer Generator is FromGrammar");
            # }

         }

         $max_status = $execution_result->status() if $execution_result->status() > $max_status;
         push @execution_results, $execution_result;

         # If one server has crashed, do not send the query to the second one in order to
         # preserve consistency.
         # FIXME: This is not 100% accurate.
         # We
         # - do not send even if
         #   - $execution_result->status() > STATUS_CRITICAL_FAILURE like for data corruption
         #   - might have STATUS_SERVER_CRASHED got but its in reality false alarm
         # - omit all remaining queries of the current group too
         # Nevertheless this should not be a that big problem because
         # - It is quite likely that we abort the RQG run anyway.
         #   Some thread or reporter or ... will probably show some corresponding critical status.
         # - The likelihood of some thinkable scenario like
         #      1. The server finished the execution of the query with success.
         #      2. The server crashed before being able to tell the connection that the execution
         #         had success.
         #      --> Not sending the query will destroy consistency.
         #   is extreme low.
         # - It is unlikely that some rare "omit the execution of a small and rather arbitrary group
         #   of remaing queries" has some significant impact on funtional coverage.
         if ($execution_result->status() > STATUS_CRITICAL_FAILURE) {
            say("Mixer for $mixer_role : Critical failure " .
                status2text($execution_result->status()) . " (" . $execution_result->err() . ") " .
                "reported at dsn " . $executor->dsn());
            last query;
         }

         $restart_timeout = $mixer->restart_timeout();
         next query if $execution_result->status() == STATUS_SKIP;
      } # End of loop called "EXECUTE_QUERY"

      foreach my $validator (@{$mixer->validators()}) {
         my $validation_result = $validator->validate($executors, \@execution_results);
         if (($validation_result != STATUS_WONT_HANDLE) && ($validation_result > $max_status)) {
            $max_status = $validation_result;
         }
      }
   } # End of loop called "query"

   #
   # Record the lowest (best) status achieved for all participating rules. The goal
   # is for all rules to generate at least some STATUS_OK queries. If not, the offending
   # rules will be reported on DESTROY.
   #

   if ((rqg_debug()) && (ref($mixer->generator()) eq 'GenTest::Generator::FromGrammar')) {
      my $participating_rules = $mixer->generator()->participatingRules();
      foreach my $participating_rule (@$participating_rules) {
         if ((not exists $rule_status{$participating_rule})    ||
             ($rule_status{$participating_rule} > $max_status)   ) {
            $rule_status{$participating_rule} = $max_status
         }
      }
   } # End of loop called "query"

   say("DEBUG: Mixer for $mixer_role : Will return maxstatus : " .
       status2text($max_status) . "($max_status).");

   return $max_status;
}

sub DESTROY {

   my $mixer = shift;

   my @rule_failures;

   foreach my $rule (keys %rule_status) {
      if ($rule_status{$rule} > STATUS_OK) {
         push @rule_failures, "$rule (" . status2text($rule_status{$rule}) . ")";
      }
   }

   if ($#rule_failures > -1) {
      say("Mixer for " . $mixer->role() . " : The following rules produced no STATUS_OK queries: " .
          join(', ', @rule_failures));
   }
}

sub generator {
   return $_[0]->[MIXER_GENERATOR];
}

sub executors {
   return $_[0]->[MIXER_EXECUTORS];
}

sub validators {
   return $_[0]->[MIXER_VALIDATORS];
}

sub properties {
   return $_[0]->[MIXER_PROPERTIES];
}

sub filters {
   return $_[0]->[MIXER_FILTERS];
}

sub setValidators {
   $_[0]->[MIXER_VALIDATORS] = $_[1];
}

sub end_time {
   return ($_[0]->[MIXER_END_TIME] > 0) ? $_[0]->[MIXER_END_TIME] : undef;
}

sub restart_timeout {
   return ( $_[0]->[MIXER_RESTART_TIMEOUT] || 0 );
}

sub role {
   return $_[0]->[MIXER_ROLE];
}

1;
