package MooX::Role::DependsOn;
use strictures 1; no warnings 'recursion';

use List::Objects::WithUtils 2;
use List::Objects::Types -all;

use Scalar::Util 'refaddr', 'reftype';

use Types::TypeTiny ();

use Moo::Role; use MooX::late 0.014;

has dependency_tag => (
  is      => 'rw',
  default => sub { my ($self) = @_; "$self" },
);

has __depends_on => (
  is      => 'ro',
  isa     => TypedArray[ Types::TypeTiny::to_TypeTiny(sub { 
      blessed $_ and $_->can('does') and $_->does('MooX::Role::DependsOn') 
    })
  ]
);

sub depends_on {
  my ($self, $node) = @_;
  defined $node ? $self->__depends_on->push($node)
    : @{ $self->__depends_on }
}

sub __resolve_deps {
  my ($self, $node, $resolved, $res_by_tag, $unresolved) = @_;

  $res_by_tag  ||= +{};
  $unresolved  ||= +{};

  my $item = $node->dependency_tag;

  $unresolved->{$item} = 1;

  DEP: for my $edge ($node->depends_on) {
    my $depitem = $edge->dependency_tag;
    next DEP if exists $res_by_tag->{$depitem};
    if (exists $unresolved->{$depitem}) {
      die "Circular dependency detected: $item -> $depitem\n"
    }
    __resolve_deps($self, $edge, $resolved, $res_by_tag, $unresolved)
  }

  push @$resolved, $node;
  $res_by_tag->{$item} = delete $unresolved->{$item};
  ()
}

sub scheduled {
  my ($self, %params) = @_;

  my $res_by_tag;
  if (defined $params{skip}) {
    confess "Expected 'skip' param to be an ARRAY type"
      unless reftype $params{skip} eq 'ARRAY';
    $res_by_tag = +{
      map {; "$_" => 1 } @{ $params{skip} }
    };
  }

  my $resolved = [];
  $self->__resolve_deps($self, $resolved, $res_by_tag);
  $resolved
}


1;

# vim: ts=2 sw=2 et sts=2 ft=perl
