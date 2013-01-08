#!perl

use 5.010;
use strict;
use warnings;
use English qw( -no_match_vars );

use Getopt::Long;
use Marpa::R2;

my $do_demo = 0;
my $getopt_result = GetOptions( "demo!" => \$do_demo, );

sub usage {
    die <<"END_OF_USAGE_MESSAGE";
$PROGRAM_NAME --demo
$PROGRAM_NAME 'exp' [...]

Run $PROGRAM_NAME with either the "--demo" argument
or a series of calculator expressions.
END_OF_USAGE_MESSAGE
} ## end sub usage

if ( not $getopt_result ) {
    usage();
}
if ($do_demo) {
    if ( scalar @ARGV > 0 ) { say join " ", @ARGV; usage(); }
}
elsif ( scalar @ARGV <= 0 ) { usage(); }

my $rules = <<'END_OF_GRAMMAR';
:start ::= script
script ::= expression
script ::= (script ';') expression
reduce_op ::= '+' | '-' | '/' | '*'
expression ::=
     NUM
   | VAR action => do_is_var
   | ('(') expression (')') assoc => group
  || '-' expression action => do_negate
  || expression '^' expression action => do_caret assoc => right
  || expression '*' expression action => do_star
   | expression '/' expression action => do_slash
  || expression '+' expression action => do_plus
   | expression '-' expression action => do_minus
  || expression ',' expression action => do_array
  || reduce_op 'reduce' expression action => do_reduce
  || VAR '=' expression action => do_set_var

NUM ~ [\d]+
VAR ~ [\w]+
:discard ~ whitespace
whitespace ~ [\s]+
# allow comments
:discard ~ <hash comment>
<hash comment> ~ <terminated hash comment> | <unterminated
   final hash comment>
