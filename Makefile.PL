use ExtUtils::MakeMaker;
WriteMakefile(
              NAME => "Data::Dumper",
              DISTNAME => "Data-Dumper",
	      PM => { 'Dumper.pm' => '$(INST_LIBDIR)/Dumper.pm' },
              VERSION => '2.04',
              'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'}
             );
