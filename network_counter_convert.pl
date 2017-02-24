#!/usr/bin/perl

use strict;
use warnings;

#use feature qw( say );
use Carp;
use Config::General;
use Redis;
use Getopt::Std;
use Data::Dumper;
use IO::All;
use Data::UUID;

my $ug = Data::UUID->new;

my %opts;

my $REDIS     = '127.0.0.1:6379';
my $CTRL_PORT = 3161;
my $CTRL_IP   = '127.0.0.1';
my $VERSION   = '0.01';

my $CONFIG_FILE = '/opt/snmp_emul/etc/daemon.conf';
getopts( 'd:hr:c:I:P:v', \%opts );
if ( $opts{'h'} )
{
    print "usage $0 [-D] [-d level] [-B base] [-p port] [-r ip:port] [-i ip] [-h] [-v]\n\n";
    print "\t -h \t\t this help\n";
    print "\t -c conf_file \t configuration file to use (format: peer,def_file,[community])\n";
    print "\t -d level \t debug level\n";
    print "\t -I CTRL_IP \t IP for the control channel (default=$CTRL_IP)\n";
    print "\t -P CTRL_PORT \t PORT for the control channel (default=$CTRL_PORT)\n";
    print "\t -r ip:port \t server to use for the DB (default=$REDIS)\n";

    exit;
}

my $DEBUG = $opts{d} // $ENV{DEBUG} // 0;
$CTRL_IP   = $opts{I} if $opts{I};
$CTRL_PORT = $opts{P} if $opts{P};

if ( $opts{v} )
{
    die "$0 v$VERSION (c) DULAUNOY Fabrice, 2012-2013\n";
}

$REDIS //= $opts{r};
$CONFIG_FILE = ( $opts{c} ) // $CONFIG_FILE;

my $redis = Redis->new(
    server => $REDIS,
    debug  => 0
);
$redis->select( 4 );    # use DB nbr 4 ( why not !!!)
my @listeners = io( $CONFIG_FILE )->chomp->slurp;

my @counters32_list = qw(
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

my @to_update;

foreach my $line ( @listeners )
{
    next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
    my ( $host_port, $def, $community ) = split /,/, $line;
    my ( $host, $port ) = split /:/, $host_port;
    $port //= 2161;
    my $BASE  = "$host:$port";
    my @lines = io( $def )->chomp->slurp;
    foreach my $line ( @lines )
    {
        foreach my $counter ( @counters32_list )
        {
            if ( $line =~ /($counter\S+)\s=\s(\w+(\d\d)):/ )
            {
                my $uuid = $ug->create_hex();
                my $var  = '$_SE_' . $uuid;
                my $m   = ( 2**$3 ) - 1;
                my $inc = int( $m / 200 );
                my $do  = "$var=($var += int rand($inc))>$m ? $var - $m : $var";
                push @to_update, $BASE . ',' . $var . ',' . $1 . ',' . $do;
            }
        }
    }
}

print Dumper( @to_update )if $DEBUG > 1;
foreach my $l ( @to_update )
{
    my ( $b, $u, $o, $d ) = split /,/, $l;
    print "b=<$b>\no=<$o>\nu=<$u>\nd=<$d>\n"if $DEBUG;
    $redis->hset( $b . '_val', $o, $u );
    $redis->hset( $b . '_do',  $o, $d );
}
