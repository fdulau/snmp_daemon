#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use feature qw( say );
use Redis;
use Getopt::Long qw(:config no_ignore_case bundling);
use Data::UUID;

my $ug = Data::UUID->new;

my $VERSION = '3.03';

my $REDIS = '127.0.0.1:6379';
#my $REDIS = '166.59.83.179:6379';
my $oid;
my $new_val;
my $new_type;
my $new_do;
my $auto_do;
my $new_community;
my $new_access;
my $preset = 0;
my $help;
my $version;
my $BASE = 4161;

GetOptions(
    'h'   => \$help,
    'v'   => \$version,
    'o=s' => \$oid,
    'r=s' => \$REDIS,
    'V=s' => \$new_val,
    't=s' => \$new_type,
    'd=s' => \$new_do,
    'D=s' => \$auto_do,
    'c=s' => \$new_community,
    'a=s' => \$new_access,
    'B=s' => \$BASE,
);

if ( $version )
{
    print "$0 version=$VERSION\n";
    exit;
}
if ( $help )
{
    print "usage $0 -o oid  [-V val] [-d do] [-D [max|counter|maxXXX|counterXXX]=[val|max32] [-c community] [-a access] [-B base] [-h] [-v]\n\n";
    print "\t -h \t\t this help\n";
    print "\t -o oid \t oid to edit\n";
    print "\t -B base \t base for the SNMP_DAEMON port (see snmp_daemon.pl) default = 4161\n";
    print "\t -V val \t new val or a variable name starting by \$_SE_... modified by the -o code\n";
    print "\t -d code \t perl code to execute\n";
    print "\t -D autolabel \t set val and code automatically (see example)\n";
    print "\t -t type \t new type\n";
    print "\t -c community \t new community string\n";
    print "\t -a access \t new access string\n";
    print "\t -r ip:port \t server to use for the DB (default=$REDIS)\n";
    print "\t -v \t\t print version and die\n";
    print "\n\t
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V 3333 
                => set a static value for the OID and in the default base (4161)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V '\$_SE_intA' -d '\$_SE_int46=(\$_SE_intA += int rand(24571116))>24571116 ? \$_SE_intA - 24571116 : \$_SE_intA' -B 4163
                => a perl code executed and retuenrd in the value (!!! the var name MUST start by \$_SE_ and the name could not contain operator like + - ...)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=24571116'
                => a counter with random increment looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=24571116'
                => a random value looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=max32'
                => a counter with random increment looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=max32'
                => a random value looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter5000=max32'  -B 4162
                => a counter with an increment of 5000 looping when reaching the value 2^32 in the default 4162
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max1000=max32'  -B 4163
                => a random walue with an increment of 1000 looping when reaching the value 2^32  in the default 4163\n";
    exit;
}
my $redis = Redis->new(
    server => $REDIS,
    debug  => 0
);

$redis->select( 4 );    # use DB nbr 4 ( why not !!!)

my %types = (
    1  => 'BOOLEAN',
    2  => 'INTEGER',
    3  => 'BIT_STR',
    4  => 'OCTET_STR',
    5  => 'NULL',
    6  => 'OBJECT_ID',
    16 => 'SEQUENCE',
    17 => 'SET ',
    64 => 'APPLICATION',
    64 => 'IPADDRESS',
    65 => 'COUNTER',
    66 => 'GAUGE',
    66 => 'UNSIGNED',
    67 => 'TIMETICKS',
    68 => 'OPAQUE',
    70 => 'COUNTER64',
    72 => 'FLOAT',
    73 => 'DOUBLE',
    74 => 'INTEGER64',
    75 => 'UNSIGNED64'
);

my %sepyt = reverse %types;

say "*****<$new_val>" if ( $new_val );

