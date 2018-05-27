#!/usr/bin/perl

# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab
# Copyright (C) 2016, 2018 MariaDB Corporation Ab
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

#################### FOR THE MOMENT THIS SCRIPT IS FOR TESTING PURPOSES

# TODO:
# Make here some very strict version
# 1. Conflicts option1 vs option2 are not allowed and lead to abort of test
# 2. Computing the number of servers based on number of basedirs or vardirs must not happen
# 3. vardir must be assigned but it is only a directory where the RQG runner itself will
#    handle all vardirs for servers required.
# 4. Zero ambiguity.
#    The tool calling the RQG runner, the RQG runner and all ingredients taken by it must
#    must belong to the same version.
#    So either RQG_HOME is in the environment and that dictates from where ingredients are
#    taken or the call to the RQG runner was with absolute path and that allows to compute
#    RQG_HOME.
# 5. workdir is rather mandatory
# 6. Maybe reduce the horrible flood of options
# 7. Introduce a config file for the RQG runner

use Carp;

# Note: /work/RQG_mleich1 is the one and only RQG source directory
#       RQG_HOME is not set
# cwd               | Command line call              | $0                       | abs_path(dirname($0))
# -----------------------------------------------------------------------------------------------------
# /work/RQG_mleich1 | perl /work/RQG_mleich1/rqg.pl  | /work/RQG_mleich1/rqg.pl | /work/RQG_mleich1
# /work/RQG_mleich1 | perl rqg.pl                    | rqg.pl                   | /work/RQG_mleich1
# /work/RQG_mleich1 | perl ./rqg.pl                  | ./rqg.pl                 | /work/RQG_mleich1
# /work/RQG_mleich1 | ./rqg.pl                       | ./rqg.pl                 | /work/RQG_mleich1
# /work/RQG_mleich1 | rqg.pl                         | /home/mleich/bin/rqg.pl  | /home/mleich/bin
# -----------------------------------------------------------------------------------------------------
# /home/mleich      | rqg.pl                         | Perl BEGIN failed--compilation aborted ...
# /home/mleich      | <variants>/rqg.pl              | Perl BEGIN failed--compilation aborted ...
#
# 1. The RQG runner must be found via path in the command line call or via $PATH.
# 2. Variants which work are
#    a) Current working directory is whereever. RQG_HOME is already set and pointing to the root of
#       some RQG install.
#    b) RQG_HOME is not already set. The current working directory is the root of some RQG install.
# The problems with the variants:
# a) In case the RQG runner called is not located in RQG_HOME assigned than we might get consistency
#    issues like the runner expects some routine or behavior offered by the libs which $RQG_HOME/lib
#    does not satisfy.
#    Hence the RQG runner must located in that RQG_HOME.
# b) It is quite common to have the current working directory in the root of some RQG install and
#    than to start some start RQG tool or runner being located in that install. 
#    In case the RQG tool or runner start to write into or below that root directory than we might
#    hit the following issues
#    - The permissions set do not allow to write there. (unlikely but at least possible)
#    - We more or less pollute the RQG install which annoys when using that RQG install with GIT.
#    Hence there should be a way to have a current working directory outside of the RQG install
#    and than to run RQG.
# 

# use File::Basename qw(dirname);
# use Cwd qw(abs_path);
use File::Basename; # We use dirname
use Cwd;            # We use abs_path , getcwd
my $rqg_home;
my $rqg_home_call = Cwd::abs_path(File::Basename::dirname($0));
my $rqg_home_env  = $ENV{'RQG_HOME'};
my $start_cwd     = Cwd::getcwd();

use lib 'lib'; # In case we are in the root of a RQG install than we have at least a chance.

print("DEBUG: \$0 ->$0<-, rqg_home_call ->$rqg_home_call<-, rqg_home_env ->$rqg_home_env<-\n");

if (defined $rqg_home_env) {
   if ($rqg_home_env ne $rqg_home_call) {
      print("ERROR: RQG_HOME found in environment ('$rqg_home_env') and RQG_HOME computed from " .
            "the RQG call ('$rqg_home_call') differ.\n");
      Auxiliary::help_rqg_home();
      exit 2;
   } else {
      $rqg_home = $rqg_home_env;
      say("DEBUG: rqg_home '$rqg_home' taken from environment might be usable.\n");
   }
} else {
   # RQG_HOME is not set
   if ($rqg_home_call ne $start_cwd) {
      # We will maybe not able to find the libs and harvest
      # Perl BEGIN failed--compilation aborted ... immediate.
      print("ERROR: RQG_HOME was not found in environment and RQG_HOME computed from the "  .
            "RQG call ('$rqg_home_call') is not equal to the current working directory.\n");
      Auxiliary::help_rqg_home();
      exit 2;
   } else {
      $rqg_home = $start_cwd;
      print("DEBUG: rqg_home '$rqg_home' computed usable\n");
   }
}
say("DEBUG: rqg_home might be ->$rqg_home<-");
if (not -e $rqg_home . "/lib/GenTest.pm") {
   print("ERROR: The rqg_home ('$rqg_home') determined does not look like the root of a " .
         "RQG install.\n");
         exit 2;
}
$ENV{'RQG_HOME'} = $rqg_home;
say("INFO: Environment variable 'RQG_HOME' set to '$rqg_home'");

# use lib 'lib';
use lib $rqg_home . "/lib";
$rqg_home_env = $ENV{'RQG_HOME'};

use Carp;
# How many characters of each argument to a function to print.
$Carp::MaxArgLen=  200;
# How many arguments to each function to show. Btw. 8 is also the default.
$Carp::MaxArgNums= 8;

use constant RQG_RUNNER_VERSION  => 'Version 3.0.0 (2018-05)';
use constant STATUS_CONFIG_ERROR => 199;

use strict;
use GenTest;
use Auxiliary;
use GenTest::BzrInfo;
use GenTest::Constants;
use GenTest::Properties;
use GenTest::App::GenTest;
use GenTest::App::GenConfig;
use DBServer::DBServer;
use DBServer::MySQL::MySQLd;
use DBServer::MySQL::ReplMySQLd;
use DBServer::MySQL::GaleraMySQLd;

# TODO:
# Direct
# - nearly all output to $rqg_workdir/rqg.log
#   This would be
#   - clash free in case a clash free $workdir is assigned.
#   - not clash free in case $workdir is not assigned -> pick cwd().
#     But than we should have no parallel RQG runs anyway and
#     additional clashes on vardirs etc. are to be feared too.
# - rare and only early and late output to STDOUT.
#   This can than be merged into the output of some upper level caller
#   like combinations.pl.
# Example:
# 1. combinations.pl reports that it calls rqg.pl.
# 2. rqg.pl reports into combinations.pl that it has taken over.
# 3. rqg.pl does its main work and reports into $rqg_workdir/rqg.log.
# 4. rqg.pl reports at end something of interest into combinations.pl.
#

$| = 1;
my $logger;
eval
{
   require Log::Log4perl;
   Log::Log4perl->import();
   $logger = Log::Log4perl->get_logger('randgen.gentest');
};

$| = 1;
if (osWindows()) {
   $SIG{CHLD} = "IGNORE";
}

if (defined $ENV{RQG_HOME}) {
   if (osWindows()) {
      $ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
   } else {
      $ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
   }
}

use Getopt::Long;
use GenTest::Constants;
use DBI;
use Cwd;

# This is the "default" database. Connects go into that database.
my $database = 'test';
# Connects which do not specify a different user use that user.
my $user     = 'rqg';
my @dsns;

my ($gendata, @basedirs, @mysqld_options, @vardirs, $rpl_mode,
    @engine, $help, $debug, @validators, @reporters, @transformers,
    $grammar_file, $skip_recursive_rules,
    @redefine_files, $seed, $mask, $mask_level, $mem, $rows,
    $varchar_len, $xml_output, $valgrind, @valgrind_options, @vcols, @views,
    $start_dirty, $filter, $build_thread, $sqltrace, $testname,
    $report_xml_tt, $report_xml_tt_type, $report_xml_tt_dest,
    $notnull, $logfile, $logconf, $report_tt_logdir, $querytimeout, $no_mask,
    $short_column_names, $strict_fields, $freeze_time, $wait_debugger, @debug_server,
    $skip_gendata, $skip_shutdown, $galera, $use_gtid, $genconfig, $annotate_rules,
    $restart_timeout, $gendata_advanced, $scenario, $upgrade_test, $store_binaries,
    $ps_protocol, @gendata_sql_files, $config_file,
    @whitelist_statuses, @whitelist_patterns, @blacklist_statuses, @blacklist_patterns,
    $archiver_call, $workdir,
    $options);

my $gendata   = ''; ## default simple gendata
my $genconfig = ''; # if template is not set, the server will be run with --no-defaults

# Place rather into the preset/default section for all variables.
my $threads  = my $default_threads  = 10;
my $queries  = my $default_queries  = 100000000;
my $duration = my $default_duration = 3600;

