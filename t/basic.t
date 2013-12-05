use Test::More;
use strict; use warnings FATAL => 'all';

{ package
    BareConsumer; use strict; use warnings;
  use Moo;
  with 'MooX::Role::DependsOn';
}

my $nA = BareConsumer->new;
my $nB = BareConsumer->new;
my $nC = BareConsumer->new;
my $nD = BareConsumer->new;
my $nE = BareConsumer->new;

$nA->depends_on($nB);  # A deps on B
$nA->depends_on($nD);  # A deps on D

$nB->depends_on($nC);  # B deps on C
$nB->depends_on($nE);  # B deps on E

$nC->depends_on($nD);  # C (and A) dep on D
$nC->depends_on($nE);  # C (and B) dep on E

my @result = $nA->dependency_schedule;

is_deeply \@result,
  [ $nD, $nE, $nC, $nB, $nA ],
  'simple deps resolved ok'
    or diag explain \@result;


done_testing
