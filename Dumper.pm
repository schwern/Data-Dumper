#
# Data/Dumper.pm
#
# convert perl data structures into perl syntax suitable for both printing
# and eval
#
# Documentation at the __END__
#

package Data::Dumper;

$VERSION = $VERSION = '2.01';

#$| = 1;

require 5.002;
require Exporter;
require DynaLoader;

use Carp;

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(Dumper);
@EXPORT_OK = qw(DumperX);

bootstrap Data::Dumper;

# module vars and their defaults
$Indent = 2 unless defined $Indent;
$Purity = 0 unless defined $Purity;
$Pad = "" unless defined $Pad;
$Varname = "VAR" unless defined $Varname;

#
# expects an arrayref of values to be dumped.
# can optionally pass an arrayref of names for the values.
# names must have leading $ sign stripped. begin the name with *
# to cause output of arrays and hashes rather than refs.
#
sub new {
  my($c, $v, $n) = @_;

  croak "Usage:  PACKAGE->new(ARRAYREF, [ARRAYREF])" 
    unless (defined($v) && (ref($v) eq 'ARRAY'));
  $n = [] unless (defined($n) && (ref($v) eq 'ARRAY'));

  my($s) = { 
             level      => 0,        # current recursive depth
	     indent     => $Indent,  # various styles of indenting
	     xpad       => $Pad,     # all lines prefixed by this string
	     pad        => "",       # padding-per-level
	     apad       => "",       # added padding for hash keys n such
	     sep        => "",       # list separator
	     seen       => {},       # local (nested) refs (id => [name, val])
	     todump     => $v,       # values to dump []
	     names      => $n,       # optional names for values []
	     anonpfx    => $Varname, # prefix to use for tagging nameless ones
             purity     => $Purity,  # degree to which output is evalable
#             useqq => 0,             # use "" for strings (backslashitis)
#             freezer => "",          # name of Freezer method for objects
#             maxdepth => 0,          # depth beyond which we give up
#	      expdepth   => 0,        # cutoff for explicit dumping
	   };

  if ($Indent > 0) {
    $s->{pad} = "  ";
    $s->{sep} = "\n";
  }
  return bless($s, $c);
}

