use lib "./lib";
require Data::Dumper;
use ExtUtils::MakeMaker;
WriteMakefile(
              NAME => "Data::Dumper",
              DISTNAME => "Data-Dumper",
              VERSION => $Data::Dumper::VERSION,
              SKIP => [qw(static dynamic)],
              'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'},
              'macro' => {CONFIGDEP => 'lib/Data/Dumper.pm'}
             );
