#!/usr/bin/perl

# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab
# Copyright (c) 2017, MariaDB Corporation Ab
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

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use Switch;
use strict;
use GenTest;
use GenTest::BzrInfo;
use GenTest::Constants;
use GenTest::Properties;
use GenTest::App::GenTest;
use GenTest::App::GenConfig;
use DBServer::DBServer;
use DBServer::MySQL::MySQLd;
use DBServer::MySQL::ReplMySQLd;
use DBServer::MySQL::GaleraMySQLd;

my $logger;
eval
{
    require Log::Log4perl;
    Log::Log4perl->import();
    $logger= Log::Log4perl->get_logger('randgen.gentest');
};

$| = 1;
if (osWindows()) {
    $SIG{CHLD}= "IGNORE";
}

if (defined $ENV{RQG_HOME}) {
    if (osWindows()) {
        $ENV{RQG_HOME}= $ENV{RQG_HOME}.'\\';
    } else {
        $ENV{RQG_HOME}= $ENV{RQG_HOME}.'/';
    }
}

use Getopt::Long;
Getopt::Long::Configure("pass_through");
use GenTest::Constants;
use DBI;
use Cwd;

my $database= 'test';
my $user= 'rqg';

my ($gendata, $rpl_mode,
    @engine, $help, $debug, @validators, @reporters, @transformers, 
    $skip_recursive_rules,
    @redefine_files, $seed, $mask, $mask_level, $mem, $rows,
    $varchar_len, $xml_output, $valgrind, @valgrind_options,
    $start_dirty, $filter, $build_thread, $sqltrace, $testname,
    $report_xml_tt, $report_xml_tt_type, $report_xml_tt_dest,
    $notnull, $logfile, $logconf, $report_tt_logdir, $querytimeout, $no_mask,
    $short_column_names, $strict_fields, $freeze_time, $wait_debugger, @debug_server,
    $skip_gendata, $skip_shutdown, $galera, $use_gtid, $genconfig, $annotate_rules,
    $restart_timeout, $gendata_advanced, $upgrade_test, $rpl_topology);

my $gendata=''; ## default simple gendata
my $genconfig=''; # if template is not set, the server will be run with --no-defaults

my $threads = my $default_threads = 10;
my $queries = my $default_queries = 100000000;
my $duration = my $default_duration = 3600;

my @ARGV_saved = @ARGV;

GetOptions(
    'rpl_mode|rpl-mode=s' => \$rpl_mode,
    'skip-recursive-rules' > \$skip_recursive_rules,
    'redefine=s@' => \@redefine_files,
    'queries=s' => \$queries,
    'duration=i' => \$duration,
    'help' => \$help,
    'debug' => \$debug,
    'validators=s@' => \@validators,
    'reporters=s@' => \@reporters,
    'transformers=s@' => \@transformers,
    'gendata:s' => \$gendata,
    'gendata_advanced|gendata-advanced' => \$gendata_advanced,
    'skip_gendata|skip-gendata' => \$skip_gendata,
    'genconfig:s' => \$genconfig,
    'notnull' => \$notnull,
    'short_column_names' => \$short_column_names,
    'freeze_time' => \$freeze_time,
    'strict_fields' => \$strict_fields,
    'seed=s' => \$seed,
    'mask=i' => \$mask,
    'mask-level=i' => \$mask_level,
    'mem' => \$mem,
    'rows=s' => \$rows,
    'rpl_topology|rpl-topology|rpl=s' => \$rpl_topology,
    'varchar-length=i' => \$varchar_len,
    'xml-output=s'    => \$xml_output,
    'report-xml-tt'    => \$report_xml_tt,
    'report-xml-tt-type=s' => \$report_xml_tt_type,
    'report-xml-tt-dest=s' => \$report_xml_tt_dest,
    'restart_timeout|restart-timeout=i' => \$restart_timeout,
    'testname=s'        => \$testname,
    'valgrind!'    => \$valgrind,
    'valgrind_options=s@'    => \@valgrind_options,
    'wait_for_debugger|wait-for-debugger' => \$wait_debugger,
    'start_dirty|start-dirty'    => \$start_dirty,
    'filter=s'    => \$filter,
    'mtr-build-thread=i' => \$build_thread,
    'sqltrace:s' => \$sqltrace,
    'logfile=s' => \$logfile,
    'logconf=s' => \$logconf,
    'report-tt-logdir=s' => \$report_tt_logdir,
    'querytimeout=i' => \$querytimeout,
    'no-mask' => \$no_mask,
    'skip_shutdown|skip-shutdown' => \$skip_shutdown,
    'galera=s' => \$galera,
    'use-gtid=s' => \$use_gtid,
    'use_gtid=s' => \$use_gtid,
    'annotate_rules|annotate-rules' => \$annotate_rules,
    'upgrade_test|upgrade-test:s' => \$upgrade_test,
);