my @ARGV_saved = @ARGV;

# Warning:
# Lines starting with names of options like "rpl_mode" and "rpl-mode" are not duplicates because
# the difference "_" and "-".
# FIXME: Offer more
# 1. config file
# 7. Archiver command

# TODO:
# If possible
# It must be ensured that the right rqg.pl is called.
# Scenarios like
# Some upper level tool like /<ABC>.pl picks a /<DEF/rqg.pl with <ABC> != <DEF>
# must be prevented!!
#

say("DEBUG: Before reading commannd line options");

# Take the options assigned in command line and
# - fill them into the of variables allowed in command line
# - abort in case of meeting some not supported options
my $opt_result = {};

if (not GetOptions(
    $opt_result,
    'workdir:s'                   => \$workdir,
    'mysqld=s@'                   => \$mysqld_options[0],
    'mysqld1=s@'                  => \$mysqld_options[1],
    'mysqld2=s@'                  => \$mysqld_options[2],
    'mysqld3=s@'                  => \$mysqld_options[3],
    'basedir=s@'                  => \$basedirs[0],
    'basedir1=s'                  => \$basedirs[1],
    'basedir2=s'                  => \$basedirs[2],
    'basedir3=s'                  => \$basedirs[3],
    #'basedir=s@'                 => \@basedirs,
    'vardir=s'                    => \$vardirs[0],
#   'vardir1=s'                   => \$vardirs[1], # used internal only
#   'vardir2=s'                   => \$vardirs[2], # used internal only
#   'vardir3=s'                   => \$vardirs[3], # used internal only
    'debug-server'                => \$debug_server[0],
    'debug-server1'               => \$debug_server[1],
    'debug-server2'               => \$debug_server[2],
    'debug-server3'               => \$debug_server[3],
    #'vardir=s@'                  => \@vardirs,
    'rpl_mode=s'                  => \$rpl_mode,
    'rpl-mode=s'                  => \$rpl_mode,
    'engine=s'                    => \$engine[0],
    'engine1=s'                   => \$engine[1],
    'engine2=s'                   => \$engine[2],
    'engine3=s'                   => \$engine[3],
    'grammar=s'                   => \$grammar_file,
    'skip-recursive-rules'        => \$skip_recursive_rules,
    'redefine=s@'                 => \@redefine_files,
    'threads=i'                   => \$threads,
    'queries=s'                   => \$queries,
    'duration=i'                  => \$duration,
    'help'                        => \$help,
    'debug'                       => \$debug,
    'validators=s@'               => \@validators,
    'reporters=s@'                => \@reporters,
    'transformers=s@'             => \@transformers,
    'gendata:s'                   => \$gendata,
    'gendata_sql:s@'              => \@gendata_sql_files,
    'gendata_advanced'            => \$gendata_advanced,
    'gendata-advanced'            => \$gendata_advanced,
    'skip-gendata'                => \$skip_gendata,
    'genconfig:s'                 => \$genconfig,
    'notnull'                     => \$notnull,
    'short_column_names'          => \$short_column_names,
    'freeze_time'                 => \$freeze_time,
    'strict_fields'               => \$strict_fields,
    'seed=s'                      => \$seed,
    'mask:i'                      => \$mask,
    'mask-level:i'                => \$mask_level,
    'mask_level:i'                => \$mask_level,
    'mem'                         => \$mem,
    'rows=s'                      => \$rows,
    'varchar-length=i'            => \$varchar_len,
    'xml-output=s'                => \$xml_output,
    'report-xml-tt'               => \$report_xml_tt,
    'report-xml-tt-type=s'        => \$report_xml_tt_type,
    'report-xml-tt-dest=s'        => \$report_xml_tt_dest,
    'restart_timeout=i'           => \$restart_timeout,
    'testname=s'                  => \$testname,
    'valgrind!'                   => \$valgrind,
    'valgrind_options=s@'         => \@valgrind_options,
    'vcols:s'                     => \$vcols[0],
    'vcols1:s'                    => \$vcols[1],
    'vcols2:s'                    => \$vcols[2],
    'vcols3:s'                    => \$vcols[3],
    'views:s'                     => \$views[0],
    'views1:s'                    => \$views[1],
    'views2:s'                    => \$views[2],
    'views3:s'                    => \$views[3],
    'wait-for-debugger'           => \$wait_debugger,
    'start-dirty'                 => \$start_dirty,
    'filter=s'                    => \$filter,
    'mtr-build-thread=i'          => \$build_thread,
    'sqltrace:s'                  => \$sqltrace,
    'logfile=s'                   => \$logfile,
    'logconf=s'                   => \$logconf,
    'report-tt-logdir=s'          => \$report_tt_logdir,
    'querytimeout=i'              => \$querytimeout,
    'no-mask'                     => \$no_mask,
    'skip_shutdown'               => \$skip_shutdown,
    'skip-shutdown'               => \$skip_shutdown,
    'galera=s'                    => \$galera,
    'use-gtid=s'                  => \$use_gtid,
    'use_gtid=s'                  => \$use_gtid,
    'annotate_rules'              => \$annotate_rules,
    'annotate-rules'              => \$annotate_rules,
    'upgrade-test:s'              => \$upgrade_test,
    'upgrade_test:s'              => \$upgrade_test,
    'scenario:s'                  => \$scenario,
    'ps-protocol'                 => \$ps_protocol,
    'ps_protocol'                 => \$ps_protocol,
    'store-binaries'              => \$store_binaries,
    'store_binaries'              => \$store_binaries,
    'whitelist_statuses:s@'       => \@whitelist_statuses,
    'whitelist_patterns:s@'       => \@whitelist_patterns,
    'blacklist_statuses:s@'       => \@blacklist_statuses,
    'blacklist_patterns:s@'       => \@blacklist_patterns,
    'archiver_call:s'             => \$archiver_call,
    )) {
   help();
   exit STATUS_CONFIG_ERROR;
};

say("DEBUG: After reading command line options");

if ( defined $help ) {
   help();
   exit STATUS_OK;
}

# Convert strings with list as content to lists
# ---------------------------------------------
my $list_ref;
Auxiliary::print_list("DEBUG: Initial RQG whitelist_statuses ", @whitelist_statuses);
if (not defined $whitelist_statuses[0]) {
   $whitelist_statuses[0] = STATUS_ANY_ERROR;
   say("DEBUG: whitelist_statuses[0] was not defined. Setting whitelist_statuses[0] " .
       "to STATUS_ANY_ERROR (== default).");
};
$list_ref = Auxiliary::input_to_list(@whitelist_statuses);
if(defined $list_ref) {
   @whitelist_statuses = @$list_ref;
   Auxiliary::print_list("INFO: Final RQG whitelist_statuses ",  @whitelist_statuses);
} else {
   say("ERROR: Auxiliary::input_to_list hit problems we cannot handle. Will exit with STATUS_ENVIRONMENT_FAILURE.");
   exit STATUS_ENVIRONMENT_FAILURE;
}
Auxiliary::print_list("DEBUG: Initial RQG whitelist_patterns ", @whitelist_patterns);
if (not defined $whitelist_patterns[0]) {
   $whitelist_patterns[0] = undef;
   say("DEBUG: whitelist_patterns[0] was not defined. Setting whitelist_patterns[0] " .
       "to undef (== default).");
};
$list_ref = Auxiliary::input_to_list(@whitelist_patterns);
if(defined $list_ref) {
   @whitelist_patterns = @$list_ref;
   Auxiliary::print_list("INFO: Final RQG whitelist_patterns ",  @whitelist_patterns);
} else {
   say("ERROR: Auxiliary::input_to_list hit problems we cannot handle. Will exit with STATUS_ENVIRONMENT_FAILURE.");
   exit STATUS_ENVIRONMENT_FAILURE;
}


Auxiliary::print_list("DEBUG: Initial RQG blacklist_statuses ", @blacklist_statuses);
if (not defined $blacklist_statuses[0]) {
   $blacklist_statuses[0] = STATUS_OK;
   say("DEBUG: blacklist_statuses[0] was not defined. Setting blacklist_statuses[0] " .
       "to STATUS_OK (== default).");
};
$list_ref = Auxiliary::input_to_list(@blacklist_statuses);
if(defined $list_ref) {
   @blacklist_statuses = @$list_ref;
   Auxiliary::print_list("INFO: Final RQG blacklist_statuses ",  @blacklist_statuses);
} else {
   say("ERROR: Auxiliary::input_to_list hit problems we cannot handle. Will exit with STATUS_ENVIRONMENT_FAILURE.");
   exit STATUS_ENVIRONMENT_FAILURE;
}
Auxiliary::print_list("DEBUG: Initial RQG blacklist_patterns ", @blacklist_patterns);
if (not defined $blacklist_patterns[0]) {
   $blacklist_patterns[0] = undef;
   say("DEBUG: blacklist_patterns[0] was not defined. Setting blacklist_patterns[0] " .
       "to undef (== default).");
};
$list_ref = Auxiliary::input_to_list(@blacklist_patterns);
if(defined $list_ref) {
   @blacklist_patterns = @$list_ref;
   Auxiliary::print_list("INFO: Final RQG blacklist_patterns ",  @blacklist_patterns);
} else {
   say("ERROR: Auxiliary::input_to_list hit problems we cannot handle. Will exit with STATUS_ENVIRONMENT_FAILURE.");
   exit STATUS_ENVIRONMENT_FAILURE;
}

