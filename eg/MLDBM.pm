#
#  MLDBM - storing complex structures in DBM files
#
#  refs are stringified and stored. non-refs are stored
#  in the native format
#
#  needs DB_File and the Data::Dumper package (available at CPAN)
#
#  Gurusamy Sarathy
#  gsar@umich.edu
#

package MLDBM;

require DB_File;

require TieHash;

use Data::Dumper;

@ISA = qw(TieHash);

# this has to be something unique since we try to store
# stuff natively if it is not a ref
$key = 'CrYpTiCkEy';

sub TIEHASH {
  my $c = shift;
  return bless { db => DB_File->TIEHASH(@_) }, $c;
}

sub FETCH {
  my($s, $k) = @_;
  my $ret = $s->{db}->FETCH($k);
  if ($ret =~ /^\$$key/o) {
    eval "undef \$$key;" . $ret; 
    if ($@) {
      warn "MLDBM error: $@\twhile evaluating:\n $ret";
      $ret = undef;
    }
    else {
      $ret = $$key;
    }
  }
  return $ret;
}

sub STORE {
  my($s, $k, $v) = @_;
  if (ref $v) {
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Purity = 1;
    $v = Data::Dumper->Dump([$v], [$key]);
#    print $v;
  }
  $s->{db}->STORE($k, $v);
}

sub DELETE { 
  my $s = shift;
  $s->{db}->DELETE(@_);
}

sub FIRSTKEY { 
  my $s = shift;
  $s->{db}->FIRSTKEY(@_);
}

sub NEXTKEY { 
  my $s = shift;
  $s->{db}->NEXTKEY(@_);
}

1;
__END__
# try this example
use Fcntl;  # to get 'em constants
use MLDBM;
use Data::Dumper;
tie %o, MLDBM, 'testmldbm', O_CREAT|O_RDWR, 0640 or die $!;

$c = [\'c'];
$b = {};
$a = [1, $b, $c];
$b->{a} = $a;
$b->{b} = $a->[1];
$b->{c} = $a->[2];
@o{qw(a b c)} = ($a, $b, $c);
print Data::Dumper->Dump([@o{qw(a b c)}], [qw(a b c)]);

