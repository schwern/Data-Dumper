print "1..1\n";

use Data::Dumper;

package Foo;
use overload '""' => 'as_string';

sub new { bless { foo => "bar" }, shift }
sub as_string { "%%%%" }

package main;

my $f = Foo->new;

print "\$f=$f\n";

$_ = Dumper($f);

print $_;

print "not " unless /bar/ && /Foo/;
print "ok 1\n";

