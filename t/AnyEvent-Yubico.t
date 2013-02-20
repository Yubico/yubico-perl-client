# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl AnyEvent-Yubico.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;
BEGIN { use_ok('AnyEvent::Yubico') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $validator = AnyEvent::Yubico->new({
	client_id => 10450,
	api_key => "uSzStPl2FolBbpJyDrDQxlIQElk="
});

my $test_params = {
	a => 12345,
	c => "hello world",
	b => "foobar"
};

my $test_signature = "k7ZRKLOn3C6565YVqmG2rd4PHVU=";

ok(defined($validator) && ref $validator eq "AnyEvent::Yubico", "new() works");

is($validator->sign($test_params), $test_signature, "sign() works");

is($validator->verify_sync("ccccccbhjkbulvkhvfuhlltctnjtgrvjuvcllliufiht")->{status}, "REPLAYED_OTP", "replayed OTP");

is($validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu")->{status}, "BAD_OTP", "invalid OTP");

my $default_urls = $validator->{urls};
$validator->{urls} = [ "http://example.com" ];

dies_ok {
	my $res = $validator->verify_async("vvgnkjjhndihvgdftlubvujrhtjnllfjneneugijhfll");
	$res->recv();
} 'invalid URL';

#ok(1);

$validator->{urls} = $default_urls;
$validator->{local_timeout} = 0.0;

is($validator->verify_sync("vvgnkjjhndihvgdftlubvujrhtjnllfjneneugijhfll")->{status}, "TIMEOUT_REACHED", "timeout");
