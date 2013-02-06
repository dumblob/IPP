#!/usr/bin/perl

#JSN:xpacne00

use common::sense;
use Switch;
use Data::Types('is_int', 'to_int');
use JSON;
use XML::RegExp;  # XML entity validator

use constant {
  E_ARG        => 1,    # arguments
  E_F_IN       => 2,    # input file (ro)
  E_F_OUT      => 3,    # output file (rw)
  E_F_FORMAT   => 4,    # input file format
  E_ROOT_ELEM  => 50,   # invalid root element given
  E_ARRAY_NAME => 50,   # invalid array name given
  E_ITEM_NAME  => 50,   # invalid item name given
  E_XML_ELEM   => 51,   # invalid XML after "dash" normalization
  E_MISC       => 100,  # other error

  # tag for hash strings (to distinguish them from numbers)
  STR_PREFIX => '?#%&*$+-;<>',
  I_START    => 1,  # initial array counter value
  XML_HEAD   => "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
};

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

sub arg_mismatch {
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
my $_str_prefix = STR_PREFIX;
my $_str_prefix_quoted = quotemeta($_str_prefix);
my $str_json;
while (<$f_in>) { $str_json .= $_; }
# tag hash strings (to distinguish them from numbers) by adding prefix
$str_json =~ s/("[^"]*"\s*[:]\s*")([^"]*?[\\]?")/$1$_str_prefix$2/g,
my $ref_json = decode_json($str_json);

# output: XML head
print $f_out XML_HEAD unless ($arg_n);

# we don't want <root></root>, but <root/> if there is no content
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

# return true if the given hash is empty
sub hash_empty {
  my $hash = shift @_;
  # it is not empty
  foreach (keys %{$hash}) { return 0; }
  # it is empty
  return 1;
}

# return true if the given array is empty
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
  # no non-empty value found
  return 1;
}

# handle the -l argument
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
  my ($name, $tmp, $from_hash) = @_;

  if (JSON::is_bool($tmp)) {
    handle_l($name, $tmp);
  }
  # JSON null
  elsif (!defined $tmp) {
    handle_l($name, 'null');
  }
  else {
    if (defined $from_hash && $tmp =~ m/^$_str_prefix_quoted/) {
      # remove prefix from hash string
      $tmp =~ s/^$_str_prefix_quoted//;

      # "dash" normalization
      $name = normalize($name);

      # check element name XML validity
      if ($name !~ /^$XML::RegExp::Name$/) {
        print STDERR "Invalid XML element name.\n"; exit E_XML_ELEM;
      }

      if ($arg_c) {
        $tmp = translate($tmp);
      }
      else {
        # check attribute value XML validity
        if ("\"$tmp\"" !~ /^$XML::RegExp::AttValue$/) {
          print STDERR "Invalid XML element value.\n"; exit E_XML_ELEM;
        }
      }

      if ($arg_s) {
        print $f_out "<$name>\n$tmp\n</$name>\n";
      }
      else {
        print $f_out "<$name value=\"$tmp\"/>\n";
      }
    }
    # FIXME because "string" could not be in ARRAY, this is definitely a number
    else {
      $tmp = to_int($tmp);

      if ($arg_i) {
        print $f_out "<$name>\n$tmp\n</$name>\n";
      }
      else {
        print $f_out "<$name value=\"$tmp\"/>\n";
      }
    }
  }
}

# traverse the JSON structure and produce XML (handle array + object)
sub traverse_json {
  # array/array_item/hash, array_index
  my ($item, $index) = @_;

  # handle indexing
  my $common_attrs;
  if (defined $index && $arg_t) {
    $common_attrs = "$common_attrs index=\"$index\"";
  }

  if (ref $item eq 'ARRAY') {
    # <array index="" size=""/>
    if (array_empty($item)) {
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
        # we MUST index the non-existing array-items too!
        #if (ref $_ eq 'HASH' && hash_empty($_)) { next; }

        traverse_json($_, $i);
        $i++;
      }
      print $f_out "</$arg_array_name>\n";
    }
  }
  elsif (ref $item eq 'HASH') {
    # hash in array, wtf?
    if (defined $index) {
      print $f_out "<$arg_item_name$common_attrs>\n";
    }

    if (hash_empty($item)) { return; };

    foreach (keys %{$item}) {
      if (ref $item->{$_} eq 'HASH') {
        if (hash_empty($item->{$_})) {
          print $f_out "<".normalize($_)."/>\n";
        }
        else {
          print $f_out "<".normalize($_).">\n";
          traverse_json($item->{$_});
          print $f_out "</".normalize($_).">\n";
        }
      }
      elsif (ref $item->{$_} eq 'ARRAY') {
        print $f_out "<".normalize($_).">\n";
        traverse_json($item->{$_});
        print $f_out "</".normalize($_).">\n";
      }
      else {
        handle_scalar($_, $item->{$_}, 'it_is_from_hash');
      }
    }

    # hash in array, wtf?
    if (defined $index) {
      print $f_out "</$arg_item_name>\n";
    }
  }
  # it is an ordinary array value
  else {
    handle_scalar("$arg_item_name$common_attrs", $item);
  }
}
