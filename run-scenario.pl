#!/usr/bin/perl

# Copyright (C) 2017 MariaDB Corporatin Ab
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

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
#use Carp;
use strict;
use GenTest;
#use GenTest::BzrInfo;
#use GenTest::Constants;
#use GenTest::Properties;
#use GenTest::App::GenTest;
#use GenTest::App::GenConfig;
#use DBServer::DBServer;
#use DBServer::MySQL::MySQLd;
#use DBServer::MySQL::ReplMySQLd;
#use DBServer::MySQL::GaleraMySQLd;
use Data::Dumper;

$| = 1;
#my $logger;
#eval
#{
#    require Log::Log4perl;
#    Log::Log4perl->import();
#    $logger = Log::Log4perl->get_logger('randgen.gentest');
#};

#$| = 1;
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

use Getopt::Long qw( :config pass_through );
use GenTest::Constants;
use GenTest::Scenario;
use GenTest::Scenario::Upgrade;
#use DBI;
#use Cwd;

#my ($gendata, @basedirs, @mysqld_options, @vardirs, $rpl_mode,
#    @engine, $help, $debug, @validators, @reporters, @transformers, 
#    $grammar_file, $skip_recursive_rules,
#    @redefine_files, $seed, $mask, $mask_level, $mem, $rows,
#    $varchar_len, $xml_output, $valgrind, @valgrind_options, @vcols, @views,
#    $start_dirty, $filter, $build_thread, $sqltrace, $testname,
#    $report_xml_tt, $report_xml_tt_type, $report_xml_tt_dest,
#    $notnull, $logfile, $logconf, $report_tt_logdir, $querytimeout, $no_mask,
#    $short_column_names, $strict_fields, $freeze_time, $wait_debugger, @debug_server,
#    $skip_gendata, $skip_shutdown, $galera, $use_gtid, $genconfig, $annotate_rules,
#    $restart_timeout, $gendata_advanced, $upgrade_test);

#my $gendata=''; ## default simple gendata
#my $genconfig=''; # if template is not set, the server will be run with --no-defaults

#my $threads = my $default_threads = 10;
#my $queries = my $default_queries = 100000000;
#my $duration = my $default_duration = 3600;

my $help;

# @{$sc_opts{mysqld}} is an array of scalars containing options provided via --mysqld=--..
# They will be applied to all servers in the scenario.
# They can be partially overridden by --mysqldX=-- options with identical names,
# where X is the server number. Those will be collected later

my %sc_opts;

my @ARGV_saved = @ARGV;
my $opt_result = GetOptions(
  'basedir=s' => \$sc_opts{basedir},
  'debug' => \$sc_opts{debug},
  'duration=i' => \$sc_opts{test_duration},
  'engine=s' => \$sc_opts{engine},
#  'genconfig:s' => \$sc_opts{genconfig},
  'gendata=s' => \$sc_opts{gendata},
  'grammar=s' => \$sc_opts{grammar},
  'help' => \$help,
  'mtr-build-thread|mtr_build_thread=i' => \$sc_opts{build_thread},
  'mysqld=s@' => \@{$sc_opts{mysqld}},
  'queries=s' => \$sc_opts{queries},
  'redefine=s' => \$sc_opts{redefine},
  'scenario=s' => \$sc_opts{scenario},
  'seed=s' => \$sc_opts{seed},
  'sqltrace:s' => \$sc_opts{sqltrace},
  'threads=i' => \$sc_opts{threads},
  'valgrind!'    => \$sc_opts{valgrind},
  'vardir=s' => \$sc_opts{vardir},
);

if ($help) {
  help();
  exit 0;
}

if (!$opt_result) {
  print STDERR "\nERROR: Error occured while reading options\n\n";
  exit 1;
}

if (!$sc_opts{scenario}) {
  print STDERR "\nERROR: Scenario is not defined\n\n";
  exit 1;
}

# Some options can be defined per server. Different scenarios
# can define them differently, here we just want to store all them
# and pass over to the scenario. Since we don't know how many servers
# the given scenario runs, it's impossible to put it all in GetOptions,
# thus we will parse them manually

foreach my $o (@ARGV) {
  if ($o =~ /^--(mysqld\d+)=(\S+)$/) {
    if (not defined $sc_opts{$1}) {
      @{$sc_opts{$1}}= ();
    }
    push @{$sc_opts{$1}}, $2;
  }
  elsif ($o =~ /^--([-_\w]+)=(\S+)$/) {
    $sc_opts{$1}= $2;
  }
  elsif ($o =~ /^--skip-([-_\w]+)$/) {
    $sc_opts{$1}= 0;
  }
  elsif ($o =~ /^([-_\w]+)$/) {
    $sc_opts{$1}= 1;
  }
}

if (not defined $sc_opts{basedir} and not defined $sc_opts{basedir1}) {
  print STDERR "\nERROR: Basedir is not defined\n\n";
  exit 1;
}
elsif (not defined $sc_opts{basedir}) {
  $sc_opts{basedir}= $sc_opts{basedir1};
}

if (not defined $sc_opts{vardir} and not defined $sc_opts{vardir1}) {
  print STDERR "\nERROR: Vardir is not defined\n\n";
  exit 1;
}
elsif (not defined $sc_opts{vardir}) {
  $sc_opts{vardir}= $sc_opts{vardir1};
}

say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));


# Calculate initial port based on MTR_BUILD_THREAD (MTR
#
if (not defined $sc_opts{build_thread}) {
  if (defined $ENV{MTR_BUILD_THREAD}) {
    $sc_opts{build_thread} = $ENV{MTR_BUILD_THREAD}
  } else {
    $sc_opts{build_thread} = DEFAULT_MTR_BUILD_THREAD;
  }
}

if ( $sc_opts{build_thread} eq 'auto' ) {
  say ("Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' (recommended) or unset it (will take the value ".DEFAULT_MTR_BUILD_THREAD.") ");
  exit (STATUS_ENVIRONMENT_FAILURE);
}

$sc_opts{port}= 10000 + 10 * $sc_opts{build_thread};
say("Base port: " . $sc_opts{port} . " MTR_BUILD_THREAD : " . $sc_opts{build_thread});

if (defined $sc_opts{seed} and $sc_opts{seed} eq 'time') {
  $sc_opts{seed}= time();
}

my $cmd = $0 . " " . join(" ", @ARGV_saved);
$cmd =~ s/seed=time/seed=$sc_opts{seed}/g;
say("Final command line: \nperl $cmd");

my $cnf_array_ref;

#if ($sc_opts{genconfig}) {
#  unless (-e $sc_opts{genconfig}) {
#    croak("ERROR: Specified config template $sc_opts{genconfig} does not exist");
#  }
#  $cnf_array_ref = GenTest::App::GenConfig->new(
#    spec_file => $sc_opts{genconfig},
#    seed => $sc_opts{seed},
#    debug => $sc_opts{debug}
#  );
#}

my $scenario= GenTest::Scenario::Upgrade->new(
    properties => \%sc_opts,
    type => 'normal'
);
my $status= $scenario->run();

exit_test($status);

sub exit_test {
  my $status = shift;
  say("[$$] $0 will exit with exit status ".status2text($status). " ($status)");
  safe_exit($status);
}