if ($help) {
    help();
    exit 0;
}


if (defined $logfile && defined $logger) {
    setLoggingToFile($logfile);
} else {
    if (defined $logconf && defined $logger) {
        setLogConf($logconf);
    }
}

# Now @ARGV should only contain options which relate to multiple servers,
# as described below

# We can have arbitrary number of servers.
# For each array, x[0] stands is default, and x[N] where N>0 belongs
# to the corresponging server
my @basedirs= ();
my @debug_servers= (); # TODO: remind me, what is it?
my @engines= ();
my @grammars= ();
my @mysqld_options= (); # array of arrays
my @threads= ();
my @vardirs= ();
my @vcols= ();
my @views= ();

# Find the highest server index from the options, it will be the number of our servers.
# And while we are at it, check that we don't have unknown options
# and populate the arrays above

# TODO: it can also be defined via rpl_topology (the highest server number in the topology)

my $num_servers= 0;
my $opt_result= 0;

foreach my $opt (@ARGV) {
    if ($opt =~ /^--(basedir|debug[-_]server|engine|grammar|mysqld|threads|vardir|vcols|views)(\d*)=?(.*)$/) {
        my ($nm, $num, $val)= ($1, $2, $3);
        $num ||= 0; # In case it was undefined
        $num_servers= $num if $num > $num_servers;
        switch ($nm) {
            case 'basedir'          { @basedirs[$nm]= $val }
            case /^debug[-_]server/ { @debug_servers[$nm]= $val }
            case 'engine'           { @engines[$nm]= $val }
            case 'grammar'          { @grammars[$nm]= $val }
            case 'mysqld'           { @{mysqld_options[$nm]} = ($mysqld_options[$nm] ? (@{$mysqld_options[$nm]}, $val) : ($val)) }
            case 'threads'          { @threads[$nm]= $val }
            case 'vardir'           { @vardirs[$nm]= $val }
            case 'vcols'            { @vcols[$nm]= $val }
            case 'views'            { @views[$nm]= $val }
        }
    } else {
        print STDERR "Unknown option: $opt\n";
        $opt_result= 1;
    }
}

if ($opt_result) {
    help();
    print "\nFATAL ERROR: option check failed, see errors above\n\n";
    exit 1;
} elsif (not $basedirs[0] and not $basedirs[1]) {
    print "\nFATAL ERROR: no servers have been defined, provide at least one of --basedir or --basedir1\n\n";
    exit 1;
}

if (not scalar(@grammars)) {
    print STDERR "\nFATAL ERROR: No grammar files are defined\n\n";
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
            say("Invalid value for --sqltrace option: '$sqltrace'");
            say("Valid values are: ".join(', ', keys(%sqltrace_legal_values)));
            say("No value means that default/plain sqltrace will be used.");
            exit(STATUS_ENVIRONMENT_FAILURE);
        }
    } else {
        # If no value is given, GetOpt will assign the value '' (empty string).
        # We interpret this as plain tracing (no marking of errors, prefixing etc.).
        # Better to use 1 instead of empty string for comparisons later.
        $sqltrace = 1;
    }
}

# TODO: replace with something more relevant
say("Copyright (c) 2010,2011 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.");
#say("Please see http://forge.mysql.com/wiki/Category:RandomQueryGenerator for more information on this test framework.");
say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

#
# Calculate master and slave ports based on MTR_BUILD_THREAD
#

if (not defined $build_thread) {
    if (defined $ENV{MTR_BUILD_THREAD}) {
        $build_thread = $ENV{MTR_BUILD_THREAD}
    } else {
        $build_thread = DEFAULT_MTR_BUILD_THREAD;
    }
}

if ( $build_thread eq 'auto' ) {
    say ("Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' (recommended) or unset it (will take the value ".DEFAULT_MTR_BUILD_THREAD.") ");
    exit (STATUS_ENVIRONMENT_FAILURE);
}

# num_servers contains the number of servers to be run. 
# Populate missing values for each server

