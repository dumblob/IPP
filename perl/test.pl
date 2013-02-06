#!/usr/bin/perl

#JSN:xpacne00

# http://stackoverflow.com/questions/7637042/perl-data-structure-traversal-reference-followed-key

# * --help NElze kombinovat s jinym parametrem
# * --input=filename relativne nebo absolutne; pokud chybi, tak stdin
# * --output=filename - || -; bez neho stdout; bez varovani prepise/vytvori_new
# * -n negenerovat hlavicku
# * -r=root-element parovy element obalujici cely vystup (krome hlavicky);
# *   pokud nezadan, tak nicim neobalovat; root-element musi byt validni
# * --array-name=array-element prejmenuje implicitni element obalujici pole z
# *   array na array-element; array-element musi byt validni
#   --item-name=item-element prejmenuje element pro prvek pole z item na
#     item-element; item-element musi byt validni
# * -s dvojice typu string transformuje na textovy element misto atributu
# *   FIXME retezec vsak v poli nebude (NEmusim to kontrolovat)
# * -i dvojice typu number transformuje na textovy element misto atributu
# *   FIXME retezec vsak v poli nebude (NEmusim to kontrolovat)
# * -l true, false, null transformuje na <true/> <false/> <null/> misto na
# *   atributy (POZOR, tyto jsou narozdil od zbytku implicitne atributama)
#   -c prekladat znaky s ord()<128 na XML varianty s & (FIXME vypsat si vsechny)
#     &amp; &lt; &gt; &quot; &apos;
#     toto se tyka pouze hodnot, NE jmen
#     pokud nebude -c, ale bude NEvalidni XML vystup, tak vyhodit chybu a hotovo
# * -a
# * --array-size prida k poli atribut size s poctem prvku v tomto poli
#   -t
#   --index-items prida ke kazdemu prvku pole atribut index s cislem poradi
#     v tom poli
#   --start=n lze zadat pouze s -t|--index-items; nastavi FIXME
#
#   parametry se NEsmi opakovat
#   ve vstupnim souboru ve jmene elementu nahrazovat nepovolene znaky pomlckou
#     toto NEplati pro uzivatelovy argumenty!!!
#   NEkontrolovat namespace XML

#FIXME kontrolovat znaky 0x00 .. 0x7F jestli jsou XML validni pro element/apod.
#  entityValue   NEsmi %&"'
#  attValue      NEsmi <&"'
#  FIXME fakt tam nepatri > &gt; ???????????

use constant {
  E_ARG        => 1,    # arguments
  E_F_IN       => 2,    # input file (ro)
  E_F_OUT      => 3,    # output file (rw)
  E_F_FORMAT   => 4,    # input file format
  E_ROOT_ELEM  => 50,   # invalid root element given FIXME default zadne obalovani do takoveho elementu
  E_ARRAY_NAME => 50,   # invalid array name given FIXME default array
  E_ITEM_NAME  => 50,   # invalid item name given FIXME default item
  E_XML_ELEM   => 51,   # invalid XML after "dash" normalization
  E_MISC       => 100,  # other error

  I_START  => 1,  # initial array counter value FIXME muze byt treba zaporna?
  XML_HEAD => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
};

use common::sense;
use Switch;
use Data::Types('is_int', 'to_int');
#use Data::Walk;  # FIXME fakt to potrebuji?
use JSON;
use XML::RegExp;  # XML entity validator

#FIXME filter_json_single_key_object() aby se ve vstupnim JSONu neobjevily
#  perl znaky jako $ apod. - to by pekne pomichalo hashe atd.
#  JSON numbers and strings become simple Perl scalars. JSON arrays become Perl
#  arrayrefs and JSON objects become Perl hashrefs. true becomes 1 (JSON::true),
#  false becomes 0 (JSON::false) and null becomes undef.

