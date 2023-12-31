package Dist::Zilla::Plugin::Git::GatherDir;
# ABSTRACT: Gather all tracked files in a Git working directory

our $VERSION = '2.050';

use Moose;
extends 'Dist::Zilla::Plugin::GatherDir' => { -version => 4.200016 }; # exclude_match

=head1 SYNOPSIS

In your F<dist.ini>:

    [Git::GatherDir]
    root = .                     ; this is the default
    prefix =                     ; this is the default
    include_dotfiles = 0         ; this is the default
    include_untracked = 0        ; this is the default
    exclude_filename = dir/skip  ; there is no default
    exclude_match = ^local_      ; there is no default

=head1 DESCRIPTION

This is a trivial variant of the L<GatherDir|Dist::Zilla::Plugin::GatherDir>
plugin.  It looks in the directory named in the L</root> attribute and adds all
the Git tracked files it finds there (as determined by C<git ls-files>).  If the
root begins with a tilde, the tilde portion is passed through C<glob()> first.

Most users just need:

  [Git::GatherDir]

...and this will pick up all tracked files from the current directory into the
dist.  You can use it multiple times, as you can any other plugin, by providing
a plugin name.  For example, if you want to include external specification
files into a subdir of your dist, you might write:

  [Git::GatherDir]
  ; this plugin needs no config and gathers most of your files

  [Git::GatherDir / SpecFiles]
  ; this plugin gets all tracked files in the root dir and adds them under ./spec
  root   = ~/projects/my-project/spec
  prefix = spec

=cut

use List::Util 1.45 qw(uniq any);
use Types::Standard 'Bool';

use namespace::autoclean;

=head1 ATTRIBUTES

This plugin inherits attributes from L<Dist::Zilla::Plugin::GatherDir>, with the following
modifications:

=attr root

See L<Dist::Zilla::Plugin::GatherDir/root>.
It does not need to be the root of a
Git repository, but it must be inside a repository.

=attr include_untracked

By default, files not tracked by Git will not be gathered.  If this is
set to a true value, then untracked files not covered by a Git ignore
pattern (i.e. those reported by C<git ls-files -o --exclude-standard>)
are also gathered (and you'll probably want to use
L<Git::Check|Dist::Zilla::Plugin::Git::Check> to ensure all files are
checked in before a release).

C<include_untracked> requires at least Git 1.5.4, but you should
probably not use it if your Git is older than 1.6.5.2.  Versions
before that would not list files matched by your F<.gitignore>, even
if they were already being tracked by Git (which means they will not
be gathered, even though they should be).  Whether that is a problem
depends on the contents of your exclude files (including the global
one, if any).

=attr follow_symlinks

Git::GatherDir does not honor GatherDir's
L<follow_symlinks|Dist::Zilla::Plugin::GatherDir/follow_symlinks>
option.  While the attribute exists (because Git::GatherDir is a
subclass), setting it has no effect.

Directories that are symlinks will not be gathered.  Instead, you'll
get a message saying C<WARNING: %s is symlink to directory, skipping it>.
To suppress the warning, add that directory to C<exclude_filename> or
C<exclude_match>.  To gather the files in the symlinked directory, use
a second instance of GatherDir or Git::GatherDir with appropriate
C<root> and C<prefix> options.

Files which are symlinks are always gathered.

=cut

has include_untracked => (
  is  => 'ro',
  isa => Bool,
  default => 0,
);

around dump_config => sub
{
    my $orig = shift;
    my $self = shift;

    my $config = $self->$orig;

    $config->{+__PACKAGE__} = {
        include_untracked => $self->include_untracked ? 1 : 0,
        blessed($self) ne __PACKAGE__ ? ( version => $VERSION ) : (),
    };

    $self->log('WARNING: unused config variable "follow_symlinks"')
      if $config->{'Dist::Zilla::Plugin::GatherDir'}{follow_symlinks};

    delete @{$config->{'Dist::Zilla::Plugin::GatherDir'}}{qw(follow_symlinks)};

    return $config;
};

override gather_files => sub {
  my ($self) = @_;

  require Git::Wrapper;
  require Path::Tiny;

  my $root = '' . $self->root;

  # Convert ~ portion to real directory:
  $root =~ s{^(~[^\\/]*)([\\/])}{$self->_homedir($1) . $2}e;

  $root = Path::Tiny::path($root)->absolute($self->zilla->root);

  # Prepare to gather files
  my $git = Git::Wrapper->new($root->stringify);

  my @opts;
  @opts = qw(--cached --others --exclude-standard) if $self->include_untracked;

  my $exclude_regex = qr/\000/;
  $exclude_regex = qr/$exclude_regex|$_/
    for (@{ $self->exclude_match });

  my %is_excluded = map +($_ => 1), @{ $self->exclude_filename };

  my $prefix = $self->prefix;

  # Loop over files reported by git ls-files
  for my $filename (uniq $git->ls_files(@opts)) {
    # $file is a Path::Tiny relative to $root
    my $file = Path::Tiny::path($filename);

    $self->log_debug("considering $file");

    # Exclusion tests
    unless ($self->include_dotfiles) {
      next if grep /^\./, split q{/}, $file->stringify;
    }

    next if $file =~ $exclude_regex;
    next if $is_excluded{ $file };

    # skip if any directory in the path matches a 'prune_directory' regex.
    my @dirs = split /\//, $file->dirname;
    next if any {
      my $pd = $_;
      any { $_ =~ $pd } @dirs;
    }
    @{ $self->prune_directory };

    # DZil can't gather directory symlinks
    my $path = $root->child($file);

    if (-d $path) {
      $self->log("WARNING: $file is symlink to directory, skipping it");
      next;
    }

    # Gather the file
    my $fileobj = $self->_file_from_filename($path->stringify);

    $file = Path::Tiny::path($prefix, $file) if length $prefix;

    $fileobj->name($file->stringify);
    $self->add_file($fileobj);
    $self->log_debug("gathered $file");
  }

  return;
};

sub _homedir {
  my ($self, $tilde_dir) = @_;

  # other architectures have no issue with globbing any kind of ~user path
  return (glob($tilde_dir))[0] if $^O ne 'Win32';

  # on Win32, we can use the environment variable(s) for the current user
  return "$]" < '5.016' ? $ENV{HOME} || $ENV{USERPROFILE} : (glob('~'))[0]
    if $tilde_dir eq '~';

  # but otherwise, we can't support this at all, on any version.
  $self->log_fatal('expanding "' . $tilde_dir . '" on Win32 not supported');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=for Pod::Coverage
    gather_dir
    gather_files

=cut
