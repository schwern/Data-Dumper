#!./perl -w
#
# testsuite for Data::Dumper
#

use Data::Dumper;

my $TMAX;
my $XS;
my $TNUM = 0;
my $want = '';

sub TEST {
  my $t = join '', @_;
  ++$TNUM;
  print $t eq $want ? "ok $TNUM\n"
	: "not ok $TNUM\n--Expected--\n$want\n--Got--\n$t\n";
}

if (defined &Data::Dumper::Dumpxs) {
  print "### XS extension loaded, will run XS tests\n";
  $TMAX = 40; $XS = 1;
}
else {
  print "### XS extensions not loaded, will NOT run XS tests\n";
  $TMAX = 20; $XS = 0;
}

print "1..$TMAX\n";

#############
#############

@c = ('c');
$c = \@c;
$b = {};
$a = [1, $b, $c];
$b->{a} = $a;
$b->{b} = $a->[1];
$b->{c} = $a->[2];

#############
##
$want = <<'EOT';
$a = [
       1,
       {
         a => $a,
         b => $a->[1],
         c => [
                'c'
              ]
       },
       $a->[1]{c}
     ];
$b = $a->[1];
$c = $a->[1]{c};
EOT

TEST(Data::Dumper->Dump([$a,$b,$c], [qw(a b c)]));


#############
##
$want = <<'EOT';
@a = (
       1,
       {
         'a' => [],
         'b' => {},
         'c' => [
                  'c'
                ]
       },
       []
     );
$a[1]{'a'} = \@a;
$a[1]{'b'} = $a[1];
$a[2] = $a[1]{'c'};
$b = $a[1];
EOT

$Data::Dumper::Purity = 1;         # fill in the holes for eval
TEST(Data::Dumper->Dump([$a, $b], [qw(*a b)])); # print as @a

#############
##
$want = <<'EOT';
%b = (
       'a' => [
                1,
                {},
                [
                  'c'
                ]
              ],
       'b' => {},
       'c' => []
     );
$b{'a'}[1] = \%b;
$b{'b'} = \%b;
$b{'c'} = $b{'a'}[2];
$a = $b{'a'};
EOT

TEST(Data::Dumper->Dump([$b, $a], [qw(*b a)])); # print as %b

#############
##
$want = <<'EOT';
$a = [
  1,
  {
    'a' => [],
    'b' => {},
    'c' => []
  },
  []
];
$a->[1]{'a'} = $a;
$a->[1]{'b'} = $a->[1];
$a->[1]{'c'} = \@c;
$a->[2] = \@c;
$b = $a->[1];
EOT

$Data::Dumper::Indent = 1;
$d = Data::Dumper->new([$a,$b], [qw(a b)]);     # go OO
$d->Seen({'*c' => $c});            # stash a ref without printing it
TEST($d->Dump);

#############
##
$want = <<'EOT';
$a = [
       #0
       1,
       #1
       {
         a => $a,
         b => $a->[1],
         c => [
                #0
                'c'
              ]
       },
       #2
       $a->[1]{c}
     ];
$b = $a->[1];
EOT

$d->Indent(3);
$d->Reset;                         # empty the seen cache
$d->Purity(0);
TEST($d->Dump);

#############
##
$want = <<'EOT';
$VAR1 = [
  1,
  {
    'a' => [],
    'b' => {},
    'c' => [
      'c'
    ]
  },
  []
];
$VAR1->[1]{'a'} = $VAR1;
$VAR1->[1]{'b'} = $VAR1->[1];
$VAR1->[2] = $VAR1->[1]{'c'};
EOT

TEST(Dumper($a));

#############
##
$want = <<'EOT';
[
  1,
  {
    a => $VAR1,
    b => $VAR1->[1],
    c => [
      'c'
    ]
  },
  $VAR1->[1]{c}
]
EOT

{
  local $Data::Dumper::Purity = 0;
  local $Data::Dumper::Terse = 1;
  TEST(Dumper($a));
}

#############
##
$want = <<'EOT';
$VAR1 = {
  "abc\000\efg" => "mno\000"
};
EOT

$foo = { "abc\000\efg" => "mno\000" };
{
  local $Data::Dumper::Useqq = 1;
  TEST(Dumper($foo));
}


#############
#############

