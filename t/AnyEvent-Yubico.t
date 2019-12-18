# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl AnyEvent-Yubico.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;
require Test::MockModule;
BEGIN { use_ok('AnyEvent::Yubico') };

#########################

my $client_id = 10450;
my $api_key = "uSzStPl2FolBbpJyDrDQxlIQElk=";

my $validator = AnyEvent::Yubico->new({
	client_id => $client_id,
	api_key => $api_key
});

my $test_params = {
	a => 12345,
	c => "hello world",
	b => "foobar"
};

my $test_signature = "k7ZRKLOn3C6565YVqmG2rd4PHVU=";

ok(defined($validator) && ref $validator eq "AnyEvent::Yubico", "new() works");

is($validator->sign($test_params), $test_signature, "sign() works");

my $default_url = $validator->{url};
$validator->{url} = "http://127.0.0.1:0";

is($validator->verify_async("vvgnkjjhndihvgdftlubvujrhtjnllfjneneugijhfll")->recv()->{status}, "Connection refused", "invalid URL");

$validator->{local_timeout} = 0.0001;

is($validator->verify_sync("vvgnkjjhndihvgdftlubvujrhtjnllfjneneugijhfll")->{status}, "Connection timed out", "timeout");

$validator->{url} = $default_url;
$validator->{local_timeout} = 30.0;

subtest 'Tests that require access to the Internet' => sub {
	if(exists($ENV{'NO_INTERNET'})) {
		plan skip_all => 'Internet tests';
	} else {
		plan tests => 5;
	}

	is($validator->verify_sync("ccccccbhjkbulvkhvfuhlltctnjtgrvjuvcllliufiht")->{status}, "REPLAYED_OTP", "replayed OTP");

	$validator = AnyEvent::Yubico->new({
		client_id => $client_id,
	});

	my $result = $validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu");

	is($result->{status}, "BAD_OTP", "invalid OTP");

	#Test manual signature verification
	ok(exists($result->{h}), "signature exists");
	my $sig = $result->{h};
	delete $result->{h};
	$validator->{api_key} = $api_key;
	is($validator->sign($result), $sig, "signature is correct");

	ok(! $validator->verify("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu"), "verify(\$bad_otp)");
};

subtest 'HTTP error tests' => sub {
    plan tests => 4;

    my @mocked_responses = ();
    # AnyEvent::Yubico `use`es AnyEvent::HTTP to get http_get
    my $mock_anyevent_http = Test::MockModule->new('AnyEvent::Yubico');
    $mock_anyevent_http->redefine('http_get', sub {
        my $callback = pop;
        my $response = pop @mocked_responses;
        $callback->($response->{body}, $response->{head});
    });

    my $error_response = { body => "Nope.", head => { Status => 500, Reason => 'Internal Server Error' } };
    my $ratelimit_response = { body => "Nope.", head => { Status => 429 } };
    my $almostok_response = { body => "status=OK", head => { Status => 200 } };

    push @mocked_responses, $ratelimit_response;

    my $result = $validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu");
    is($result->{status}, "RATE_LIMITED", "detect rate limiting");

    push @mocked_responses, $ratelimit_response;
    push @mocked_responses, $almostok_response;
    push @mocked_responses, $error_response;
    push @mocked_responses, $error_response;

    # Disable checking signature because I CBF calculating it for the test
    $validator->{api_key} = '';

    # This throws a response nonce mismatch, which is correct because
    # the mocked response has no nonce. It's too annoying to grab that
    # nonce in the mock, and it's good to validate that we do error
    # when the nonce doesn't match anyway.
    throws_ok { $validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu"); } qr/Response nonce does not match/, "Retry works, as does nonce checking";

    # Just to make sure that the 500s are being retried rather than us
    # mocking the responses in the wrong order
    $result = $validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu");
    is($result->{status}, "RATE_LIMITED", "double check the retrying mock works");


    # 3 retries means give up after 4th error
    push @mocked_responses, $almostok_response;
    push @mocked_responses, $error_response;
    push @mocked_responses, $error_response;
    push @mocked_responses, $error_response;
    push @mocked_responses, $error_response;

    $result = $validator->verify_sync("ccccccbhjkbubrbnrtifbiuhevinenrhtlckuctjjuuu");
    is($result->{status}, "Internal Server Error", "Retries are limited");
};
