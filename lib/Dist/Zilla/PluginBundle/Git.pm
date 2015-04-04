use 5.008;
use strict;
use warnings;

package Dist::Zilla::PluginBundle::Git;
# ABSTRACT: all git plugins in one go


use Moose;
use Module::Runtime 'use_module';

with 'Dist::Zilla::Role::PluginBundle';

# bundle all git plugins
my @names   = qw{ Check Commit Tag Push };

my %multi;
for my $name (@names) {
    my $class = "Dist::Zilla::Plugin::Git::$name";
    use_module $class;
    @multi{$class->mvp_multivalue_args} = ();
}

sub mvp_multivalue_args { keys %multi; }

sub bundle_config {
    my ($self, $section) = @_;
    #my $class = ( ref $self ) || $self;
    my $arg   = $section->{payload};

    my @config;

    for my $name (@names) {
        my $class = "Dist::Zilla::Plugin::Git::$name";
        my %payload;
        foreach my $k (keys %$arg) {
            $payload{$k} = $arg->{$k} if $class->can($k);
        }
        push @config, [ "$section->{name}/$name" => $class => \%payload ];
    }

    return @config;
}


__PACKAGE__->meta->make_immutable;
no Moose;
1;
__END__

=for Pod::Coverage
    bundle_config
    mvp_multivalue_args

=head1 SYNOPSIS

In your F<dist.ini>:

    [@Git]
    changelog   = Changes             ; this is the default
    allow_dirty = dist.ini            ; see Git::Check...
    allow_dirty = Changes             ; ... and Git::Commit
    commit_msg  = v%v%n%n%c           ; see Git::Commit
    tag_format  = %v                  ; see Git::Tag
    tag_message = %v                  ; see Git::Tag
    push_to     = origin              ; see Git::Push


=head1 DESCRIPTION

This is a plugin bundle to load the most common Git plugins.
It is equivalent to:

    [Git::Check]
    [Git::Commit]
    [Git::Tag]
    [Git::Push]

Any options given are passed through to each plugin.  See each
plugin's documentation for the options it supports.  (Plugins just
ignore options they don't understand.)

=head1 SEE ALSO

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

For a list of Git plugins in this distribution that are not part of
this bundle, see L<Dist::Zilla::Plugin::Git>.
