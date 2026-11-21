#!/usr/bin/env perl
# scripts/source-check.pl: the source check of a release asset (spec D12 of
# docs/specs/getevinced-mirror.md, and docs/specs/public-tap.md). It prints one
# line, "<path>: <why>", for each file of the asset that is source, and exits 0;
# no line means the asset passes. It exits non-zero, with the reason on stderr,
# when it cannot read the asset.
#
#   perl scripts/source-check.pl --entry <entry .rb> --tree <dir>
#       reads the files listed on stdin, one per line, from the unpacked tree
#       <dir> (scripts/mirror.sh, which unpacks a .zip, a .tar.gz or a .pkg)
#   perl scripts/source-check.pl --entry <entry .rb> --archive <file>
#       reads a .zip or a .tar.gz in memory, found by its first bytes
#       (scripts/bump.sh, which runs where unzip and tar may be missing)
#
# Core Perl modules only: bump.sh runs it under any caller's system perl.
# The rules (each path relative to the asset's root, extensions in any case):
# outside node_modules/, a .ts, .tsx, .mts or .cts file that is not a declaration
# file (.d.ts) is source, unless the entry names its path under libexec and it
# holds minified output; so is a .map file, and a .json file that holds
# "sourcesContent". In a package of a first-party scope under node_modules/,
# those files are source with no exception, and so is any file that holds
# "sourcesContent". Anywhere outside node_modules/ or in such a package, a JS,
# TS or CSS file with an inline source map (sourceMappingURL=data:) is source.
# An AppleDouble file (._<name>) is metadata, and is not read.
# Postfix conditions only: brew style's layout pass misreads a line that starts
# with `if` in shell strings, and the same habit keeps this file uniform.
use strict;
use warnings;
use Compress::Raw::Zlib qw(MAX_WBITS Z_OK Z_STREAM_END);

# The package scopes of the operator's own code. A package under node_modules/
# in one of them is held to the check. Add a fleet repo's new scope here.
my @FIRST_PARTY_SCOPES = qw(@21starkcom @atlas @floorplan @idun @sleipnir);
# A .ts file an entry names under libexec passes only as minified output: a mean
# line of this many bytes or more. Source runs at about 40.
my $MINIFIED_LINE_BYTES = 200;

my ($entry, $mode, $from);
while (@ARGV) {
  my $flag = shift @ARGV;
  my $value = shift @ARGV;
  die "source-check.pl: $flag needs a value\n" unless defined $value;
  $entry = $value, next if $flag eq "--entry";
  ($mode, $from) = ($flag, $value), next if $flag eq "--tree" || $flag eq "--archive";
  die "source-check.pl: unknown flag $flag\n";
}
die "usage: source-check.pl --entry <entry .rb> (--tree <dir> | --archive <file>)\n"
  unless defined $entry && defined $mode;

my %scope = map { $_ => 1 } @FIRST_PARTY_SCOPES;
my $ts = qr/\.(?:ts|tsx|mts|cts)\z/i;
my $decl = qr/\.d\.(?:ts|mts|cts)\z/i;
my $text = qr/\.(?:js|mjs|cjs|jsx|ts|tsx|mts|cts|css)\z/i;
my $json = qr/\.json\z/i;

