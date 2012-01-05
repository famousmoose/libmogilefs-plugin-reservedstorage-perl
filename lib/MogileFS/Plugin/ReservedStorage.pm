# ReservedStorage plugin for MogileFS

package MogileFS::Plugin::ReservedStorage;

use strict;
use warnings;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

use MogileFS::Server;
use MogileFS::Util;

sub conv_to_mb($) {
    my ($val) = @_;
    return undef if not defined $val;
    my ($n, $u) = ($val =~ /^(\d+(?:\.\d*))\s*([kMGT])[bB]?$/) 
        or return undef;

    $n /= 1024 if $u eq 'k';
    $n *= 1024 if $u eq 'G' || $u eq 'T';
    $n *= 1024 if $u eq 'T';
    return $n;
}


sub sort_devs_by_freespace {
    my @devices_with_weights;

    my $sto = Mgd::get_store();
    my $default_reserved = conv_to_mb $sto->server_setting('reserved_storage');

    foreach my $dev (@_) {
        next unless $dev->should_get_new_files;

        my $mb_resrv = conv_to_mb 
            $sto->server_setting('reserved_storage_dev_'.$dev->devid);
        $mb_resrv = $default_reserved if not defined $mb_resrv;
        $mb_resrv = 0 if not defined $mb_resrv;

        next if $dev->mb_free < $mb_resrv;
        
        my $percent = ($dev->mb_free - $mb_resrv) / $dev->{mb_total};
        next if $percent <= 0;

        my $weight = 100 * $percent;
        push @devices_with_weights, [$dev, $weight];
    }

    my @list = MogileFS::Util::weighted_list(@devices_with_weights);

    return @list;
}

sub load {
    MogileFS::register_global_hook( 'cmd_create_open_order_devices', sub {
        my $devices = shift;
        my $sorted_devs = shift;

        @$sorted_devs = sort_devs_by_freespace(@$devices);

        return 1;
    });

    return 1;
}

sub unload {
    # remove our hooks
    MogileFS::unregister_global_hook( 'cmd_create_open_order_devices' );

    return 1;
}


1;