my $arg_f_in; my $f_in;
my $arg_f_out; my $f_out;
my $arg_n;
my $arg_r;
my $arg_array_name;
my $arg_item_name;
my $arg_s;
my $arg_i;
my $arg_l;
my $arg_c;
my $arg_a;
my $arg_t;
my $arg_start;

sub arg_mismatch
{
  print STDERR "Argument '".$_[0]."' mismatch\n"; exit E_ARG;
}

# parse arguments
while (scalar @ARGV) {
  switch ($ARGV[0]) {
    case '--help' {
      if (scalar @ARGV == 1) {
        print <<HEREDOC
--help
  print this help
--input=filename
  JSON file; if none given, STDIN is used
--output=filename
  XML file; if none given, STDOUT is used
-n
  do not generate XML header
-r=root-element
  wrap the resulting XML output in a root element named root-element
--array-name=array-element
  rename the array element in XML output to array-element; default: array
--item-name=item-element
  rename the item element in XML output to item-element; default: item
-s
  transform the string into a text element; default: transform into an
  attribute
-i
  transform number into a text element; default: transform into an attribute
-l
  transform true false null into <true/> <false/> <null/>; default:
  transform into an attribute
-c
  replace collision characters &<>"'% into XML variants &amp;&lt;&gt;
  &quot;&apos;&#37;
-a --array-size
  add attribute size to arrays with count of items
-t --index-items
  add attribute index to array items with their index number
--start=n
  set the starting value for array items indexing (requires the -t option);
  default: 1
HEREDOC
        ; exit 0
      }

      arg_mismatch($ARGV[0]);
    }
    case m/^--input=/ {
      (defined $arg_f_in) && arg_mismatch($ARGV[0]);

      $arg_f_in = substr(shift @ARGV, length('--input='));

      unless (open($f_in, "<", $arg_f_in)) {
        print STDERR "Can't open ".$arg_f_in." for reading.\n"; exit E_F_IN;
      }
    }
    case m/^--output=/ {
      (defined $arg_f_out) && arg_mismatch($ARGV[0]);

      $arg_f_out = substr(shift @ARGV, length('--output='));

      unless (open($f_out, ">", $arg_f_out)) {
        print STDERR "Can't open ".$arg_f_out." for writing.\n"; exit E_F_OUT;
      }
    }
    case '-n' {
      (defined $arg_n) && arg_mismatch($ARGV[0]);

      $arg_n = 1; shift @ARGV;
    }
    case m/^-r=/ {
      (defined $arg_r) && arg_mismatch($ARGV[0]);

      $arg_r = substr(shift @ARGV, length('-r='));

      unless ($arg_r =~ /^$XML::RegExp::Name$/) {
        print STDERR "Invalid root element name.\n"; exit E_ROOT_ELEM;
      }
    }
    case m/^--array-name=/ {
      (defined $arg_array_name) && arg_mismatch($ARGV[0]);

      $arg_array_name = substr(shift @ARGV, length('--array-name='));

      unless ($arg_array_name =~ /^$XML::RegExp::Name$/) {
        print STDERR "Invalid array name.\n"; exit E_ARRAY_NAME;
      }
    }
    case m/^--item-name=/ {
      (defined $arg_item_name) && arg_mismatch($ARGV[0]);

      $arg_item_name = substr(shift @ARGV, length('--item-name='));

      unless ($arg_item_name =~ /^$XML::RegExp::Name$/) {
        print STDERR "Invalid item name.\n"; exit E_ITEM_NAME;
      }
    }
    case '-s' {
      (defined $arg_s) && arg_mismatch($ARGV[0]);

      $arg_s = 1; shift @ARGV;
    }
    case '-i' {
      (defined $arg_i) && arg_mismatch($ARGV[0]);

      $arg_i = 1; shift @ARGV;
    }
    case '-l' {
      (defined $arg_l) && arg_mismatch($ARGV[0]);

      $arg_l = 1; shift @ARGV;
    }
    case '-c' {
      (defined $arg_c) && arg_mismatch($ARGV[0]);

      $arg_c = 1; shift @ARGV;
    }
    case {$ARGV[0] eq '-a' || $ARGV[0] eq '--array-size'} {
      (defined $arg_a) && arg_mismatch($ARGV[0]);

      $arg_a = 1; shift @ARGV;
    }
    case {$ARGV[0] eq '-t' || $ARGV[0] eq '--index-items'} {
      (defined $arg_t) && arg_mismatch($ARGV[0]);

      $arg_t = 1; shift @ARGV;
    }
    case m/^--start=/ {
      (defined $arg_start) && arg_mismatch($ARGV[0]);

      $arg_start = substr(shift @ARGV, length('--start='));

      # FIXME negative numbers?
      unless (is_int($arg_start)) {
        print STDERR "Invalid start number.\n"; exit E_ARG;
      }
    }
    else {
      print STDERR "Unknown argument ".$ARGV[0]."\n"; exit E_ARG
    }
  }
}

