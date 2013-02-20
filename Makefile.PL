use 5.014002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'AnyEvent::Yubico',
    VERSION_FROM      => 'lib/AnyEvent/Yubico.pm', # finds $VERSION
    PREREQ_PM         => {
        "AnyEvent::HTTP" => "0",
        "UUID::Tiny" => "0",
        "MIME::Base64" => "0",
        "Digest::HMAC_SHA1" => "0",
        "URI::Escape" => "0",
    }, # e.g., Module::Name => 1.1
    BUILD_REQUIRES     => {
        "Test::More" => "0",
        "Test::Exception" => "0",
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/AnyEvent/Yubico.pm', # retrieve abstract from module
       AUTHOR         => 'Dain Nilsson <dain@yubico.com>') : ()),
);
