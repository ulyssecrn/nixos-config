#!/usr/bin/env perl
# Claude Code status line — Tokyo Night
# model | effort | wd | [████░░░░] ctx% | 5h:% 7d:% | resets:0h00m

use strict;
use warnings;
use JSON::PP ();

my $input = do { local $/; <STDIN> };
my $j = eval { JSON::PP->new->decode($input) };
my $parsed = ref $j eq 'HASH';   # only fall back to $PWD if the payload was unusable
$j = {} unless $parsed;

# Dig a nested path out of the decoded JSON, returning undef on any miss.
sub get {
    my ($node, @path) = @_;
    for my $k (@path) {
        return undef unless ref $node eq 'HASH' && defined $node->{$k};
        $node = $node->{$k};
    }
    return ref $node ? undef : $node;
}

# ── Tokyo Night palette (truecolor, matches ~/.config/kitty/kitty.conf) ──
my $BLUE   = "\033[38;2;122;162;247m";  # #7aa2f7
my $PURPLE = "\033[38;2;187;154;247m";  # #bb9af7
my $CYAN   = "\033[38;2;125;207;255m";  # #7dcfff
my $GREEN  = "\033[38;2;158;206;106m";  # #9ece6a
my $YELLOW = "\033[38;2;224;175;104m";  # #e0af68
my $ORANGE = "\033[38;2;255;158;100m";  # #ff9e64
my $RED    = "\033[38;2;247;118;142m";  # #f7768e
my $TEAL   = "\033[38;2;115;218;202m";  # #73daca
my $WHITE  = "\033[38;2;192;202;245m";  # #c0caf5 (foreground)
my $R      = "\033[0m";

my $model    = get($j, 'model', 'display_name')                    // '?';
my $effort   = get($j, 'effort', 'level')                          // '';
my $cwd      = get($j, 'workspace', 'current_dir') // get($j, 'cwd')
            // ($parsed ? '?' : ($ENV{PWD} // '?'));
# Tolerate a field arriving as a string ("12.5") or as junk
sub num { my ($v, $dflt) = @_; return ($v // '') =~ /^-?\d+(?:\.\d+)?$/ ? $v + 0 : $dflt }

my $ctx_pct  = num(get($j, 'context_window', 'used_percentage'), 0);
my $fh_pct   = num(get($j, 'rate_limits', 'five_hour', 'used_percentage'), -1);
my $sd_pct   = num(get($j, 'rate_limits', 'seven_day', 'used_percentage'), -1);
my $fh_reset = num(get($j, 'rate_limits', 'five_hour', 'resets_at'), 0);
my $sd_reset = num(get($j, 'rate_limits', 'seven_day', 'resets_at'), 0);

# Colour by load: $calm is the calm colour, escalating to red as it fills
sub heat {
    my ($p, $calm) = @_;
    $p = int($p || 0);
    return $RED    if $p >= 90;
    return $ORANGE if $p >= 75;
    return $YELLOW if $p >= 50;
    return $calm;
}

my $sep = " ${WHITE}|${R} ";

# ── model (drop the "(1M)" / "[1m]" context-size suffix) ──
$model =~ s/ \(.*//;
$model =~ s/ \[.*//;
my $out = "${BLUE}${model}${R}";

# ── effort (absent on non-reasoning models) ──
$out .= "${sep}${PURPLE}${effort}${R}" if length $effort;

# ── working dir (+ branch) ──
my $home = $ENV{HOME} // '';
my $short_cwd = $cwd;
$short_cwd =~ s/^\Q$home\E/~/ if length $home;

# Single-quote for /bin/sh: a path may contain spaces or shell metacharacters
sub shq { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'" }

my $branch = '';
my $git = 'git -C ' . shq($cwd) . ' -c core.fsmonitor=false';
if (system("$git rev-parse --is-inside-work-tree >/dev/null 2>&1") == 0) {
    $branch = `$git symbolic-ref --short HEAD 2>/dev/null`;
    $branch = `$git rev-parse --short HEAD 2>/dev/null` unless $branch =~ /\S/;
    $branch =~ s/\s+\z//;
}
$out .= "${sep}${CYAN}${short_cwd}${R}";
$out .= " ${ORANGE}${branch}${R}" if length $branch;

# ── context window bar ──
my $ctx_int = sprintf('%.0f', $ctx_pct);
$ctx_int = 100 if $ctx_int > 100;
$ctx_int = 0   if $ctx_int < 0;
my $width   = 20;
my $filled  = int($ctx_int * $width / 100);
my $bar     = ("\x{2588}" x $filled) . ("\x{2591}" x ($width - $filled));
my $ctx_col = heat($ctx_int, $GREEN);
$out .= sprintf("%s%s[%s%s%s]%s %s%3d%%%s",
                $sep, $WHITE, $ctx_col, $bar, $WHITE, $R, $ctx_col, $ctx_int, $R);

# ── rate limits ──
sub fmt_limit {
    my ($label, $pct) = @_;
    my $p = sprintf('%.0f', $pct);
    return sprintf('%s%s:%s%d%%%s', $WHITE, $label, heat($p, $TEAL), $p, $R);
}
my @limits;
push @limits, fmt_limit('5h', $fh_pct) if $fh_pct >= 0;
push @limits, fmt_limit('7d', $sd_pct) if $sd_pct >= 0;
$out .= $sep . join(' ', @limits) if @limits;

# ── time until the next window resets ──
my $reset = $fh_reset > 0 ? $fh_reset : $sd_reset;
if ($reset > 0) {
    my $left = $reset - time;
    $left = 0 if $left < 0;
    $out .= sprintf('%s%sresets:%s%dh%02dm%s',
                    $sep, $WHITE, $YELLOW, int($left / 3600), int($left % 3600 / 60), $R);
}

binmode(STDOUT, ':encoding(UTF-8)');
print $out;
