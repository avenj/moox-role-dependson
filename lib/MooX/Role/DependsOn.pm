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

my $ConsumerType = Types::TypeTiny::to_TypeTiny(
  sub { blessed $_ and $_->can('does') and $_->does('MooX::Role::DependsOn') }
);

has __depends_on => (
  init_arg => 'depends_on',
  lazy    => 1,
  is      => 'ro',
  isa     => TypedArray[$ConsumerType],
  coerce  => 1,
  default => sub { array_of $ConsumerType },
);

sub depends_on {
  my ($self, @nodes) = @_;
  return @{ $self->__depends_on } unless @nodes;
  $self->__depends_on->push(@nodes)
}

sub clear_dependencies {
  my ($self) = @_;
  $self->__depends_on->clear
}

sub has_dependencies {
  my ($self) = @_;
  $self->__depends_on->has_any
}

sub __resolve_deps {
  my ($self, $params) = @_;

  my $node       = $params->{node};
  my $resolved   = $params->{resolved};
  my $skip       = $params->{skip}       ||= +{};
  my $unresolved = $params->{unresolved} ||= +{};

  my $item = $node->dependency_tag;

  $unresolved->{$item} = 1;

  DEP: for my $edge ($node->depends_on) {
    my $depitem = $edge->dependency_tag;
    next DEP if exists $skip->{$depitem};
    if (exists $unresolved->{$depitem}) {
      die "Circular dependency detected: $item -> $depitem\n"
    }
    __resolve_deps( $self,
      +{ 
        node => $edge, 
        skip => $skip, 
        
        resolved   => $resolved,
        unresolved => $unresolved ,
      }
    )
  }

  push @$resolved, $node;
  $skip->{$item} = delete $unresolved->{$item};

  if (my $cb = $params->{callback}) {
    $self->$cb(
      $node,                  # Node we just scheduled
      [ @$resolved ],         # Scheduled nodes 
      [ keys %$unresolved ],  # Nodes in the process of being scheduled   
    )
  }

  ()
}

sub dependency_schedule {
  my ($self, %params) = @_;

  my $cb;
  if ($cb = $params{callback}) {
    confess "Expected 'callback' param to be a coderef"
      unless ref $cb
      and reftype $cb eq 'CODE';
  }

  my $resolved = [];
  $self->__resolve_deps(
    +{
      node     => $self,
      resolved => $resolved,
      ( defined $cb   ? (callback => $cb)   : () ),
    },
  );

  @$resolved
}


1;

=pod

=head1 NAME

MooX::Role::DependsOn - Add a dependency tree to your cows

=head1 SYNOPSIS

  package Task;
  use Moo;
  with 'MooX::Role::DependsOn';

  sub execute {
    my ($self) = @_;
    # ... do stuff ...
  }

  package main;
  # Create some objects that consume MooX::Role::DependsOn:
  my $job = {};
  for my $jobname (qw/ A B C D E /) {
    $job->{$jobname} = Task->new
  }

  # Add some dependencies:
  # A depends on B, D:
  $job->{A}->depends_on( $job->{B}, $job->{D} );
  # B depends on C, E:
  $job->{B}->depends_on( $job->{C}, $job->{E} );
  # C depends on D, E:
  $job->{C}->depends_on( $job->{D}, $job->{E} );

  # Resolve dependencies (recursively) for an object:
  my @ordered = $job->{A}->dependency_schedule;
  # -> scheduled as ( D, E, C, B, A ):
  for my $obj (@ordered) {
    $obj->execute;
  }

=head1 DESCRIPTION

A L<Moo::Role> that adds a dependency graph builder to your class; objects
with this role applied can recursively depend on other objects with this role
applied.

This is useful for tasks such as job ordering (see the SYNOPSIS) and resolving
software dependencies.

=head2 Attributes

=head3 dependency_tag

An object's B<dependency_tag> is used to perform the actual resolution; the
tag should be a stringifiable value that is unique within the tree.

Defaults to the stringified value of C<$self>.

=head2 Methods

=head3 depends_on

If passed no arguments, returns the current direct dependencies of the object
as a list.

If passed objects that are L<MooX::Role::DependsOn> consumers, the objects are
pushed to the current dependency list.

=head3 clear_dependencies

Clears the current dependency list for this object.

=head3 has_dependencies

Returns boolean true if the object has dependencies.

=head3 dependency_schedule

This method recursively resolves dependencies and returns an ordered
'schedule' (as a list of objects). See the L</SYNOPSIS> for an example.

An exception is thrown if circular dependencies are detected.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut

# vim: ts=2 sw=2 et sts=2 ft=perl
