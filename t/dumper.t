#
# test Data::Dumper
#

use Data::Dumper;


$TNUM = 0;

sub T { print "ok ", ++$TNUM, "\n" };

$TMAX = 2;
if (defined &Data::Dumper::Dumpxs) {
  print "# XS extension loaded, will test XS versions\n";
  $TMAX = 2; $XS = 1;
}
else {
  print "# XS extensions not loaded, will not test them\n";
  $TMAX = 1; $XS = 0;
}

print "1..$TMAX\n";


@c = ('c');
$c = \@c;
$b = {};
$a = [1, $b, $c];
$b->{a} = $a;
$b->{b} = $a->[1];
$b->{c} = $a->[2];


$out = "";
$out .= Data::Dumper->Dump([$a,$b,$c], [qw(a b c)]);

$Data::Dumper::Purity = 1;         # fill in the holes for eval
$out .= Data::Dumper->Dump([$a, $b], [qw(*a b)]); # print as @a
$out .= Data::Dumper->Dump([$b, $a], [qw(*b a)]); # print as %b
$Data::Dumper::Indent = 1;
$d = Data::Dumper->new([$a,$b], [qw(a b)]);     # go OO
$d->Seen({'*c' => $c});            # stash a ref without printing it
$out .= $d->Dump;
$d->Indent(3);
$d->Reset;                         # empty the seen cache
$d->Purity(0);
$out .= $d->Dump;
$out .= Data::Dumper::Dumper($a);
#print $out;
$want = <<'EOT';
$a = [
       '1',
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
@a = (
       '1',
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
%b = (
       'a' => [
                '1',
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
$a = [
  '1',
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
$a = [
       #0
       '1',
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
$VAR1 = [
  '1',
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

&T if $out eq $want;

$wantxs = <<'EOT';
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
$a->[1]{'a'} = \@a;
$a->[1]{'b'} = $a->[1];
$a->[2] = $a->[1]{'c'};
$b = $a->[1];
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
$b->{'a'}[1] = \%b;
$b->{'b'} = \%b;
$b->{'c'} = $b->{'a'}[2];
$a = $b->{'a'};
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

if ($XS) {
  $out = "";
  $out .= Data::Dumper->Dumpxs([$a,$b,$c], [qw(a b c)]);
  
  $Data::Dumper::Purity = 1;         # fill in the holes for eval
  $out .= Data::Dumper->Dumpxs([$a, $b], [qw(*a b)]); # print as @a
  $out .= Data::Dumper->Dumpxs([$b, $a], [qw(*b a)]); # print as %b
  $Data::Dumper::Indent = 1;
  $d = Data::Dumper->new([$a,$b], [qw(a b)]);     # go OO
  $d->Seen({'*c' => $c});            # stash a ref without printing it
  $out .= $d->Dumpxs;
  $d->Indent(3);
  $d->Reset;                         # empty the seen cache
  $d->Purity(0);
  $out .= $d->Dumpxs;
  $out .= Data::Dumper::DumperX($a);
#  print $out;
  &T if $wantxs eq $out;
}
