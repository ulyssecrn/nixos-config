#!/usr/bin/env perl
# Claude Code status line: model | effort | dir | context bar | 5h/7d plan usage
use strict;
use warnings;

my $in = do { local $/; <STDIN> } // '';

if ( $ENV{STATUSLINE_DUMP} || -e "$ENV{HOME}/.claude/.statusline-dump" ) {
    if ( open my $fh, '>', "$ENV{HOME}/.claude/.statusline-dump" ) {
        print {$fh} $in;
        close $fh;
    }
}

# Return the balanced {...} body of "$key" within $src (objects nest, so a
# non-greedy regex would stop at the first inner closing brace).
sub scope {
    my ( $src, $key ) = @_;
    return undef unless $src =~ /"\Q$key\E"\s*:\s*\{/g;
    my $start = pos($src);
    my $depth = 1;
    for my $i ( $start .. length($src) - 1 ) {
        my $ch = substr( $src, $i, 1 );
        $depth++ if $ch eq '{';
        $depth-- if $ch eq '}';
        return substr( $src, $start, $i - $start ) if $depth == 0;
    }
    return undef;
}

sub field {
    my ( $src, $key ) = @_;
    return undef unless defined $src;
    return $src =~ /"\Q$key\E"\s*:\s*"?([^",}\]]*)"?/ ? $1 : undef;
}

# Object names have drifted across releases, so accept aliases: "a|b" tries each.
sub pick {
    my ( $src, $names ) = @_;
    for my $n ( split /\|/, $names ) {
        my $s = scope( $src, $n );
        return $s if defined $s;
    }
    return undef;
}

sub obj { field( pick( $in, $_[0] ), $_[1] ) }
sub nested { field( pick( pick( $in, $_[0] ) // '', $_[1] ), $_[2] ) }

my $model  = obj( 'model',     'display_name' ) // 'claude';
my $effort = obj( 'effort',    'level' );
my $dir    = obj( 'workspace', 'current_dir' );
$dir = $1 if !defined $dir && $in =~ /"cwd"\s*:\s*"([^"]*)"/;
$dir //= '?';
my $home = $ENV{HOME} // '';
$dir =~ s/^\Q$home\E/~/ if $home;

my $ctx = obj( 'context_window|context', 'used_percentage' );
warn "statusline: no context percentage in payload\n" unless defined $ctx;
$ctx = int( ( $ctx // 0 ) + 0.5 );
$ctx = 0 if $ctx < 0;
$ctx = 100 if $ctx > 100;

my $width  = 20;
my $filled = int( $ctx * $width / 100 );
my $bar    = ( '#' x $filled ) . ( '-' x ( $width - $filled ) );

my $h5 = nested( 'rate_limits', 'five_hour', 'used_percentage' );
my $d7 = nested( 'rate_limits', 'seven_day', 'used_percentage' );

# resets_at is a unix timestamp in seconds; render time remaining, not wall clock.
sub until_reset {
    my $at = shift;
    return undef unless defined $at && $at =~ /^\d+$/;
    my $s = $at - time;
    return 'now' if $s <= 0;
    my ( $d, $h, $m ) = ( int( $s / 86400 ), int( $s % 86400 / 3600 ), int( $s % 3600 / 60 ) );
    return sprintf( '%dd%dh', $d, $h ) if $d;
    return sprintf( '%dh%02d', $h, $m ) if $h;
    return sprintf( '%dm', $m );
}

my $r5 = until_reset( nested( 'rate_limits', 'five_hour', 'resets_at' ) );
my $r7 = until_reset( nested( 'rate_limits', 'seven_day', 'resets_at' ) );

# 24-bit colors (tokyonight-ish)
sub c { my ( $rgb, $s ) = @_; "\033[38;2;${rgb}m${s}\033[0m" }
my $PURPLE = '187;154;247';
my $BLUE   = '122;162;247';
my $ORANGE = '224;175;104';
my $RED    = '247;118;142';
my $DIM    = '86;95;137';

# Context and plan usage get separate ramps so they read as different metrics.
sub ctx_heat {    # green -> orange -> red
    my $p = shift;
    return $p >= 90 ? $RED : $p >= 70 ? $ORANGE : '158;206;106';
}

sub limit_heat {    # teal -> gold -> red
    my $p = shift;
    return $p >= 90 ? $RED : $p >= 70 ? '255;199;119' : '115;218;202';
}

my @parts = ( c( $PURPLE, $model ) );
push @parts, c( $ORANGE, $effort ) if defined $effort && length $effort;
push @parts, c( $BLUE, $dir );
push @parts, c( ctx_heat($ctx), sprintf( '[%s] %d%%', $bar, $ctx ) );

my @lim;
push @lim, c( $DIM, '5h:' ) . ' ' . c( limit_heat($h5), sprintf( '%d%%', $h5 + 0.5 ) )
    if defined $h5;
push @lim, c( $DIM, '7d:' ) . ' ' . c( limit_heat($d7), sprintf( '%d%%', $d7 + 0.5 ) )
    if defined $d7;
push @parts, join( ' ', @lim ) if @lim;

my $FG = '169;177;214';
my @rst = grep { defined } ( $r5, $r7 );
push @parts, c( $DIM, 'reset:' ) . ' ' . c( $FG, join( c( $DIM, ' / ' ), @rst ) ) if @rst;

print join( c( $DIM, ' | ' ), @parts ), "\n";
