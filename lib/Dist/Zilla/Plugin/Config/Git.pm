package Dist::Zilla::Plugin::Config::Git;

# VERSION
# ABSTRACT: Plugin configuration containing settings for a Git repo

#############################################################################
# Modules

use sanity;
use Moose;
use Type::Utils -all;
use Types::Standard qw(Str ArrayRef RegexpRef);

with 'Dist::Zilla::Role::Plugin';

use namespace::clean;
no warnings 'uninitialized';

#############################################################################
# Regular Expressions (for subtypes)

### NOTE: Subtypes are responsible for using ^$ ###

# RegExp rule based on git-check-ref-format
my $valid_ref_name = qr%
   (?!
      # begins with
      /|                # (from #6)   cannot begin with /
      # contains
      .*(?:
         [/.]\.|        # (from #1,3) cannot contain /. or ..
         //|            # (from #6)   cannot contain multiple consecutive slashes
         @\{|           # (from #8)   cannot contain a sequence @{
         \\             # (from #9)   cannot contain a \
      )
   )
                        # (from #2)   (waiving this rule; too strict)
   [^\040\177 ~^:?*[]+  # (from #4-5) valid character rules

   # ends with
   (?<!\.lock)          # (from #1)   cannot end with .lock
   (?<![/.])            # (from #6-7) cannot end with / or .
%x;

# based mostly on git-clone
### XXX: While not technically valid, we're making \s illegal everywhere for sanity ###

my $valid_git_repo = qr%
   # standard ref name
   # XXX: This is probably wrong, but it works for now.
   $valid_ref_name|

   # valid URL (with standard git schemes)
   (?:
      (?:ssh|git|https?|ftps?|rsync|file)://   # scheme
      (?:[^\s@]+\@)?     # user
      [\w\d\.\[\]\:]+    # host/port
      /*\S+              # dir/file
   )|

   # non-scheme URL format
   (?:
      (?:[^\s@]+\@)?     # user
      [\w\d\.\[\]]+      # host
      :
      /*\S+              # dir/file
   )|

   # filename
   (?:
      (?:\.\.)?[\\/]+  # ../ or ..\ or / or \
      \S+              # (Thanks UNIX!)
   )
%x;

#############################################################################
# Subtypes

my $GitRepo = declare 'GitRepo',
   as Str,
   where { /^$valid_git_repo$/ }
;

my $GitBranch = declare 'GitBranch',
   as Str,
   where { /^$valid_ref_name$/ }
;

#############################################################################
# Attributes

has remote => (
   is       => 'ro',
   isa      => $GitRepo,
   default  => 'origin',
);

has local_branch => (
   is       => 'ro',
   isa      => $GitBranch,
   default  => 'master',
);

has remote_branch => (
   is       => 'ro',
   isa      => $GitBranch,
   lazy     => 1,
   default  => sub { shift->local_branch },
);

has allow_dirty => (
   is      => 'ro',
   isa     => ArrayRef[Str|RegexpRef],
   lazy    => 1,
   default => sub { [ 'dist.ini', shift->changelog ] },
);

has changelog => (
   is       => 'ro',
   isa      => 'Str',
   default  => 'Changes',
);

sub mvp_multivalue_args { qw(allow_dirty) }

#############################################################################
# Pre/post-BUILD

sub BUILDARGS {
   my ($class, @arg) = @_;
   my %copy = ref $arg[0] ? %{$arg[0]} : @arg;

   my $zilla = delete $copy{zilla};

   # Morph allow_dirty REs
   if (defined $copy{allow_dirty}) {
      my @new;
      my @allow_dirty = ref $copy{allow_dirty} ? @{ $copy{allow_dirty} } : ($copy{allow_dirty});
      foreach my $filespec (@allow_dirty) {
         if ($filespec =~ m!
            # Mimic a real Perl qr with delimiters
            ^qr(?:
               <.+>|\(.+\)|\[.+\]||\{.+\}|   # <>, (), [], {}
               ([^\w\s]).+\1                 # any non-word/space character
            )$
         !x) {
            my $re = substr($filespec, 3, -1);
            push @new, qr/$re/;
         }
         else {
            push @new, $filespec;
         }
      }

      $copy{allow_dirty} = \@new;
   }

   return {
      zilla => $zilla,
      %copy,
   };
}

42;

__END__

=for Pod::Coverage mvp_multivalue_args

=begin wikidoc

= SYNOPSIS

   [Config::Git / Git::main]
   remote        = origin
   local_branch  = master
   remote_branch = master
   allow_dirty   = dist.ini
   allow_dirty   = README
   allow_dirty   = qr{\w+\.ini}
   changelog     = Changes

   [Git::CheckFor::CorrectBranch]
   git_config = Git::main

   [@Git]
   git_config = Git::main

   ; etc.

= DESCRIPTION

This is a configuration plugin for Git repo/branch information.  A configuration plugin is sort of like a Stash, but is better suited
for intra-plugin data sharing, using distro (not user) data.

Why use this?  To provide a standard set of information to other Git plugins easily, especially if the repo data is non-standard, or if
you need more than one set of data.

= OPTIONS

== remote

Name of the remote repo, in standard Git repo format (refspec or git URL).

Default is {origin}.

== local_branch

Name of the local branch name.

Default is {master}.

== remote_branch

Name of the remote branch name.

Default is {master}.

== allow_dirty

Filenames of files in the local repo that are allowed to have modifications prior to a write action, such as a commit.  Multiple lines
are allowed.  Any strings in standard {qr} notation are interpreted as regular expressions.

Default is {dist.ini} and whatever [changelog] is set to.

== changelog

Name of your change log.

Default is {Changes}.

= ACKNOWLEDGEMENTS

Kent Fredric and Karen Etheridge for implementation discussion.  Graham Knop for continuous code reviews.

=end wikidoc
