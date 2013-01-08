#!perl
# Copyright 2012 Jeffrey Kegler
# This file is part of Marpa::R2.  Marpa::R2 is free software: you can
# redistribute it and/or modify it under the terms of the GNU Lesser
# General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Marpa::R2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser
# General Public License along with Marpa::R2.  If not, see
# http://www.gnu.org/licenses/.

# Testing an ambiguous equation
# using the thin interface

use 5.010;
use strict;
use warnings;

use Test::More tests => 12;

use lib 'inc';
use Marpa::R2::Test;
use English qw( -no_match_vars );
use Fatal qw( close open );
use Marpa::R2;

# Marpa::R2::Display
# name: Thin example

my $grammar = Marpa::R2::Thin::G->new( { if => 1 } );
my $symbol_S = $grammar->symbol_new();
my $symbol_E = $grammar->symbol_new();
$grammar->start_symbol_set($symbol_S);
my $symbol_op     = $grammar->symbol_new();
my $symbol_number = $grammar->symbol_new();
my $start_rule_id = $grammar->rule_new( $symbol_S, [$symbol_E] );
my $op_rule_id =
    $grammar->rule_new( $symbol_E, [ $symbol_E, $symbol_op, $symbol_E ] );
my $number_rule_id = $grammar->rule_new( $symbol_E, [$symbol_number] );
$grammar->precompute();

my $recce = Marpa::R2::Thin::R->new($grammar);
$recce->start_input();

# The numbers from 1 to 3 are themselves --
# that is, they index their own token value.
# Important: zero cannot be itself!

my @token_values         = ( 0 .. 3 );
my $zero                 = -1 + push @token_values, 0;
my $minus_token_value    = -1 + push @token_values, q{-};
my $plus_token_value     = -1 + push @token_values, q{+};
my $multiply_token_value = -1 + push @token_values, q{*};

$recce->alternative( $symbol_number, 2, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_op, $minus_token_value, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_number, $zero, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_op, $multiply_token_value, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_number, 3, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_op, $plus_token_value, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_number, 1, 1 );
$recce->earleme_complete();

my $latest_earley_set_ID = $recce->latest_earley_set();
my $bocage        = Marpa::R2::Thin::B->new( $recce, $latest_earley_set_ID );
my $order         = Marpa::R2::Thin::O->new($bocage);
my $tree          = Marpa::R2::Thin::T->new($order);
my @actual_values = ();
while ( $tree->next() ) {
    my $valuator = Marpa::R2::Thin::V->new($tree);
    $valuator->rule_is_valued_set( $op_rule_id,     1 );
    $valuator->rule_is_valued_set( $start_rule_id,  1 );
    $valuator->rule_is_valued_set( $number_rule_id, 1 );
    my @stack = ();
    STEP: while ( 1 ) {
        my ( $type, @step_data ) = $valuator->step();
        last STEP if not defined $type;
        if ( $type eq 'MARPA_STEP_TOKEN' ) {
            my ( undef, $token_value_ix, $arg_n ) = @step_data;
            $stack[$arg_n] = $token_values[$token_value_ix];
            next STEP;
        }
        if ( $type eq 'MARPA_STEP_RULE' ) {
            my ( $rule_id, $arg_0, $arg_n ) = @step_data;
            if ( $rule_id == $start_rule_id ) {
                my ( $string, $value ) = @{ $stack[$arg_n] };
                $stack[$arg_0] = "$string == $value";
                next STEP;
            }
            if ( $rule_id == $number_rule_id ) {
                my $number = $stack[$arg_0];
                $stack[$arg_0] = [ $number, $number ];
                next STEP;
            }
            if ( $rule_id == $op_rule_id ) {
                my $op = $stack[ $arg_0 + 1 ];
                my ( $right_string, $right_value ) = @{ $stack[$arg_n] };
                my ( $left_string,  $left_value )  = @{ $stack[$arg_0] };
                my $value;
                my $text = '(' . $left_string . $op . $right_string . ')';
                if ( $op eq q{+} ) {
                    $stack[$arg_0] = [ $text, $left_value + $right_value ];
                    next STEP;
                }
                if ( $op eq q{-} ) {
                    $stack[$arg_0] = [ $text, $left_value - $right_value ];
                    next STEP;
                }
                if ( $op eq q{*} ) {
                    $stack[$arg_0] = [ $text, $left_value * $right_value ];
                    next STEP;
                }
                die "Unknown op: $op";
            } ## end if ( $rule_id == $op_rule_id )
            die "Unknown rule $rule_id";
        } ## end if ( $type eq 'MARPA_STEP_RULE' )
        die "Unexpected step type: $type";
    } ## end while ( my ( $type, @step_data ) = $valuator->step() )
    push @actual_values, $stack[0];
} ## end while ( $tree->next() )

# Marpa::R2::Display::End

my %expected_value = (
    '(2-(0*(3+1))) == 2' => 1,
    '(((2-0)*3)+1) == 7' => 1,
    '((2-(0*3))+1) == 3' => 1,
    '((2-0)*(3+1)) == 8' => 1,
    '(2-((0*3)+1)) == 1' => 1,
);

