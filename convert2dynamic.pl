#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Config::General;
use Redis;
use Getopt::Long qw(:config no_ignore_case bundling);
use Data::Dumper;
use IO::All;
use Data::UUID;

my $ug = Data::UUID->new;

#my %opts;

#my $CTRL_PORT = 3161;
#my $CTRL_IP   = '127.0.0.1';
my $VERSION = '0.01';

#getopts( 'd:hr:c:I:P:v', \%opts );

GetOptions(
    my $opts = {
        redis  => '127.0.0.1:6379',
        config => '/opt/snmp_emul/etc/daemon.conf',
        step   => 200
    },
    'debug|d=i',
    'help|h!',
    'redis|r=s',
    'config|c=s',
    'version|v!',
    'counter=s@',
    'total_used=s@',
    'used_free=s@',
    'blank|b!',
    'step|s=i'
);

if ( $opts->{help} )
{
    print "usage $0 [--help|-h] [--version|-v] [--debug|-d level]  [--redis|-r ip:port] [-extra|-e OID,val] \n\n";
    print "\t -h \t\t\t\t this help\n";
    print "\t -v \t\t\t\t version and exit\n";
    print "\t -c conf_file \t\t configuration file to use (format: ip[:port],walk_file,[community]) current=$opts->{config}\n";
    print "\t -d level \t\t\t debug level (also possible to set by ENV variable DEBUG)\n";
    print "\t -r ip:port \t\t redis server to use for the DB (current=$opts->{redis})\n";
    print "\t --counter OID \t\t an OID to add to the list of counter and could be repeated\n";
    print "\t --total_used OID,OID \t total space OID separator used space OID , this peer is added in the total_used list and could be repeated\n";
    print "\t\t\t\t\t (the separator is anything that is not a dot or a digit, be care of the shell specification) \n";
    print "\t --used_free OID,OID \t used space OID separator free space OID , this peer is added in the used_free list and could be repeated\n";
    print "\t\t\t\t\t (the separator is anything that is not a dot or a digit, be care of the shell specification) \n";
    print "\t --blank|-b \t\t don't insert the result (running at blank)\n";
    print "\t --step|-s \t\t the number of step to increment a counter before it reach the limit (current=$opts->{step})\n";
    exit;
}

my $DEBUG = $opts->{debug} // $ENV{DEBUG} // 0;

if ( $opts->{version} )
{
    die "$0 v$VERSION (c) DULAUNOY Fabrice, 2009-2013\n";
}

$opts->{step} ||= 200;

my $redis = Redis->new(
    server => $opts->{redis},
    debug  => 0
);
$redis->select( 4 );    # use DB nbr 4 ( why not !!!)
my @listeners = io( $opts->{config} )->chomp->slurp;

my @counters_list = qw(
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.2.1.31.1.1.1.6.
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.4.1.8962.2.1.3.1.1.3.1.5.2.
  .1.3.6.1.2.1.2.2.1.10.
  .1.3.6.1.2.1.31.1.1.1.6.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.2.1.31.1.1.1.10.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.4.1.8962.2.1.3.1.1.3.1.11.2.
  .1.3.6.1.2.1.2.2.1.16.
  .1.3.6.1.2.1.31.1.1.1.10.
);

my @total_used_list = (
    {
        total => {oid => '.1.3.6.1.2.1.25.2.3.1.5.'},
        used  => {oid => '.1.3.6.1.2.1.25.2.3.1.6.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.106.4.1.6.'},
        used  => {oid => '.1.3.6.1.4.1.12356.106.4.1.5.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.101.4.1.7.'},
        used  => {oid => '.1.3.6.1.4.1.12356.101.4.1.6.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.102.99.2.6.'},
        used  => {oid => '.1.3.6.1.4.1.12356.102.99.2.7.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.103.2.1.3.'},
        used  => {oid => '.1.3.6.1.4.1.12356.103.2.1.2.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.106.4.1.4.'},
        used  => {oid => '.1.3.6.1.4.1.12356.106.4.1.3.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.106.14.2.1.1.24.'},
        used  => {oid => '.1.3.6.1.4.1.12356.106.14.2.1.1.23.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.12356.106.14.2.1.1.22.'},
        used  => {oid => '.1.3.6.1.4.1.12356.106.14.2.1.1.21.'}
    },
    {
        total => {oid => '.1.3.6.1.4.1.2021.9.1.6.'},
        used  => {oid => '.1.3.6.1.4.1.2021.9.1.8.'}
    },
);

my @used_free_list = (
    {
        used => {oid => '.1.3.6.1.4.1.2620.1.6.7.1.4.'},
        free => {oid => '.1.3.6.1.4.1.2620.1.6.7.1.5.'}
    },
    {
        used => {oid => '.1.3.6.1.4.1.2620.1.6.7.4.4.'},
        free => {oid => '.1.3.6.1.4.1.2620.1.6.7.4.5.'}
    },
    {
        used => {oid => '.1.3.6.1.4.1.9.9.48.1.1.1.5.'},
        free => {oid => '.1.3.6.1.4.1.9.9.48.1.1.1.6.'}
    },
    {
        used => {oid => '.1.3.6.1.4.1.3224.16.2.1.1.'},
        free => {oid => '.1.3.6.1.4.1.3224.16.2.1.2.'}
    },
    {
        free => {oid => '.1.3.6.1.4.1.2021.9.1.7.'},
        used => {oid => '.1.3.6.1.4.1.2021.9.1.8.'}
    },

);

