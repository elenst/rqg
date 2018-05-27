#  Copyright (c) 2018, MariaDB
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301  USA */
#

package Auxiliary;

# TODO:
# - Structure everything better.
# - Add missing routines
# - Decide about the relationship to the content of
#   lib/GenTest.pm, lib/DBServer/DBServer.pm, maybe more.
#   There are various duplicate routines like sayFile, tmpdir, ....
# - search for string (pid or whatever) after pattern before line end in some file
#


use GenTest::Constants;
use GenTest;
use File::Copy;
use Cwd;

# use constant STATUS_OK       => 0;
use constant STATUS_FAILURE    => 1; # Just the opposite of STATUS_OK

sub check_value_supported {

   my ($parameter, $value_list_ref, $assigned_value) = @_;

# Some testing code.
# --> The parameter name is not defined or ''.
# my $return = Auxiliary::check_value_supported (undef, ['A'] , 'iltis');
# --> The supported values for 'otto' are 'A'.
# my $return = Auxiliary::check_value_supported ('otto', ['A'] , 'iltis');
# --> The value assigned to the parameter 'otto' is not defined.
# my $return = Auxiliary::check_value_supported ('otto', ['A','B'] , undef);

   if (not defined $parameter or $parameter eq '') {
      Carp::cluck("INTERNAL ERROR: The parameter name is not defined or ''.");
      return INTERNAL_TOOL_ERROR;
   }
   if (not defined $value_list_ref) {
      Carp::cluck("INTERNAL ERROR: The value_list is not defined.");
      return INTERNAL_TOOL_ERROR;
   }
   if (not defined $assigned_value or $assigned_value eq '') {
      Carp::cluck("ERROR: The value assigned to the parameter '$parameter' is not defined.");
      # ???
      return INTERNAL_TOOL_ERROR;
   }

   my (@value_list) = @$value_list_ref;

   my $message1 = "ERROR: Configuration parameter '$parameter' : The assigned value ->" .
                  $assigned_value . "<- is not supported.";
   my $message2 = "ERROR: The supported values for '$parameter' are ";
   my $no_match = 0;

   # Problem: Pick right comparison operator depending on if the value is numeric or string.
   # Forward and backward comparison helps.
   foreach my $supported_value (@value_list) {
      if (    $assigned_value  =~ m{$supported_value}s
          and $supported_value =~ m{$assigned_value}s  ) {
         return STATUS_OK; # 0
      } else {
         if ($no_match == 0) {
            $message2 = $message2 . "'"   . $supported_value . "'";
            $no_match++;
         } else {
            $message2 = $message2 . ", '" . $supported_value . "'";
         }
      }
   }
   $message2 = $message2 . '.';
   say($message1);
   say($message2);

   return STATUS_FAILURE; # The opposite of STATUS_OK;

} # End of sub check_value_supported


sub append_string_to_file {

   my ($my_file, $my_string) = @_;
   if (not defined $my_file) {
      Carp::cluck("INTERNAL ERROR: The value for the file name is undef.");
      return STATUS_FAILURE;
   }
   if (not defined $my_string) {
      Carp::cluck("INTERNAL ERROR: The string to be appended to the file '$my_file' is undef.");
      return STATUS_FAILURE;
   }
   if (not -f $my_file) {
      Carp::cluck("INTERNAL ERROR: The file '$my_file' does not exist or is no plain file.");
      return STATUS_FAILURE;
   }
   if (not open (MY_FILE, '>>', $my_file)) {
      say("ERROR: Open file '>>$my_file' failed : $!");
      return STATUS_FAILURE;
   }
   if (not print MY_FILE $my_string) {
      say("ERROR: Print to file '$my_file' failed : $!");
      return STATUS_FAILURE;
   }
   if (not close (MY_FILE)) {
      say("ERROR: Close file '$my_file' failed : $!");
      return STATUS_FAILURE;
   }
   return STATUS_OK;
}


sub make_file {
   my ($my_file) = @_;
   if (not open (MY_FILE, '>', $my_file)) {
      say("ERROR: Open file '>$my_file' failed : $!");
      return STATUS_FAILURE;
   }
   if (not close (MY_FILE)) {
      say("ERROR: Close file '$my_file' failed : $!");
      return STATUS_FAILURE;
   }
   return STATUS_OK; # 0
}