if (not defined $workdir) {
   $workdir = Cwd::getcwd() . "/workdir_" . $$;
   say("INFO: The RQG workdir was not defined. Setting it to '$workdir' and removing+creating it.");
   if(-d $workdir) {
      if(not File::Path::rmtree($workdir)) {
         say("ERROR: Removal of the tree '$workdir' failed. : $!. " .
             "Will exit with STATUS_ENVIRONMENT_FAILURE");
         exit STATUS_ENVIRONMENT_FAILURE ;
      }
      say("DEBUG: The already existing RQG workdir '$workdir' was removed.");
   }
   if (mkdir $workdir) {
      say("DEBUG: The RQG workdir '$workdir' was created.");
   } else {
      say("ERROR: Creating the RQG workdir '$workdir' failed : $!. " .
          "Will exit with STATUS_ENVIRONMENT_FAILURE");
   }

   my $result = Auxiliary::make_rqg_infrastructure($workdir);
   if ($result) {
      say("ERROR: Auxiliary::make_rqg_infrastructure failed with $result. \n" .
          "Will exit with STATUS_ENVIRONMENT_FAILURE.");
      exit_test(STATUS_ENVIRONMENT_FAILURE);
   }
} else {
   my $result = Auxiliary::check_rqg_infrastructure($workdir);
   if ($result) {
      say("ERROR: Auxiliary::check_rqg_infrastructure failed with $result. \n" .
          "Will exit with STATUS_ENVIRONMENT_FAILURE.");
      exit_test(STATUS_ENVIRONMENT_FAILURE);
   }
}

say("INFO: RQG workdir : '$workdir' and infrastructure is prepared.");
# This works only if RQG_HOME is set to the right value before calling the RQG runner.
# In addition all files assigned by relative path will no more work.
# if ( not chdir($workdir) ) {
#    say("ERROR: chdir() to '" . $workdir . "' failed : $!");
#     exit_test(STATUS_ENVIRONMENT_FAILURE);
# }
# say("MLML chdir to $workdir passed.");

# Shift from init -> start
my $return = Auxiliary::set_rqg_phase($workdir, 'start');
say("DEBUG: RQG phase return is : '$return'");
$return = Auxiliary::get_rqg_phase($workdir);
say("DEBUG: RQG phase is '$return'");


say("INFO: RQG archiver_call : " . $archiver_call);

if (defined $scenario) {
   system("perl $ENV{RQG_HOME}/run-scenario.pl @ARGV_saved");
   exit $? >> 8;
}

# MLML Experiment
$logfile = $workdir . "/rqg.log";
if (defined $logfile && defined $logger) {
   setLoggingToFile($logfile);
} else {
   # FIXME: What is this branch good for?
   if (defined $logconf && defined $logger) {
      setLogConf($logconf);
   }
}

if ($help) {
   help();
   exit 0;
}
if (not defined $grammar_file) {
   print STDERR "\nERROR: Grammar file is not defined\n\n";
   help();
   exit 1;
}

if (defined $sqltrace) {
   # --sqltrace may have a string value (optional).
   # Allowed values for --sqltrace:
   my %sqltrace_legal_values = (
      'MarkErrors'    => 1  # Prefixes invalid SQL statements for easier post-processing
   );

   if (length($sqltrace) > 0) {
      # A value is given, check if it is legal.
      if (not exists $sqltrace_legal_values{$sqltrace}) {
          say("ERROR: Invalid value for --sqltrace option: '$sqltrace'.\n"               .
              "       Valid values are: " . join(', ', keys(%sqltrace_legal_values))     .
              "       No value means that default/plain sqltrace will be used.");
          exit(STATUS_ENVIRONMENT_FAILURE);
      } else {
          say("INFO: Sqltracing '$sqltrace' enabled.");
      }
   } else {
      # If no value is given, GetOpt will assign the value '' (empty string).
      # We interpret this as plain tracing (no marking of errors, prefixing etc.).
      # Better to use 1 instead of empty string for comparisons later.
      $sqltrace = 1;
      say("INFO: Default/plain sqltracing enabled.");
   }
}


say("Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.");
say("Please see http://forge.mysql.com/wiki/Category:RandomQueryGenerator for more information on this test framework.");
say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

#
# Calculate master and slave ports based on MTR_BUILD_THREAD (MTR
# Version 1 behaviour)
#

if (not defined $build_thread) {
   if (defined $ENV{MTR_BUILD_THREAD}) {
      $build_thread = $ENV{MTR_BUILD_THREAD};
      say("INFO: Setting build_thread to '$build_thread' picked from process environment (MTR_BUILD_THREAD).");
   } else {
      $build_thread = DEFAULT_MTR_BUILD_THREAD;
      say("INFO: Setting build_thread to the RQG default '$build_thread'.");
   }
} else {
   say("INFO: build_thread : $build_thread");
}

if ( $build_thread eq 'auto' ) {
   say ("ERROR: Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' " .
        "(recommended) or unset it (will take the default value " . DEFAULT_MTR_BUILD_THREAD .").");
   exit (STATUS_ENVIRONMENT_FAILURE);
}

my @ports = (10000 + 10 * $build_thread, 10000 + 10 * $build_thread + 2, 10000 + 10 * $build_thread + 4);

say("INFO: master_port : $ports[0] slave_port : $ports[1] ports : @ports MTR_BUILD_THREAD : $build_thread ");

if (not defined $rpl_mode or $rpl_mode eq '') {
   $rpl_mode = Auxiliary::RQG_RPL_NONE;
   say("INFO: rpl_mode was not defined or eq '' and therefore set to '$rpl_mode'.");
}
my $result = Auxiliary::check_value_supported (
                'rpl_mode', Auxiliary::RQG_RPL_ALLOWED_VALUE_LIST, $rpl_mode);
if ($result != STATUS_OK) {
   Auxiliary::print_list("The values supported for 'rpl_mode' have to start with :" ,
                         Auxiliary::RQG_RPL_ALLOWED_VALUE_LIST);
   Carp::cluck("ERROR: Auxiliary::check_value_supported returned $result. Will return that too.");
   exit $result;
}
my $number_of_servers = 0;
if ($rpl_mode eq Auxiliary::RQG_RPL_NONE) {
   $number_of_servers = 1;
} elsif (($rpl_mode eq Auxiliary::RQG_RPL_STATEMENT)        or
         ($rpl_mode eq Auxiliary::RQG_RPL_STATEMENT_NOSYNC) or
         ($rpl_mode eq Auxiliary::RQG_RPL_MIXED)            or
         ($rpl_mode eq Auxiliary::RQG_RPL_MIXED_NOSYNC)     or
         ($rpl_mode eq Auxiliary::RQG_RPL_ROW)              or
         ($rpl_mode eq Auxiliary::RQG_RPL_ROW_NOSYNC)       or
         ($rpl_mode eq Auxiliary::RQG_RPL_RQG2)        ) {
   $number_of_servers = 2;
} elsif ($rpl_mode eq Auxiliary::RQG_RPL_RQG3) {
   $number_of_servers = 3;
} else {
   # Galera lands here.
   $number_of_servers = 0;
}
say("INFO: Number of servers involved = $number_of_servers. (0 means unknown)");

# Different servers can be defined either by providing separate basedirs (basedir1, basedir2[, basedir3]),
# or by providing separate vardirs (vardir1, vardir2[, vardir3]).
# Now it's time to clean it all up and define for sure how many servers we need to run, and with options