my @used_timeticks_list = qw(
  .1.3.6.1.4.1.9694.1.6.2.2.
  .1.3.6.1.2.1.1.3.
  .1.3.6.1.2.1.1.8.
  .1.3.6.1.2.1.25.1.1.
);

my @to_update;
my %to_update_oid;
push @counters_list, @{$opts->{counter}} if exists $opts->{counter};

if ( exists $opts->{total_used} )
{
    foreach my $t_u ( @{$opts->{total_used}} )
    {
        my ( $total, $used ) = split /[^\d.]/, $t_u;
        push @total_used_list,
          {
            total => {oid => $total},
            used  => {oid => $used}
          };
    }
}

if ( exists $opts->{used_free} )
{
    foreach my $t_u ( @{$opts->{used_free}} )
    {
        my ( $used, $free ) = split /[^\d.]/, $t_u;
        push @used_free_list,
          {
            free => {oid => $free},
            used => {oid => $used}
          };
    }
}

foreach my $line ( @listeners )
{
    next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
    my ( $host_port, $def, $community ) = split /,/, $line;
    my ( $host, $port ) = split /:/, $host_port;
    $port //= 2161;
    my $BASE = "$host:$port";
    my $all  = io( $def )->slurp;

    foreach my $counter ( @counters_list )
    {
        $counter =~ s/\./\./g;
        while ( $all =~ /^($counter\S+)\s+=\s+(\w+(\d\d)):/mg )
        {
            my $oid  = $1;
            my $type = $2;
            my $size = $3 // 32;
            my $uuid = $ug->create_hex();
            my $var  = '$_SE_' . $uuid;
            my $m    = ( 2**$size ) - 1;
            my $inc  = '$_SE_inc';
            my $do   = "$inc  = int( $m / $opts->{step} );$var=($var += int rand($inc))>$m ? $m - $var : $var";
            push @to_update, $BASE . ',' . $var . ',' . $oid . ',' . $do;
        }
    }

    while ( $all =~ /^(\S+)\s+=\s+(Timeticks):/mg )
    {
        my $oid  = $1;
        my $type = $2;
        my $uuid = $ug->create_hex();
        my $var  = '$_SE_' . $uuid;
        my $inc  = '$_SE_inc';
        my $m    = 4294967295;
        my $do   = "$inc = int rand($opts->{step});($var += $inc)>$m ? $inc : $var";
        push @to_update, $BASE . ',' . $var . ',' . $oid . ',' . $do;
    }
    my %tmp_to_update_oid;
    foreach my $item ( @total_used_list )
    {
        my @all_type = qw(total used);
        foreach my $type ( @all_type )
        {
            my $oid = $item->{$type}{oid};
            while ( $all =~ /^($oid\S+)\s+=\s+(\S+):\s+(\S+)/mg )
            {
                my $val      = $3;
                my $oid_real = $1;
                $tmp_to_update_oid{$BASE . '_' . $type . '_' . $oid_real}{val}      = $val;
                $tmp_to_update_oid{$BASE . '_' . $type . '_' . $oid_real}{oid_real} = $oid_real;
                if ( exists $tmp_to_update_oid{$BASE . '_total_' . $oid_real} && $tmp_to_update_oid{$BASE . '_total_' . $oid_real}{val} && exists $tmp_to_update_oid{$BASE . '_used_' . $oid_real} )
                {
                    my $uuid = $ug->create_hex();
                    my $var  = '$_SE_' . $uuid;
                    my $inc  = '$_SE_inc';
                    my $do   = "$inc  = int( $tmp_to_update_oid{$BASE . '_total_' . $oid_real}{val} / $opts->{step} ) || 1;$var=($var += rand($inc))>$tmp_to_update_oid{$BASE.'_total_'.$oid_real}{val}   ? $var - $tmp_to_update_oid{$BASE.'_total_'.$oid_real}{val} : $var;";
                    push @to_update, $BASE . ',' . $var . ',' . $oid_real . ',' . $do;
                }
            }
        }
    }

    foreach my $item ( @used_free_list )
    {
        my $all1 = $all;
        my $oid  = $item->{used}{oid};
        while ( $all =~ /^($oid(\S+))\s+=\s+(\S+):\s+(\d+)$/mg )
        {
            my $used_val = $4;
            my $used_oid = $1;
            my $oid_ind  = $2;
            my $free_oid = $item->{free}{oid} . $oid_ind;
            while ( $all1 =~ /^$free_oid\s+=\s+(\S+):\s+(\d+)$/mg )
            {
                my $free_val = $2;
                my $total    = $free_val + $used_val;
                my $inc      = '$_SE_inc';
                my $uuid     = $ug->create_hex();
                my $var      = '$_SE_' . $uuid;
                my $do       = "$inc      = int( $total / $opts->{step} ) || 1;$var=($var += rand($inc))>$total ? $var - $total : $var;";
                push @to_update, $BASE . ',' . $var . ',' . $used_oid . ',' . $do;
                $do = "$var=($var -= $inc))<=0 ? $total-$var : $var;";
                push @to_update, $BASE . ',' . $var . ',' . $free_oid . ',' . $do;
            }
        }
    }
}

print Dumper( @to_update ) if $DEBUG;

foreach my $l ( @to_update )
{
    my ( $b, $u, $o, $d ) = split /,/, $l;
    print "b=<$b>\no=<$o>\nu=<$u>\nd=<$d>\n" if $DEBUG > 1;
    if ( !$opts->{blank} )
    {
        $redis->hset( $b . '_val', $o, $u );
        $redis->hset( $b . '_do',  $o, $d );
    }
}