my $i = 0;
for my $actual_value (@actual_values) {
    if ( defined $expected_value{$actual_value} ) {
        delete $expected_value{$actual_value};
        Test::More::pass("Expected Value $i: $actual_value");
    }
    else {
        Test::More::fail("Unexpected Value $i: $actual_value");
    }
    $i++;
} ## end for my $actual_value (@actual_values)

# For the error methods, start clean,
# with a new, trivial grammar
$grammar = $recce = $bocage = $order = $tree = undef;
$grammar = Marpa::R2::Thin::G->new( { if => 1 } );

# Marpa::R2::Display
# name: Thin throw_set() example

$grammar->throw_set(0);

# Marpa::R2::Display::End

# Turn it right back on, for safety's sake
$grammar->throw_set(0);

# Marpa::R2::Display
# name: Thin grammar error methods

my ( $error_code, $error_description ) = $grammar->error();
my @error_names = Marpa::R2::Thin::error_names();
my $error_name = $error_names[$error_code];

# Marpa::R2::Display::End

Test::More::is( $error_code, 0, 'Grammar error code' );
Test::More::is( $error_name, 'MARPA_ERR_NONE', 'Grammar error name' );
Test::More::is( $error_description, 'No error', 'Grammar error description' );

$symbol_S = $grammar->symbol_new();
my $symbol_a = $grammar->symbol_new();
my $symbol_sep = $grammar->symbol_new();
$grammar->start_symbol_set($symbol_S);

# Marpa::R2::Display
# name: Thin sequence_new() example

my $sequence_rule_id = $grammar->sequence_new(
        $symbol_S,
        $symbol_a,
        {   separator => $symbol_sep,
            proper    => 0,
            min       => 1
        }
    );

# Marpa::R2::Display::End

$grammar->precompute();
my @events;
my $event_ix = $grammar->event_count();
while ( $event_ix-- ) {

# Marpa::R2::Display
# name: Thin event() example

    my ( $event_type, $value ) = $grammar->event( $event_ix++ );

# Marpa::R2::Display::End

}

$recce = Marpa::R2::Thin::R->new($grammar);

# Marpa::R2::Display
# name: Thin ruby_slippers_set() example

$recce->ruby_slippers_set(1);

# Marpa::R2::Display::End

$recce->start_input();
$recce->alternative( $symbol_a, 1, 1 );
$recce->earleme_complete();

# Marpa::R2::Display
# name: Thin terminals_expected() example

   my @terminals = $recce->terminals_expected();

# Marpa::R2::Display::End

Test::More::is( (scalar @terminals), 1, 'count of terminals expected' );
Test::More::is( $terminals[0], $symbol_sep, 'expected terminal' );

my $report;

# Marpa::R2::Display
# name: Thin progress_item() example

    my $ordinal = $recce->latest_earley_set();
    $recce->progress_report_start($ordinal);
    ITEM: while (1) {
        my ($rule_id, $dot_position, $origin) = $recce->progress_item();
        last ITEM if not defined $rule_id;
        push @{$report}, [$rule_id, $dot_position, $origin];
    }
    $recce->progress_report_finish();

# Marpa::R2::Display::End

Test::More::is( ( join q{ }, map { @{$_} } @{$report} ),
    '0 -1 0 0 0 0', 'progress report' );

$recce->alternative( $symbol_sep, 1, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_a, 1, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_sep, 1, 1 );
$recce->earleme_complete();
$recce->alternative( $symbol_a, 1, 1 );
$recce->earleme_complete();
$latest_earley_set_ID = $recce->latest_earley_set();
$bocage        = Marpa::R2::Thin::B->new( $recce, $latest_earley_set_ID );
$order         = Marpa::R2::Thin::O->new($bocage);
$tree          = Marpa::R2::Thin::T->new($order);
$tree->next();
my $valuator = Marpa::R2::Thin::V->new($tree);
$valuator->rule_is_valued_set( $sequence_rule_id, 1 );
my $locations_report = q{};
STEP: for ( ;; ) {
    my ( $type, @step_data ) = $valuator->step();
    last STEP if not defined $type;

# Marpa::R2::Display
# name: Thin location() example

    $type = $valuator->step_type();
    my ( $start, $end ) = $valuator->location();
    if ( $type eq 'MARPA_STEP_RULE' ) {
        my ($rule_id) = @step_data;
        $locations_report .= "Rule $rule_id is from $start to $end\n";
    }
    if ( $type eq 'MARPA_STEP_TOKEN' ) {
        my ($token_id) = @step_data;
        $locations_report .= "Token $token_id is from $start to $end\n";
    }
    if ( $type eq 'MARPA_STEP_NULLING_SYMBOL' ) {
        my ($symbol_id) = @step_data;
        $locations_report
            .= "Nulling symbol $symbol_id is from $start to $end\n";
    }

# Marpa::R2::Display::End

} ## end STEP: for ( ;; )

Test::More::is( $locations_report, <<'EXPECTED', 'Step locations' );
Token 1 is from 0 to 1
Token 2 is from 1 to 2
Token 1 is from 2 to 3
Token 2 is from 3 to 4
Token 1 is from 4 to 5
Rule 0 is from 0 to 5
EXPECTED

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
