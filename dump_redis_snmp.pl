#!/usr/bin/perl

##########################################################
# snmp_emul
# Gnu GPL2 license
#
# $Id: dump_redis_snmp.pl  2010-12-18 14:32:07 fabrice $
#
# Fabrice Dulaunoy <fabrice@dulaunoy.com>
# copyright 2010,2011,2012,2013 Fabrice Dulaunoy
###########################################################

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case bundling);
use Redis;

my $VERSION = '3.013';

my $REDIS = '127.0.0.1:6379';

use subs qw(say);

my $oid;
my $type;
my $val;
my $do;
my $next;
my $access;
my $community;
my $label;
my $small = 50;
my $version;
my $help;
my $sub_tree;
my $no_next;
my $no_community;
my $no_enterprise;
my $no_access;
my $no_do;
my $no_label;
my $no_type;
my $trim_tree;
my $BASE = 4161;

GetOptions(
    'l=s' => \$small,
    'h'   => \$help,
    'v'   => \$version,
    'r=s' => \$REDIS,
    's=s' => \$sub_tree,
    'S=s' => \$trim_tree,
    'n'   => \$no_next,
    'c'   => \$no_community,
    'e'   => \$no_enterprise,
    'a'   => \$no_access,
    'd'   => \$no_do,
    'L'   => \$no_label,
    't'   => \$no_type,
    'B=s' => \$BASE,

);
$sub_tree =~ s/\./\\./g if ( $sub_tree );
if ( $version ) { print "$0 $VERSION \n"; exit; }

if ( $help )
{
    print "Usage: $0 [options ...]\n\n";

    print "Where options include:\n";
    print "\t -h \t\t\t Print version and exit \n";
    print "\t -v \t\t\t This help \n";
    print "\t -l len \t\t max length of data tag. Truncate data. (default=$small) If set to 0 = no limit \n";
    print "\t -r server:port \t use that redis server (default=$REDIS)\n";
    print "\t -B base \t\t head name to add to all REDIS request. It is also the SNMP port used for the daemon (default=$BASE)\n";
    print "\t -s sub_tree \t\t only return OID under that sub_tree\n";
    print "\t -S length \t\t trim OID (from the left)\n";
    print "\t -n \t\t\t don't print next oid \n";
    print "\t -e \t\t\t don't print enterprise info\n";
    print "\t -a \t\t\t don't print access column\n";
    print "\t -c \t\t\t don't print community column\n";
    print "\t -d \t\t\t don't print do column\n";
    print "\t -L \t\t\t don't print label column\n";
    print "\t -t \t\t\t don't print type column\n";

    exit;
}

my $redis = Redis->new(
    server => $REDIS,
    debug  => 0
);

$redis->select( 4 );    # use DB nbr 4 ( why not !!!)

unless ( $no_enterprise )
{
    my @enterprises = $redis->smembers( 'enterprise' );
    {
        $Data::Dumper::Varname = 'enterprise';
        say \@enterprises;
    }
}

my %all_next = $redis->hgetall( $BASE . '_next' );
my %all_type = $redis->hgetall( $BASE . '_type' );

## merge all_next and all_type to get all oid in all case( oops, a lot of all in that comment ) ##

my %all_oid = ( %all_next, %all_type );

my $tot_item = scalar keys %all_oid;
say "Total items: $tot_item";