sub make_rqg_infrastructure {
   my ($workdir) = @_;
   # say("DEBUG: Auxiliary::make_rqg_infrastructure workdir is '$workdir'");
   if (not -d $workdir) {
      say("ERROR: RQG workdir '$workdir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   my $my_file;
   my $result;
   $my_file = $workdir . '/rqg.log';
   $result  = make_file ($my_file);
   return $result if $result;
   $my_file = $workdir . '/rqg_phase.init';
   $result  = make_file ($my_file);
   return $result if $result;
   $my_file = $workdir . '/rqg_verdict.init';
   $result  = make_file ($my_file);
   return $result if $result;
   return STATUS_OK;
}

sub check_rqg_infrastructure {
   # We check the early/premade infrastructure.
   # The names of the files will change later.
   my ($workdir) = @_;
   # say("DEBUG: Auxiliary::make_rqg_infrastructure workdir is '$workdir'");
   if (not -d $workdir) {
      say("ERROR: RQG workdir '$workdir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   my $my_file;
   my $result;
   $my_file = $workdir . '/rqg.log';
   if (not -e $my_file) {
      say("ERROR: RQG file '$my_file' is missing.");
      return STATUS_FAILURE;
   }
   $my_file = $workdir . '/rqg_phase.init';
   if (not -e $my_file) {
      say("ERROR: RQG file '$my_file' is missing.");
      return STATUS_FAILURE;
   }
   $my_file = $workdir . '/rqg_verdict.init';
   if (not -e $my_file) {
      say("ERROR: RQG file '$my_file' is missing.");
      return STATUS_FAILURE;
   }
   return STATUS_OK;
}

sub rename_file {
   my ($source_file, $target_file) = @_;
   if (not -e $source_file) {
      Carp::cluck("ERROR: Auxiliary::rename_file The source file '$source_file' does not exist.");
      return STATUS_FAILURE;
   }
   if (-e $target_file) {
      Carp::cluck("ERROR: Auxiliary::rename_file The target file '$target_file' does already exist.");
      return STATUS_FAILURE;
   }
   # Perl documentation claims that
   # - "File::Copy::move" is platform independent
   # - "rename" is not and might have probems accross filesystem boundaries etc.
   # In addition I hope that the operation within the filesystem is roughly atomic
   # especially compared to whatever writes into some file.
   if (not move ($source_file , $target_file)) {
      # The move operation failed.
      Carp::cluck("ERROR: Auxiliary::rename_file '$source_file' to '$target_file' failed : $!");
      return STATUS_FAILURE;
   } else {
      # say("DEBUG: Auxiliary::rename_file '$source_file' to '$target_file'.");
      return STATUS_OK;
   }
}

use constant RQG_PHASE_INIT               => 'init';
use constant RQG_PHASE_START              => 'start';
use constant RQG_PHASE_GENDATA            => 'gendata';
use constant RQG_PHASE_GENTEST            => 'gentest';
use constant RQG_PHASE_ANALYZE            => 'analyze';
use constant RQG_PHASE_ARCHIVING          => 'archiving';
use constant RQG_PHASE_COMPLETE           => 'finished';
use constant RQG_PHASE_ALLOWED_VALUE_LIST => [
      RQG_PHASE_INIT, RQG_PHASE_START, RQG_PHASE_GENDATA, RQG_PHASE_GENTEST,
      RQG_PHASE_ANALYZE, RQG_PHASE_ARCHIVING, RQG_PHASE_COMPLETE
   ];

sub set_rqg_phase {
   my ($workdir, $new_phase) = @_;
   if (not -d $workdir) {
      say("ERROR: RQG workdir '$workdir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   if (not defined $new_phase or $new_phase eq '') {
      Carp::cluck("ERROR: Auxiliary::get_set_phase new_phase is either not defined or ''.");
      return STATUS_FAILURE;
   }
   my $result = Auxiliary::check_value_supported ('phase', RQG_PHASE_ALLOWED_VALUE_LIST,
                                                  $new_phase);
   if ($result != STATUS_OK) {
      Carp::cluck("ERROR: Auxiliary::check_value_supported returned $result. Will return that too.");
      return $result;
   }

   my $old_phase = '';
   foreach my $phase_value (@{&RQG_PHASE_ALLOWED_VALUE_LIST}) {
      if ($old_phase eq '') {
         my $file_to_try = $workdir . '/rqg_phase.' . $phase_value;
         if (-e $file_to_try) {
            $old_phase = $phase_value;
         }
      }
   }
   if ($old_phase eq '') {
      Carp::cluck("ERROR: Auxiliary::set_rqg_phase no rqg_phase file found.");
      return STATUS_FAILURE;
   }
   if ($old_phase eq $new_phase) {
      Carp::cluck("INTERNAL ERROR: Auxiliary::set_rqg_phase old_phase equals new_phase.");
      return STATUS_FAILURE;
   }

   $result = Auxiliary::rename_file ($workdir . '/rqg_phase.' . $old_phase,
                                     $workdir . '/rqg_phase.' . $new_phase);
   if ($result) {
      say("ERROR: Auxiliary::set_rqg_phase from '$old_phase' to '$new_phase' failed.");
      return STATUS_FAILURE;
   } else {
      say("PHASE: $new_phase");
      return STATUS_OK;
   }
}

sub get_rqg_phase {
# Return values:
# undef - $workdir not existing, phase file not found ==> RQG should abort later
# $phase_value - all ok
   my ($workdir) = @_;
   if (not -d $workdir) {
      say("ERROR: Auxiliary::get_rqg_phase : RQG workdir '$workdir' " .
          " is missing or not a directory. Will return undef.");
      return undef;
   }
   foreach my $phase_value (@{&RQG_PHASE_ALLOWED_VALUE_LIST}) {
      my $file_to_try = $workdir . '/rqg_phase.' . $phase_value;
      if (-e $file_to_try) {
         return $phase_value;
      }
   }
   # In case we reach this point than we have no phase file found.
   say("ERROR: Auxiliary::get_rqg_phase : No RQG phase file in directory '$workdir' found. " .
       "Will return undef.");
   return undef;
}


# For use in routines checking if some criterion (element in list) like
# - exit status achieved
# - pattern in whatever text found
#
# The pattern list was empty.
# Example:
#    blacklist_statuses are not defined.
#    == We focus on blacklist_patterns only.
use constant MATCH_NO_LIST_EMPTY   => 'match_no_list_empty';
#
# The pattern list was not empty but the text is obvious incomplete.
# Therefore a decision is impossible.
# Example:
#    The RQG run ended (abort or get killed) before having
#    - the work finished and
#    - a message about the exit status code written.
use constant MATCH_UNKNOWN         => 'match_unknown';
#
# The pattern list was not empty and one element matched.
# Examples:
# 1. whitelist_statuses has an element with STATUS_SERVER_CRASHED
#    and the RQG(GenTest) run finished with that status.
# 2. whitelist_patterns has an element with '<signal handler called>'
#    and the RQG log contains a snip of a backtrace with that.
use constant MATCH_YES             => 'match_yes';
#
# The pattern list was not empty, none of the elements matched and
# nothing looks interesting at all.
# Example:
#    whitelist_statuses has an element with STATUS_SERVER_CRASHED
#    and the RQG(GenTest) run finished with some other status.
#    But this other status is STATUS_OK.
use constant MATCH_NO              => 'match_no';
#
# The pattern list was not empty, none of the elements matched
# but the outcome looks interesting.
# Example:
#    whitelist_statuses has only one element like STATUS_SERVER_CRASHED
#    and the RQG(GenTest) run finished with some other status.
#    But this other status is bad too (!= STATUS_OK).
use constant MATCH_NO_BUT_INTEREST => 'match_no_but_interest';


sub content_matching {

# Purpose
# =======
#
# Search within $content for matches with elements within some list of
# text patterns.
#

   my ($content, $pattern_list, $message_prefix, $debug) = @_;

# Input parameters
# ================
#
# Parameter               | Explanation
# ------------------------+-------------------------------------------------------
# $content                | Some text with multiple lines to be processed.
#                         | Typical example: The protocol of a RQG run.
# ------------------------+-------------------------------------------------------
# $pattern_list           | List of pattern to search for within the text.
# ------------------------+-------------------------------------------------------
# $message_prefix         | Use it for making messages written by the current
#                         | routine more informative.
#                         | Some upper level caller routine knows more about the
#                         | for calling content_matching on low level.
# ------------------------+-------------------------------------------------------
# $debug                  | If the value is > 0 than the routine is more verbose.
#                         | Use it for debugging the curent routine, the caller
#                         | routine, unit tests and similar.
#
# Return values
# =============
#
# Return value            | state
# ------------------------+---------------------------------------------
# MATCH_NO                | There are elements defined but none matched.
# ('match_no')            |
# ------------------------+----------------------------------------
# MATCH_YES               | One element matched. Possibly remaining
# ('match_yes')           | elements will be not checked.     FIXME
# ------------------------+---------------------------------------------
# MATCH_NO_LIST_EMPTY     | There are no elements defined.
# ('match_no_list_empty') |
# ------------------------+---------------------------------------------
#
# Hint:
# The calling routines need frequent some rigorous Yes/No. Therefore they might
# twist the return value MATCH_NO_LIST_EMPTY.
# Example:
#    Whitelist maching : MATCH_NO_LIST_EMPTY -> MATCH_YES
#    Blacklist maching : MATCH_NO_LIST_EMPTY -> MATCH_NO
#

   my $no_pattern = 1;
   my $match      = 0;
   foreach my $pattern (@{$pattern_list}) {
      last if not defined $pattern;
      $no_pattern = 0;
      my $message = "$message_prefix element '$pattern' :";
      if ($content =~ m{$pattern}s) {
         if ($debug) { say("$message match"); };
         $match = 1;
      } else {
         if ($debug) { say("$message no match"); };
      }
   }
   if ($no_pattern == 1) {
      if ($debug) {
         say("$message_prefix : No elements defined.");
      }
      return MATCH_NO_LIST_EMPTY;
   } else {
      if ($match) {
         return MATCH_YES;
      } else {
         return MATCH_NO;
      }
   }

} # End sub content_matching

# ----------

sub status_matching {

   if (5 != scalar @_) {
      Carp::confess("INTERNAL ERROR: Auxiliary::status_matching : Five parameters " .
                    "are required.");
      # This accident could roughly only happen when coding RQG or its tools.
      # Already started servers need to be killed manually!
   }

# Input parameters
# ================
#
# Purpose
# =======
#
# Search within $content for matches with elements within some list of
# text patterns.
#

   my ($content, $pattern_list, $pattern_prefix, $message_prefix, $debug) = @_;

# Parameter               | Explanation
# ------------------------+-------------------------------------------------------
# $content                | Some text with multiple lines to be processed.
#                         | Typical example: The protocol of a RQG run.
# ------------------------+-------------------------------------------------------
# $pattern_list           | List of pattern to search for within the text.
# ------------------------+-------------------------------------------------------
# $pattern_prefix         | Some additional text before the pattern.
#                         | Example: 'The RQG run ended with status'
# ------------------------+-------------------------------------------------------
# $message_prefix         | Use it for making messages written by the current
#                         | routine more informative.
#                         | Some upper level caller routine knows more about the
#                         | for calling content_matching on low level.
# ------------------------+-------------------------------------------------------
# $debug                  | If the value is > 0 than the routine is more verbose.
#                         | Use it for debugging the curent routine, the caller
#                         | routine, unit tests and similar.
#
# Return values
# =============
#
# Return value            | state
# ------------------------+---------------------------------------------
# MATCH_NO                | There are elements defined but none matched.
# ('match_no')            |
# ------------------------+----------------------------------------
# MATCH_YES               | One element matched. Possibly remaining
# ('match_yes')           | elements will be not checked.     FIXME
# ------------------------+---------------------------------------------
# MATCH_NO_LIST_EMPTY     | There are no elements defined.
# ('match_no_list_empty') |
# ------------------------+---------------------------------------------
# MATCH_UNKNOWN           | $pattern_prefix was not found.
# ('match_unknown)        |
# ------------------------+---------------------------------------------
#
# Hint:
# The calling routines need frequent some rigorous Yes/No. Therefore they might
# twist the return value MATCH_NO_LIST_EMPTY.
# Example:
#    Whitelist maching : MATCH_NO_LIST_EMPTY -> MATCH_YES
#    Blacklist maching : MATCH_NO_LIST_EMPTY -> MATCH_NO
#

   if (not defined $pattern_prefix or $pattern_prefix eq '') {
      # Its an internal error or (rather) misuse of routine.
      Carp::cluck("INTERNAL ERROR: pattern_prefix is not defined or empty");
   }
   if (not defined $content or $content eq '') {
      # Its an internal error or (rather) misuse of routine.
      Carp::cluck("INTERNAL ERROR: pattern_prefix is not defined or empty");
   }
   if (not defined $message_prefix or $message_prefix eq '') {
      # Its an internal error or (rather) misuse of routine.
      Carp::cluck("INTERNAL ERROR: pattern_prefix is not defined or empty");
   }

   # Count the number of pattern matches thanks to the 'g'.
   my $pattern_prefix_found = () = $content =~ m{$pattern_prefix}gs;
   if ($pattern_prefix_found > 1) {
      Carp::cluck("INTERNAL ERROR: pattern_prefix matched $pattern_prefix_found times.");
   } elsif ($pattern_prefix_found == 0) {
      say("INFO: status_matching : The pattern_prefix '$pattern_prefix' was not found. " .
          "Assume aborted RQG run and will return MATCH_UNKNOWN.");
      return MATCH_UNKNOWN;
   } else {
      # say("DEBUG: status_matching : The pattern_prefix '$pattern_prefix' was found once.");
   }

   my $no_pattern = 1;
   my $match      = 0;
   foreach my $pattern (@{$pattern_list}) {
      last if not defined $pattern;
      $no_pattern = 0;
      $pattern    = $pattern_prefix . $pattern;
      my $message = "$message_prefix, element '$pattern' :";
      if ($content =~ m{$pattern}s) {
         if ($debug) { say("$message match"); };
         $match   = 1;
      } else {
         if ($debug) { say("$message no match"); };
      }
   }
   if ($no_pattern == 1) {
      if ($debug) {
         say("$message_prefix , no element defined.");
      }
      return MATCH_NO_LIST_EMPTY;
   } else {
      if ($match) {
         return MATCH_YES;
      } else {
         return MATCH_NO;
      }
   }

} # End sub status_matching

# ----------

use constant RQG_VERDICT_INIT             => 'init';
use constant RQG_VERDICT_REPLAY           => 'replay';
use constant RQG_VERDICT_INTEREST         => 'interest';
use constant RQG_VERDICT_IGNORE           => 'ignore';
use constant RQG_VERDICT_ALLOWED_VALUE_LIST => [
      RQG_VERDICT_INIT, RQG_VERDICT_REPLAY, RQG_VERDICT_INTEREST, RQG_VERDICT_IGNORE
   ];


sub set_final_rqg_verdict {
   my ($workdir, $verdict) = @_;
   if (not -d $workdir) {
      say("ERROR: RQG workdir '$workdir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   if (not defined $verdict or $verdict eq '') {
      Carp::cluck("ERROR: Auxiliary::get_set_verdict verdict is either not defined or ''.");
      return STATUS_FAILURE;
   }
   my $result = Auxiliary::check_value_supported ('verdict', RQG_VERDICT_ALLOWED_VALUE_LIST,
                                                  $verdict);
   if ($result != STATUS_OK) {
      Carp::cluck("ERROR: Auxiliary::check_value_supported returned $result. Will return that too.");
      return $result;
   }
   my $initial_verdict = RQG_VERDICT_INIT;

   my $source_file = $workdir . '/rqg_verdict.' . $initial_verdict;
   my $target_file = $workdir . '/rqg_verdict.' . $verdict;

   # Auxiliary::rename_file is safe regarding existence of these files.
   my $result = Auxiliary::rename_file ($source_file, $target_file);
   if ($result) {
      say("ERROR: Auxiliary::set_rqg_verdict from '$initial_verdict' to '$verdict' failed.");
      return STATUS_FAILURE;
   } else {
      # say("DEBUG: Auxiliary::set_rqg_verdict from '$initial_verdict' to '$verdict'.");
      return STATUS_OK;
   }
}

sub get_rqg_verdict {
# Return values:
# undef - $workdir not existing, verdict file not found ==> RQG should abort later
# $verdict_value - all ok
   my ($workdir) = @_;
   if (not -d $workdir) {
      say("ERROR: Auxiliary::get_rqg_verdict : RQG workdir '$workdir' " .
          " is missing or not a directory. Will return undef.");
      return undef;
   }
   foreach my $verdict_value (@{&RQG_VERDICT_ALLOWED_VALUE_LIST}) {
      my $file_to_try = $workdir . '/rqg_verdict.' . $verdict_value;
      if (-e $file_to_try) {
         return $verdict_value;
      }
   }
   # In case we reach this point than we have no verdict file found.
   say("ERROR: Auxiliary::get_rqg_verdict : No RQG verdict file in directory '$workdir' found. " .
       "Will return undef.");
   return undef;
}

# ----------


sub print_list {
   my ($prefix, @input) = @_;
   my $output = $prefix .  ": ";
   my $has_elements = 0;
   foreach my $element (@input) {
      $has_elements = 1;
      if (not defined $element) {
         $element = "undef";
      }
      $output = $output . "->" . $element . "<-";
   }
   if ($has_elements) {
      say($output);
   } else {
      say($output . "List had no elements.");
   }
}

sub unified_value_list {
   my (@input) = @_;
   my $has_elements = 0;
   my @unified_element_list;
   foreach my $element (@input) {
      $has_elements = 1;
      if (not defined $element) {
         push @unified_element_list, 'undef';
      } else {
         push @unified_element_list, $element;
       }
   }
   if ($has_elements) {
      return @unified_element_list;
   } else {
      return undef;
   }
}


sub input_to_list {

# We have certain RQG options which need to be finally some list.
# But in order to offer some comfort in
# - RQG command line calls
# - config files
# assignments like xyz=<comma separated elements> should be supported.
# Example: --redefine=a.yy,b1.yy
#
# Stuff for experimenting
# blacklist_statuses           highest index element[0]  final  join(' , ', @blub)
# not in cmdline                      -1       undef
# --blacklist_statuses=                0       undef
# --blacklist_statuses=,               0       ,         <nothing> !!!
# --blacklist_statuses=','             0       ,         <nothing> !!!
# --blacklist_statuses="','"           0       ,         , (one element!)
# --blacklist_statuses=abc             0       abc       abc
# --blacklist_statuses=A,B             0       A,B       A , B
# --blacklist_statuses="A,B"           0       A,B       A , B
# --blacklist_statuses="A","B"         0       A,B       A , B
# --blacklist_statuses='A','B'         0       A,B       A , B
# --blacklist_statuses="'A','B'"       0       A,B       A , B
#
# my @blub;                 #         -1       undef     3
# my @blub = ();            #         -1       undef     3
# my @blub = undef;         #          0       undef     3
# my @blub = (undef);       #          0       undef     3
# my @blub = 'abc';         #          0       abc       abc
# my @blub = 'a,c';         #          0       a,c       a , c
# my @blub = "a,c";         #          0       a,c       a , c
# my @blub = "a","c";       #          0       a         a
# my @blub = ("a","c");     #          0       a,c       a , c
# my @blub = ('a','c');     #          0       a,c       a , c
#
# my $h_i_blub = $#blub;
# say("highest index is $h_i_blub");
# if (not defined $blub[0]) {
#    say("elem 0 is undef");
# } else {
#    say("elem 0 is : " . $blub[0]);
# }
# say("Listing of elems in blub -- Begin");
# foreach my $elem (@blub) {
#    if (not defined $elem) {
#       say("elem is undef");
#    } else {
#       say("elem is : " . $elem);
#    }
# }
# say("Listing of elems in blub -- End");
# }
#
# say("DEBUG: Initial RQG blub : " . join(' , ', @blub));
# if (not defined $blub[0]) {
#    $blub[0] = STATUS_ANY_ERROR;
#    say("DEBUG: blub[0] was not defined. Setting blub[0] " .
#        "to STATUS_ANY_ERROR (== default).");
# };
# @blub = Auxiliary::input_to_list(@blub);
# say("INFO: Final RQG blub : " . join(' , ', @blub));

# say("Listing of elems in blub -- Begin");
# foreach my $elem (@blub) {
#    if (not defined $elem) {
#       say("elem is undef");
#    } else {
#       say("elem is : " . $elem);
#    }
# }

# return a reference to @input or undef

   if (@_ < 1) {
      Carp::confess("INTERNAL ERROR: Auxiliary::input_to_list : One Parameter " .
                    "(input) is required.");
      # This accident could roughly only happen when coding RQG or its tools.
      # Already started servers need to be killed manually!
   }
   my (@input) = @_;

   if ($#input != 0) {
      # say("DEBUG: input_to_list : The input does not consist of one element. " .
      #     "Will return that input.");
      return \@input;
   }
   if (not defined $input[0]) {
      # say("DEBUG: input_to_list : \$input[0] is not defined. Will return the input.");
      return \@input;
   }

   my $single_quote_protection = 0;

   # print_list("DEBUG: input_to_list initial value ", @input);
   if (substr($input[0],  0, 1) eq "'" and substr($input[0], -1, 1) eq "'") {
      # say("DEBUG: The input is surrounded by single quotes. Assume 'single quote protection' " .
      #     "and remove these quotes.");
      $single_quote_protection = 1;
      $input[0] = substr($input[0], 1, length($input[0]) - 2);
      # print_list("DEBUG: input_to_list value after begin/end single quote removal", @input);
   } elsif (substr($input[0],  0, 1) eq "'" or substr($input[0], -1, 1) eq "'") {
      say("ERROR: input_to_list : Either begin and end with single quote or both without " .
          "single quote.");
      say("ERROR: The input was -->" . $input[0] . "<--");
      say("ERROR: Will return undef.");
      return undef;
   } else {
      # say("DEBUG: The input is not surrounded by single quotes. Assume no " .
      #     "'single quote protection'.");
      $single_quote_protection = 0;
   }

   my $separator;
   if ($single_quote_protection and $input[0] =~ m/','/) {
      # say("DEBUG: -->','<-- in input found. Splitting required.");
      $separator = "','";
   } elsif ($single_quote_protection == 0 and $input[0] =~ m/,/) {
      # say("DEBUG: -->,<-- in input found. Splitting required.");
      $separator = ",";
   } else {
      # say("DEBUG: Neither -->','<-- nor -->,<-- in input found. Will return current input.");
      return \@input;
   }

   @input = split(/$separator/, $input[0]);
   # print_list("DEBUG: input_to_list final value (will be returned)", @input);
   return \@input;
}


sub getFileSlice {

# Return
# - up to $search_var_size bytes read from the end of the file $file_to_read
# - undef if there is whatever trouble with the file (existence, type etc.)
# or abort with confess if the routine is used wrong.

#
# Some code used for testing the current routine
# 'not_exists' -- does not exist.
# 'empty'      -- is empty
# 'otto'       -- is not empty and bigger than 100 Bytes
# my $content_slice = Auxiliary::getFileSlice();
# say("EXPERIMENT:  Auxiliary::getFileSlice() content_slice : $content_slice");
# say("content_slice is undef") if not defined $content_slice;
#
# my $content_slice = Auxiliary::getFileSlice('not_exists');
# say("EXPERIMENT:  Auxiliary::getFileSlice('not_exists') content_slice : $content_slice");
# say("content_slice is undef") if not defined $content_slice;
#
# my $content_slice = Auxiliary::getFileSlice('not_exists', 100);
# say("EXPERIMENT:  Auxiliary::getFileSlice('not_exists', 100) content_slice : $content_slice");
# say("content_slice is undef") if not defined $content_slice;
#
# my $content_slice = Auxiliary::getFileSlice('empty', 100);
# say("EXPERIMENT:  Auxiliary::getFileSlice('empty', 100) content_slice : $content_slice");
# say("content_slice is undef") if not defined $content_slice;
#
# my $content_slice = Auxiliary::getFileSlice('otto', 100);
# say("EXPERIMENT:  Auxiliary::getFileSlice('otto', 100) content_slice : $content_slice");
# say("content_slice is undef") if not defined $content_slice;
#

   my ($file_to_read, $search_var_size) = @_;
   if (@_ != 2) {
      Carp::confess("INTERNAL ERROR: Auxiliary::getFileSlice : 2 Parameters (file_to_read, " .
              "search_var_size) are required.");
      # This accident could roughly only happen when coding RQG or its tools.
      # Already started servers need to be killed manually!
   }

   if (not -e $file_to_read) {
      say("ERROR: The file '$file_to_read' does not exist. Will return undef.");
      return undef;
   }
   if (not -f $file_to_read) {
      say("ERROR: The file '$file_to_read' is not a plain file. Will return undef.");
      return undef;
   }

   my $file_handle;
   if (not open ($file_handle, '<', $file_to_read)) {
      say("ERROR: Open '$file_to_read' failed : $!. Will return undef.");
      return undef;
   }

   my @filestats = stat($file_to_read);
   my $filesize  = $filestats[7];
   my $offset    = $filesize - $search_var_size;

   if ($filesize <= $search_var_size) {
      if (not seek($file_handle, 0, 0)) {
         Carp::cluck("ERROR: Seek to the begin of '$file_to_read' failed: $!. Will return undef.");
         return undef;
      }
   } else {
      if (not seek($file_handle, - $search_var_size, 2)) {
         Carp::cluck("ERROR: Seek " . $search_var_size . " Bytes from end of '$file_to_read.' " .
                     "towards file begin failed: $!. Will return undef.");
      }
   }

   my $content_slice;
   read($file_handle, $content_slice, $search_var_size);
   close ($file_handle);

   return $content_slice;

}


sub get_git_info {
   my ($directory) = @_;

   # Code just for testing the current routine
   # say("Auxiliary::get_git_info() ---");
   # Auxiliary::get_git_info();
   # say("Auxiliary::get_git_info(undef) ---");
   # Auxiliary::get_git_info(undef);
   # say("Auxiliary::get_git_info('/tmp/does_not_exist') ---");
   # Auxiliary::get_git_info('/tmp/does_not_exist');
   # say("Auxiliary::get_git_info($0) ---");
   # Auxiliary::get_git_info($0);
   # say("Auxiliary::get_git_info('/tmp') ---");
   # Auxiliary::get_git_info('/tmp');
   #

   my $cmd ;             # For commands run through system ...
   my $result ;          # For the return of system ...
   my $git_output_file ; # For the output of git commands
   my $fail = 0;
   if (not defined $directory) {
      say("ERROR: Auxiliary::get_git_info : No parameter or undef was assigned. " .
          "Will return STATUS_INTERNAL_ERROR");
      return STATUS_INTERNAL_ERROR;
   }
   if (not -e $directory) {
      say("ERROR: Auxiliary::get_git_info : The assigned '$directory' does not exist. " .
          "Will return STATUS_INTERNAL_ERROR");
      return STATUS_INTERNAL_ERROR;
   }
   if (not -d $directory) {
      say("ERROR: Auxiliary::get_git_info : The assigned '$directory' is not a directory. " .
          "Will return STATUS_INTERNAL_ERROR");
      return STATUS_INTERNAL_ERROR;
   }

   my $cwd = Cwd::cwd();
   $git_output_file = $cwd . "/rqg-git-version-info." . $$;
   $cmd = "git --version > $git_output_file 2>&1";
   $result = system($cmd) >> 8;
   # my $cmd = "nogit --version > $git_output_file";
   #   sh: 1: nogit: not found
   # 127 PGM does not exist
   # my $cmd = "git --version > /";
   #   sh: 1: cannot create /: Is a directory
   #   2 Create failed because of directory there
   # my $cmd = "git --version > /27";
   #   sh: 1: cannot create /27: Permission denied
   #   2 Create failed because of permission
   # my $cmd = "git --whatever_version > $git_output_file";
   #   Unknown option: --whatever_version
   # 129 PGM denies service/wrong used
   # Be in some directory lke '/tmp' which is not controlled by GIT
   #   fatal: Not a git repository (or any of the parent directories): .git
   # 128 No GIT deriectory
   if ($result != STATUS_OK) {
      if ($result == 127) {
         say("INFO: GIT binary not found. Will return STATUS_OK");
         unlink($git_output_file);
         return STATUS_OK;
      } else {
         say("ERROR: Trouble with GIT or similar. Will return STATUS_INTERNAL_ERROR");
         sayFile($git_output_file);
         unlink($git_output_file);
         return STATUS_INTERNAL_ERROR;
      }
   }
   unlink($git_output_file);
   if (not chdir($directory))
   {
      say("ALARM: chdir to '$directory' failed with : $!\n" .
          "       Will return STATUS_ENVIRONMENT_FAILURE");
      return STATUS_ENVIRONMENT_FAILURE;
   }
#  my $cmd = "git branch  > $git_output_file 2>&1";
#  system($cmd);
#  my $cmd = "git show -s >> $git_output_file 2>&1";
#  system($cmd);
   # git show --pretty='format:%D %H  %cI' -s
   # HEAD -> experimental, origin/experimental ce3c84fc53216162ef8cc9fdcce7aed24887e305  2018-05-04T12:39:45+02:00
   # %s would show the title of the last commit but that could be longer than wanted.
   $cmd = "git show --pretty='format:%D %H %cI' -s > $git_output_file 2>&1";
   system ($cmd);
   sayFile ($git_output_file);
   unlink ($git_output_file);

   chdir($cwd);
   return STATUS_OK;
}

# Run with one server only.
use constant RQG_RPL_NONE                 => 'none';
# Run with two servers and binlog_format=statement.
use constant RQG_RPL_STATEMENT            => 'statement';
use constant RQG_RPL_STATEMENT_NOSYNC     => 'statement-nosync';
# Run with two servers and binlog_format=mixed.
use constant RQG_RPL_MIXED                => 'mixed';
use constant RQG_RPL_MIXED_NOSYNC         => 'mixed-nosync';
# Run with two servers and binlog_format=row.
use constant RQG_RPL_ROW                  => 'row';
use constant RQG_RPL_ROW_NOSYNC           => 'row-nosync';
# Not used. # Run with n? servers and Galera
use constant RQG_RPL_GALERA               => 'galera';
# Run with two servers and RQG builtin statement based replication.
use constant RQG_RPL_RQG2                 => 'rqg2';
# Run with three servers and RQG builtin statement based replication.
use constant RQG_RPL_RQG3                 => 'rqg3';

use constant RQG_RPL_ALLOWED_VALUE_LIST => [
       RQG_RPL_NONE,
       RQG_RPL_STATEMENT, RQG_RPL_STATEMENT_NOSYNC, RQG_RPL_MIXED, RQG_RPL_MIXED_NOSYNC,
       RQG_RPL_ROW, RQG_RPL_ROW_NOSYNC,
       RQG_RPL_GALERA,
       RQG_RPL_RQG2, RQG_RPL_RQG3
];

sub archive_results {
   my ($workdir, $vardir) = @_;
   if (not -d $workdir) {
      say("ERROR: RQG workdir '$workdir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   if (not -d $vardir) {
      say("ERROR: RQG vardir '$vardir' is missing or not a directory.");
      return STATUS_FAILURE;
   }
   # Maybe check if some of the all time required/used files exists in order to be sure to have
   # picked the right directory.
   my $archive     = $workdir . "/archive.tgz";
   my $archive_err = $workdir . "/rqg_arch.err";

   my $status;
   # FIXME/DECIDE:
   # - Use the GNU tar long options bacuse the describe better what is done
   # Failing cmd for experimenting
   # my $cmd = "cd $workdir ; tar csf $archive rqg* $vardir 2>$archive_err";

   my $cmd = "cd $workdir ; tar czf $archive rqg* $vardir 2>$archive_err";
   # say("DEBUG: cmd : ->$cmd<-");
   my $rc = system($cmd);
   if ($rc != 0) {
      say("ERROR: The command for archiving '$cmd' failed with exit status " . ($? >> 8));
      sayFile($archive_err);
      $status = STATUS_FAILURE;
   } else {
      $status = STATUS_OK;
   }
   # We need to remove $archive_err even in case of archiver success because it might contain
   # messages like 'tar: Removing leading `/' from member names' etc.
   unlink $archive_err;
   return $status;
}

sub help_rqg_home {
   print(
"HELP: About the RQG home directory used and the RQG tool/runner called.\n"                        .
"      In order to ensure the consistency of the RQG tool/runner called and the ingredients\n"     .
"      picked from the libraries only two variants for the call are supported.\n"                  .
"      a) The current working directory is whereever.\n"                                           .
"         The environment variable RQG_HOME is set and pointing to the top level directory\n"      .
"         of some RQG install.\n"                                                                  .
"         The RQG tool/runner called is inside that RQG_HOME.\n"                                   .
"         Example\n"                                                                               .
"            RQG_HOME=\"/work/rqg\"\n"                                                             .
"            cd <somewhere>\n"                                                                     .
"            perl /work/rqg/<runner.pl> or /work/rqg/util/<tool>.pl\n"                             .
"      b) The current working directory is the root directory of a RQG install.\n"                 .
"         The RQG tool/runner called is inside the current working directory.\n"                   .
"         In case RQG_HOME is set than it must be equal to the current working directory.\n"       .
"         Example:\n"                                                                              .
"            unset RQG_HOME\n"                                                                     .
"            cd /work/rqg\n"                                                                       .
"            perl /work/rqg/<runner.pl> or /work/rqg/util/<tool>.pl\n"
    );
}

1;
