#
# Data/Dumper.pm
#
# convert perl data structures into perl syntax suitable for both printing
# and eval
#
# Documentation at the __END__
#

package Data::Dumper;

$VERSION = $VERSION = '1.21';

#$| = 1;

require 5.001;
require Exporter;
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(Dumper);
#@EXPORT_OK = qw(Dumper);

# module vars and their defaults
$Indent = 2 unless defined $Indent;
$Purity = 0 unless defined $Purity;
$Pad = "" unless defined $Pad;
$Varname = "VAR" unless defined $Varname;

$i = 0;

#
# expects an arrayref of values to be dumped.
# can optionally pass an arrayref of names for the values.
# names must have leading $ sign stripped. begin the name with *
# to cause output of arrays and hashes rather than refs.
#
sub new {
  my($c, $v, $n) = @_;

  die "Usage:  $c->new(ARRAYREF, [ARRAYREF])" 
    unless (defined($v) && (ref($v) eq 'ARRAY'));
  $n = [] unless (defined($n) && (ref($v) eq 'ARRAY'));

  my($s) = { 
             level      => 0,        # current recursive depth
	     indent     => $Indent,  # various styles of indenting
	     xpad       => $Pad,     # all lines prefixed by this string
	     pad        => "",       # padding-per-level
	     apad       => "",       # added padding for hash keys n such
	     sep        => " ",      # list separator
	     seen       => {},       # local (nested) refs (id => [name, val])
	     todump     => $v,       # values to dump []
	     names      => $n,       # optional names for values []
	     anonpfx    => $Varname, # prefix to use for tagging nameless ones
             purity     => $Purity,  # degree to which output is evalable
#             maxdepth => 0,          # depth beyond which we give up
#	      expdepth   => 0,        # cutoff for explicit dumping
	   };

  return bless($s, $c);
}


#
# non-OO style of earlier version
#
sub Dumper {
  return new("Data::Dumper", [@_])->Dump();
}


#
# reset the "seen" cache 
#
sub Reset {
  my($s) = shift;
  $s->{seen} = {};
}


# set or query the table of already seen references
# expects a hashref of name => ref pairs. if the first char of
# name is *, name will be converted to @name or %name depending
# on the ref. in other cases, it will become $name.  if no arg
# is supplied, will return a list of name, ref pairs in an array
# context
#
sub Seen {
  my($s, $g) = @_;
  if (defined($g) && (ref($g) eq 'HASH'))  {
    my($k, $v, $id);
    while (($k, $v) = each %$g) {
      if (defined $v and ref $v) {
	($id) = ("$v" =~ /\((.*)\)$/o);
	if ($k =~ /^[*](.*)$/o) {
	  $k = (ref $v eq 'ARRAY') ? ( "\\\@" . $1 ) :
	    (ref $v eq 'HASH') ? ( "\\\%" . $1 ) :
	      ("\$" . $1 );
	}
	elsif ($k !~ /^\$/o) {
	  $k = "\$" . $k;
	}
	$s->{seen}{$id} = [$k, $v];
      }
      else {
	carp "Only refs supported, ignoring non-ref item \$$k";
      }
    }
  }
  else {
    return wantarray ? map { @$_ } values %{$s->{seen}} : undef;
  }
}

#
# dump the refs in the current dumper object.
# expects same args as new() if called via package name.
#
sub Dump {
  my($s) = shift;
  my($out, $val, $name);
  local(@post);

  $s = $s->new(@_) unless ref $s;

  $s->{indent} = $Indent;
  $s->{purity} = $Purity;
  $s->{anonpfx} = $Varname;
  $s->{xpad} = $Pad;
  if ($Indent >= 1) {
    $s->{pad} = "  ";
    $s->{sep} = "\n";
#    $s->{expdepth} = 5;
  }

  for $val (@{$s->{todump}}) {
    @post = ();
    $name = shift(@{$s->{names}});
    if (defined $name) {
      if ($name =~ /^[*](.*)$/o) {
	if (defined $val) {
	  $name = (ref $val eq 'ARRAY') ? ( "\@" . $1 ) :
	    (ref $val eq 'HASH') ? ( "\%" . $1 ) :
	      ("\$" . $1 );
	}
	else {
	  $name = "\@" . $1;
	  $val = [];
	}
      }
      elsif ($name !~ /^\$/o) {
	$name = "\$" . $name;
      }
    }
    else {
      $name = "\$" . $s->{anonpfx} . ++$i;
    }
    $s->{apad} = ' ' x (length($name) + 3) if $s->{indent} >= 2;
    $out .= $s->{xpad} . "$name = " . $s->_dump($val, $name) . ';' . $s->{sep};
    $out .= $s->{xpad} . join(";" . $s->{sep} . $s->{xpad}, @post) . ";" . $s->{sep} if @post;
  }
  return $out;
}