if ( $redis->hexists( $BASE . '_type', $oid ) )
{
    my $type      = $redis->hget( $BASE . '_type',      $oid );
    my $access    = $redis->hget( $BASE . '_access',    $oid ) // '';
    my $community = $redis->hget( $BASE . '_community', $oid ) // 'public';
    my $val       = $redis->hget( $BASE . '_val',       $oid ) // '';
    my $do        = $redis->hget( $BASE . '_do',        $oid ) // '';
    my $next      = $redis->hget( $BASE . '_next',      $oid ) // '';

    say "<$oid> <$type> (" . $types{ $type } . ") <$val> <$do> <$next> <$access>";

    if ( !defined $new_type && !defined $new_val && !defined $new_do && !defined $auto_do && !defined $new_community )
    {
        say "New type? (enter if you would like to keep the old type )";
        $new_type = <STDIN>;
        chomp $new_type;
    }
    if ( $new_type )
    {
        if ( $new_type =~ /^\d+$/ && exists $types{ $new_type } )
        {
            $redis->hset( $BASE . '_type', $oid, $new_type );
        }
        elsif ( exists $sepyt{ $new_type } )
        {
            $redis->hset( $BASE . '_type', $oid, $sepyt{ $new_type } );
        }
        else
        {
            say "not a possible type keeping the old one";
        }
    }

    if ( !defined $new_val && !defined $new_do && !defined $auto_do )
    {
        say "New value? (enter if you would like to keep the old value )";
        $new_val = <STDIN>;
        chomp $new_val;
    }
    if ( defined $auto_do )
    {
        my ( $t, $m ) = split /[\s;,=]+/, $auto_do;
        my $uuid = $ug->create_hex();
        my $var  = '$_SE_' . $uuid;
        if ( $t =~ /^counter$/i )
        {
            $do = "$var=($var += int (rand()*$m))>$m ? $var - $m : $var";
            #$_SE_int46=($_SE_intA += int rand(24571116))>24571116 ? $_SE_intA - 24571116 : $_SE_intA
        }
        elsif ( $t =~ /^counter(\d+)$/i )
        {
            my $inc = $1;
            $do = "$var=($var += int rand($inc))>$m ? $var - $m : $var";
        }
        elsif ( $t =~ /^max$/i )
        {
            $do = "$var=($var = int rand($m))>$m ? $var - $m : $var";
        }
        elsif ( $t =~ /^max(\d)+$/i )
        {
            my $inc = $1;
            $do = "$var=($var += $inc)>$m ? $var - $m : $var";
        }
        else
        {
            say "Not a correct type for auto_do ($t)";
            exit;
        }
        say "<$do>";

        $redis->hset( $BASE . '_do',  $oid, $do );
        $redis->hset( $BASE . '_val', $oid, $var );
        say "do=" . $redis->hget( $BASE . '_do', $oid );
        say "val=" . $redis->hget( $BASE . '_val', $oid );
    }
    else
    {
        if ( defined $new_val )
        {
            $redis->hset( $BASE . '_val', $oid, $new_val );
        }
        else
        {
            $redis->hdel( $BASE . '_val', $oid );
        }

        if ( !defined $new_do )
        {
            say "New DO? (enter if you would like to keep the old DO )";
            $new_do = <STDIN>;
            chomp $new_do;
        }
        if ( $new_do )
        {
            $redis->hset( $BASE . '_do', $oid, $new_do );
        }
        if ( $new_community )
        {
            #say "New Community? (enter if you would like to keep the old community )";
            #     my $new_community = <STDIN>;
            #    chomp $new_community;

            $redis->hset( $BASE . '_community', $oid, $new_community ) if ( $new_community );
        }

        if ( $new_access )
        {
            #say "New Community? (enter if you would like to keep the old community )";
            #     my $new_community = <STDIN>;
            #    chomp $new_community;

            $redis->hset( $BASE . '_access', $oid, $new_access );
        }
    }

}
else
{
    say "NO such OID <$oid>";
}
say "*****<$new_val>" if ( $new_val );