{
  package main;
  use Data::Dumper;
  $foo = 5;
  @foo = (10,\*foo);
  %foo = (a=>1,b=>\$foo,c=>\@foo);
  $foo{d} = \%foo;
  $foo[2] = \%foo;

#############
##
  $want = <<'EOT';
$foo = \*::foo;
*::foo{SCALAR} = \5;
*::foo{ARRAY} = [
  10,
  '',
  {
    'a' => 1,
    'b' => '',
    'c' => [],
    'd' => {}
  }
];
*::foo{ARRAY}->[1] = $foo;
*::foo{ARRAY}->[2]{'b'} = *::foo{SCALAR};
*::foo{ARRAY}->[2]{'c'} = *::foo{ARRAY};
*::foo{ARRAY}->[2]{'d'} = *::foo{ARRAY}->[2];
*::foo{HASH} = *::foo{ARRAY}->[2];
@bar = @{*::foo{ARRAY}};
%baz = %{*::foo{ARRAY}->[2]};
EOT

  $Data::Dumper::Purity = 1;
  TEST(Data::Dumper->Dump([\*foo, \@foo, \%foo], ['*foo', '*bar', '*baz']));

#############
##
  $want = <<'EOT';
$foo = \*::foo;
*::foo{SCALAR} = \5;
*::foo{ARRAY} = [
  10,
  '',
  {
    'a' => 1,
    'b' => '',
    'c' => [],
    'd' => {}
  }
];
*::foo{ARRAY}->[1] = $foo;
*::foo{ARRAY}->[2]{'b'} = *::foo{SCALAR};
*::foo{ARRAY}->[2]{'c'} = *::foo{ARRAY};
*::foo{ARRAY}->[2]{'d'} = *::foo{ARRAY}->[2];
*::foo{HASH} = *::foo{ARRAY}->[2];
$bar = *::foo{ARRAY};
$baz = *::foo{ARRAY}->[2];
EOT

  TEST(Data::Dumper->Dump([\*foo, \@foo, \%foo], ['foo', 'bar', 'baz']));

#############
##
  $want = <<'EOT';
@bar = (
  10,
  \*::foo,
  {}
);
*::foo{SCALAR} = \5;
*::foo{ARRAY} = \@bar;
*::foo{HASH} = {
  'a' => 1,
  'b' => '',
  'c' => [],
  'd' => {}
};
*::foo{HASH}->{'b'} = *::foo{SCALAR};
*::foo{HASH}->{'c'} = \@bar;
*::foo{HASH}->{'d'} = *::foo{HASH};
$bar[2] = *::foo{HASH};
%baz = %{*::foo{HASH}};
$foo = $bar[1];
EOT

  TEST(Data::Dumper->Dump([\@foo, \%foo, \*foo], ['*bar', '*baz', '*foo']));

#############
##
  $want = <<'EOT';
$bar = [
  10,
  \*::foo,
  {}
];
*::foo{SCALAR} = \5;
*::foo{ARRAY} = $bar;
*::foo{HASH} = {
  'a' => 1,
  'b' => '',
  'c' => [],
  'd' => {}
};
*::foo{HASH}->{'b'} = *::foo{SCALAR};
*::foo{HASH}->{'c'} = $bar;
*::foo{HASH}->{'d'} = *::foo{HASH};
$bar->[2] = *::foo{HASH};
$baz = *::foo{HASH};
$foo = $bar->[1];
EOT

  TEST(Data::Dumper->Dump([\@foo, \%foo, \*foo], ['bar', 'baz', 'foo']));

#############
##
  $want = <<'EOT';
$foo = \*::foo;
@bar = (
  10,
  $foo,
  {
    a => 1,
    b => \5,
    c => \@bar,
    d => $bar[2]
  }
);
%baz = %{$bar[2]};
EOT

  $Data::Dumper::Purity = 0;
  TEST(Data::Dumper->Dump([\*foo, \@foo, \%foo], ['*foo', '*bar', '*baz']));

#############
##
  $want = <<'EOT';
$foo = \*::foo;
$bar = [
  10,
  $foo,
  {
    a => 1,
    b => \5,
    c => $bar,
    d => $bar->[2]
  }
];
$baz = $bar->[2];
EOT

  TEST(Data::Dumper->Dump([\*foo, \@foo, \%foo], ['foo', 'bar', 'baz']));

}

