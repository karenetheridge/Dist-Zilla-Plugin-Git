use 5.010;
use strict;
use warnings;

package Dist::Zilla::Plugin::Git::Init;
# ABSTRACT: Initialize git repository on dzil new

our $VERSION = '2.048';

our %transform = (
  lc => sub { lc shift },
  uc => sub { uc shift },
  '' => sub { shift },
);

use Moose;
use Git::Wrapper;
use String::Formatter method_stringf => {
  -as => '_format_string',
  codes => {
    n => sub { "\n" },
    N => sub { $transform{$_[1] || ''}->( $_[0]->zilla->name ) },
  },
};

use Types::Standard qw(Str Bool ArrayRef);
with 'Dist::Zilla::Role::AfterMint';
use namespace::autoclean;

has commit_message => (
    is      => 'ro',
    isa     => Str,
    default => 'initial commit',
);

has commit => (
    is      => 'ro',
    isa     => Bool,
    default => 1,
);

has branch => (
    is      => 'ro',
    isa     => Str,
    default => '',
);

has remotes => (
  is   => 'ro',
  isa  => ArrayRef[Str],
  default => sub { [] },
);

has push_urls => (
  is   => 'ro',
  isa  => ArrayRef[Str],
  default => sub { [] },
);

has config_entries => (
  is   => 'ro',
  isa  => ArrayRef[Str],
  default => sub { [] },
);

sub mvp_multivalue_args { qw(config_entries remotes push_url) }
sub mvp_aliases { return { config => 'config_entries', remote => 'remotes', push_url => 'push_urls' } }

sub after_mint {
    my $self = shift;
    my ($opts) = @_;
    my $git = Git::Wrapper->new("$opts->{mint_root}");
    $self->log("Initializing a new git repository in " . $opts->{mint_root});
    $git->init;

    foreach my $configSpec (@{ $self->config_entries }) {
      my ($option, $value) = split ' ', _format_string($configSpec, $self), 2;
      $self->log_debug("Configuring $option $value");
      $git->config($option, $value);
    }

    $git->add("$opts->{mint_root}");
    if ($self->commit) {
      my $message = 'Made initial commit';
      if (length $self->branch) {
        $git->checkout('-b', $self->branch);
        $message .= ' on branch ' . $self->branch;
      }
      $git->commit({message => _format_string($self->commit_message, $self)});
      $self->log($message);
    }

    foreach my $remoteSpec (@{ $self->remotes }) {
      my ($remote, $url) = split ' ', _format_string($remoteSpec, $self), 2;
      $self->log_debug("Adding remote $remote as $url");
      $git->remote(add => $remote, $url);
    }

    foreach my $remoteSpec (@{ $self->push_urls }) {
      my ($remote, $url) = split ' ', _format_string($remoteSpec, $self), 2;
      $self->log_debug("Setting push URL for remote $remote to $url");
      $git->remote('set-url' => $remote, '--push' => $url);
    }
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=pod

=for Pod::Coverage
    after_mint mvp_aliases mvp_multivalue_args

=head1 SYNOPSIS

In your F<profile.ini>:

    [Git::Init]
    commit_message = initial commit  ; this is the default
    commit = 1                       ; this is the default
    branch =                         ; this is the default (means master)
    remote = origin https://github.com/USERNAME/%N.git ; no default
    push_url = origin git@github.com:USERNAME/%{lc}N.git ; no default
    config = user.email USERID@cpan.org  ; there is no default

=head1 DESCRIPTION

This plugin initializes a git repository when a new distribution is
created with C<dzil new>.

=head2 Plugin options

The plugin accepts the following options:

=over 4

=item * commit_message - the commit message to use when checking in
the newly-minted dist. Defaults to C<initial commit>.

=item * commit - if true (the default), commit the newly-minted dist.
If set to a false value, add the files to the Git index but don't
actually make a commit.

=item * branch - the branch name under which the newly-minted dist is checked
in (if C<commit> is true). Defaults to an empty string, which means that
the Git default branch is used (master).

=item * config - a config setting to make in the repository.  No
config entries are made by default.  A setting is specified as
C<OPTION VALUE>.  This may be specified multiple times to add multiple entries.

=item * remote - a remote to add to the repository.  No remotes are
added by default.  A remote is specified as C<NAME URL>.  This may be
specified multiple times to add multiple remotes.

=item * push_url - the URL to use to push to a particular remote to add to
the repository.  No URLs are added by default.  A remote is specified as C<NAME URL>.
This may be specified multiple times to specify push URLs for multiple remotes, and
is not required if the URL is the same as the one already set for that remote.

Per the documentation for L<git-remote(1)>: Note that the push_url and the
corresponding URL specified with C<remote>, even though they can be set
differently, must still refer to the same place. What you pushed to the push URL
should be what you would see if you immediately fetched from the fetch URL (the URL
specified with C<remote>.) If you are trying to fetch from one place (e.g. your
upstream) and push to another (e.g. your publishing repository), use two
separate remotes.

This, therefore, is best used in cases where pushing requires authentication, but
pulling does not, or if pulling is via git or ssh, but pushing is via https, on the
same repository.

=back

=head2 Formatting options

You can use the following codes in C<commit_message>, C<config>, C<remote>, or C<push_url>:

=over 4

=item C<%n>

A newline.

=item C<%N>

The distribution name.  You can also use C<%{lc}N> or C<%{uc}N> to get
the name in lower case or upper case, respectively.

=back

=cut
