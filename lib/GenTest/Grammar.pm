# Copyright (c) 2008,2012 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2016,2018 MariaDB Corporation
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

package GenTest::Grammar;

require Exporter;
@ISA = qw(GenTest);
@EXPORT = qw(
	GRAMMAR_FLAG_COMPACT_RULES
	GRAMMAR_FLAG_SKIP_RECURSIVE_RULES
);

use strict;

use GenTest;
use GenTest::Constants;
use GenTest::Grammar::Rule;
use GenTest::Random;

use Data::Dumper;

use constant GRAMMAR_RULES	=> 0;
use constant GRAMMAR_FILES	=> 1;
use constant GRAMMAR_STRING	=> 2;
use constant GRAMMAR_FLAGS	=> 3;

use constant GRAMMAR_FLAG_COMPACT_RULES         => 1;
use constant GRAMMAR_FLAG_SKIP_RECURSIVE_RULES  => 2;

1;

sub new {
	my $class = shift;


	my $grammar = $class->SUPER::new({
		'grammar_files'			=> GRAMMAR_FILES,
		'grammar_string'		=> GRAMMAR_STRING,
		'grammar_flags'		=> GRAMMAR_FLAGS,
		'grammar_rules'		=> GRAMMAR_RULES
	}, @_);


	if (defined $grammar->rules()) {
		$grammar->[GRAMMAR_STRING] = $grammar->toString();
	} else {
		$grammar->[GRAMMAR_RULES] = {};

		if (defined $grammar->files()) {
			my $parse_result = $grammar->extractFromFiles($grammar->files());
			return undef if not defined $parse_result;
            # If not undef than $grammar->[GRAMMAR_STRING] is now filled.
		}

		if (defined $grammar->string()) {
			my $parse_result = $grammar->parseFromString($grammar->string());
			return undef if $parse_result > STATUS_OK;
            # If not undef than $grammar->[GRAMMAR_RULES] is now filled.
		}
	}

	return $grammar;
}

sub files {
	return $_[0]->[GRAMMAR_FILES];
}

sub string {
	return $_[0]->[GRAMMAR_STRING];
}


sub toString {
	my $grammar = shift;
	my $rules = $grammar->rules();
	return join("\n\n", map { $grammar->rule($_)->toString() } sort keys %$rules);
}


sub extractFromFiles {
# Return
# - Some string even if empty ('')
# - undef if hitting an error

   my ($grammar, $grammar_files) = @_;

   $grammar->[GRAMMAR_STRING] = '';
   foreach my $grammar_file (@$grammar_files) {
      # For experimenting.
      # $grammar_file = '/otto';
      if (not open (GF, $grammar_file)) {
         say("ERROR: Unable to open() grammar file '$grammar_file': $!.  Will return undef.");
         return undef;
      }
      say "Reading grammar from file $grammar_file";
      my $grammar_string;
      my $result = read (GF, $grammar_string, -s $grammar_file);
      if (not defined $result) {
         say("ERROR: Unable to read() '$grammar_file': $!. Will return undef.");
         return undef;
      } else {
         say("DEBUG: $result bytes from grammar file '$grammar_file' read.");
      }
      if (0 == $result) {
         say("WARN: The grammar file '$grammar_file' is empty.");
      }
      $grammar->[GRAMMAR_STRING] .= $grammar_string;
   }

   return $grammar->[GRAMMAR_STRING];

}