#############
#############
{
  package main;
  my @dogs = ( 'Fido', 'Wags' );
  my %kennel = (
  	    First => \$dogs[0],
  	    Second =>  \$dogs[1],
  	   );
  $dogs[2] = \%kennel;
  my $mutts = \%kennel;
  
#############
##
  $want = <<'EOT';
%kennels = (
  First => \'Fido',
  Second => \'Wags'
);
@dogs = (
  $kennels{First},
  $kennels{Second},
  \%kennels
);
%mutts = %kennels;
EOT

  my $d = Data::Dumper->new( [\%kennel, \@dogs, $mutts], [qw(*kennels *dogs *mutts)] );
  TEST($d->Dump);
  
#############
##
  $want = <<'EOT';
%kennels = %kennels;
@dogs = @dogs;
%mutts = %kennels;
EOT

  TEST($d->Dump);
  
#############
##
  $want = <<'EOT';
%kennels = (
  First => \'Fido',
  Second => \'Wags'
);
@dogs = (
  $kennels{First},
  $kennels{Second},
  \%kennels
);
%mutts = %kennels;
EOT

  $d->Reset;
  TEST($d->Dump);

#############
##
  $want = <<'EOT';
@dogs = (
  'Fido',
  'Wags',
  {
    First => \$dogs[0],
    Second => \$dogs[1]
  }
);
%kennels = %{$dogs[2]};
%mutts = %{$dogs[2]};
EOT

  $d = Data::Dumper->new( [\@dogs, \%kennel, $mutts], [qw(*dogs *kennels *mutts)] );
  TEST($d->Dump);
  
#############
##
  $d->Reset;
  TEST($d->Dump);

#############
##
  $want = <<'EOT';
@dogs = (
  'Fido',
  'Wags',
  {
    First => \'Fido',
    Second => \'Wags'
  }
);
%kennels = (
  First => \'Fido',
  Second => \'Wags'
);
EOT

  $d = Data::Dumper->new( [\@dogs, \%kennel], [qw(*dogs *kennels)] );
  $d->Deepcopy(1);
  TEST($d->Dump);
  
}

#############
##
print "### XS tests\n";