my @ports= (10000 + 10 * $build_thread);

# TODO:
# make default values apply to server#1 automatically if only one server is running

foreach my $n (1..$num_servers) 
{
    # In general, every server should have a unique port.
    # Port numbers are shifted one value comparing to server numbers, e.g
    # server 1 runs on port 19300,
    # server 2 runs on port 19301, 
    # etc.
    # Baseport is 10000 + 10 * $build_thread (stored in $ports[0])
    $ports[$n]= $ports[0] + $n - 1;

    # We checked earlier that either basedir or basedir1 is populated.
    # We'll use them as a default value for basedir for all requested servers
    unless ($basedirs[$n]) {
        $basedirs[$n]= $basedirs[0] || $basedirs[1];
    }

    # Every server should have unique vardir.
    # If default vardir is provided in vardirs[0], we'll use it as a base
    # and create vardirs[0]/1 , vardirs[0]/2 etc.
    # Otherwise, if the location is not defined for a server, let's use 
    # basedir/mysql-test/var as it was before, and also create
    # basedir/mysql-test/var/1, basedir/mysql-test/var/2 etc.
    unless ($vardirs[$n]) {
        $vardirs[$n]= (defined $vardirs[0] ? "$vardirs[0]/$n" : "$basedirs[$n]/mysql-test/var/$n");
    }

    # For mysqld options, we will merge server-specific set with the default set.
    # Default set should go first, so that server-specific options would override default ones
    # if both were configured
    @{$mysqld_options[$n]}= ( ( $mysqld_options[0] ? @{$mysqld_options[0]} : () ), ( $mysqld_options[$n] ? @{$mysqld_options[$n]} : () ));

    # Grammar will only apply to the server if it's configured explicitly
    # (comparison tests will take care of it in their own way).
    #unless (defined $grammars[$n]) {
    #    $grammars[$n]= $grammars[0];
    #}

    # threads number is optional, it should only be set if a grammar is defined for the server
    if (defined $grammars[$n]) {
        $threads[$n] ||= $threads[0];
    }

    # Other values are simple: if they were defined for the server, use them,
    # Otherwise if the default is defined, use it, otherwise keep them unset
    
    unless (defined $debug_servers[$n]) {
        $debug_servers[$n]= $debug_servers[0];
    }
    unless (defined $engines[$n]) {
        $engines[$n]= $engines[0];
    }
    unless (defined $vcols[$n]) {
        $vcols[$n]= $vcols[0];
    }
    unless (defined $views[$n]) {
        $views[$n]= $views[0];
    }
}

# Now we can convert the numerous arrays into one mega-array of hashes,
# array element per server

my @server_settings= ();

foreach my $n (1..$#basedirs) {
    my %s= (
        'basedir' => $basedirs[$n],
        'debug' => $debug_servers[$n],
        'engines' => $engines[$n],
        'grammar' => $grammars[$n],
        'mysqld_options' => $mysqld_options[$n],
        'port' => $ports[$n],
        'threads' => $threads[$n],
        'vardir' => $vardirs[$n],
        'vcols' => $vcols[$n],
        'views' => $views[$n]
    );
    push @server_settings, {%s};
}

# TODO: print better
foreach my $n (0..$#server_settings) {
    say "Configuration for server $n:";
    my $s= $server_settings[$n];
    foreach my $sk (sort keys %{$s}) {
        say "    $sk : $s->{$sk}";
    }
}


say("MTR_BUILD_THREAD : $build_thread, server ports: @ports[1..$#ports]");

#push @{$mysqld_options[0]}, "--sql-mode=no_engine_substitution" if join(' ', @ARGV_saved) !~ m{sql-mode}io;

# TODO: Replace with Git Info
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