# FIXME:
# It seems the concept of basedir, vardir and server use is like (I take 'basedir' as example)
# 1. The "walk through" of options to variables is
#    'basedir=s@'                  => \$basedirs[0],
#    'basedir1=s'                  => \$basedirs[1],
#    'basedir2=s'                  => \$basedirs[2],
#    'basedir3=s'                  => \$basedirs[3]
# 2. It is doable (convenient in command line) to assign values to several variables by assigning
#    a string with a comma separated list to basedir<no number>.
#    RQG will decompose that later and distribute the values got to basedirs[<n>].
#    It needs to be checked that such a decomposition will be only done in case @basedirs contains
#    nothing else than a defined $basedirs[0].
# --- After decomposition if required ---
# 3. Server get counted starting with 1.
# 4. Server <n> -> $basedirs[<n>] ->  vardirs[<n>]
# 5. In case $basedirs[<n>] is required but nothing was assigned than take $basedirs[0] in case
#    that was assigned. Otherwise abort.
# 6. We could end up with
#       Server 1 uses $basedirs[1] (assigned as basedir1 in command line)
#       Server 2 uses $basedirs[2] (not assigned in command line but there was a basedir assigned
#                                   and that was pushed to $basedirs[2])
#    Would that be reasonable?
# 7. vardir<whatever> assigned at commandline
#    For the case that we want to have all servers on the current box only, than wouldn't is make
#    sense to: Get one "top" vardir assigned and than RQG creates subdirs which get than used
#    for the servers.
#    To be solved problem: What if the test should start with "start-dirty".
#
# Depending on how (command line, some tool managing RQG runs) the current RQG runner was started
# we might meet
# - undef   Example: --basedir1= --> $basedirs[1] is not defined
# - ''      Example: <tool> --basedir1= --> tool gets undef for variable but sets to default ''
Auxiliary::print_list("INFO: Early RQG basedirs ",  @basedirs);
if ((not defined $basedirs[0] or $basedirs[0] eq '') and
    (not defined $basedirs[1] or $basedirs[1] eq '')    ) {
   # We need in minimum the server 1 and for it a basedir.
   say("\nERROR: Neither basedir nor basedir1 is defined\n.");
   help();
   exit 1;
}
# Attention:
# We cannot treat basedirs like for example blacklist_patterns because of the following reasons:
# 1. blacklist_patterns has only one option "--blacklist_patterns" which can be assigned.
#    There is no --blacklist_patterns1, --blacklist_patterns2 etc.
#    To be handled clashes like between
#    - '--blacklist_patterns' got as value a string which would be decomposed and than filling
#      blacklist_patterns[0], blacklist_patterns[1], ...
#    - '--blacklist_patterns1' got a value assigned too and usually goes into blacklist_patterns[1]
#    cannot happen.
#    Not assigned values, lets assume a blacklist_patterns[7] is not defined have
#    - no impact on "How the RQG test is executed" (gendata with views or not or ...)
#    - only an impact which final result leads to some information that pattern matched or not
# 2. basedirs has 4 options basedirs, basedirs1, basedirs2, basedirs3 which get than immediate
#    pushed into the corresponding variables basedirs[0], basedirs[1], ...
#    - To be handled clashes
#    - Historic comfort features like take basedir1 if basedirs2 not assigned but needed.
#   'basedir=s@'                  => \$basedirs[0],
#   'blacklist_patterns:s@'       => \@blacklist_patterns,
# Treat the case that only $basedirs[0] was assigned
if ($#basedirs == 0) {
   if (not defined $basedirs[0] or $basedirs[0] eq '') {
      say("\nERROR: Neither basedir nor basedir1 is defined\n.");
      help();
      exit 1;
   } else {
      # There might be several basedirs put into $basedirs[0]
      Auxiliary::print_list("DEBUG: Initial RQG basedirs ", @basedirs);
      my $list_ref = Auxiliary::input_to_list(@basedirs);
      if(defined $list_ref) {
         @basedirs = @$list_ref;
      } else {
         say("ERROR: Auxiliary::input_to_list hit problems we cannot handle. Will exit with STATUS_ENVIRONMENT_FAILURE.");
         exit STATUS_ENVIRONMENT_FAILURE;
      }
   }
}

#
# Rule of thumb with some comfort and some fault tolerance.
# 1. If $basedirs[0] not defined or eq '' and $basedirs[1] defined and ne '' (ensured above)
#    than set $basedirs[0] = $basedirs[1].
if ((not defined $basedirs[0] or $basedirs[0] eq '') and
    (defined $basedirs[1] and $basedirs[1] ne '')       ) {
   say("DEBUG: \$basedirs[0] is not defined or eq ''. Setting it to \$basedirs[1] '$basedirs[1]'.");
   $basedirs[0] = $basedirs[1];
}
# 2. Set any required $basedirs[n] but not defined or eq '' = $basedirs[0].
# 3. Warn and set to undef what is non sense like a basedir for some never started server.
#
# Current code might work wrong in case of upgrade test or Galera.
foreach my $i (1..3) {
   if ($i <= $number_of_servers) {
      if (not defined $basedirs[$i] or $basedirs[$i] eq '') {
         say("DEBUG: \$basedirs[$i] is not defined or ''. Setting it to \$basedirs[0] : '\$basedirs[0]'.");
         $basedirs[$i] = $basedirs[0];
      };
   } else {
      # $i is bigger than $number_of_servers
      if (defined $basedirs[$i] and $basedirs[$i] ne '') {
         say("WARN: \$basedirs[$i] is defined and ne ''. Setting it to undef.");
         $basedirs[$i] = undef;
      };
   }
}
Auxiliary::print_list("INFO: Final RQG basedirs ", @basedirs);
foreach my $i (0..3) {
   if ((defined $basedirs[$i] and $basedirs[$i] ne '') and 
       (not -d $basedirs[$i])                             ) {
      say("ERROR: $basedirs[$i] is defined and ne '' but does not exist or is not a directory.");
      exit STATUS_ENVIRONMENT_FAILURE;
   }
}
# if ($upgrade_test and $basedirs[2] eq '') {
#    $basedirs[2] = $basedirs[0];
#    say("DEBUG: Setting basedirs[2] to basedirs[0] : $basedirs[0]");
# }

# Other semantics ?
# $vardirs[0] set == The RQG runner creates and destroys the required vardirs as subdirs below $vardirs[0].
# $vardirs[>0] set == The RQG runner will use that vardir. Create/destroy would be ok but what if start-dirty?
# rmtree or not? What if somebody assigns some valuable dir?
if (not defined $vardirs[0] or $vardirs[0] eq '') {
   say("INFO: 'vardirs' is not defined or eq ''. But we need some vardir for the RQG run and its servers.");
   $vardirs[0] = $workdir . "/vardir";
   say("INFO: Setting 'vardirs' to its default '$vardirs[0]'.");
   if(-d $vardirs[0]) {
      if(not File::Path::rmtree($vardirs[0])) {
         say("ERROR: Removal of the tree '$vardirs[0]' failed. : $!. " .
             "Will exit with STATUS_ENVIRONMENT_FAILURE");
         exit STATUS_ENVIRONMENT_FAILURE ;
      }
      say("DEBUG: The already existing RQG vardir '$vardirs[0]' was removed.");
   }
   if (mkdir $vardirs[0]) {
      say("DEBUG: The RQG vardir '$vardirs[0]' was created.");
   } else {
      say("ERROR: Creating the RQG vardir '$vardirs[0]' failed : $!. " .
          "Will exit with STATUS_ENVIRONMENT_FAILURE");
   }
}
foreach my $number (1..$number_of_servers) {
   $vardirs[$number] = $vardirs[0] . '/' . $number;
}
Auxiliary::print_list("INFO: Final RQG vardirs ",  @vardirs);


# We need a directory where the RQG run could store temporary files and do that by setting
# the environment variable TMP to some directory which is specific for the RQG run
# before (REQUIRED) calling GenTest the first time.
# So we go with TMP=$vardirs[0]
# - This is already set. --> No extra command line parameter required.
# - It gets destroyed (if already existing) and than created at begin of the test.
#   --> No chance to accidently process files of some finished test missing cleanup.
# - In case $vardirs[0] is unique to the RQG run
#      Example:
#      Smart tools causing <n> concurrent RQG runs could go with generating a timestamp first.
#      vardir of tool run = /dev/shm/vardir/<timestamp>
#         in case that directory already exists sleep 1 second and try again.
#      vardir of first RQG runner = /dev/shm/vardir/<timestamp>/1
#      vardir of n'th  RQG runner = /dev/shm/vardir/<timestamp>/<n>
#   than clashes with concurrent RQG runs are nearly impossible.
# - In case of a RQG failing we archive the vardir of the RQG runner and the maybe valuable
#   temporary files (dumps?) are already included.
# - In case we destroy the RQG run vardir at test end than all the temporary files are gone.
#   --> free space in some maybe small filesystem like a tmpfs
#   --> no pollution of '/tmp' with garbage laying there around for months
# - No error prone addition of process pids to file names.
#   Pids will repeat sooner or later. And maybe a pice of code forgets to add the pid.
#
# if (not defined $vardirs[0]) {
#    say("ALARM: \$vardirs[0] is not defined. Abort");
#    exit STATUS_INTERNAL_ERROR;
# }

# Put into environment so that child processes will compute via GenTest.pm right.
$ENV{'TMP'} = $vardirs[0];
# Modify direct so that we get rid of crap values.
settmpdir($vardirs[0]);
   
## Make sure that "default" values ([0]) are also set, for compatibility,
## in case they are used somewhere
#$basedirs[0] ||= $basedirs[1];
#$vardirs[0]  ||= $vardirs[1];
#Auxiliary::print_list("INFO: Now 1 RQG vardirs ",  @vardirs);
#Auxiliary::print_list("INFO: Now 1 RQG basedirs ",  @basedirs);

