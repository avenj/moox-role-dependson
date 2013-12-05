use Test::More;
use strict; use warnings FATAL => 'all';

{ package
    BareConsumer; use strict; use warnings;
  use Moo;
  with 'MooX::Role::DependsOn';
}


# basic schedule, default dependency_tag:

my $nA = BareConsumer->new;
my $nB = BareConsumer->new;
my $nC = BareConsumer->new;
my $nD = BareConsumer->new;
my $nE = BareConsumer->new;

$nA->depends_on($nB, $nD);  # A deps on B, D
$nB->depends_on($nC, $nE);  # B deps on C, E
$nC->depends_on($nD, $nE);  # C deps on D, E

my @deplist = $nA->depends_on;
is_deeply \@deplist,
  [ $nB, $nD ],
  'depends_on list ok'
    or diag explain \@deplist;

my @result = $nA->dependency_schedule;

is_deeply \@result,
  [ $nD, $nE, $nC, $nB, $nA ],
  'simple deps resolved ok'
    or diag explain \@result;


# circular dep:

$nD->depends_on($nB);  # D deps on B, B deps on C, C deps on D
eval {; $nA->dependency_schedule };
like $@, qr/Circular dependency/, 'circular dep died ok';


# FIXME tests for:
#  - obj with initial depends_on
#  - has_dependencies
#  - clear_dependencies
#  - custom dependency_tag
#  - resolution callbacks
#  - failures:
#    - type failures (depends_on fed bad item)


done_testing