if ($XS) {

#############
##
  $want = <<'EOT';
$a = [
  1,
  {
    'a' => [],
    'b' => {},
    'c' => [
      'c'
    ]
  },
  []
];
$a->[1]{'a'} = $a;
$a->[1]{'b'} = $a->[1];
$a->[2] = $a->[1]{'c'};
$b = $a->[1];
$c = $a->[1]{'c'};
EOT

  $Data::Dumper::Purity = 1;
  TEST(Data::Dumper->Dumpxs([$a,$b,$c], [qw(a b c)]));
  
#############
##
  $want = <<'EOT';
@a = (
  1,
  {
    'a' => [],
    'b' => {},
    'c' => [
      'c'
    ]
  },
  []
);
$a[1]{'a'} = \@a;
$a[1]{'b'} = $a[1];
$a[2] = $a[1]{'c'};
$b = $a[1];
EOT

  $Data::Dumper::Purity = 1;         # fill in the holes for eval
  TEST(Data::Dumper->Dumpxs([$a, $b], [qw(*a b)])); # print as @a

#############
##
  $want = <<'EOT';
%b = (
  'a' => [
    1,
    {},
    [
      'c'
    ]
  ],
  'b' => {},
  'c' => []
);
$b{'a'}[1] = \%b;
$b{'b'} = \%b;
$b{'c'} = $b{'a'}[2];
$a = $b{'a'};
EOT

  TEST(Data::Dumper->Dumpxs([$b, $a], [qw(*b a)])); # print as %b


#############
##
  $want = <<'EOT';
$a = [
  1,
  {
    'a' => [],
    'b' => {},
    'c' => []
  },
  []
];
$a->[1]{'a'} = $a;
$a->[1]{'b'} = $a->[1];
$a->[1]{'c'} = \@c;
$a->[2] = \@c;
$b = $a->[1];
EOT

  $Data::Dumper::Indent = 1;
  $d = Data::Dumper->new([$a,$b], [qw(a b)]);     # go OO
  $d->Seen({'*c' => $c});            # stash a ref without printing it
  TEST($d->Dumpxs);


#############
##
  $want = <<'EOT';
$a = [
  #0
  1,
  #1
  {
    'a' => $a,
    'b' => $a->[1],
    'c' => [
             #0
             'c'
           ]
  },
  #2
  $a->[1]{'c'}
];
$b = $a->[1];
EOT

  $d->Indent(3);
  $d->Reset;                         # empty the seen cache
  $d->Purity(0);
  TEST($d->Dumpxs);


#############
##
  $want = <<'EOT';
$VAR1 = [
  1,
  {
    'a' => [],
    'b' => {},
    'c' => [
      'c'
    ]
  },
  []
];
$VAR1->[1]{'a'} = $VAR1;
$VAR1->[1]{'b'} = $VAR1->[1];
$VAR1->[2] = $VAR1->[1]{'c'};
EOT

  TEST(Data::Dumper::DumperX($a));


#############
##
  $want = <<'EOT';
[
  1,
  {
    'a' => $VAR1,
    'b' => $VAR1->[1],
    'c' => [
      'c'
    ]
  },
  $VAR1->[1]{'c'}
]
EOT

  {
    local $Data::Dumper::Purity = 0;
    local $Data::Dumper::Terse = 1;
    TEST(Data::Dumper::DumperX($a));
  }


#############
##
  $want = <<"EOT";
\$VAR1 = {
  'abc\000\efg' => 'mno\000'
};
EOT

  $foo = { "abc\000\efg" => "mno\000" };
  {
    local $Data::Dumper::Useqq = 1;
    TEST(Data::Dumper::DumperX($foo));
  }

#############
#############

  $foo = 5;
  @foo = (10,\*foo);
  %foo = (a=>1,b=>\$foo,c=>\@foo);
  $foo{d} = \%foo;
  $foo[2] = \%foo;

#############
##
  $want = <<'EOT';
$foo = \*{'main::foo'};
*{'main::foo'}{SCALAR} = \5;
*{'main::foo'}{ARRAY} = [
  10,
  '',
  {
    'a' => 1,
    'b' => '',
    'c' => [],
    'd' => {}
  }
];
*{'main::foo'}{ARRAY}->[1] = $foo;
*{'main::foo'}{ARRAY}->[2]{'b'} = *{'main::foo'}{SCALAR};
*{'main::foo'}{ARRAY}->[2]{'c'} = *{'main::foo'}{ARRAY};
*{'main::foo'}{ARRAY}->[2]{'d'} = *{'main::foo'}{ARRAY}->[2];
*{'main::foo'}{HASH} = *{'main::foo'}{ARRAY}->[2];
@bar = @{*{'main::foo'}{ARRAY}};
%baz = %{*{'main::foo'}{ARRAY}->[2]};
EOT

  $Data::Dumper::Purity = 1;
  TEST(Data::Dumper->Dumpxs([\*foo, \@foo, \%foo], ['*foo', '*bar', '*baz']));

#############
##
  $want = <<'EOT';
$foo = \*{'main::foo'};
*{'main::foo'}{SCALAR} = \5;
*{'main::foo'}{ARRAY} = [
  10,
  '',
  {
    'a' => 1,
    'b' => '',
    'c' => [],
    'd' => {}
  }
];
*{'main::foo'}{ARRAY}->[1] = $foo;
*{'main::foo'}{ARRAY}->[2]{'b'} = *{'main::foo'}{SCALAR};
*{'main::foo'}{ARRAY}->[2]{'c'} = *{'main::foo'}{ARRAY};
*{'main::foo'}{ARRAY}->[2]{'d'} = *{'main::foo'}{ARRAY}->[2];
*{'main::foo'}{HASH} = *{'main::foo'}{ARRAY}->[2];
$bar = *{'main::foo'}{ARRAY};
$baz = *{'main::foo'}{ARRAY}->[2];
EOT

  TEST(Data::Dumper->Dumpxs([\*foo, \@foo, \%foo], ['foo', 'bar', 'baz']));

#############
##
  $want = <<'EOT';
@bar = (
  10,
  \*{'main::foo'},
  {}
);
*{'main::foo'}{SCALAR} = \5;
*{'main::foo'}{ARRAY} = \@bar;
*{'main::foo'}{HASH} = {
  'a' => 1,
  'b' => '',
  'c' => [],
  'd' => {}
};
*{'main::foo'}{HASH}->{'b'} = *{'main::foo'}{SCALAR};
*{'main::foo'}{HASH}->{'c'} = \@bar;
*{'main::foo'}{HASH}->{'d'} = *{'main::foo'}{HASH};
$bar[2] = *{'main::foo'}{HASH};
%baz = %{*{'main::foo'}{HASH}};
$foo = $bar[1];
EOT

  TEST(Data::Dumper->Dumpxs([\@foo, \%foo, \*foo], ['*bar', '*baz', '*foo']));

#############
##
  $want = <<'EOT';
$bar = [
  10,
  \*{'main::foo'},
  {}
];
*{'main::foo'}{SCALAR} = \5;
*{'main::foo'}{ARRAY} = $bar;
*{'main::foo'}{HASH} = {
  'a' => 1,
  'b' => '',
  'c' => [],
  'd' => {}
};
*{'main::foo'}{HASH}->{'b'} = *{'main::foo'}{SCALAR};
*{'main::foo'}{HASH}->{'c'} = $bar;
*{'main::foo'}{HASH}->{'d'} = *{'main::foo'}{HASH};
$bar->[2] = *{'main::foo'}{HASH};
$baz = *{'main::foo'}{HASH};
$foo = $bar->[1];
EOT

  TEST(Data::Dumper->Dumpxs([\@foo, \%foo, \*foo], ['bar', 'baz', 'foo']));

#############
##
  $want = <<'EOT';
$foo = \*{'main::foo'};
@bar = (
  10,
  $foo,
  {
    'a' => 1,
    'b' => \5,
    'c' => \@bar,
    'd' => $bar[2]
  }
);
%baz = %{$bar[2]};
EOT

  $Data::Dumper::Purity = 0;
  TEST(Data::Dumper->Dumpxs([\*foo, \@foo, \%foo], ['*foo', '*bar', '*baz']));

#############
##
  $want = <<'EOT';
$foo = \*{'main::foo'};
$bar = [
  10,
  $foo,
  {
    'a' => 1,
    'b' => \5,
    'c' => $bar,
    'd' => $bar->[2]
  }
];
$baz = $bar->[2];
EOT

  TEST(Data::Dumper->Dumpxs([\*foo, \@foo, \%foo], ['foo', 'bar', 'baz']));

}