#
# twist, toil and turn;
# and recurse, of course.
#
sub _dump {
  my($s, $val, $name) = @_;
  my($sname);
  my($out, $realpack, $realtype, $type, $i, $ipad, $id, $blesspad);

  return "undef" unless defined $val;

  $type = ref $val;

  if ($type) { 
    ($realpack, $realtype, $id) = ("$val" =~ /^(([^=]*)\=)?(.*)\((.*)\)$/o)[1,2,3];
    
    # keep a tab on it so that we dont fall into recursive pit
    if (exists $s->{seen}{$id}) {
#      if ($s->{expdepth} < $s->{level}) {
      $out = $s->{seen}{$id}[0];
      if ($s->{level} == 0) {
	$out = $1 . '{' . $out . '}' if $name =~ /^([\@\%])/;
      }
      else {
	push @post, $name . " = " . $s->{seen}{$id}[0] if $s->{purity} == 1;
      }
      return $out;
#      }
    }
    else {
      # store our name
      $s->{seen}{$id} = [($name =~ /^[@%].*$/) ? ('\\' . $name ) : $name, $val];
    }

    $s->{level}++;
    $ipad = $s->{pad} x $s->{level};

    if ($realpack) {          # we have a blessed ref
      $out = 'bless( ';
      $blesspad = $s->{apad};
      $s->{apad} .= '       ' if ($s->{indent} >= 2);
    }
    
    if ($realtype eq 'REF') {
      if ($realpack) {
	  $out .= '\\' . '($_ = ' . $s->_dump($$val, "\$$name") . ')';
      }
      else {
	$out .= '\\' . $s->_dump($$val, "\$$name");
      }
    }
    elsif ($realtype eq 'GLOB') {
      $out .= '\\' . "$$val";
    }
    elsif ($realtype eq 'SCALAR') {
      if ($realpack) {
	$out .= '\\' . '($_ = ' . $s->_dump($$val, "\$$name") . ')';
      }
      else {
	$out .= '\\' . $s->_dump($$val, "\$$name");
      }
    }
    elsif ($realtype eq 'ARRAY') {
      my($v, $pad, $mname);
      $out .= ($name =~ /^\@/o) ? '(' : '[';
      $i = -1;
      $pad = $s->{sep} . $s->{xpad} . $s->{apad};
      ($name =~ /^\@(.*)$/o) ? ($mname = "\$" . $1) : 
	($name =~ /[]}]$/o) ? ($mname = $name) : ($mname = $name . '->');
      for $v (@$val) {
	$sname = $mname . '[' . ++$i . ']';
	$out .= $pad . $ipad . '#' . $i if $s->{indent} >= 3;
	$out .= $pad . $ipad . $s->_dump($v, $sname);
	$out .= "," if $i < $#$val;
      }
      $out .= $pad . ($s->{pad} x ($s->{level} - 1)) unless substr($out, -1) eq '[';
      $out .= ($name =~ /^\@/o) ? ')' : ']';
    }
    elsif ($realtype eq 'HASH') {
      my($k, $v, $pad, $lpad, $mname);
      $out .= ($name =~ /^\%/o) ? '(' : '{';
      $pad = $s->{sep} . $s->{xpad} . $s->{apad};
      $lpad = $s->{apad};
      ($name =~ /^\%(.*)$/o) ? ($mname = "\$" . $1) : 
	($name =~ /[]}]$/o) ? ($mname = $name) : ($mname = $name . '->');
      while (($k, $v) = each %$val) {
	$sname = $mname . '{' . $k . '}'; 
	$out .= $pad . $ipad . $k . " => ";

	# temporarily alter apad
	$s->{apad} .= (" " x (length($k) + 4)) if $s->{indent} >= 2;
	$out .= $s->_dump($v, $sname) . ",";
	$s->{apad} = $lpad if $s->{indent} >= 2;
      }
      if (substr($out, -1) ne '{') {
	chop $out;
	$out .= $pad . ($s->{pad} x ($s->{level} - 1));
      }
      $out .= ($name =~ /^\%/o) ? ')' : '}';
    }
    elsif ($realtype eq 'CODE') {
      $out .= "$val";
      $out = 'sub { \'' . $out . '\'}';
    }
    else {
      die "Can\'t handle $realtype type.";
    }
    
    if ($realpack) { # we have a blessed ref
      $out .= ', \'' . $realpack . '\'' . ' )';
      $s->{apad} = $blesspad;
    }
    $s->{level}--;
  }
  else {   # simple scalar
    if ($val =~ /^[+-]?\d+\.?[\d]*$/o || ref(\$val) eq 'GLOB') {
      $out .= $val;                      # if number or glob
    }
    else {
      $out .= '\'' . $val .  '\'';       # if string
    }
  }

  return $out;
}
  
1;
__END__

=head1 NAME

Dumper - stringified perl data structures, suitable for both printing
and eval


=head1 SYNOPSIS

    use Data::Dumper;

    # simple usage
    print Dumper($foo, $bar);

    # extended usage with names
    print Data::Dumper->Dump([$foo, $bar], [qw(foo *ary)]);

    # OO usage
    $d = Data::Dumper->new([$foo, $bar], [qw(foo *ary)]);
       ...
    print $d->Dump;
       ...
    $Data::Dump::Purity = 1;
    eval $d->Dump;