<terminated hash comment> ~ '#' <hash comment body> <vertical space char>
<unterminated final hash comment> ~ '#' <hash comment body>
<hash comment body> ~ <hash comment char>*
<vertical space char> ~ [\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
<hash comment char> ~ [^\x{A}\x{B}\x{C}\x{D}\x{2028}\x{2029}]
END_OF_GRAMMAR

my $grammar = Marpa::R2::Scanless::G->new(
    {   action_object  => 'My_Actions',
        default_action => 'do_arg0',
        source          => \$rules,
    }
);

my %binop_closure = (
    '*' => sub { $_[0] * $_[1] },
    '/' => sub {
        Marpa::R2::Context::bail('Division by zero') if not $_[1];
        $_[0] / $_[1];
    },
    '+' => sub { $_[0] + $_[1] },
    '-' => sub { $_[0] - $_[1] },
    '^' => sub { $_[0]**$_[1] },
);

my %symbol_table = ();

package main;

# For debugging
sub add_brackets {
    my ( undef, @children ) = @_;
    return $children[0] if 1 == scalar @children;
    my $original = join q{}, grep {defined} @children;
    return '[' . $original . ']';
} ## end sub add_brackets

sub calculate {
    my ($p_string) = @_;

    %symbol_table = ();

    my $recce = Marpa::R2::Scanless::R->new( { grammar => $grammar } );

    my $self = bless { grammar => $grammar }, 'My_Actions';
    $self->{slr} = $recce;
    local $My_Actions::SELF = $self;

    if ( not defined eval { $recce->read($p_string); 1 } ) {

        # Add last expression found, and rethrow
        my $eval_error = $EVAL_ERROR;
        chomp $eval_error;
        die $self->show_last_expression(), "\n", $eval_error, "\n";
    } ## end if ( not defined eval { $recce->read($p_string); 1 })
    my $value_ref = $recce->value();
    if ( not defined $value_ref ) {
        die $self->show_last_expression(), "\n",
            "No parse was found, after reading the entire input\n";
    }
    return ${$value_ref};

} ## end sub calculate

sub report_calculation {
    my ($string) = @_;
    my $output   = qq{Input: "$string"\n};
    my $result   = calculate(\$string);
    $result = join q{,}, @{$result} if ref $result eq 'ARRAY';
    $output .= "  Parse: $result\n";
    for my $symbol ( sort keys %symbol_table ) {
        $output .= qq{"$symbol" = "} . $symbol_table{$symbol} . qq{"\n};
    }
    return $output;
} ## end sub report_calculation

if (@ARGV) {
    my $result = calculate( join ';', grep {/\S/} @ARGV );
    $result = join q{,}, @{$result} if ref $result eq 'ARRAY';
    say "Result is ", $result;
    for my $symbol ( sort keys %symbol_table ) {
        say qq{"$symbol" = "} . $symbol_table{$symbol} . qq{"};
    }
    exit 0;
} ## end if (@ARGV)

my $output = join q{},
    report_calculation('4 * 3 + 42 / 1'),
    report_calculation('4 * 3 / (a = b = 5) + 42 - 1'),
    report_calculation('4 * 3 /  5 - - - 3 + 42 - 1'),
    report_calculation('a=1;b = 5;  - a - b'),
    report_calculation('1 * 2 + 3 * 4 ^ 2 ^ 2 ^ 2 * 42 + 1'),
    report_calculation('+ reduce 1 + 2, 3,4*2 , 5')
    ;

print $output or die "print failed: $ERRNO";
$output eq <<'EXPECTED_OUTPUT' or die 'FAIL: Output mismatch';
Input: "4 * 3 + 42 / 1"
  Parse: 54
Input: "4 * 3 / (a = b = 5) + 42 - 1"
  Parse: 43.4
"a" = "5"
"b" = "5"
Input: "4 * 3 /  5 - - - 3 + 42 - 1"
  Parse: 40.4
Input: "a=1;b = 5;  - a - b"
  Parse: -6
"a" = "1"
"b" = "5"
Input: "1 * 2 + 3 * 4 ^ 2 ^ 2 ^ 2 * 42 + 1"
  Parse: 541165879299
Input: "+ reduce 1 + 2, 3,4*2 , 5"
  Parse: 19
EXPECTED_OUTPUT

package My_Actions;
our $SELF;
sub new { return $SELF }

sub do_is_var {
    my ( undef, $var ) = @_;
    my $value = $symbol_table{$var};
    Marpa::R2::Context::bail(qq{Undefined variable "$var"})
        if not defined $value;
    return $value;
} ## end sub do_is_var

sub do_set_var {
    my ( undef, $var, undef, $value ) = @_;
    return $symbol_table{$var} = $value;
}

sub do_negate {
    return -$_[2];
}

sub do_arg0 { return $_[1]; }
sub do_arg1 { return $_[2]; }
sub do_arg2 { return $_[3]; }

sub do_array {
    my ( undef, $left, undef, $right ) = @_;
    my @value = ();
    my $ref;
    if ( $ref = ref $left ) {
        Marpa::R2::Context::bail("Bad ref type for array operand: $ref")
            if $ref ne 'ARRAY';
        push @value, @{$left};
    }
    else {
        push @value, $left;
    }
    if ( $ref = ref $right ) {
        Marpa::R2::Context::bail("Bad ref type for array operand: $ref")
            if $ref ne 'ARRAY';
        push @value, @{$right};
    }
    else {
        push @value, $right;
    }
    return \@value;
} ## end sub do_array

sub do_binop {
    my ( $op, $left, $right ) = @_;
    my $closure = $binop_closure{$op};
    Marpa::R2::Context::bail(
        qq{Do not know how to perform binary operation "$op"})
        if not defined $closure;
    return $closure->( $left, $right );
} ## end sub do_binop

sub do_caret {
    my ( undef, $left, undef, $right ) = @_;
    return do_binop( '^', $left, $right );
}

sub do_star {
    my ( undef, $left, undef, $right ) = @_;
    return do_binop( '*', $left, $right );
}

sub do_slash {
    my ( undef, $left, undef, $right ) = @_;
    return do_binop( '/', $left, $right );
}

sub do_plus {
    my ( undef, $left, undef, $right ) = @_;
    return do_binop( '+', $left, $right );
}

sub do_minus {
    my ( undef, $left, undef, $right ) = @_;
    return do_binop( '-', $left, $right );
}

sub do_reduce {
    my ( undef, $op, undef, $args ) = @_;
    my $closure = $binop_closure{$op};
    Marpa::R2::Context::bail(
        qq{Do not know how to perform binary operation "$op"})
        if not defined $closure;
    $args = [$args] if ref $args eq '';
    my @stack = @{$args};
    OP: while (1) {
        return $stack[0] if scalar @stack <= 1;
        my $result = $closure->( $stack[-2], $stack[-1] );
        splice @stack, -2, 2, $result;
    }
    Marpa::R2::Context::bail('Should not get here');
} ## end sub do_reduce

sub show_last_expression {
    my ($self) = @_;
    my $slr = $self->{slr};
    my ( $start, $end ) = $slr->last_completed_range('Expression');
    return 'No expression was successfully parsed' if not defined $start;
    my $last_expression = $slr->range_to_string( $start, $end );
    return "Last expression successfully parsed was: $last_expression";
} ## end sub show_last_expression

# vim: expandtab shiftwidth=4:
