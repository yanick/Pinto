package Pinto::Tester::Util;

# ABSTRACT: Static helper functions for testing

use strict;
use warnings;

use Carp;
use Path::Class;
use File::Temp qw(tempdir);
use Module::Faker::Dist;

use Pinto::Schema;

use base 'Exporter';

#-------------------------------------------------------------------------------

# VERSION

#-------------------------------------------------------------------------------

our @EXPORT_OK = qw( make_dist_obj
                     make_pkg_obj
                     make_dist_struct
                     make_dist_archive
                     parse_pkg_spec
                     parse_dist_spec
                     parse_reg_spec );

#-------------------------------------------------------------------------------

sub make_pkg_obj {
    my %attrs = @_;
    return Pinto::Schema->resultset('Package')->new_result( \%attrs );
}

#------------------------------------------------------------------------------

sub make_dist_obj {
    my %attrs = @_;
    return Pinto::Schema->resultset('Distribution')->new_result( \%attrs );
}

#------------------------------------------------------------------------------

sub make_dist_archive {
    my ($spec_or_struct) = @_;

    my $struct    = ref $spec_or_struct eq 'HASH' ? $spec_or_struct
                                                  : make_dist_struct( $spec_or_struct );

    my $temp_dir     = tempdir(CLEANUP => 1 );
    my $fake_dist    = Module::Faker::Dist->new( $struct );
    my $fake_archive = $fake_dist->make_archive( {dir => $temp_dir} );

    return file($fake_archive);
}

#------------------------------------------------------------------------------

sub make_dist_struct {
    my ($spec) = @_;

    my ($dist, $provides, $requires) = parse_dist_spec($spec);

    for my $provision ( @{ $provides } ) {
        my $version = $provision->{version};
        my $name    = $provision->{name};
        my $file    = "lib/$name.pm";
        $dist->{provides}->{ $name } = { file => $file, version => $version };
    }

    for my $requirement ( @{ $requires } ) {
        my $version = $requirement->{version};
        my $name    = $requirement->{name};
        $dist->{requires}->{ $name } = $version;
    }

    return $dist;
}


#------------------------------------------------------------------------------

sub parse_dist_spec {
    my ($spec) = @_;

    # AUTHOR / Foo-1.2 = Foo~1.0,Bar~2 & Baz~1.1,Nuts~2.3
    # -------- -------   -------------   ----------------
    #    |        |             |               |
    #  auth*    dist         provides       requires*
    #
    # * means optional (including the delimiter)
    #   All whitespace is ignored too

    $spec =~ s{\s+}{}g;  # Remove any whitespace
    $spec =~ m{ ^ (?: ([^/]+) /)? (.+) = ([^&]+) (?: & (.+) )? $ }mx
        or confess "Could not parse distribution spec: $spec";

    my ($author, $dist, $provides, $requires) = ($1, $2, $3, $4);

    $dist = parse_pkg_spec($dist);
    $dist->{cpan_author} = $author || 'LOCAL';

    my @provides = map { parse_pkg_spec($_) } split /,/, $provides || '';
    my @requires = map { parse_pkg_spec($_) } split /,/, $requires || '';

    return ($dist, \@provides, \@requires);
}

#------------------------------------------------------------------------------

sub parse_pkg_spec {
    my ($spec) = @_;

    # Looks like: "Foo" or "Foo-1" or "Foo-Bar-2.3.4_1"
    $spec =~ m/^ ( .+? ) (?: [~-] ( [\d\._]+ ) )? $/x
        or confess "Could not parse spec: $spec";

    return {name => $1, version => $2 || 0};
}

#------------------------------------------------------------------------------

sub parse_reg_spec {
    my ($spec) = @_;

    # Remove all whitespace from spec
    $spec =~ s{\s+}{}g;

    # Spec looks like "AUTHOR/Foo-Bar-1.2/Foo::Bar-1.2/stack/+"
    my ($author, $dist_archive, $pkg, $stack_name, $is_pinned) = split m{/}x, $spec;

    # Spec must at least have these
    confess "Could not parse pkg spec: $spec"
       if not ($author and $dist_archive and $pkg);

    # Append the usual suffix to the archive
    $dist_archive .= '.tar.gz' unless $dist_archive =~ m{\.tar\.gz$}x;

    # Normalize the is_pinned flag
    $is_pinned = ($is_pinned eq '+' ? 1 : 0) if defined $is_pinned;

    # Parse package name/version
    my ($pkg_name, $pkg_version) = split m{~}x, $pkg;

    # Set defaults
    $stack_name  ||= 'init';
    $pkg_version ||= 0;

    return ($author, $dist_archive, $pkg_name, $pkg_version, $stack_name, $is_pinned);
}

#------------------------------------------------------------------------------

1;

__END__