=head1 DESCRIPTION

Given a list of scalars or reference variables, writes out their contents in
perl syntax. The references can also be objects.  The contents of each
variable is output in a single Perl statement.

The return value can be C<eval>ed to get back the original reference
structure. Bear in mind that a reference so created will not preserve
pointer equalities with the original reference.

Handles self-referential structures correctly.  Any references that are the
same as one of those passed in will be marked C<$VARn>, and other duplicate
references to substructures within C<$VARn> will be appropriately labeled
using arrow notation.

The default output of self-referential structures can be C<eval>ed, but the
nested references to C<$VARn> will be undefined, since a recursive structure
cannot be constructed using one Perl statement.  You can set
C<$Data::Dumper::Purity> to 1 to get additional statements that will
correctly fill in these references.

In the extended usage form, the supplied references can be given user-specified
names.  If a supplied name begins with a C<*>, the output will describe the
dereferenced type of the supplied reference for hashes and arrays.

Several styles of output are possible.  Style 0 gives the output without any
newlines or indentation.  Style 1 outputs a compact form with newlines but
no fancy indentation (each level in the structure is simply indented by a
fixed amount of whitespace).  Style 2 (the default) outputs a very readable
form which takes into account the length of hash keys (so the hash values
line up).  Style 3 is like style 2, but also annotates the elements of
arrays with their index (but the comment is on its own line, so array output
consumes twice the number of lines).


=head2 Exports

C<Dumper>


=head2 Configuration

The module variable C<$Data::Dumper::Indent> controls the style of
indentation.  It can be set to 0, 1, 2 or 3.  2 is the default.

The module variable C<$Data::Dumper::Purity> controls the degree to which
the output can be C<eval>ed to recreate the supplied reference structures.
Setting it to 1 will output additional perl statements that will correctly
recreate nested references.  The default is 0.

The module variable C<$Data::Dumper::Pad> specifies the string that will be
prefixed to every line of the output.  Empty string by default.

The module variable C<$Data::Dumper::Varname> controls the prefix to use
for tagging variable names in the output. The default is "VAR".


=head1 EXAMPLE

    use Data::Dumper;

    package Foo;
    sub new {bless {'a' => 1, 'b' => sub { return "foo" }}, $_[0]};

    package Fuz;                       # a wierd REF-REF-SCALAR object
    sub new {bless \($_ = \'fuz'), $_[0]};

    package main;
    $foo = Foo->new;
    $fuz = Fuz->new;
    $boo = [ 1, [], "abcd", \*foo, 
             {1 => 'a', 023 => 'b', 0x45 => 'c'},  
             \\"pqr", $foo, $fuz];
    $bar = eval(Dumper($boo)); 
    print($@) if $@;
    print Dumper($boo), Dumper($bar);  # pretty print (no array indices)
    
    $Data::Dumper::Indent = 0;         # turn off all pretty print
    print Dumper($boo), "\n";

    $Data::Dumper::Indent = 1;         # mild pretty print
    print Dumper($boo);

    $Data::Dumper::Indent = 3;         # pretty print with array indices
    print Dumper($boo);

    # recursive structure
    @c = ('c');
    $c = \@c;
    $b = {};
    $a = [1, $b, $c];
    $b->{a} = $a;
    $b->{b} = $a->[1];
    $b->{c} = $a->[2];
    print Data::Dumper->Dump([$a,$b,$c], [qw(a b c)]);

    $Data::Dumper::Purity = 1;         # fill in the holes for eval
    print Data::Dumper->Dump([$a, $b], [qw(*a b)]); # print as @a
    print Data::Dumper->Dump([$b, $a], [qw(*b a)]); # print as %b

    $d = Data::Dumper->new([$a,$b], [qw(a b)]);
    $d->Seen({'*c' => $c});            # stash a ref without printing it
    print $d->Dump;
    $d->Reset;                         # empty the seen cache
    print $d->Dump;


=head1 BUGS

Due to limitations of Perl subroutine call semantics, you can't pass an
array or hash.  Prepend it with a C<\> to pass its reference instead.  This
will be remedied in time, with the arrival of prototypes in later versions
of Perl.  For now, you need to use the extended usage form, and prepend the
name with a C<*> to output it as a hash or array.

C<Dumper> cheats with CODE references. If a code reference is encountered in
the structure being processed, an anonymous subroutine returning the perl
string-interpolated representation of the original CODE reference will be
inserted in its place. You can C<eval> the result, but bear in mind that the
anonymous sub that gets created is a dummy placeholder. Someday, perl will
have a switch to cache-on-demand the string representation of a compiled
piece of code, I hope.

SCALAR objects have the wierdest looking C<bless> workaround.


=head1 AUTHOR

Gurusamy Sarathy        gsar@umich.edu

Copyright (c) 1995 Gurusamy Sarathy. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 VERSION

Version 1.21    20 Nov 1995


=head1 SEE ALSO

perl(1)

=cut
