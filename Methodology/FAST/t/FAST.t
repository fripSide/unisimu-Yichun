#: FAST.t
#: Test lib/FAST.pm
#: Copyright (c) 2006 Agent Zhang
#: 2006-03-08 2006-03-08

use strict;
use warnings;

use Test::More tests => 51;

use Test::MockObject;
use Test::Differences;

BEGIN { use_ok('FAST'); }

my $g = FAST->new('t/01sample');
ok $g;
isa_ok $g, 'FAST';

is_deeply(
    $g->{edge_to},
    {
        entry => ['<p>'],
        '<p>' => [qw< [c] [a] >],
        '[c]' => ['<q>'],
        '<q>' => ['<p>', 'exit'],
        '[a]' => ['[b]'],
        '[b]' => ['exit'],
        'exit' => [],
    }
);

is_deeply(
    $g->{edge_from},
    {
        'entry' => [],
        '<p>'   => [qw( entry <q> )],
        '<q>'   => ['[c]'],
        '[a]'   => ['<p>'],
        '[b]'   => ['[a]'],
        '[c]'   => ['<p>'],
        'exit'  => [qw( <q> [b] )],
    }
);

{
    # Test the plot_edge method:
    my $mock = Test::MockObject->new;
    $mock->set_true( 'add_edge' );

    $g->plot_edge($mock, '<p>', '[c]');
    $g->plot_edge($mock, '<p>', '[a]');
    $g->plot_edge($mock, '[a]', '[b]');

    is( $mock->call_pos(1),  'add_edge', 'plot_edge calls $gv->add_edge' );
    my @args = $mock->call_args(1);
    is_deeply(
        \@args,
        [$mock, qw( <p> [c] label Y )],
        'plot_edge calls $gv->add_edge with the right args'
    );

    is( $mock->call_pos(2),  'add_edge', 'plot_edge calls $gv->add_edge' );
    @args = $mock->call_args(2);
    is_deeply(
        \@args,
        [$mock, qw( <p> [a] label N )],
        'plot_edge calls $gv->add_edge with the right args'
    );

    is( $mock->call_pos(3),  'add_edge', 'plot_edge calls $gv->add_edge' );
    @args = $mock->call_args(3);
    is_deeply(
        \@args,
        [$mock, qw( [a] [b] )],
        'plot_edge calls $gv->add_edge with the right args'
    );
}

{
    # Test the plot_node method:
    my $mock = Test::MockObject->new;
    $mock->set_true( 'add_node' );
    
    $g->plot_node($mock, '[a]');
    $g->plot_node($mock, '<p>');
    $g->plot_node($mock, 'exit');

    is( $mock->call_pos(1),  'add_node', 'plot_node calls $gv->add_node for box node' );
    my @args = $mock->call_args(1);
    is shift(@args), $mock;
    is shift(@args), '[a]';
    my %opts = @args;
    is $opts{label}, 'a';
    is $opts{shape}, 'box';

    is( $mock->call_pos(2),  'add_node', 'plot_node calls $gv->add_node for diamond node' );
    @args = $mock->call_args(2);
    is shift(@args), $mock;
    is shift(@args), '<p>';
    %opts = @args;
    is $opts{label}, 'p';
    is $opts{shape}, 'diamond';

    is( $mock->call_pos(3),  'add_node', 'plot_node calls $gv->add_node for plain node' );
    @args = $mock->call_args(3);
    is shift(@args), $mock;
    is shift(@args), 'exit';
    %opts = @args;
    is $opts{label}, 'exit';
    is $opts{shape}, 'plaintext';
}

{
    # Test method as_png
    my $data = $g->as_png;
    ok $data;
    my $outfile = 't/01sample.png';
    unlink $outfile if -f $outfile;
    $g->as_png($outfile);
    ok -f $outfile;
}

{
    # Test the new/parse/error methods:
    my $g = FAST->new;
    ok !defined $g, 'call ->new with no arguments';
    is( FAST->error, "FAST::new: No input source specified.\n" );

    $g = FAST->new('no_such_file');
    ok !defined $g, 'call ->new with invalid file name';
    is( FAST->error, "FAST::parse: Can't open `no_such_file' for reading: $!\n" );

    my $src = <<'.';
[a] => [c]
[a => d s
.
    $g = FAST->new(\$src);
    ok !defined $g, 'syntax error in the source';
    is( FAST->error, "FAST::parse: STRING: line 2: syntax error: [a => d s\n" );

    $src = <<'.';
[a] => <p>
<p> => [a]
.
    $g = FAST->new(\$src);
    ok $g;
    isa_ok $g, 'FAST';

    is_deeply(
        $g->{edge_to},
        {
            '[a]' => ['<p>'],
            '<p>' => ['[a]'],
        }
    );

    is_deeply(
        $g->{edge_from},
        {
            '[a]' => ['<p>'],
            '<p>' => ['[a]'],
        }
    );

    my $asm = $g->as_asm;
    ok not $asm;
    is( $g->error, "as_asm: No `entry' node found.\n" );
}

{
    # Test the method as_asm:

    my $src = <<'.';
entry => <p>
<p> => [c]
[c] => <q>
<p> => [a]
<q> => <p>
<q> => exit
[a] => [b]
[b] => exit
.

    $g = FAST->new(\$src);
    ok $g;
    isa_ok ($g, 'FAST');

    # Test method node2asm:

    is $g->node2asm('<p>'), 'test p';
    is $g->node2asm('[a]'), 'do   a';
    is $g->node2asm('exit'), 'exit';

    my $asm = $g->as_asm;
    eq_or_diff( $asm, <<'_EOC_', 'as_asm' );
L1:
    test p
    jno  L2
    do   c
    test q
    jno  L3
    jmp  L1
L2:
    do   a
    do   b
L3:
    exit
_EOC_

    $g = FAST->new('t/01sample');
    ok $g;
    isa_ok ($g, 'FAST');

    my $asmfile = 't/01sample.asm';
    unlink $asmfile if -f $asmfile;
    ok $g->as_asm($asmfile);
    open (my $in, $asmfile);
    ok $in;
    undef $/;
    $asm = <$in>;
    eq_or_diff $asm, <<'_EOC_';
L1:
    test p
    jno  L2
    do   c
    test q
    jno  L3
    jmp  L1
L2:
    do   a
    do   b
L3:
    exit
_EOC_
    close $in;
}