# Now sort out other options that can be set differently for different servers:
# - mysqld_options
# - debug_server
# - views
# - engine
# values[0] are those that are applied to all servers.
# values[N] expand or override values[0] for the server N

@{$mysqld_options[0]} = () if not defined $mysqld_options[0];
push @{$mysqld_options[0]}, "--sql-mode=no_engine_substitution" if join(' ', @ARGV_saved) !~ m{sql-mode}io;

# FIXME: Clean up/make more safe
foreach my $i (1..3) {
            @{$mysqld_options[$i]} = ( defined $mysqld_options[$i]
            ? ( @{$mysqld_options[0]}, @{$mysqld_options[$i]} )
            : @{$mysqld_options[0]}
   );
   $debug_server[$i] = $debug_server[0] if not defined $debug_server[$i] or $debug_server[$i] eq '';
   $vcols[$i]        = $vcols[0]        if not defined $vcols[$i]        or $vcols[$i]        eq '';
   $views[$i]        = $views[0]        if not defined $views[$i]        or $views[$i]        eq '';
   $engine[$i]       = $engine[0]       if not defined $engine[$i]       or $engine[$i]       eq '';
}

shift @mysqld_options;
shift @debug_server;
shift @vcols;
shift @views;
shift @engine;

#foreach my $dir (cwd(), @basedirs) {
## calling bzr usually takes a few seconds...
#    if (defined $dir) {
#        my $bzrinfo = GenTest::BzrInfo->new(
#            dir => $dir
#        );
#        my $revno = $bzrinfo->bzrRevno();
#        my $revid = $bzrinfo->bzrRevisionId();
#
#        if ((defined $revno) && (defined $revid)) {
#            say("$dir Revno: $revno");
#            say("$dir Revision-Id: $revid");
#        } else {
#            say($dir.' does not look like a bzr branch, cannot get revision info.');
#        }
#    }
#}

my $client_basedir;

foreach my $path ("$basedirs[0]/client/RelWithDebInfo",
                  "$basedirs[0]/client/Debug",
                  "$basedirs[0]/client", "$basedirs[0]/bin") {
   if (-e $path) {
      $client_basedir = $path;
      last;
   }
}

# Originally it was done in Gendata, but we want the same seed for all components

if (defined $seed and $seed eq 'time') {
   $seed = time();
   say("Converted --seed=time to --seed=$seed");
}

my $cmd = $0 . " " . join(" ", @ARGV_saved);
$cmd =~ s/seed=time/seed=$seed/g;
say("INFO: Final command line: \nperl $cmd");


my $cnf_array_ref;

if ($genconfig) {
   unless (-e $genconfig) {
      croak("ERROR: Specified config template '$genconfig' does not exist");
   }
   $cnf_array_ref = GenTest::App::GenConfig->new(spec_file => $genconfig,
                                                 seed      => $seed,
                                                 debug     => $debug
   );
}

#
# Start servers.
#

my @server;
my $rplsrv;

say("DEBUG: rpl_mode is '$rpl_mode'");
if ((defined $rpl_mode and $rpl_mode ne Auxiliary::RQG_RPL_NONE) and 
    (($rpl_mode eq Auxiliary::RQG_RPL_STATEMENT)        or
     ($rpl_mode eq Auxiliary::RQG_RPL_STATEMENT_NOSYNC) or
     ($rpl_mode eq Auxiliary::RQG_RPL_MIXED)            or
     ($rpl_mode eq Auxiliary::RQG_RPL_MIXED_NOSYNC)     or
     ($rpl_mode eq Auxiliary::RQG_RPL_ROW)              or
     ($rpl_mode eq Auxiliary::RQG_RPL_ROW_NOSYNC)         )) {

   say("DEBUG: We run with MariaDB replication");
                                               
   $rplsrv = DBServer::MySQL::ReplMySQLd->new(
                 master_basedir      => $basedirs[1],
                 slave_basedir       => $basedirs[2],
                 master_vardir       => $vardirs[1],
                 debug_server        => $debug_server[1],
                 master_port         => $ports[0],
                 slave_vardir        => $vardirs[2],
                 slave_port          => $ports[1],
                 mode                => $rpl_mode,
                 server_options      => $mysqld_options[1],
                 valgrind            => $valgrind,
                 valgrind_options    => \@valgrind_options,
                 general_log         => 1,
                 start_dirty         => $start_dirty, # This will not work for the first start. (vardir is empty)
                 use_gtid            => $use_gtid,
                 config              => $cnf_array_ref,
                 user                => $user
   );

   my $status = $rplsrv->startServer();

   if ($status > DBSTATUS_OK) {
      stopServers($status);
      if (osWindows()) {
         say(system("dir ".unix2winPath($rplsrv->master->datadir)));
         say(system("dir ".unix2winPath($rplsrv->slave->datadir)));
      } else {
         say(system("ls -l ".$rplsrv->master->datadir));
         say(system("ls -l ".$rplsrv->slave->datadir));
      }
      croak("Could not start replicating server pair");
    }

    $dsns[0]   = $rplsrv->master->dsn($database,$user);
    $dsns[1]   = undef; ## passed to gentest. No dsn for slave!
    $server[0] = $rplsrv->master;
    $server[1] = $rplsrv->slave;

} elsif (defined $galera and $galera ne '') {

   if (osWindows()) {
      croak("Galera is not supported on Windows (yet)");
   }

   unless ($galera =~ /^[ms]+$/i) {
      # maybe FIXME: Replace the damned croak
      croak ("--galera option should contain a combination of M and S, indicating masters and slaves");
   }

   $rplsrv = DBServer::MySQL::GaleraMySQLd->new(
        basedir            => $basedirs[0],
        parent_vardir      => $vardirs[0],
        debug_server       => $debug_server[1],
        first_port         => $ports[0],
        server_options     => $mysqld_options[1],
        valgrind           => $valgrind,
        valgrind_options   => \@valgrind_options,
        general_log        => 1,
        start_dirty        => $start_dirty,
        node_count         => length($galera)
   );

   my $status = $rplsrv->startServer();

   if ($status > DBSTATUS_OK) {
       stopServers($status);

       sayError("Could not start Galera cluster");
       exit_test(STATUS_ENVIRONMENT_FAILURE);
   }

   my $galera_topology = $galera;
   my $i = 0;
   while ($galera_topology =~ s/^(\w)//) {
       if (lc($1) eq 'm') {
          $dsns[$i] = $rplsrv->nodes->[$i]->dsn($database,$user);
       }
       $server[$i] = $rplsrv->nodes->[$i];
       $i++;
   }

} elsif (defined $upgrade_test) {

   say("DEBUG: We are running an upgrade test.");

   # There are 'normal', 'crash', 'recovery' and 'undo' modes.
   # 'normal' will be used by default
   $upgrade_test= 'normal' if $upgrade_test !~ /(?:crash|undo|recovery)/i;

   $upgrade_test= lc($upgrade_test);

   # recovery is an alias for 'crash' test when the basedir before and after is the same
   # undo-recovery is an alias for 'undo' test when the basedir before and after is the same
   if ($upgrade_test =~ /recovery/) {
      $basedirs[2] = $basedirs[1] = $basedirs[0];
   }
   if ($upgrade_test =~ /undo/ and not $restart_timeout) {
      $restart_timeout= int($duration/2);
   }

   # server0 is the "old" server (before upgrade).
   # We will initialize and start it now
   $server[0] = DBServer::MySQL::MySQLd->new(basedir          => $basedirs[1],
                                             vardir           => $vardirs[1],
                                             debug_server     => $debug_server[0],
                                             port             => $ports[0],
                                             start_dirty      => $start_dirty,
                                             valgrind         => $valgrind,
                                             valgrind_options => \@valgrind_options,
                                             server_options   => $mysqld_options[0],
                                             general_log      => 1,
                                             config           => $cnf_array_ref,
                                             user             => $user);

   my $status = $server[0]->startServer;

   if ($status > DBSTATUS_OK) {
      stopServers($status);
      if (osWindows()) {
            say(system("dir ".unix2winPath($server[0]->datadir)));
      } else {
            say(system("ls -l ".$server[0]->datadir));
      }
      sayError("Could not start the old server in the upgrade test");
      exit_test(STATUS_CRITICAL_FAILURE);
   }

   $dsns[0] = $server[0]->dsn($database,$user);

   if ((defined $dsns[0]) && (defined $engine[0])) {
      my $dbh = DBI->connect($dsns[0], undef, undef, { mysql_multi_statements => 1, RaiseError => 1 } );
      $dbh->do("SET GLOBAL default_storage_engine = '$engine[0]'");
   }

    # server1 is the "new" server (after upgrade).
    # We will initialize it, but won't start it yet
    $server[1] = DBServer::MySQL::MySQLd->new(basedir => $basedirs[2],
                                                       vardir => $vardirs[1], # Same vardir as for the first server!
                                                       debug_server => $debug_server[1],
                                                       port => $ports[0],     # Same port as for the first server!
                                                       start_dirty => 1,
                                                       valgrind => $valgrind,
                                                       valgrind_options => \@valgrind_options,
                                                       server_options => $mysqld_options[1],
                                                       general_log => 1,
                                                       config => $cnf_array_ref,
                                                       user => $user);

    $dsns[1] = $server[1]->dsn($database,$user);

} else {

   # "Simple" test with either
   # - one server
   # - two or three servers and checks maybe (some variants might be not yet supported) like
   #   a) same or different (origin like MariaDB, MySQL, versions like 10.1, 10.2) servers
   #      - show the same reaction (pass/fail) when running the same SQL statement
   #      - show logical the same result sets when running the same SELECTs
   #      - have finally the same content in user defined tables and similar
   #      Basically some RQG builtin statement based replication is used.
   #   b) same server binaries
   #      Show logical the same result sets when running some SELECT on the first server
   #      and transformed SELECTs on some other server
   #
   my $max_id = $number_of_servers - 1;
   say("DEBUG: max_id is $max_id");

   foreach my $server_id (0.. $max_id) {

      $server[$server_id] = DBServer::MySQL::MySQLd->new(
                               basedir            => $basedirs[$server_id+1],
                               vardir             => $vardirs[$server_id+1],
                               debug_server       => $debug_server[$server_id],
                               port               => $ports[$server_id],
                               start_dirty        => $start_dirty,
                               valgrind           => $valgrind,
                               valgrind_options   => \@valgrind_options,
                               server_options     => $mysqld_options[$server_id],
                               general_log        => 1,
                               config             => $cnf_array_ref,
                               user               => $user);

      if (not defined $server[$server_id]) {
         say("ERROR: Preparing the server[$server_id] for the start failed.");
         say("ERROR: Will call   exit_test(STATUS_ENVIRONMENT_FAILURE)  ");
         # sayError("Preparing the server[$server_id] for the start failed.");
         exit_test(STATUS_ENVIRONMENT_FAILURE);
      }

      my $status = $server[$server_id]->startServer;

      if ($status > DBSTATUS_OK) {
         stopServers($status);
         if (osWindows()) {
             say(system("dir ".unix2winPath($server[$server_id]->datadir)));
         } else {
             say(system("ls -l ".$server[$server_id]->datadir));
         }
         sayError("Could not start all servers");
         exit_test(STATUS_CRITICAL_FAILURE);
      }

      # FIXME: Isn't that questionable? We are in the non
      # MariaDB replication or Galera or Upgrade branch.
      # if (($server_id == 0) || ($rpl_mode eq Auxiliary::RQG_RPL_NONE) ) {
      $dsns[$server_id] = $server[$server_id]->dsn($database, $user);
      say("DEBUG: dsns[$server_id] defined.");

      if ((defined $dsns[$server_id]) && (defined $engine[$server_id] and $engine[$server_id] ne '')) {
         my $dbh = DBI->connect($dsns[$server_id], undef, undef, { mysql_multi_statements => 1, RaiseError => 1 } );
         $dbh->do("SET GLOBAL default_storage_engine = '$engine[$server_id]'");
      }
   }
}


