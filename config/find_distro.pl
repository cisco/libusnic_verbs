#!/usr/bin/env perl

sub find_distro {
    my $distro;
    my $rhel_rel_path = "/etc/redhat-release";
    my $sles_rel_path = "/etc/SuSE-release";
    my $lsb_rel_path = "/etc/lsb-release";

    # RHEL 6, 7
    if (-r $rhel_rel_path) {
        $distro = `cat $rhel_rel_path | cut -d " " -f 7 | sed "s/^/rhel/" | sed "s/\\\./u/"`;
    }

    # SLES 12
    elsif (-r $sles_rel_path) {
        my $ver = `cat $sles_rel_path | grep "^VERSION" | tr -d " " | cut -d "=" -f 2`;
        chomp($ver);
        my $patchlevel = `cat $sles_rel_path | grep "^PATCHLEVEL" | tr -d " " | cut -d "=" -f 2`;
        $distro = "sles${ver}sp${patchlevel}";
    }

    # Ubuntu 14, 16 LTS
    elsif (-r $lsb_rel_path) {
        open(IN, $lsb_rel_path) ||
            die "Can't open $lsb_rel_path";
        my $lsb_fields;
        while (<IN>) {
            chomp;
            my ($field, $value) = split('=', $_);
            $lsb_fields->{$field} = $value;
        }
        close(IN);

        if ($lsb_fields->{'DISTRIB_ID'} eq "Ubuntu" &&
            $lsb_fields->{'DISTRIB_RELEASE'} eq "14.04") {
            $distro = "ubuntu1404lts";
        } elsif ($lsb_fields->{'DISTRIB_ID'} eq "Ubuntu" &&
            $lsb_fields->{'DISTRIB_RELEASE'} eq "16.04") {
            $distro = "ubuntu1604lts";
        } else {
            die "*** Unknown Linux distro: $lsb_fields->{'DISTRIB_ID'} / $lsb_fields->{'DISTRIB_RELEASE'}";
        }
    }

    # Shrug
    else {
        die "*** Unknown Linux distro -- aborting build";
    }

    chomp($distro);
    return $distro;
}

print(find_distro() . "\n");
exit(0);
