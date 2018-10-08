use 5.010;
use strict;
use warnings;

package Dist::Zilla::Plugin::Git::Init;
# ABSTRACT: Initialize git repository on dzil new

our $VERSION = '2.046';

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

use MooseX::Types::Moose qw(Str Bool ArrayRef);
with 'Dist::Zilla::Role::AfterMint',
    'Dist::Zilla::Role::BeforeMint',
    'Dist::Zilla::Role::Git::Config';
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

has config_entries => (
  is   => 'ro',
  isa  => ArrayRef[Str],
  default => sub { [] },
);

sub mvp_multivalue_args { qw(config_entries remotes) }
sub mvp_aliases { return { config => 'config_entries', remote => 'remotes' } }

sub before_mint {
    my $self = shift;
    $self->check_config;
}

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
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=pod

=for Pod::Coverage
    after_mint before_mint mvp_aliases mvp_multivalue_args

=head1 SYNOPSIS

In your F<profile.ini>:

    [Git::Init]
    commit_message = initial commit  ; this is the default
    commit = 1                       ; this is the default
    branch =                         ; this is the default (means master)
    remote = origin git@github.com:USERNAME/%{lc}N.git ; no default
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

=back

=head2 Formatting options

You can use the following codes in C<commit_message>, C<config>, or C<remote>:

=over 4

=item C<%n>

A newline.

=item C<%N>

The distribution name.  You can also use C<%{lc}N> or C<%{uc}N> to get
the name in lower case or upper case, respectively.

=back

=cut