foreach my $path ("$basedirs[0]/client/RelWithDebInfo", "$basedirs[0]/client/Debug", "$basedirs[0]/client", "$basedirs[0]/bin") {
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
say("Final command line: \nperl $cmd");


my $cnf_array_ref;

if ($genconfig) {
    unless (-e $genconfig) {
        croak("ERROR: Specified config template $genconfig does not exist");
    }
    $cnf_array_ref = GenTest::App::GenConfig->new(spec_file => $genconfig,
                                               seed => $seed,
                                               debug => $debug
    );
}

#
# Start servers. Use rpl_alter if replication is needed.
#

my @server;
my $rplsrv;

# Unlike previous arrays, this one will be generated
my @dsns;


if ($rpl_topology ne '') {

    $rpl_topology= '1->2'; # TODO: make it configurable and check vs the number of servers!

# TODO: 
# Should start-dirty be here?
# debug_servers?
# config?
    $rplsrv = DBServer::MySQL::ReplMySQLd->new(servers => \@server_settings,
                                               topology => $rpl_topology,
                                               valgrind => $valgrind,
                                               valgrind_options => \@valgrind_options,
                                               general_log => 1,
                                               start_dirty => $start_dirty,
                                               use_gtid => $use_gtid,
                                               config => $cnf_array_ref,
                                               user => $user
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
    
    foreach my $n (1..$num_servers) {
        $server[$n]= $rplsrv->server->[$n];
        $dsns[$n]= $server[$n]->dsn($database,$user);
    }
    
} elsif ($galera ne '') {

    if (osWindows()) {
        croak("Galera is not supported on Windows (yet)");
    }

    unless ($galera =~ /^[ms]+$/i) {
        croak ("--galera option should contain a combination of M and S, indicating masters and slaves");
    }

    $rplsrv = DBServer::MySQL::GaleraMySQLd->new(
        basedir => $basedirs[0],
        parent_vardir => $vardirs[0],
        debug_server => $debug_server[1],
        first_port => $ports[0],
        server_options => $mysqld_options[1],
        valgrind => $valgrind,
        valgrind_options => \@valgrind_options,
        general_log => 1,
        start_dirty => $start_dirty,
        node_count => length($galera)
    );
    
    my $status = $rplsrv->startServer();
    
    if ($status > DBSTATUS_OK) {
        stopServers($status);

        say("ERROR: Could not start Galera cluster");
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

    # There are 'normal' and 'crash' modes.
    # 'normal' will be used by default
    $upgrade_test= 'normal' if $upgrade_test !~ /crash/i;
    $upgrade_test= lc($upgrade_test);

    # server0 is the "old" server (before upgrade).
    # We will initialize and start it now
    $server[0] = DBServer::MySQL::MySQLd->new(basedir => $basedirs[1],
                                                       vardir => $vardirs[1],
                                                       debug_server => $debug_server[0],
                                                       port => $ports[0],
                                                       start_dirty => $start_dirty,
                                                       valgrind => $valgrind,
                                                       valgrind_options => \@valgrind_options,
                                                       server_options => $mysqld_options[0],
                                                       general_log => 1,
                                                       config => $cnf_array_ref,
                                                       user => $user);

    my $status = $server[0]->startServer;

    if ($status > DBSTATUS_OK) {
        stopServers($status);
        if (osWindows()) {
            say(system("dir ".unix2winPath($server[0]->datadir)));
        } else {
            say(system("ls -l ".$server[0]->datadir));
        }
        say("ERROR: Could not start the old server in the upgrade test");
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

    foreach my $server_id (0..2) {
        next unless $basedirs[$server_id+1];
        
        $server[$server_id] = DBServer::MySQL::MySQLd->new(basedir => $basedirs[$server_id+1],
                                                           vardir => $vardirs[$server_id+1],
                                                           debug_server => $debug_server[$server_id],
                                                           port => $ports[$server_id],
                                                           start_dirty => $start_dirty,
                                                           valgrind => $valgrind,
                                                           valgrind_options => \@valgrind_options,
                                                           server_options => $mysqld_options[$server_id],
                                                           general_log => 1,
                                                           config => $cnf_array_ref,
                                                           user => $user);
        
        my $status = $server[$server_id]->startServer;
        
        if ($status > DBSTATUS_OK) {
            stopServers($status);
            if (osWindows()) {
                say(system("dir ".unix2winPath($server[$server_id]->datadir)));
            } else {
                say(system("ls -l ".$server[$server_id]->datadir));
            }
            say("ERROR: Could not start all servers");
            exit_test(STATUS_CRITICAL_FAILURE);
        }
        
        if ( ($server_id == 0) || ($rpl_mode eq '') ) {
            $dsns[$server_id] = $server[$server_id]->dsn($database,$user);
        }
    
        if ((defined $dsns[$server_id]) && (defined $engine[$server_id])) {
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
    say('Number of servers started: '.($#server+1));
    say('Server PID: '.join(', ', @pids));
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
              'upgrade-test'
]
    );

my @gentest_options;

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

$gentestProps->property('generator','FromGrammar') if not defined $gentestProps->property('generator');

$gentestProps->property('start-dirty',1) if defined $start_dirty;
$gentestProps->gendata($gendata) unless defined $skip_gendata;
$gentestProps->property('gendata-advanced',1) if defined $gendata_advanced;
$gentestProps->engine(\@engine) if @engine;
$gentestProps->rpl_mode($rpl_mode) if defined $rpl_mode;
$gentestProps->validators(\@validators) if @validators;
$gentestProps->reporters(\@reporters) if @reporters;
$gentestProps->transformers(\@transformers) if @transformers;
$gentestProps->threads($threads) if defined $threads;
$gentestProps->queries($queries) if defined $queries;
$gentestProps->duration($duration) if defined $duration;
$gentestProps->dsn(\@dsns) if @dsns;
$gentestProps->grammar(\@grammars);
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
my $gentest_result = $gentest->run();
say("GenTest exited with exit status ".status2text($gentest_result)." ($gentest_result)");

# If Gentest produced any failure then exit with its failure code,
# otherwise if the test is replication/with two servers compare the 
# server dumps for any differences else if there are no failures exit with success.

if (($gentest_result == STATUS_OK) && !$upgrade_test && ($rpl_mode || (defined $basedirs[2]) || (defined $basedirs[3]) || $galera)) {
#if (0) {
#
# Compare master and slave, or all masters
#
    my $diff_result = STATUS_OK;
    if ($rpl_mode ne '') {
        $diff_result = $rplsrv->waitForSlaveSync;
        if ($diff_result != STATUS_OK) {
            exit_test(STATUS_INTERNAL_ERROR);
        }
    }
  
    my @dump_files;
  
    foreach my $i (0..$#server) {
        $dump_files[$i] = tmpdir()."server_".abs($$)."_".$i.".dump";
      
        my $dump_result = $server[$i]->dumpdb($database,$dump_files[$i]);
        exit_test($dump_result >> 8) if $dump_result > 0;
    }
  
    say("Comparing SQL dumps...");
    
    foreach my $i (1..$#server) {
        my $diff = system("diff -u $dump_files[$i-1] $dump_files[$i]");
        if ($diff == STATUS_OK) {
            say("No differences were found between servers ".($i-1)." and $i.");
        } else {
            say("ERROR: found differences between servers ".($i-1)." and $i.");
            $diff_result = STATUS_CONTENT_MISMATCH;
        }
    }

    foreach my $dump_file (@dump_files) {
        unlink($dump_file);
    }
    exit_test($diff_result);
} else {
    # If test was not sucessfull or not rpl/multiple servers.
    exit_test($gentest_result);
}

sub stopServers {
    my $status = shift;
    if ($skip_shutdown) {
        say("Server shutdown is skipped upon request");
        return;
    }
    say("Stopping server(s)...");
    if ($rpl_mode ne '') {
        $rplsrv->stopServer($status);
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
    --vardir    : Optional. (default \$basedir/mysql-test/var);
    --debug-server: Use mysqld-debug server

    Options related to two MySQL servers

    --basedir1  : Specifies the base directory of the first MySQL installation;
    --basedir2  : Specifies the base directory of the second MySQL installation;
    --mysqld    : Options passed to both MySQL servers
    --mysqld1   : Options passed to the first MySQL server
    --mysqld2   : Options passed to the second MySQL server
    --debug-server1: Use mysqld-debug server for MySQL server1
    --debug-server2: Use mysqld-debug server for MySQL server2
    --vardir1   : Optional. (default \$basedir1/mysql-test/var);
    --vardir2   : Optional. (default \$basedir2/mysql-test/var);

    General options

    --grammar   : Grammar file to use when generating queries (REQUIRED);
    --redefine  : Grammar file(s) to redefine and/or add rules to the given grammar
    --rpl_mode  : Replication type to use (statement|row|mixed) (default: no replication);
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
    --help      : This help message

    If you specify --basedir1 and --basedir2 or --vardir1 and --vardir2, two servers will be started and the results from the queries
    will be compared between them.
EOF
    ;
    print "$0 arguments were: ".join(' ', @ARGV_saved)."\n";
#    exit_test(STATUS_UNKNOWN_ERROR);
}

sub exit_test {
    my $status = shift;
    stopServers($status);
    say("[$$] $0 will exit with exit status ".status2text($status). " ($status)");
    safe_exit($status);
}