# The TypeScript paths the entry file names under libexec: the minified bundles
# its wrappers and tests run (sleipnir).
my %named;
{
  open my $h, "<", $entry or die "source-check.pl: cannot read $entry: $!\n";
  local $/;
  my $rb = <$h>;
  $named{$1} = 1
    while $rb =~ m{(?:#\{(?:opt_)?libexec\}/|(?:opt_)?libexec/")([^"\s#{}]+?\.(?:ts|tsx|mts|cts))(?![A-Za-z0-9_])}g;
}

# Why the file at path $p is source, or "" when it is not. $ours is true in a
# first-party package. $body returns the file's bytes, or undef for a link or
# anything that is not a plain file; it is called only when a rule needs them.
sub why {
  my ($p, $ours, $body) = @_;
  my $in = $ours ? " in a first-party package" : "";
  my $source = $p =~ $ts && $p !~ $decl;
  my $bundle = $source && !$ours && $named{$p};
  return "TypeScript source$in" if $source && !$bundle;
  return "a source map$in" if $p =~ /\.map\z/i;
  return "" unless $ours || $p =~ $text || $p =~ $json;
  my $b = $body->();
  return $bundle ? "a named TypeScript path that is not a plain file" : "" unless defined $b;
  my $mean = int(length($b) / (($b =~ tr/\n//) + ($b =~ /[^\n]\z/ ? 1 : 0) || 1));
  return "TypeScript source, not minified (a mean line of $mean bytes)" if $bundle && $mean < $MINIFIED_LINE_BYTES;
  # A .json outside node_modules/ that holds sourcesContent is a source map by another name.
  return "holds sourcesContent$in" if ($ours || $p =~ $json) && index($b, "sourcesContent") >= 0;
  return "an inline source map$in" if $p =~ $text && $b =~ /sourceMappingURL=data:/;
  return "";
}

# Checks one path of the asset and prints it when it is source. Under
# node_modules/, only a package of a first-party scope is read: the package after
# the last node_modules/ in the path.
sub consider {
  my ($p, $body) = @_;
  $p =~ s{\A(?:\./)+}{};
  return if $p eq "" || $p =~ m{/\z};
  # An AppleDouble file (._<name>, as macOS tar and zip write one beside a file
  # with extended attributes) holds that file's metadata, not its bytes.
  return if $p =~ m{(?:\A|/)\._[^/]*\z};
  my ($rest) = $p =~ m{.*(?:\A|/)node_modules/(.*)\z};
  my $ours = defined $rest && $rest =~ m{\A(@[^/]+)/[^/]+/} && $scope{$1} ? 1 : 0;
  return if defined $rest && !$ours;
  my $why = why($p, $ours, $body);
  print "$p: $why\n" if $why ne "";
}

sub tree {
  my ($root) = @_;
  while (my $p = <STDIN>) {
    chomp $p;
    (my $rel = $p) =~ s{\A(?:\./)+}{};
    consider($p, sub {
      my $f = "$root/$rel";
      return undef if -l $f || !-f $f;
      open my $h, "<:raw", $f or die "cannot read $rel: $!\n";
      local $/;
      return scalar <$h>;
    });
  }
}

# A .zip, read from its central directory: the one place that says which member
# is a symlink (its Unix mode). Members are inflated only when a rule reads them.
sub zip {
  my ($file, $h) = @_;
  my $size = -s $h;
  my $tail = $size < 65557 ? $size : 65557;
  seek $h, $size - $tail, 0 or die "$file: cannot seek: $!\n";
  read($h, my $end, $tail) == $tail or die "$file: cannot read its end\n";
  my $at = rindex $end, "PK\x05\x06";
  die "$file: no zip end record\n" if $at < 0;
  my ($count, $cd_size, $cd_at) = unpack "x10 v V V", substr($end, $at, 20);
  # A zip64 archive keeps the real numbers in its zip64 end record.
  if ($count == 0xFFFF || $cd_size == 0xFFFFFFFF || $cd_at == 0xFFFFFFFF) {
    die "$file: a zip64 archive with no zip64 locator\n" unless $at >= 20 && substr($end, $at - 20, 4) eq "PK\x06\x07";
    my $z64_at = unpack "x8 Q<", substr($end, $at - 20, 16);
    seek $h, $z64_at, 0 or die "$file: cannot seek: $!\n";
    my $z64;
    read($h, $z64, 56) == 56 && substr($z64, 0, 4) eq "PK\x06\x06" or die "$file: no zip64 end record\n";
    ($count, $cd_size, $cd_at) = unpack "x32 Q< Q< Q<", $z64;
  }
  seek $h, $cd_at, 0 or die "$file: cannot seek: $!\n";
  read($h, my $cd, $cd_size) == $cd_size or die "$file: its central directory is short\n";
  my $o = 0;
  for (1 .. $count) {
    die "$file: a bad central directory entry\n" unless substr($cd, $o, 4) eq "PK\x01\x02";
    my ($made_by, $flags, $method, $csize, $usize, $nlen, $xlen, $clen, $attrs, $local) =
      unpack "x4 v x2 v v x8 V V v v v x4 V V", substr($cd, $o, 46);
    my $name = substr($cd, $o + 46, $nlen);
    my $extra = substr($cd, $o + 46 + $nlen, $xlen);
    $o += 46 + $nlen + $xlen + $clen;
    # The zip64 extra field holds each size or offset that reads 0xFFFFFFFF, in this order.
    while (length $extra >= 4) {
      my ($id, $len) = unpack "v v", $extra;
      my @q = unpack "Q<*", substr($extra, 4, $len);
      ($usize, $csize, $local) = map { $_ == 0xFFFFFFFF && @q ? shift @q : $_ } $usize, $csize, $local if $id == 1;
      $extra = substr($extra, 4 + $len);
    }
    my $unix_mode = ($made_by >> 8) == 3 ? ($attrs >> 16) & 0xFFFF : 0;
    my $plain = ($unix_mode & 0170000) != 0120000;
    consider($name, sub {
      return undef unless $plain;
      die "$file: $name is encrypted\n" if $flags & 1;
      seek $h, $local, 0 or die "$file: cannot seek: $!\n";
      my $head;
      read($h, $head, 30) == 30 && substr($head, 0, 4) eq "PK\x03\x04" or die "$file: a bad local header for $name\n";
      my ($n, $x) = unpack "x26 v v", $head;
      seek $h, $local + 30 + $n + $x, 0 or die "$file: cannot seek: $!\n";
      my $data = "";
      read($h, $data, $csize) == $csize or die "$file: the data of $name is short\n" if $csize;
      return $data if $method == 0;
      die "$file: $name uses compression method $method, which the check cannot read\n" unless $method == 8;
      my ($inflate, $status) = Compress::Raw::Zlib::Inflate->new(-WindowBits => -MAX_WBITS());
      die "$file: cannot start to inflate $name\n" unless $status == Z_OK;
      my $out;
      $status = $inflate->inflate($data, $out);
      die "$file: cannot inflate $name: $status\n" unless $status == Z_STREAM_END;
      die "$file: $name inflates to " . length($out) . " bytes, not $usize\n" unless length($out) == $usize;
      return $out;
    });
  }
}

# A .tar.gz, one member at a time.
sub tar_gz {
  my ($file) = @_;
  require Archive::Tar;
  my $next = Archive::Tar->iter($file, 1) or die "$file: cannot read: " . Archive::Tar->error . "\n";
  while (my $f = $next->()) {
    next if $f->is_dir;
    consider($f->full_path, sub { $f->is_file ? $f->get_content : undef });
  }
  my $error = Archive::Tar->error;
  die "$file: cannot read: $error\n" if defined $error && $error ne "";
}

if ($mode eq "--tree") {
  tree($from);
} else {
  open my $h, "<:raw", $from or die "source-check.pl: cannot read $from: $!\n";
  read($h, my $magic, 4) == 4 or die "source-check.pl: $from is too short to be an archive\n";
  if ($magic eq "PK\x03\x04" || $magic eq "PK\x05\x06") {
    zip($from, $h);
  } elsif (substr($magic, 0, 2) eq "\x1f\x8b") {
    close $h;
    tar_gz($from);
  } else {
    die "source-check.pl: $from is neither a .zip nor a .tar.gz\n";
  }
}