sub parseFromString {
	my ($grammar, $grammar_string) = @_;

	#
	# provide an #include directive
	#

	while ($grammar_string =~ s{#include [<"](.*?)[>"]$}{
		{
			my $include_string;
			my $include_file = $1;
		        open (IF, $1) or die "Unable to open include file $include_file: $!";
		        read (IF, my $include_string, -s $include_file) or die "Unable to open $include_file: $!";
			$include_string;
	}}mie) {};

	# Strip comments. Note that this is not Perl-code safe, since perl fragments
	# can contain both comments with # and the $# expression. A proper lexer will fix this
	
	$grammar_string =~ s{#.*$}{}iomg;

	# Join lines ending in \

	$grammar_string =~ s{\\$}{ }iomg;

	# Strip end-line whitespace

	$grammar_string =~ s{\s+$}{}iomg;

	# Add terminating \n to ease parsing

	$grammar_string = $grammar_string."\n";

	my @rule_strings = split (";\s*[\r\n]+", $grammar_string);

	my %rules;

    # Redefining grammars might want to *add* something to an existing rule
    # rather than replace them. For now we recognize additions only to init queries
    # and to the main queries ('query' and 'threadX'). Additions should end with '_add':
    # - query_add
    # - threadX_add
    # - query_init_add
    # _ threadX_init_add
    # Grammars can have multiple additions like these, they all will be stored
    # and appended to the corresponding rule.
    #
    # Additions to 'query' and 'threadX' will be appended as an option, e.g.
    #
    # In grammar files we have:
    #   query:
    #     rule1 | rule2;
    #   query_add:
    #     rule3;
    # In the resulting grammar we will have:
    #   query:
    #     rule1 | rule2 | rule3;
    #
    # Additions to '*_init' rules will be added as a part of a multiple-statement, e.g.
    #
    # In grammar files we have:
    #   query_init:
    #     rule4 ;
    #   query_init_add:
    #     rule5;
    # In the resulting grammar we will have:
    #   query_init:
    #     rule4 ; rule5;
    #
    # Also, we will add threadX_init_add to query_init (if it's not overridden for the given thread ID).
    # That is, if we have in the grammars
    # query_init: ...
    # query_init_add: ...
    # thread2_init_add: ...
    # thread3_init: ...
    #
    # then the resulting init sequence for threads will be:
    # 1: query_init; query_init_add
    # 2: query_init; query_init_add; thread2_init_add
    # 3: thread3_init


    my @query_adds = ();
    my %thread_adds = ();
    my @query_init_adds = ();
    my %thread_init_adds = ();

	foreach my $rule_string (@rule_strings) {
        say("DEBUG: rule_string : ->" . $rule_string . "<-");
		my ($rule_name, $components_string) = $rule_string =~ m{^(.*?)\s*:(.*)$}sio;

        if (not defined $rule_name) {
            say("DEBUG: Step1 rule_name not detected.");
            next;
        }
		$rule_name =~ s{[\r\n]}{}gsio;
        if (not defined $rule_name) {
            say("DEBUG: Step2 rule_name not detected.");
            next;
        }
		$rule_name =~ s{^\s*}{}gsio;
        if (not defined $rule_name) {
            say("DEBUG: Step3 rule_name not detected.");
            next;
        }

		next if $rule_name eq '';

        if ($rule_name =~ /^query_add$/) {
            push @query_adds, $components_string;
        }
        elsif ($rule_name =~ /^thread(\d+)_add$/) {
            @{$thread_adds{$1}} = () unless defined $thread_adds{$1};
            push @{$thread_adds{$1}}, $components_string;
        }
        elsif ($rule_name =~ /^query_init_add$/) {
            push @query_init_adds, $components_string;
        }
        elsif ($rule_name =~ /^thread(\d+)_init_add$/) {
            @{$thread_init_adds{$1}} = () unless defined $thread_init_adds{$1};
            push @{$thread_init_adds{$1}}, $components_string;
        }
        else {
            say("Warning: Rule $rule_name is defined twice.") if exists $rules{$rule_name};
            $rules{$rule_name} = $components_string;
        }
    }

    if (@query_adds) {
        my $adds = join ' | ', @query_adds;
        $rules{'query'} = ( defined $rules{'query'} ? $rules{'query'} . ' | ' . $adds : $adds );
    }

    foreach my $tid (keys %thread_adds) {
        my $adds = join ' | ', @{$thread_adds{$tid}};
        $rules{'thread'.$tid} = ( defined $rules{'thread'.$tid} ? $rules{'thread'.$tid} . ' | ' . $adds : $adds );
    }

    if (@query_init_adds) {
        my $adds = join '; ', @query_init_adds;
        $rules{'query_init'} = ( defined $rules{'query_init'} ? $rules{'query_init'} . '; ' . $adds : $adds );
    }

    foreach my $tid (keys %thread_init_adds) {
        my $adds = join '; ', @{$thread_init_adds{$tid}};
        $rules{'thread'.$tid.'_init'} = (
            defined $rules{'thread'.$tid.'_init'}
                ? $rules{'thread'.$tid.'_init'} . '; ' . $adds
                : ( defined $rules{'query_init'}
                    ? $rules{'query_init'} . '; ' . $adds
                    : $adds
                )
        );
    }

    if (0 == scalar keys %rules) {
        say("WARN/ERROR: GenTest::Grammar::parseFromString : There are no rules in the grammar. " .
            "Will return STATUS_ENVIRONMENT_FAILURE.");
        return STATUS_ENVIRONMENT_FAILURE;
    }

    # Now we have all the rules extracted from grammar files, time to parse

	foreach my $rule_name (keys %rules) {

        my $components_string = $rules{$rule_name};

		my @component_strings = split (m{\|}, $components_string);
		my @components;
		my %components;

		foreach my $component_string (@component_strings) {
			# Remove leading whitespace
			$component_string =~ s{^\s+}{}sgio;
			$component_string =~ s{\s+$}{}sgio;
		
			# Rempove repeating whitespaces
			$component_string =~ s{\s+}{ }sgio;

			# Split this so that each identifier is separated from all syntax elements
			# The identifier can start with a lowercase letter or an underscore , plus quotes

			$component_string =~ s{([_a-z0-9'"`\{\}\$\[\]]+)}{|$1|}sgio;

			# Revert overzealous splitting that splits things like _varchar(32) into several tokens
		
			$component_string =~ s{([a-z0-9_]+)\|\(\|(\d+)\|\)}{$1($2)|}sgo;

			# Remove leading and trailing pipes
			$component_string =~ s{^\|}{}sgio;
			$component_string =~ s{\|$}{}sgio;

			if (
				(exists $components{$component_string}) &&
				(defined $grammar->[GRAMMAR_FLAGS] & GRAMMAR_FLAG_COMPACT_RULES)
			) {
				next;
			} else {
				$components{$component_string}++;
			}

            # Split at the '|' added above.
			my @component_parts = split (m{\|}, $component_string);
            # say("DEBUG: component_string ->" . $component_string . "<-");

			if (
				(grep { $_ eq $rule_name } @component_parts) &&
				(defined $grammar->[GRAMMAR_FLAGS] & GRAMMAR_FLAG_SKIP_RECURSIVE_RULES)
			) {
				say("Skipping recursive production in rule '$rule_name'.") if rqg_debug();
				next;
			}

			#
			# If this grammar rule contains Perl code, assemble it between the various
			# component parts it was split into. This "reconstructive" step is definitely bad design
			# The way to do it properly would be to tokenize the grammar using a full-blown lexer
			# which should hopefully come up in a future version.
			#

			my $nesting_level = 0;
			my $pos = 0;
			my $code_start;

			while (1) {
				if ($component_parts[$pos] =~ m{\{}so) {
					$code_start = $pos if $nesting_level == 0;	# Code segment starts here
					my $bracket_count = ($component_parts[$pos] =~ tr/{//);
					$nesting_level = $nesting_level + $bracket_count;
				}
				
				if ($component_parts[$pos] =~ m{\}}so) {
					my $bracket_count = ($component_parts[$pos] =~ tr/}//);
					$nesting_level = $nesting_level - $bracket_count;
					if ($nesting_level == 0) {
						# Resemble the entire Perl code segment into a single string
						splice(@component_parts, $code_start, ($pos - $code_start + 1) , join ('', @component_parts[$code_start..$pos]));
						$pos = $code_start + 1;
						$code_start = undef;
					}
				}
				$pos++;
                # The incremented pos/index might be higher than the highest index existing.
                # So use "last" in order to not fiddle with a not defined $component_parts[$pos].
				last if $pos > $#component_parts;
			}

			push @components, \@component_parts;
		}

		my $rule = GenTest::Grammar::Rule->new(
			name => $rule_name,
			components => \@components
		);
		$rules{$rule_name} = $rule;
	}

	$grammar->[GRAMMAR_RULES] = \%rules;
	return STATUS_OK;

} # End of sub parseFromString

sub rule {
	return $_[0]->[GRAMMAR_RULES]->{$_[1]};
}

sub rules {
	return $_[0]->[GRAMMAR_RULES];
}

sub deleteRule {
	delete $_[0]->[GRAMMAR_RULES]->{$_[1]};
}

sub cloneRule {
	my ($grammar, $old_rule_name, $new_rule_name) = @_;

	# Rule consists of
	# rule_name
	# pointer to array called components
	#   An element of components is a pointer to an array of component_parts

	my $components = $grammar->[GRAMMAR_RULES]->{$old_rule_name}->[1];

	my @new_components;
	for (my $idx=$#$components; $idx >= 0; $idx--) {
		my $component = $components->[$idx];
		my @new_component_parts = @$component;
		# We go from the highest index to the lowest.
		# So "push @new_components , \@new_component_parts ;" would give the wrong order
		unshift @new_components , \@new_component_parts ;
	}

	my $new_rule = GenTest::Grammar::Rule->new(
		name => $new_rule_name,
		components => \@new_components
	);
	$grammar->[GRAMMAR_RULES]->{$new_rule_name} = $new_rule;

}

#
# Check if the grammar is tagged with query properties such as RESULTSET_ or ERROR_1234
#

sub hasProperties {
	if ($_[0]->[GRAMMAR_STRING] =~ m{RESULTSET_|ERROR_|QUERY_}so) {
		return 1;
	} else {
		return 0;
	}
}

##
## Make a new grammar using the patch_grammar to replace old rules and
## add new rules.
##
sub patch {
    my ($self, $patch_grammar) = @_;

    my $patch_rules = $patch_grammar->rules();

    my $rules = $self->rules();

    foreach my $ruleName (sort keys %$patch_rules) {
        if ($ruleName =~ /^query_init_add/) {
            if (defined $rules->{'query_init'}) {
                $rules->{'query_init'} .= '; ' . $patch_rules->{$ruleName}
            }
            else {
                $rules->{'query_init'} = $patch_rules->{$ruleName}
            }
        }
        elsif ($ruleName =~ /^thread(\d+)_init_add/) {
            if (defined $rules->{'thread'.$1.'_init'}) {
                $rules->{'thread'.$1.'_init'} .= '; ' . $patch_rules->{$ruleName}
            }
            else {
                $rules->{'thread'.$1.'_init'} = $patch_rules->{$ruleName}
            }
        }
        else {
            $rules->{$ruleName} = $patch_rules->{$ruleName};
        }
    }

    my $new_grammar = GenTest::Grammar->new(grammar_rules => $rules);
    return $new_grammar;
}


sub firstMatchingRule {
    my ($self, @ids) = @_;
    foreach my $x (@ids) {
        return $self->rule($x) if defined $self->rule($x);
    }
    return undef;
}

##
## The "body" of topGrammar
##

sub topGrammarX {
    my ($self, $level, $max, @rules) = @_;
    if ($max > 0) {
        my $result={};
        foreach my $rule (@rules) {
            foreach my $c (@{$rule->components()}) {
                my @subrules = ();
                foreach my $cp (@$c) {
                    push @subrules,$self->rule($cp) if defined $self->rule($cp);
                }
                my $componentrules =
                    $self->topGrammarX($level + 1, $max -1,@subrules);
                if (defined  $componentrules) {
                    foreach my $sr (keys %$componentrules) {
                        $result->{$sr} = $componentrules->{$sr};
                    }
                }
            }
            $result->{$rule->name()} = $rule;
        }
        return $result;
    } else {
        return undef;
    }
}


##
## Produce a new grammar which is the toplevel $level rules of this
## grammar
##

sub topGrammar {
    my ($self, $levels, @startrules) = @_;

    my $start = $self->firstMatchingRule(@startrules);

    my $rules = $self->topGrammarX(0,$levels, $start);

    return GenTest::Grammar->new(grammar_rules => $rules);
}

##
## Produce a new grammar keeping a masked set of rules. The mask is 16
## bits. If the mask is too short, we use the original mask as a seed
## for a random number generator and generate more 16-bit values as
## needed. The mask is applied in alphapetical order on the rules to
## ensure a deterministicresult since I don't trust the Perl %hashes
## to be always ordered the same twhen they are produced e.g. from
## topGrammar or whatever...
##


sub mask {
    my ($self, $mask) = @_;


    my $rules = $self->rules();

    my %newRuleset;

    my $i = 0;
    my $prng = GenTest::Random->new(seed => $mask);
    ## Generate the first 16 bits.
    my $mask16 = $prng->uint16(0,0x7fff);
    foreach my $rulename (sort keys %$rules) {
        my $rule = $self->rule($rulename);
        my @newComponents;
        foreach my $x (@{$rule->components()}) {
            push @newComponents, $x if (1 << ($i++)) & $mask16;
            if ($i % 16 == 0) {
                # We need more bits!
                $i = 0;
                $mask = $prng->uint16(0,0x7fff);
            }
        }

        my $newRule;

        ## If no components were chosen, we chose all to have a working
        ## grammar.
        if ($#newComponents < 0) {
            $newRule = $rule;
        } else {
            $newRule= GenTest::Grammar::Rule->new(name => $rulename,
                                              components => \@newComponents);
        }
        $newRuleset{$rulename}= $newRule;

    }

    return GenTest::Grammar->new(grammar_rules => \%newRuleset);
}

1;
