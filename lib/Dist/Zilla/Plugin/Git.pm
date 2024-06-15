use 5.008;
use strict;
use warnings;

package Dist::Zilla::Plugin::Git;
# ABSTRACT: Update your git repository after release

our $VERSION = '2.051';

1;
__END__

=pod

=head1 DESCRIPTION

This set of plugins for L<Dist::Zilla> can do interesting things for
module authors using Git (L<https://git-scm.com>) to track their work.

You need Git 1.5.4 or later to use these plugins.  Some plugins
require a more recent version of Git for certain features.

=head2 The @Git Bundle

The most commonly used plugins are part of the
L<@Git bundle|Dist::Zilla::PluginBundle::Git>.  They are:

=over 4

=item * L<Git::Check|Dist::Zilla::Plugin::Git::Check>

Before a release, check that the repo is in a clean state
(you have committed your changes).

=item * L<Git::Commit|Dist::Zilla::Plugin::Git::Commit>

After a release, commit updated files.

=item * L<Git::Tag|Dist::Zilla::Plugin::Git::Tag>

After a release, tag the just-released version.

=item * L<Git::Push|Dist::Zilla::Plugin::Git::Push>

After a release, push the released code & tag to your public repo.

=back

=head2 Non-Bundled Plugins

The other plugins in this distribution are not included in the @Git
bundle, either because they conflict with L<Dist::Zilla>'s
L<@Basic bundle|Dist::Zilla::PluginBundle::Basic> or because they
have more specialized uses.

=over 4

=item * L<Git::CommitBuild|Dist::Zilla::Plugin::Git::CommitBuild>

Commits the released files to a separate branch of your repo.

=item * L<Git::GatherDir|Dist::Zilla::Plugin::Git::GatherDir>

A replacement for Dist::Zilla's standard
L<GatherDir|Dist::Zilla::Plugin::GatherDir> plugin that gathers
files based on whether they are tracked by Git (conflicts with @Basic
because that includes GatherDir).

=item * L<Git::Init|Dist::Zilla::Plugin::Git::Init>

Can be used in a minting profile
(L<http://dzil.org/tutorial/minting-profile.html>)
to initialize and configure your Git repo automatically
when you do S<C<dzil new>>.

=item * L<Git::NextVersion|Dist::Zilla::Plugin::Git::NextVersion>

Calculates the version number of your distribution from your Git tags
using L<Version::Next>.

=back

=cut
