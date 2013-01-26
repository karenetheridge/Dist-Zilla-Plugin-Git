package Dist::Zilla::Role::Git::Repo;

# ABSTRACT: Provide repository information for Git plugins

use Moose::Role;

has 'repo_root'   => ( is => 'ro', isa => 'Str', default => '.' );

=method git

  $git = $plugin->git;

This method returns a Git::Wrapper object for the C<repo_root>
directory, constructing one if necessary.  The object is shared
between all plugins that consume this role (if they have the same
C<repo_root>).

=cut

my %cached_wrapper;

sub git {
  my $root = shift->repo_root;

  $cached_wrapper{$root} ||= do {
    require Git::Wrapper;
    Git::Wrapper->new( $root );
  };
}

1;


__END__

=pod

=head1 DESCRIPTION

This role is used within the Git plugins to get information about the
repository structure, and to create a Git::Wrapper object.

=attr repo_root

The repository root, either as a full path or relative to the distribution root. Default is C<.>.