#
# Wait for user interaction before continuing, allowing the user to attach
# a debugger to the server process(es).
# Will print a message and ask the user to press a key to continue.
# User is responsible for actually attaching the debugger if so desired.
#
if ($wait_debugger) {
   say("Pausing test to allow attaching debuggers etc. to the server process.");
   my @pids;   # there may be more than one server process
   foreach my $server_id (0..$#server) {
      $pids[$server_id] = $server[$server_id]->serverpid;
   }
   say('Number of servers started: ' . ($#server + 1));
   say('Server PID: ' .join(', ', @pids));
   say("Press ENTER to continue the test run...");
   my $keypress = <STDIN>;
}

#
# Run actual queries
#

my $gentestProps = GenTest::Properties->new(
    legal => ['grammar',
              'skip-recursive-rules',
              'dsn',
              'engine',
              'gendata',
              'gendata-advanced',
              'gendata_sql',
              'generator',
              'redefine',
              'threads',
              'queries',
              'duration',
              'help',
              'debug',
              'rpl_mode',
              'validators',
              'reporters',
              'transformers',
              'seed',
              'mask',
              'mask-level',
              'rows',
              'varchar-length',
              'xml-output',
              'vcols',
              'views',
              'start-dirty',
              'filter',
              'notnull',
              'short_column_names',
              'strict_fields',
              'freeze_time',
              'valgrind',
              'valgrind-xml',
              'testname',
              'sqltrace',
              'querytimeout',
              'report-xml-tt',
              'report-xml-tt-type',
              'report-xml-tt-dest',
              'logfile',
              'logconf',
              'debug_server',
              'report-tt-logdir',
              'servers',
              'multi-master',
              'annotate-rules',
              'restart-timeout',
              'upgrade-test',
              'ps-protocol'
]
    );

## For backward compatability
if ($#validators == 0 and $validators[0] =~ m/,/) {
    @validators = split(/,/,$validators[0]);
}

## For backward compatability
if ($#reporters == 0 and $reporters[0] =~ m/,/) {
    @reporters = split(/,/,$reporters[0]);
}

## For backward compatability
if ($#transformers == 0 and $transformers[0] =~ m/,/) {
    @transformers = split(/,/,$transformers[0]);
}

## For uniformity
if ($#redefine_files == 0 and $redefine_files[0] =~ m/,/) {
    @redefine_files = split(/,/,$redefine_files[0]);
}

if ($#gendata_sql_files == 0 and $gendata_sql_files[0] =~ m/,/) {
    @gendata_sql_files = split(/,/,$gendata_sql_files[0]);
}

$gentestProps->property('generator','FromGrammar') if not defined $gentestProps->property('generator');

$gentestProps->property('start-dirty',1) if defined $start_dirty;
$gentestProps->gendata($gendata) unless defined $skip_gendata;
$gentestProps->property('gendata-advanced',1) if defined $gendata_advanced;
$gentestProps->gendata_sql(\@gendata_sql_files) if @gendata_sql_files;
$gentestProps->engine(\@engine) if @engine;
# $gentestProps->rpl_mode($rpl_mode) if defined $rpl_mode;
$gentestProps->rpl_mode($rpl_mode);
$gentestProps->validators(\@validators) if @validators;
$gentestProps->reporters(\@reporters) if @reporters;
$gentestProps->transformers(\@transformers) if @transformers;
$gentestProps->threads($threads) if defined $threads;
$gentestProps->queries($queries) if defined $queries;
$gentestProps->duration($duration) if defined $duration;
$gentestProps->dsn(\@dsns) if @dsns;
$gentestProps->grammar($grammar_file);
$gentestProps->property('skip-recursive-rules', $skip_recursive_rules);
$gentestProps->redefine(\@redefine_files) if @redefine_files;
$gentestProps->seed($seed) if defined $seed;
$gentestProps->mask($mask) if (defined $mask) && (not defined $no_mask);
$gentestProps->property('mask-level',$mask_level) if defined $mask_level;
$gentestProps->rows($rows) if defined $rows;
$gentestProps->vcols(\@vcols) if @vcols;
$gentestProps->views(\@views) if @views;
$gentestProps->property('varchar-length',$varchar_len) if defined $varchar_len;
$gentestProps->property('xml-output',$xml_output) if defined $xml_output;
$gentestProps->debug(1) if defined $debug;
$gentestProps->filter($filter) if defined $filter;
$gentestProps->notnull($notnull) if defined $notnull;
$gentestProps->short_column_names($short_column_names) if defined $short_column_names;
$gentestProps->strict_fields($strict_fields) if defined $strict_fields;
$gentestProps->freeze_time($freeze_time) if defined $freeze_time;
$gentestProps->valgrind(1) if $valgrind;
$gentestProps->property('ps-protocol',1) if $ps_protocol;
$gentestProps->sqltrace($sqltrace) if $sqltrace;
$gentestProps->querytimeout($querytimeout) if defined $querytimeout;
$gentestProps->testname($testname) if $testname;
$gentestProps->logfile($logfile) if defined $logfile;
$gentestProps->logconf($logconf) if defined $logconf;
$gentestProps->property('report-tt-logdir',$report_tt_logdir) if defined $report_tt_logdir;
$gentestProps->property('report-xml-tt', 1) if defined $report_xml_tt;
$gentestProps->property('report-xml-tt-type', $report_xml_tt_type) if defined $report_xml_tt_type;
$gentestProps->property('report-xml-tt-dest', $report_xml_tt_dest) if defined $report_xml_tt_dest;
$gentestProps->property('restart-timeout', $restart_timeout) if defined $restart_timeout;
# In case of multi-master topology (e.g. Galera with multiple "masters"),
# we don't want to compare results after each query.
# Instead, we want to run the flow independently and only compare dumps at the end.
# If GenTest gets 'multi-master' property, it won't run ResultsetComparator
$gentestProps->property('multi-master', 1) if (defined $galera and scalar(@dsns)>1);
# Pass debug server if used.
$gentestProps->debug_server(\@debug_server) if @debug_server;
$gentestProps->servers(\@server) if @server;
$gentestProps->property('annotate-rules',$annotate_rules) if defined $annotate_rules;
$gentestProps->property('upgrade-test',$upgrade_test) if $upgrade_test;


# Push the number of "worker" threads into the environment.
# lib/GenTest/Generator/FromGrammar.pm will generate a corresponding grammar element.
$ENV{RQG_THREADS}= $threads;

my $gentest = GenTest::App::GenTest->new(config => $gentestProps);
$return = Auxiliary::set_rqg_phase($workdir, 'gendata');
$return = Auxiliary::set_rqg_phase($workdir, 'gentest');

#
# Perform the GenTest run
#
my $gentest_result = $gentest->run();

say("GenTest returned status " . status2text($gentest_result) . " ($gentest_result)");
my $final_result = $gentest_result;

# If Gentest produced any failure then exit with its failure code,
# otherwise if the test is replication/with two servers compare the
# server dumps for any differences else if there are no failures exit with success.

if (($gentest_result == STATUS_OK)                       and
    ($number_of_servers > 1 or $number_of_servers == 0)  and # 0 is Galera
    (not defined $upgrade_test or $upgrade_test eq '') and   
    ($rpl_mode ne Auxiliary::RQG_RPL_STATEMENT_NOSYNC)   and
    ($rpl_mode ne Auxiliary::RQG_RPL_MIXED_NOSYNC)       and
    ($rpl_mode ne Auxiliary::RQG_RPL_ROW_NOSYNC)            ) {

#
# Compare master and slave, or all masters
#
   my $diff_result = STATUS_OK;
   if ($rpl_mode ne '') {
      $diff_result = $rplsrv->waitForSlaveSync;
      if ($diff_result != STATUS_OK) {
         # FIXME: Shouldn't that be rather STATUS_REPLICATION_FAILURE or similar?
         # But we get only DBSTATUS_FAILURE or DBSTATUS_OK returned!
         say("ERROR: waitForSlaveSync failed with $diff_result. Setting final_result to STATUS_REPLICATION_FAILURE.");
         $final_result = STATUS_REPLICATION_FAILURE ;
      }
      # FIXME:
      # waitForSlaveSync with success does not reveal that the data content of master and
      # slave is in sync like wanted. Just the processing chain behaved like wished.
   } else {
      # We run with RQG builtin statement based replication.
      my @dump_files;
      foreach my $i (0..$#server) {
         # FIXME: Why the appended pid '$$'?
         # Any server needs his own exlusive dumpfile. This is ensured by the '$i'.
         # As soon as the caller takes care that any running rqg.pl uses his own exclusive
         # $rqg_vardir and $rqg_wordir + dumpfiles in $rqg_vardir it must be clash free.
         $dump_files[$i] = tmpdir()."server_".abs($$)."_".$i.".dump";
         # FIXME: 1. There could be more user defined schemas than 'test'.
         #        2. What about other user defined objects like views , users, ....?
         my $dump_result = $server[$i]->dumpdb($database,$dump_files[$i]);
         if ( $dump_result > 0 ) {
            $final_result = $dump_result >> 8;
            last;
         }
      }
      if ($final_result == STATUS_OK) {
         say("INFO: Comparing SQL dumps...");
         foreach my $i (1..$#server) {
            ### 0 vs. 1 , 1 vs. 2 ...
            ### my $diff = system("diff -u $dump_files[$i - 1] $dump_files[$i]");
            ### The IMHO better solution: 0 vs. 1 , 0 vs. 2 , 0 vs. 3
            my $diff = system("diff -u $dump_files[0] $dump_files[$i]");
            if ($diff == STATUS_OK) {
               say("No differences were found between servers 0 and $i.");
               # Make free space as soon ass possible.
               say("DEBUG: Deleting the dump file of server $i.");
               unlink($dump_files[$i]);
            } else {
               sayError("Found differences between servers 0 and $i. Setting final_result " .
                        "to STATUS_CONTENT_MISMATCH");
               $diff_result  = STATUS_CONTENT_MISMATCH;
               $final_result = $diff_result;
            }
         }
      }
      # FIXME: unlink even if $diff_result > 0?
      foreach my $dump_file (@dump_files) {
         unlink($dump_file);
      }
   }
}

say("The RQG run ended with status " . status2text($final_result) . " ($final_result)");

stopServers($final_result);

$return = Auxiliary::set_rqg_phase($workdir, 'analyze');
if (not defined $return) {
   say("FIXME: setting the phase failed. Handle that");
}

# GenTest exited with exit status STATUS_OK (0)
# say("MLML ==>" . $logfile . "<==");
my $content = Auxiliary::getFileSlice($logfile, 100000000);
if (not defined $content) {
   say("FIXME: No content got. Handle that");
} else {
   # say("DEBUG: Auxiliary::getFileSlice got content");
}

# ATTENTION: We need to access the output of the current RQG runner.
# 2. Find a way for intelligent binary preserving
my $maybe_archive = 1;
my $maybe_match   = 1;
# say("DEBUG: maybe_archive : $maybe_archive, maybe_match : $maybe_match");
my $p_match = Auxiliary::status_matching($content, \@blacklist_statuses   ,
                                         'The RQG run ended with status ', 'Blacklist statuses', 1);
if ($p_match eq Auxiliary::MATCH_YES) {
   $maybe_match   = 0;
   $maybe_archive = 0;
}
# say("DEBUG: maybe_archive : $maybe_archive, maybe_match : $maybe_match");
my $p_match = Auxiliary::content_matching ($content, \@blacklist_patterns ,
                                           'Blacklist text patterns', 1);
if ($p_match eq Auxiliary::MATCH_YES) {
   $maybe_match   = 0;
   $maybe_archive = 0;
}
# say("DEBUG: maybe_archive : $maybe_archive, maybe_match : $maybe_match");
if ($maybe_archive == 1) {
   $p_match = Auxiliary::status_matching($content, \@whitelist_statuses   ,
                                         'The RQG run ended with status ', 'Whitelist statuses', 1);
   if ($p_match ne Auxiliary::MATCH_YES) {
      $maybe_match   = 0;
   }
   $p_match = Auxiliary::content_matching ($content, \@whitelist_patterns ,
                                           'Whitelist text patterns', 1);
   if ($p_match ne Auxiliary::MATCH_YES) {
      $maybe_match   = 0;
   }
}
say("DEBUG: maybe_archive : $maybe_archive, maybe_match : $maybe_match");
# say("DEBUG: Previous verdict: " . Auxiliary::get_rqg_verdict($workdir));
my $verdict = Auxiliary::RQG_VERDICT_INIT;
if ($maybe_match) {
   $verdict = Auxiliary::RQG_VERDICT_REPLAY;
} elsif ($maybe_archive) {
   # No match
   $verdict = Auxiliary::RQG_VERDICT_INTEREST;
} else {
   # No match
   # No interest
   $verdict = Auxiliary::RQG_VERDICT_IGNORE;
}

say("VERDICT: $verdict");
my $result = Auxiliary::set_final_rqg_verdict($workdir, $verdict);
if ($result != STATUS_OK) {
   say("ERROR: In Auxiliary::set_final_rqg_verdict");
}

if ($verdict ne Auxiliary::RQG_VERDICT_IGNORE) {
   $return = Auxiliary::set_rqg_phase($workdir, Auxiliary::RQG_PHASE_ARCHIVING);
   if ($result != STATUS_OK) {
      say("ERROR: In Auxiliary::set_rqg_phase");
      say("FIXME: Handle that");
   }
   my $result = Auxiliary::archive_results($workdir, $vardirs[0]);
   say("INFO: Archive '" . $workdir . "/archive.tgz' created.");
   if(not File::Path::rmtree($vardirs[0])) {
      say("ERROR: Removal of the tree '$vardirs[0]' failed. : $!. " .
          "Will exit with STATUS_ENVIRONMENT_FAILURE");
      exit STATUS_ENVIRONMENT_FAILURE ;
   }
   say("DEBUG: The RQG vardir '$vardirs[0]' was removed.");
   system("ls -l $workdir");
   
   # my archiver_cmd = 
   # Archiving 
   # Partial clean up
} else {
   # Nearly full clean up
}
$return = Auxiliary::set_rqg_phase($workdir, Auxiliary::RQG_PHASE_COMPLETE);
if ($result != STATUS_OK) {
   say("ERROR: In Auxiliary::set_rqg_phase");
   say("FIXME: Handle that");
}




exit;

# $vardirs[0]




if ($final_result != STATUS_OK and $store_binaries) {
   foreach my $i ($#server) {
      my $file = $server[$i]->binary;
      my $to =   $vardirs[$i];
      say("HERE: trying to copy $file to $to");
      if (osWindows()) {
         system("xcopy \"$file\" \"".$to."\"") if -e $file and $to;
         $file =~ s/\.exe/\.pdb/;
         system("xcopy \"$file\" \"".$to."\"") if -e $file and $to;
      } else {
         system("cp $file " . $to) if -e $file and $to;
      }
   }
}
exit_test($final_result);

sub stopServers {
   # FIXME: What is the $status good for?
   my $status = shift;
   if ($skip_shutdown) {
      say("Server shutdown is skipped upon request");
      return;
   }
   say("Stopping server(s)...");
   if (($rpl_mode eq Auxiliary::RQG_RPL_STATEMENT) or
       ($rpl_mode eq Auxiliary::RQG_RPL_MIXED)     or
       ($rpl_mode eq Auxiliary::RQG_RPL_ROW)         ) {
      $rplsrv->stopServer($status);
   } elsif (defined $upgrade_test) {
      $server[1]->stopServer;
   } else {
      foreach my $srv (@server) {
         if ($srv) {
            $srv->stopServer;
         }
      }
   }
}


sub help {

    print <<EOF
Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.

$0 - Run a complete random query generation test, including server start with replication and master/slave verification

    Options related to one standalone MySQL server:

    --basedir   : Specifies the base directory of the stand-alone MySQL installation;
    --mysqld    : Options passed to the MySQL server
    --vardir    : vardir of the RQG run. The vardirs of the servers willl get created in it.
                  It is recommended to it depending on certain requirements to
                  - a RAM based filesystem like tmpfs (/dev/shm/vardir) -- high IO speed but small filesystem
                  - a non RAM based filesystem -- not that fast IO but usual big filesystem
                  The default \$workdir/vardir is frequent not that optimal.
    --debug-server: Use mysqld-debug server

    Options related to two MySQL servers

    --basedir1  : Specifies the base directory of the first MySQL installation;
    --basedir2  : Specifies the base directory of the second MySQL installation;
    --mysqld    : Options passed to both MySQL servers
    --mysqld1   : Options passed to the first MySQL server
    --mysqld2   : Options passed to the second MySQL server
    --debug-server1: Use mysqld-debug server for MySQL server1
    --debug-server2: Use mysqld-debug server for MySQL server2
    The options vardir1 and vardir2 are no more supported.            
    RQG places the vardirs of the servers inside of the vardir of the RQG run (see --vardir).

    General options

    --grammar   : Grammar file to use when generating queries (REQUIRED);
    --redefine  : Grammar file(s) to redefine and/or add rules to the given grammar
                  Write: --redefine='A B'    or    --redefine='A' --redefine='B'
    --rpl_mode  : Replication type to use (statement|row|mixed) (default: no replication).
                  The mode can contain modifier 'nosync', e.g. row-nosync. It means that at the end the test
                  will not wait for the slave to catch up with master and perform the consistency check
    --use_gtid  : Use GTID mode for replication (current_pos|slave_pos|no). Adds the MASTER_USE_GTID clause to CHANGE MASTER,
                  (default: empty, no additional clause in CHANGE MASTER command);
    --galera    : Galera topology, presented as a string of 'm' or 's' (master or slave).
                  The test flow will be executed on each "master". "Slaves" will only be updated through Galera replication
    --engine    : Table engine to use when creating tables with gendata (default no ENGINE in CREATE TABLE);
                  Different values can be provided to servers through --engine1 | --engine2 | --engine3
    --threads   : Number of threads to spawn (default $default_threads);
    --queries   : Number of queries to execute per thread (default $default_queries);
    --duration  : Duration of the test in seconds (default $default_duration seconds);
    --validator : The validators to use
    --reporter  : The reporters to use
    --transformer: The transformers to use (turns on --validator=transformer). Accepts comma separated list
    --querytimeout: The timeout to use for the QueryTimeout reporter
    --gendata   : Generate data option. Passed to gentest.pl / GenTest. Takes a data template (.zz file)
                  as an optional argument. Without an argument, indicates the use of GendataSimple (default)
    --gendata-advanced: Generate the data using GendataAdvanced instead of default GendataSimple
    --gendata_sql : Generate data option. Passed to gentest.pl / GenTest. Takes files with SQL as argument.
                    These files get processed after running Gendata, GendataSimple or GendataAdvanced.
    --logfile   : Generates rqg output log at the path specified.(Requires the module Log4Perl)
    --seed      : PRNG seed. Passed to gentest.pl
    --mask      : Grammar mask. Passed to gentest.pl
    --mask-level: Grammar mask level. Passed to gentest.pl
    --notnull   : Generate all fields with NOT NULL
    --rows      : No of rows. Passed to gentest.pl
    --sqltrace  : Print all generated SQL statements.
                  Optional: Specify --sqltrace=MarkErrors to mark invalid statements.
    --varchar-length: length of strings. passed to gentest.pl
    --xml-outputs: Passed to gentest.pl
    --vcols     : Types of virtual columns (only used if data is generated by GendataSimple or GendataAdvanced)
    --views     : Generate views. Optionally specify view type (algorithm) as option value. Passed to gentest.pl.
                  Different values can be provided to servers through --views1 | --views2 | --views3
    --valgrind  : Passed to gentest.pl
    --filter    : Passed to gentest.pl
    --mem       : Passed to mtr
    --mtr-build-thread:  Value used for MTR_BUILD_THREAD when servers are started and accessed
    --debug     : Debug mode
    --short_column_names: use short column names in gendata (c<number>)
    --strict_fields: Disable all AI applied to columns defined in \$fields in the gendata file. Allows for very specific column definitions
    --freeze_time: Freeze time for each query so that CURRENT_TIMESTAMP gives the same result for all transformers/validators
    --annotate-rules: Add to the resulting query a comment with the rule name before expanding each rule.
                      Useful for debugging query generation, otherwise makes the query look ugly and barely readable.
    --wait-for-debugger: Pause and wait for keypress after server startup to allow attaching a debugger to the server process.
    --restart-timeout: If the server has gone away, do not fail immediately, but wait to see if it restarts (it might be a part of the test)
    --upgrade-test : enable Upgrade reporter and treat server1 and server2 as old/new server, correspondingly. After the test flow
                     on server1, server2 will be started on the same datadir, and the upgrade consistency will be checked
    --workdir   : (optional) Workdir of this RQG run
                  Nothing assigned: We use the current working directory of the RQG runner process, certain files will be created.
                  Some directory assigned: We use the assigned directory and expect that certain files already exist.
    --help      : This help message

    If you specify --basedir1 and --basedir2 or --vardir1 and --vardir2, two servers will be started and the results from the queries
    will be compared between them.
EOF
    ;
    print "$0 arguments were: ".join(' ', @ARGV_saved)."\n";
    # exit_test(STATUS_UNKNOWN_ERROR);
}

sub exit_test {
   my $status = shift;
   stopServers($status);
   say("$0 will exit with exit status " . status2text($status) . "($status)");
   $return = Auxiliary::set_rqg_phase($workdir, 'complete');
   $return = Auxiliary::get_rqg_phase($workdir);
   safe_exit($status);
}

sub help_vardir {

   say("HELP: The vardir of the RQG run ('vardir').\n" .
       "      The vardirs of all database servers will be created as sub directories within that directory.\n" .
       "      Also certain dumps, temporary files (variable tmpdir in RQG code) etc. will be placed there.\n" .
       "      RQG tools and the RQG runners feel 'free' to destroy or create the vardir whenever they want.\n" .
       "      The parent directory of 'vardir' must exist in advance.\n" .
       "      The recommendation is to assign some directory placed on some filesystem which satisfies your needs.\n" .
       "      Example 1:\n" .
       "         Higher throughput and/or heavy loaded CPU cores gives better results.\n" .
       "         AND\n" .
       "         The RQG test does not consume much storage space during runtime.\n" .
       "         Use some vardir placed on a RAM based filesystem(tmpfs) like '/dev/shm/vardir'" .
       "      Example 2:\n" .
       "         Slow responding IO system gives better results.\n" .
       "         OR\n" .
       "         The RQG test does consume much storage space during runtime.\n" .
       "         Use some vardir placed on a hard disk based filesystem like <RQG workdir>/vardir\n".
       "      Default(sometimes sub optimal because test properties and your needs are not known to RQG)\n" .
       "         <RQG workdir>/vardir\n".
       "      Why is it no more supported to set the vardir<n> in the RQG call?\n".
       "      - Maximum safety against concurrent activity of other RQG and MTR tests could be only ".
       "        ensured if the RQG run uses vardirs for servers which are specific to the RQG run." .
       "        Just assume the ugly case that concurrent tests create/destroy/modify in <release>/mysql-test/var.\n" .
       "      - Creating/Archiving/Removing only one directory 'vardirs' only is easier.");
}

1;