#
# add-to or query the table of already seen references
#
sub Seen {
  my($s, $g) = @_;
  if (defined($g) && (ref($g) eq 'HASH'))  {
    my($k, $v, $id);
    while (($k, $v) = each %$g) {
      if (defined $v and ref $v) {
	($id) = ("$v" =~ /\((.*)\)$/);
	if ($k =~ /^[*](.*)$/) {
	  $k = (ref $v eq 'ARRAY') ? ( "\\\@" . $1 ) :
	    (ref $v eq 'HASH') ? ( "\\\%" . $1 ) :
	      ("\$" . $1 );
	}
	elsif ($k !~ /^\$/) {
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
    return map { @$_ } values %{$s->{seen}};
  }
}

#
# set or query the values to be dumped
#
sub Values {
  my($s, $v) = @_;
  if (defined($v) && (ref($v) eq 'ARRAY'))  {
    $s->{todump} = [@$v];        # make a copy
  }
  else {
    return @{$s->{todump}};
  }
}

#
# set or query the names of the values to be dumped
#
sub Names {
  my($s, $n) = @_;
  if (defined($n) && (ref($n) eq 'ARRAY'))  {
    $s->{names} = [@$n];         # make a copy
  }
  else {
    return @{$s->{names}};
  }
}

sub DESTROY {}

#
# dump the refs in the current dumper object.
# expects same args as new() if called via package name.
#
sub Dump {
  my($s) = shift;
  my($out, $val, $name);
  my($i) = 0;
  local(@post);

  $s = $s->new(@_) unless ref $s;
  $out = "";

  for $val (@{$s->{todump}}) {
    @post = ();
    $name = $s->{names}[$i++];
    if (defined $name) {
      if ($name =~ /^[*](.*)$/) {
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
      elsif ($name !~ /^\$/) {
	$name = "\$" . $name;
      }
    }
    else {
      $name = "\$" . $s->{anonpfx} . $i;
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
  my($out, $realpack, $realtype, $type, $ipad, $id, $blesspad);

  return "undef" unless defined $val;

  $type = ref $val;
  $out = "";

  if ($type) { 
    ($realpack, $realtype, $id) = ("$val" =~ /^(?:(.*)\=)?([^=]*)\(([^(]*)\)$/);
    
    # keep a tab on it so that we dont fall into recursive pit
    if (exists $s->{seen}{$id}) {
#      if ($s->{expdepth} < $s->{level}) {
      if ($s->{purity} and $s->{level} > 0) {
	$out = '{}' if ($realtype eq 'HASH');
	$out = '[]' if ($realtype eq 'ARRAY');
	push @post, $name . " = " . $s->{seen}{$id}[0];
      }
      else {
	$out = $s->{seen}{$id}[0];
	$out = $1 . '{' . $out . '}' if $name =~ /^([\@\%])/;
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
    
    if ($realtype eq 'SCALAR' or $realtype eq 'GLOB') {
      if ($realpack) {
	$out .= '\\' . '($_ = ' . $s->_dump($$val, "\$$name") . ')';
      }
      else {
	$out .= '\\' . $s->_dump($$val, "\$$name");
      }
    }
    elsif ($realtype eq 'ARRAY') {
      my($v, $pad, $mname);
      my($i) = 0;
      $out .= ($name =~ /^\@/) ? '(' : '[';
      $pad = $s->{sep} . $s->{xpad} . $s->{apad};
      ($name =~ /^\@(.*)$/) ? ($mname = "\$" . $1) : 
	($name =~ /[]}]$/) ? ($mname = $name) : ($mname = $name . '->');
      for $v (@$val) {
	$sname = $mname . '[' . $i . ']';
	$out .= $pad . $ipad . '#' . $i if $s->{indent} >= 3;
	$out .= $pad . $ipad . $s->_dump($v, $sname);
	$out .= "," if $i++ < $#$val;
      }
      $out .= $pad . ($s->{pad} x ($s->{level} - 1)) if $i;
      $out .= ($name =~ /^\@/) ? ')' : ']';
    }
    elsif ($realtype eq 'HASH') {
      my($k, $v, $pad, $lpad, $mname);
      $out .= ($name =~ /^\%/) ? '(' : '{';
      $pad = $s->{sep} . $s->{xpad} . $s->{apad};
      $lpad = $s->{apad};
      ($name =~ /^\%(.*)$/) ? ($mname = "\$" . $1) : 
	($name =~ /[]}]$/) ? ($mname = $name) : ($mname = $name . '->');
      while (($k, $v) = each %$val) {
	$k = '\'' . $k . '\'' if $k =~ s/([\\\'])/\\$1/g or 
                                 $k =~ /[\W\d]|^$/ or $s->{purity};
	$sname = $mname . '{' . $k . '}'; 
	$out .= $pad . $ipad . $k . " => ";

	# temporarily alter apad
	$s->{apad} .= (" " x (length($k) + 4)) if $s->{indent} >= 2;
	$out .= $s->_dump($v, $sname) . ",";
	$s->{apad} = $lpad if $s->{indent} >= 2;
      }
      if (substr($out, -1) eq ',') {
	chop $out;
	$out .= $pad . ($s->{pad} x ($s->{level} - 1));
      }
      $out .= ($name =~ /^\%/) ? ')' : '}';
    }
    elsif ($realtype eq 'CODE') {
      $out .= "$val";
      $out = 'sub { \'' . $out . '\' }';
      carp "Encountered CODE ref, using dummy placeholder" if $s->{purity};
    }
    else {
      croak "Can\'t handle $realtype type.";
    }
    
    if ($realpack) { # we have a blessed ref
      $out .= ', \'' . $realpack . '\'' . ' )';
      $s->{apad} = $blesspad;
    }
    $s->{level}--;
  }
  else {                                 # simple scalar
    if ($val =~ /^-?[1-9]\d{0,8}$/) {    # safe decimal number
      $out .= $val;
    }
    elsif (ref(\$val) eq 'GLOB') {       # glob
      $sname = substr($val, 1);
      $sname = '{\'' . $sname . '\'}' 
	if $sname =~ s/([\\\'])/\\$1/g or $sname =~ /[^:\w]|^$/;
      $out .= '*' . $sname;
    }
    else {
      $val =~ s/([\\\'])/\\$1/g;
      $out .= '\'' . $val .  '\'';       # string 
    }
  }

  return $out;
}
  
#
# non-OO style of earlier version
#
sub Dumper {
  return Data::Dumper->Dump([@_]);
}

#
# same, only calls the XS version
#
sub DumperX {
  return Data::Dumper->Dumpxs([@_], []);
}

sub Dumpf { return Data::Dumper->Dump(@_) }

sub Dumpp { print Data::Dumper->Dump(@_) }

#
# reset the "seen" cache 
#
sub Reset {
  my($s) = shift;
  $s->{seen} = {};
}

sub Indent {
  my($s, $v) = @_;
  defined($v) ? ($s->{indent} = $v) : $s->{indent};
}

sub Pad {
  my($s, $v) = @_;
  defined($v) ? ($s->{xpad} = $v) : $s->{xpad};
}

sub Varname {
  my($s, $v) = @_;
  defined($v) ? ($s->{anonpfx} = $v) : $s->{anonpfx};
}

sub Purity {
  my($s, $v) = @_;
  defined($v) ? ($s->{purity} = $v) : $s->{purity};
}

1;
__END__

=head1 NAME

Dumper - stringified perl data structures, suitable for both printing and
eval


=head1 SYNOPSIS

    use Data::Dumper;

    # simple procedural interface
    print Dumper($foo, $bar);

    # extended usage with names
    print Data::Dumper->Dump([$foo, $bar], [qw(foo *ary)]);

    # configuration variables
    {
      local $Data::Dump::Purity = 1;
      eval Data::Dumper->Dump([$foo, $bar], [qw(foo *ary)]);
    }

    # OO usage
    $d = Data::Dumper->new([$foo, $bar], [qw(foo *ary)]);
       ...
    print $d->Dump;
       ...
    $d->Purity(1);
    eval $d->Dump;


=head1 DESCRIPTION

Given a list of scalars or reference variables, writes out their contents in
perl syntax. The references can also be objects.  The contents of each
variable is output in a single Perl statement.

The return value can be C<eval>ed to get back the original reference
structure. Bear in mind that a reference so created will not preserve
pointer equalities with the original reference.

Handles self-referential structures correctly.  Any references that are the
same as one of those passed in will be marked C<$VARI<n>>, and other duplicate
references to substructures within C<$VARI<n>> will be appropriately labeled
using arrow notation.

The default output of self-referential structures can be C<eval>ed, but the
nested references to C<$VARI<n>> will be undefined, since a recursive structure
cannot be constructed using one Perl statement.  You can set
C<$Data::Dumper::Purity> to 1 to get additional statements that will
correctly fill in these references.

In the extended usage form, the references to be dumped can be given
user-specified names.  If a name begins with a C<*>, the output will 
describe the dereferenced type of the supplied reference for hashes and
arrays.

Several styles of output are possible, all controlled by setting
C<$Data::Dumper::Indent> or using the corresponding method name.  Style 0
spews output without any newlines, indentation, or spaces between list
items.  It is the most compact format possible that can still be called
valid perl.  Style 1 outputs a readable form with newlines but no fancy
indentation (each level in the structure is simply indented by a fixed
amount of whitespace).  Style 2 (the default) outputs a very readable form
which takes into account the length of hash keys (so the hash value lines
up).  Style 3 is like style 2, but also annotates the elements of arrays
with their index (but the comment is on its own line, so array output
consumes twice the number of lines).


=head2 Methods

=over 4

=item I<PACKAGE>->new(I<ARRAYREF [>, I<ARRAYREF]>)

Returns a newly created C<Dumper> object.  The first argument is an
anonymous array of values to be dumped.  The optional second argument is an
anonymous array of names for the values.  The names need not have a leading
C<$> sign, and must be comprised of alphanumeric characters.  You can begin
a name with a C<*> to specify that the dereferenced type must be dumped
instead of the reference itself.

The prefix specified by C<$Data::Dumper::Varname> will be used with a
numeric suffix if the name for a value is undefined.

=item $I<OBJ>->Dump  I<or>  I<PACKAGE>->Dump(I<ARRAYREF [>, I<ARRAYREF]>)

Returns the stringified form of the values stored in the object (preserving
the order in which they were supplied to C<new>), subject to the
configuration options below.

The second form, for convenience, simply calls the C<new> method on its
arguments before dumping the object immediately.

=item $I<OBJ>->Dumpxs  I<or>  I<PACKAGE>->Dumpxs(I<ARRAYREF [>, I<ARRAYREF]>)

This method is available if you were able to compile and install the XSUB
extension to C<Data::Dumper>. It is exactly identical to the C<Dump> method 
above, only about 4 to 5 times faster, since it is written entirely in C.

=item $I<OBJ>->Seen(I<[HASHREF]>)

Queries or adds to the internal table of already encountered references.
You must use C<Reset> to explicitly clear the table if needed.  Such
references are not dumped; instead, their names are inserted wherever they
are to be dumped subsequently.

Expects a anonymous hash of name => value pairs.  Same rules apply for names
as in C<new>.  If no argument is supplied, will return the "seen" list of
name => value pairs, in an array context.

=item $I<OBJ>->Values(I<[ARRAYREF]>)

Queries or replaces the internal array of values that will be dumped.

=item $I<OBJ>->Names(I<[ARRAYREF]>)

Queries or replaces the internal array of user supplied names for the values
that will be dumped.

=item $I<OBJ>->Reset

Clears the internal table of "seen" references.

=back

=head2 Functions

=over 4

=item Dumper(I<LIST>)

Returns the stringified form of the values in the list, subject to the
configuration options below.  The values will be named C<$VARI<n>> in the
output, where C<I<n>> is a numeric suffix.

=item DumperX(I<LIST>)

Identical to the C<Dumper> function above, but this calls the XSUB 
implementation, and is therefore about 3 to 4 times faster.  Only available
if you were able to compile and install the XSUB extensions in 
C<Data::Dumper>.

=back

=head2 Configuration Variables/Methods

Several configuration variables can be used to control the kind of output
generated when using the procedural interface.  These variables are usually
C<local>ized in a block so that other parts of the code are not affected by
the change.  

These variables determine the default state of the object created by calling
the C<new> method, but cannot be used to alter the state of the object
thereafter.  The equivalent method names should be used instead to query
or set the internal state of the object.

=over 4

=item $Data::Dumper::Indent  I<or>  $I<OBJ>->Indent(I<[NEWVAL]>)

Controls the style of indentation.  It can be set to 0, 1, 2 or 3.  2 is the
default.

=item $Data::Dumper::Purity  I<or>  $I<OBJ>->Purity(I<[NEWVAL]>)

Controls the degree to which the output can be C<eval>ed to recreate the
supplied reference structures.  Setting it to 1 will output additional perl
statements that will correctly recreate nested references.  The default is
0.

=item $Data::Dumper::Pad  I<or>  $I<OBJ>->Pad(I<[NEWVAL]>)

Specifies the string that will be prefixed to every line of the output.
Empty string by default.

=item $Data::Dumper::Varname  I<or>  $I<OBJ>->Varname(I<[NEWVAL]>)

Contains the prefix to use for tagging variable names in the output. The
default is "VAR".

=back

=head2 Exports

=item Dumper


=head1 EXAMPLE

    use Data::Dumper;

    package Foo;
    sub new {bless {'a' => 1, 'b' => sub { return "foo" }}, $_[0]};

    package Fuz;                       # a wierd REF-REF-SCALAR object
    sub new {bless \($_ = \ 'fu\'z'), $_[0]};

    package main;
    $foo = Foo->new;
    $fuz = Fuz->new;
    $boo = [ 1, [], "abcd", \*foo,
             {1 => 'a', 023 => 'b', 0x45 => 'c'}, 
             \\"p\q\'r", $foo, $fuz];
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

    $d = Data::Dumper->new([$a,$b], [qw(a b)]);     # go OO
    $d->Seen({'*c' => $c});            # stash a ref without printing it
    $d->Indent(3);
    print $d->Dump;
    $d->Reset;                         # empty the seen cache
    $d->Purity(0);
    print $d->Dump;


=head1 BUGS

Due to limitations of Perl subroutine call semantics, you can't pass an
array or hash.  Prepend it with a C<\> to pass its reference instead.  This
will be remedied in time, with the arrival of prototypes in later versions
of Perl.  For now, you need to use the extended usage form, and prepend the
name with a C<*> to output it as a hash or array.

C<Dumper> cheats with CODE references.  If a code reference is encountered in
the structure being processed, an anonymous subroutine returning the perl
string-interpolated representation of the original CODE reference will be
inserted in its place, and a warning will be printed if C<Purity> is
set.  You can C<eval> the result, but bear in mind that the anonymous sub
that gets created is a dummy placeholder. Someday, perl will have a switch
to cache-on-demand the string representation of a compiled piece of code, I
hope.

SCALAR objects have the wierdest looking C<bless> workaround.


=head1 AUTHOR

Gurusamy Sarathy        gsar@umich.edu

Copyright (c) 1995 Gurusamy Sarathy. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 VERSION

Version 2.01beta    10 April 1996


=head1 SEE ALSO

perl(1)

=cut