#############
#############
{
  package main;
  my @dogs = ( 'Fido', 'Wags' );
  my %kennel = (
  	    First => \$dogs[0],
  	    Second =>  \$dogs[1],
  	   );
  $dogs[2] = \%kennel;
  my $mutts = \%kennel;
  
#############
##
  $want = <<'EOT';
%kennels = (
  'First' => \'Fido',
  'Second' => \'Wags'
);
@dogs = (
  $kennels{'First'},
  $kennels{'Second'},
  \%kennels
);
%mutts = %kennels;
EOT

  my $d = Data::Dumper->new( [\%kennel, \@dogs, $mutts], [qw(*kennels *dogs *mutts)] );
  TEST($d->Dumpxs);
  
#############
##
  $want = <<'EOT';
%kennels = %kennels;
@dogs = @dogs;
%mutts = %kennels;
EOT

  TEST($d->Dumpxs);
  
#############
##
  $want = <<'EOT';
%kennels = (
  'First' => \'Fido',
  'Second' => \'Wags'
);
@dogs = (
  $kennels{'First'},
  $kennels{'Second'},
  \%kennels
);
%mutts = %kennels;
EOT

  $d->Reset;
  TEST($d->Dumpxs);

#############
##
  $want = <<'EOT';
@dogs = (
  'Fido',
  'Wags',
  {
    'First' => \$dogs[0],
    'Second' => \$dogs[1]
  }
);
%kennels = %{$dogs[2]};
%mutts = %{$dogs[2]};
EOT

  $d = Data::Dumper->new( [\@dogs, \%kennel, $mutts], [qw(*dogs *kennels *mutts)] );
  TEST($d->Dumpxs);
  
#############
##
  $d->Reset;
  TEST($d->Dumpxs);

#############
##
  $want = <<'EOT';
@dogs = (
  'Fido',
  'Wags',
  {
    'First' => \'Fido',
    'Second' => \'Wags'
  }
);
%kennels = (
  'First' => \'Fido',
  'Second' => \'Wags'
);
EOT

  $d = Data::Dumper->new( [\@dogs, \%kennel], [qw(*dogs *kennels)] );
  $d->Deepcopy(1);
  TEST($d->Dumpxs);

}