if ( $tot_item )
{
    my $l_oid = length( ( sort { length $a <=> length $b } keys %all_oid )[-1] );
    $l_oid = 5;
    my $l_type = 4;

    my %all_val = $redis->hgetall( $BASE . '_val' );
    my $l_val = length( ( sort { length $a <=> length $b } values %all_val )[-1] );
    if ( $small && $l_val > $small )
    {
        $l_val = $small;
    }
    my %all_access = $redis->hgetall( $BASE . '_access' );
    my $l_access = 1 + length( ( sort { length $a <=> length $b } values %all_access )[-1] );
    $l_access = $l_access >= 6 ? $l_access : 6;

    my %all_community = $redis->hgetall( $BASE . '_community' );
    my $l_community = length( ( sort { length $a <=> length $b } values %all_community )[-1] );
    $l_community = $l_community >= 9 ? $l_community : 9;

    my %all_do = $redis->hgetall( $BASE . '_do' );
    my $l_do = ( 1 + length( ( sort { length $a <=> length $b } values %all_do )[-1] ) );
    $l_do = $l_do >= 2 ? $l_do : 2;

    my %all_label = $redis->hgetall( $BASE . '_label' );
    no warnings;
    my $l_label = length( ( sort { length $a <=> length $b } values %all_label )[-1] );
    use warnings;
    my $l_mabel = ( 1 + length( ( sort { length $a <=> length $b } values %all_label )[-1] ) );
    $l_label = $l_label >= 5 ? $l_label : 5;
    #    if ( scalar keys %all_do )
    #    {
    #        $l_do = length( ( sort { length $a <=> length $b } values %all_do )[-1] );
    #    }

    say print_format_center( 'oid', 'next', 'type', 'val', 'access', 'do', 'label', 'community' );

    foreach $oid ( sort_oids( [ keys %all_oid ] ) )
    {
        if ( $sub_tree )
        {
            next if ( $oid !~ /^$sub_tree/ );
        }
        $type = $redis->hget( $BASE . '_type', $oid ) // '';
        $val  = $redis->hget( $BASE . '_val',  $oid ) // '';

        if ( $small )
        {
            $val = substr $val, 0, $small;
        }
        $next      = $redis->hget( $BASE . '_next',      $oid ) // '';
        $access    = $redis->hget( $BASE . '_access',    $oid ) // '';
        $access    = ' ' . $access;
        $do        = $redis->hget( $BASE . '_do',        $oid ) // '';
        $label     = $redis->hget( $BASE . '_label',     $oid ) // '';
        $community = $redis->hget( $BASE . '_community', $oid ) // '';
        say print_format( $oid, $next, $type, $val, $access, $do, $label, $community );
    }

    sub print_format
    {
        my $oid       = shift;
        my $next      = shift;
        my $type      = shift;
        my $val       = shift;
        my $access    = shift;
        my $do        = shift;
        my $label     = shift;
        my $community = shift;
        my $oid1      = $oid;
        my $next1     = $next;
        if ( $trim_tree )
        {
            $l_oid = $trim_tree;
            substr $oid1,  0, -$trim_tree, '';
            substr $next1, 0, -$trim_tree, '';

        }
        my $msg = '[' . append( $oid1, $l_oid ) . ']';
        $msg .= ' -> [' . append( $next1, $l_oid ) . ']' unless $no_next;
        $msg .= ' <' . append( $type,      $l_type,      1 ) . '>' unless $no_type;
        $msg .= ' <' . append( $val,       $l_val,       1 ) . '>';
        $msg .= ' <' . append( $access,    $l_access,    1 ) . '>' unless $no_access;
        $msg .= ' <' . append( $do,        $l_do,        1 ) . '>' unless $no_do;
        $msg .= ' <' . append( $label,     $l_label,     1 ) . '>' unless $no_label;
        $msg .= ' <' . append( $community, $l_community, 1 ) . '>' unless $no_community;

        return $msg;
    }

    sub print_format_center
    {
        my $oid       = shift;
        my $next      = shift;
        my $type      = shift;
        my $val       = shift;
        my $access    = shift;
        my $do        = shift;
        my $label     = shift;
        my $community = shift;
        my $oid1      = $oid;
        my $next1     = $next;
        if ( $trim_tree )
        {
            $l_oid = $trim_tree;
            substr $oid1,  0, -$trim_tree, '';
            substr $next1, 0, -$trim_tree, '';

        }
        my $msg = '[' . append( $oid1, $l_oid, 2 ) . ']';
        $msg .= ' -> [' . append( $next1, $l_oid, 2 ) . ']' unless $no_next;
        $msg .= ' <' . append( $type,      $l_type,      2 ) . '>' unless $no_type;
        $msg .= ' <' . append( $val,       $l_val,       2 ) . '>';
        $msg .= ' <' . append( $access,    $l_access,    2 ) . '>' unless $no_access;
        $msg .= ' <' . append( $do,        $l_do,        2 ) . '>' unless $no_do;
        $msg .= ' <' . append( $label,     $l_label,     2 ) . '>' unless $no_label;
        $msg .= ' <' . append( $community, $l_community, 2 ) . '>' unless $no_community;

        #        if ( $no_next )
        #        {
        #            $msg .=
        #                append( $oid, $l_oid, 2 ) . '] <'
        #              . append( $type,   $l_type,   2 ) . '> <'
        #              . append( $val,    $l_val,    2 ) . '> <'
        #              . append( $access, $l_access, 2 ) . '> <'
        #              . append( $do,     $l_do,     2 ) . '> <'
        #              . append( $label,  $l_label,  2 ) . '>';
        #        }
        #        else
        #        {
        #            $msg .=
        #                append( $oid, $l_oid, 2 )
        #              . '] -> ['
        #              . append( $next,   $l_oid,    2 ) . '] <'
        #              . append( $type,   $l_type,   2 ) . '> <'
        #              . append( $val,    $l_val,    2 ) . '> <'
        #              . append( $access, $l_access, 2 ) . '> <'
        #              . append( $do,     $l_do,     2 ) . '> <'
        #              . append( $label,  $l_label,  2 ) . '>';
        #        }
        #        if ( !$no_community )
        #        {
        #            $msg .= ' <' . append( $community, $l_community, 2 ) . '>';
        #        }
        return $msg;
    }
}

sub append
{
    my $data   = shift // '';
    my $len    = shift;
    my $justif = shift // 0;
    return ' ' unless $len;
    my $blank  = ' ' x $len;
    my $l_data = length $data;
    if ( $justif == 1 )
    {
        substr $blank, $len - $l_data, $l_data // 0, $data;
    }
    elsif ( $justif == 2 )
    {
        substr $blank, ( $len - $l_data ) / 2, $l_data, $data;
    }
    else
    {
        substr $blank, 0, $l_data, $data;
    }

    return $blank;

}

sub say
{
    my $msg = shift;
    my ( $pkg, $file, $line, $sub ) = ( caller( 0 ) )[ 0, 1, 2, 3 ];
    if ( ref $msg )
    {
        $msg = "[$line] " . Dumper( $msg );
        chomp $msg;
    }
    else
    {
        $msg = "[$line] " . $msg;
    }
    print "$msg\n";
}

sub sort_oids
{
    my $in  = shift;
    my @tmp = @$in;
    map { $_ =~ s/^\.// } @tmp;
    my @all_oid = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map {
        [ $_, join '', map { sprintf( "%30d", $_ ) } split( /\./, $_ ) ]
    } @tmp;
    map { $_ =~ s/^(\d)/.$1/ } @all_oid;
    return @all_oid;
}