# check arguments compatibility
$f_in = *STDIN unless defined $f_in;
$f_out = *STDOUT unless defined $f_out;
$arg_array_name = 'array' unless defined $arg_array_name;
$arg_item_name = 'item' unless defined $arg_item_name;

if (defined $arg_start) {
  arg_mismatch('--start') unless defined $arg_t;
} else {
  $arg_start = I_START;
}

# read and parse JSON
my $str_json;
while (<$f_in>) { $str_json .= $_; }
my $ref_json = decode_json($str_json);

# output: XML head
print $f_out XML_HEAD unless ($arg_n);

# we don't want <root></root>, but <root/> if the content is empty
if (ref $ref_json eq 'HASH' && hash_empty($ref_json)) {
    print $f_out '<'.$arg_r."/>\n" if ($arg_r);
}
else {
  print $f_out '<'.$arg_r.">\n" if ($arg_r);
  traverse_json($ref_json);
  print $f_out '</'.$arg_r.">\n" if ($arg_r);
}

# normalize JSON values to be XML compatible
sub normalize {
  $_ = shift @_;
  $_ =~ s/[&<>"']/-/g;
  return $_;
}

sub translate {
  $_ = shift @_;
  $_ =~ s/[&]/&amp;/g;
  $_ =~ s/[<]/&lt;/g;
  $_ =~ s/[>]/&gt;/g;
  $_ =~ s/["]/&quot;/g;
  $_ =~ s/[']/&apos;/g;
  return $_;
}

sub hash_empty {
  my $hash = shift @_;
  # it is not empty
  foreach (keys %{$hash}) { return 0; }
  # it is empty
  return 1;
}

sub array_empty {
  my $arr = shift @_;
  foreach (@{$arr}) {
    # only hash could be empty
    if (ref $_ eq 'HASH') {
      if (!hash_empty($_)) { return 0; }
    }
    # anything else could not be empty
    else {
      return 0;
    }
  }
  # it is definitely empty
  return 1;
}

sub handle_l {
  my ($name, $attr) = @_;

  if ($arg_l) {
    print $f_out "<$name>\n<$attr/>\n</$name>\n";
  }
  else {
    print $f_out "<$name value=\"$attr\"/>\n";
  }
}

# handle number, string, true, false, null
sub handle_scalar {
  #FIXME name value
  my ($name, $tmp) = @_;

  if (JSON::true($tmp)) {
    handle_l($name, 'true');
  }
  elsif (JSON::false($tmp)) {
    handle_l($name, 'false');
  }
  elsif (JSON::null($tmp)) {
    handle_l($name, 'null');
  }
  else {
    my $num = to_int($tmp);

    if (defined $num) {
      if ($arg_i) {
        print $f_out "<$name>\n$num\n</$name>\n";
      }
      else {
        print $f_out "<$name value=\"$num\"/>\n";
      }
    }
    else {
      # "dash" normalization
      my $ret = normalize($tmp);

      if ($arg_c) {
        $ret = translate($ret);
        # FIXME debug: check XML validity FIXME
        #   toto potom smazu/zakomentuji
        if ($ret !~ /^$XML::RegExp::AttValue$/)
        {
          print STDERR "DEBUG Invalid XML element value.\n"; exit E_XML_ELEM;
        }

      }
      else {
        # check XML validity
        if ($ret !~ /^$XML::RegExp::AttValue$/)
        {
          print STDERR "Invalid XML element value.\n"; exit E_XML_ELEM;
        }
      }

      if ($arg_s) {
        print $f_out "<$name>\n$ret\n</$name>\n";
      }
      else {
        print $f_out "<$name value=\"$ret\"/>\n";
      }
    }
  }
}

# traverse the JSON structure and produce XML (handle array + object)
sub traverse_json {
  # JSN number -> scalar
  # JSN string -> scalar
  # JSN array -> arrayref
  # JSN object -> hashref
  # JSN true -> JSON::true
  # JSN false -> JSON::false
  # JSN null -> JSON::null

  # array_item/hash_value, array_index, hash_key
  # FIXME smazat $name
  my ($item, $index, $name) = @_;

  # handle indexing
  my $common_attrs;
  if ($index && $arg_t) {
    $common_attrs = "$common_attrs index=\"$index\"";
  }

  # FIXME we know, there was a hash => handle_key_values
  if (ref $item eq 'ARRAY') {
    if (array_empty($item)) {
      # <array index="" size=""/>
      print $f_out "<$arg_array_name$common_attrs";
      # array size
      if ($arg_a) { print $f_out ' size="0"'; }
      print $f_out "/>\n";
    }
    else {
      print $f_out "<$arg_array_name$common_attrs";
      # array size
      if ($arg_a) {print $f_out ' size="'.scalar @{$item}.'"';}
      print $f_out ">\n";

      my $i = $arg_start;
      foreach (@{$item}) {
        # should we index the non-existing array-items too? NO!
        if (ref $_ eq 'HASH' && hash_empty($_)) { next; }

        # FIXME trasovat dalsi pruchod rekurzi
        traverse_json($_, $i);
        $i++;
      }
      print $f_out "</$arg_array_name>\n";
    }
  }
  elsif (ref $item eq 'HASH') {
    if (hash_empty($item)) return;

    #FIXME zanoreni s indexem v POLI: asi neresit, protoze by vsechny
    #  polozky musely mit stejny index, coz je blbost
    #print $f_out "<$name$common_attrs>" if ($name);

    foreach (keys %{$item}) {
      if (ref $item->{$_} eq 'HASH') {
        if (hash_empty($item->{$_})) {
          print $f_out "<$_/>\n";
        }
        else {
          # FIXME trasovat dalsi pruchod rekurzi
          # $_=klic $value=->{$_}
          print $f_out "<$_>\n";
          #traverse_json($item->{$_}, undef, $_);
          traverse_json($item->{$_});
          print $f_out "</$_>\n";
        }
      }
      elsif (ref $item->{$_} eq 'ARRAY') {
        print $f_out "<$_>\n";
        traverse_json($item->{$_});
        print $f_out "</$_>\n";
      }
      else {
        handle_scalar($_, $item->{$_});
      }
    }
  }
  # it is an ordinary array value
  else {
    handle_scalar("$arg_item_name$common_attrs", $item);
  }

#  my ($item, $path) = @_;
#  if (ref $item eq 'ARRAY') {
#    foreach (@{$item}) {
#      traverse($_, $path);
#    }
#  }
#  elsif (ref $item eq 'HASH') {
#    foreach (keys %{$item}) {
#      push @{$path}, $_;
#      traverse($item->{$_}, $path);
#      pop @{$path};
#    }
#  }
#  else {
#    print join('-', @$path, $item), "\n";
#  }
}

