package Dist::Zilla::Role::Git::Config;
# ABSTRACT: Check Git config has required information

our $VERSION = '2.046';

use Moose::Role;

use namespace::autoclean;
use Try::Tiny qw( catch try );

with 'Dist::Zilla::Role::Git::Repo';

sub check_config {
    my $self = shift;

    for my $key (qw(user.email user.name)) {
        try {
            $self->git->config($key);
        } catch {
            die "git $key is not set";
        };
    }

    return;
}

1;

__END__

=pod

=head1 DESCRIPTION

This role checks the Git config has both a C<user.email> and C<user.name>
available. These are required in order to create commits.

Consumers can call C<check_config> to do this.

=cut
