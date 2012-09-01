use strict;
use warnings;

package Dist::Zilla::Plugin::Git::NextVersion;
# ABSTRACT: provide a version number by bumping the last git release tag

use Dist::Zilla 4 ();
use Git::Wrapper;
use Version::Next ();
use version 0.80 ();

use Moose;
use namespace::autoclean 0.09;
use MooseX::AttributeShortcuts;

with 'Dist::Zilla::Role::VersionProvider';
with 'Dist::Zilla::Role::Git::Repo';

# -- attributes

has version_regexp  => ( is => 'ro', isa=>'Str', default => '^v(.+)$' );

has first_version  => ( is => 'ro', isa=>'Str', default => '0.001' );

has _previous_versions => (

    traits  => ['Array'],
    is      => 'lazy',
    isa     => 'ArrayRef[Str]',
    handles => {

        has_previous_versions => 'count',
        last_version          => [ get => -1 ],
    },
);

# TODO:
# - control this behaviour with a config variable?
#   "ancestor_commits_only"
#
# - check if the selected tag version already exists - if so, bail with a
# fatal error saying to use V.

sub _build__previous_versions {
  my ($self) = @_;

  local $/ = "\n"; # Force record separator to be single newline

  my $git  = Git::Wrapper->new( $self->repo_root );
  my $regexp = $self->version_regexp;

  # build [ $tag, $version ] list in reverse version order,
  # for all tags matching the specified version regexp
  my @tags_and_versions =
    sort { version->parse($b->[1]) <=> version->parse($a->[1]) }
    map {
      /$regexp/ && eval { version->parse($1) }
          ? [ $_ => $1 ]
          : ()
    } $git->tag;

  # all ancestor commits (full SHA) of current HEAD
  my @all_commits = map { $_->id } $git->log({'simplify-by-decoration'=>1});

  # since we only care about the most recent (suitable) tag, we only check
  # against our ancestor commit list for the first such tag
  my $best;
  foreach my $tag_and_version(@tags_and_versions)
  {
    my $sha = $self->_sha_from_tag($tag_and_version->[0]);

    $best = $tag_and_version and last
        if grep { $_ =~ /^$sha/ } @all_commits;


  # while we still have the tag corresponding to the selected 
  # ... check if the next version (calculated later) will collide with a
  # tag we already have. if so, fatal error and suggest the user resolve it
  # with V+.
  }

    my $nextversion = Version::Next::next_version($best->[1]);
    my $match = grep { "$nextversion" eq $_->[0] } @tags_and_versions;
    if ($match)
    {
        fatal("most recent tag found '"$best->[0]" which would make the next version $best->[1], but this conflicts with the existing tag $match->[0]! Please explicitly provide a version with V=.");
    }

  return [] if not $best;
  return [ $best->[1] ];
}

sub _sha_from_tag
{
  my ($self, $tag) = @_;

  my $git  = Git::Wrapper->new( $self->repo_root );
  my ($tag_verbose) = $git->describe({tags => 1, long => 1}, $tag);
  my ($_tag, $revisions, $sha) = ($tag_verbose =~ m/^(.+)-([^-]+)-g([^-]+)$/);
  return $sha;
}

# -- role implementation

sub provide_version {
  my ($self) = @_;

  # override (or maybe needed to initialize)
  return $ENV{V} if exists $ENV{V};

  return $self->first_version
    unless $self->has_previous_versions;

  my $last_ver = $self->last_version;
  my $new_ver  = Version::Next::next_version($last_ver);
  $self->log("Bumping version from $last_ver to $new_ver");

  return "$new_ver";
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

__END__

=for Pod::Coverage
    provide_version

=head1 SYNOPSIS

In your F<dist.ini>:

    [Git::NextVersion]
    first_version = 0.001       ; this is the default
    version_regexp  = ^v(.+)$   ; this is the default

=head1 DESCRIPTION

This does the L<Dist::Zilla::Role::VersionProvider> role.  It finds the last
version number from your git tags, increments it using L<Version::Next>, and
uses the result as the C<version> parameter for your distribution.

The plugin accepts the following options:

=over

=item *

C<first_version> - if the repository has no tags at all, this version
is used as the first version for the distribution.  It defaults to "0.001".

=item *

C<version_regexp> - regular expression that matches a tag containing
a version.  It must capture the version into $1.  Defaults to ^v(.+)$
which matches the default C<tag_format> from L<Dist::Zilla::Plugin::Git::Tag>.
If you change C<tag_format>, you B<must> set a corresponsing C<version_regexp>.

=back

You can also set the C<V> environment variable to override the new version.
This is useful if you need to bump to a specific version.  For example, if
the last tag is 0.005 and you want to jump to 1.000 you can set V = 1.000.

  $ V=1.000 dzil release

=cut

