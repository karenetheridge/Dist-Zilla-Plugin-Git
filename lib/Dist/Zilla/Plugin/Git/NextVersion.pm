use strict;
use warnings;

package Dist::Zilla::Plugin::Git::NextVersion;
# ABSTRACT: provide a version number by bumping the last git release tag

use Dist::Zilla 4 ();
use Version::Next ();
use version 0.80 ();

use Moose;
use namespace::autoclean 0.09;
use MooseX::AttributeShortcuts;
use Try::Tiny;

with 'Dist::Zilla::Role::VersionProvider';
with 'Dist::Zilla::Role::Git::Repo';

# -- attributes

has version_regexp  => ( is => 'ro', isa=>'Str', default => '^v(.+)$' );

has first_version  => ( is => 'ro', isa=>'Str', default => '0.001' );

has version_by_branch  => ( is => 'ro', isa=>'Bool', default => 0 );

sub _max_version_from_tags {
  my ($regexp, $tags) = @_;

  my @versions = sort map {
    /$regexp/ ? try { version->parse($1) } : ()
  } @$tags;

  return $versions[-1]->stringify if @versions;

  return undef;
} # end _max_version_from_tags

sub _last_version {
  my ($self) = @_;

  my $last_ver;
  my $by_branch = $self->version_by_branch;
  my $git       = $self->git;
  my $regexp    = $self->version_regexp;
  $regexp       = qr/$regexp/;

  local $/ = "\n"; # Force record separator to be single newline

  if ($by_branch) {
    try {
      # Note: git < 1.6.1 doesn't understand --simplify-by-decoration or %d
      my @tags;
      for ($git->rev_list(qw(--simplify-by-decoration --pretty=%d HEAD))) {
        /^\s*\((.+)\)/ or next;
        push @tags, split /,\s*/, $1;
      } # end for lines from git log
      $last_ver = _max_version_from_tags($regexp, \@tags);
    };
    return $last_ver if defined $last_ver;
  } # end if version_by_branch

  # Consider versions from all branches:
  $last_ver = _max_version_from_tags($regexp, [ $git->tag ]);

  $self->log("WARNING: Unable to find version on current branch")
      if defined($last_ver) and $by_branch;

  return $last_ver;
}

# -- role implementation

sub provide_version {
  my ($self) = @_;

  # override (or maybe needed to initialize)
  return $ENV{V} if exists $ENV{V};

  my $last_ver = $self->_last_version;

  return $self->first_version
    unless defined $last_ver;

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
    version_by_branch = 0       ; this is the default
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

C<version_by_branch> - if true, consider only tags on the current
branch when looking for the previous version.  If you have a
maintenance branch for stable releases and a developement branch for
trial releases, you should set this to 1.  (You'll also need git
version 1.6.1 or later.)  The default is to look at all tags, because
finding the tags reachable from a branch is a more expensive operation
than simply listing all tags.

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

