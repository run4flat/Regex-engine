# Runs Basics' test

# Load the basics module:
my $module_name = 'Basics.pm';
if (-f $module_name) {
	require $module_name;
}
elsif (-f "t/$module_name") {
	require "t/$module_name";
}
elsif (-f "t\\$module_name") {
	require "t\\$module_name";
}

use strict;
use warnings;
use Regex::Engine;
use Test::More tests => 68;
use PDL;

my ($regex, $length, $offset);
my $data = sequence(10);


###########################################################################
#                        Regex::Engine::Test::Fail - 4                       #
###########################################################################

# ---( Build and make sure it builds properly, 2 )---
$regex = eval { Regex::Engine::Test::Fail->new };
is($@, '', 'Test::Fail constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Fail');

# ---( Basic application, 2 )---
($length, $offset) = $regex->apply($data);
is($length, undef, 'Test::Fail always fails, returning undef for length');
is($offset, undef, 'Test::Fail always fails, returning undef for offset');


###########################################################################
#                     Regex::Engine::Test::Fail::Prep - 4                    #
###########################################################################

# ---( Build and make sure it builds properly, 2 )---
$regex = eval { Regex::Engine::Test::Fail::Prep->new };
is($@, '', 'Test::Fail::Prep constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Fail::Prep');

# ---( Basic application, 2 )---
($length, $offset) = $regex->apply($data);
is($length, undef, 'Test::Fail::Prep always fails, returning undef for length');
is($offset, undef, 'Test::Fail::Prep always fails, returning undef for offset');


###########################################################################
#                        Regex::Engine::Test::All - 4                        #
###########################################################################

# ---( Build and make sure it builds properly, 2 )---
$regex = eval { Regex::Engine::Test::All->new };
is($@, '', 'Test::All constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::All');

# ---( Basic regex application, 2 )---
($length, $offset) = $regex->apply($data);
is($length, $data->nelem, 'Test::All always matches all that it is given');
is($offset, 0, 'Test::All always matches at the start of what it is given');


###########################################################################
#                       Regex::Engine::Test::Croak - 3                       #
###########################################################################

# ---( Build and make sure it runs properly, 3 )---
$regex = eval { Regex::Engine::Test::Croak->new };
is($@, '', 'Test::Croak constructor does not croak (that comes during apply)');
isa_ok($regex, 'Regex::Engine::Test::Croak');
eval{$regex->apply($data)};
isnt($@, '', 'Engine croaks when its regex croaks');


###########################################################################
#                    Regex::Engine::Test::ShouldCroak - 3                    #
###########################################################################

# ---( Build and make sure it runs properly, 3 )---
$regex = eval { Regex::Engine::Test::ShouldCroak->new };
is($@, '', 'Test::ShouldCroak constructor does not croak (that comes during apply)');
isa_ok($regex, 'Regex::Engine::Test::ShouldCroak');
eval{$regex->apply($data)};
isnt($@, '', 'Engine croaks when regex consumes more than it was given');


###########################################################################
#                       Regex::Engine::Test::Even - 10                       #
###########################################################################

# ---( Build and make sure it builds properly, 2 )---
$regex = eval { Regex::Engine::Test::Even->new };
is($@, '', 'Test::Even constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Even');

# ---( Basic regex application, 8 )---
($length, $offset) = $regex->apply($data);
is($length, $data->nelem, 'Test::Even always matches the longest even length');
is($offset, 0, 'Test::Even always matches at the start of what it is given');
($length, $offset) = $regex->apply($data->slice("0:-2"));
is($length, $data->nelem - 2, 'Test::Even always matches the longest even length');
is($offset, 0, 'Test::Even always matches at the start of what it is given');
($length, $offset) = $regex->apply($data->slice("0:-3"));
is($length, $data->nelem - 2, 'Test::Even always matches the longest even length');
is($offset, 0, 'Test::Even always matches at the start of what it is given');
($length, $offset) = $regex->apply($data->slice("0:-4"));
is($length, $data->nelem - 4, 'Test::Even always matches the longest even length');
is($offset, 0, 'Test::Even always matches at the start of what it is given');


###########################################################################
#                      Regex::Engine::Test::Exactly - 12                     #
###########################################################################

# ---( Build and make sure it builds ok, 4 )---
$regex = eval{ Regex::Engine::Test::Exactly->new(N => 5) };
is($@, '', 'Test::Exactly constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Exactly');
# Test that it matches 5 elements:
($length, $offset) = $regex->apply($data);
is($length, 5, 'Test::Exactly should match the exact specified number of elements');
is($offset, 0, 'Test::Exactly should always have a matched offset of zero');

# ---( Change to a length that is too long, 2 )---
$regex->set_N(12);
($length, $offset) = eval {$regex->apply($data)};
is($length, undef, 'Test::Exactly does not match when data is too short');
is($@, '', 'Failed evaluation does not throw an exception');

# ---( Boundary conditions, 6 )---
$regex->set_N(10);
($length, $offset) = $regex->apply($data);
is($length, 10, 'Test::Exactly should match the exact specified number of elements');
is($offset, 0, 'Test::Exactly should always have a matched offset of zero');
$regex->set_N(9);
($length, $offset) = $regex->apply($data);
is($length, 9, 'Test::Exactly should match the exact specified number of elements');
is($offset, 0, 'Test::Exactly should always have a matched offset of zero');
$regex->set_N(11);
($length, $offset) = $regex->apply($data);
is($length, undef, 'Test::Exactly does not match when data is too short');
is($offset, undef, 'Test::Exactly does not match when data is too short');


###########################################################################
#                       Regex::Engine::Test::Range - 15                      #
###########################################################################

# ---( Build and make sure it builds properly, 4 )---
$regex = eval { Regex::Engine::Test::Range->new };
is($@, '', 'Test::Range constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Range');
is($regex->{min_size}, 1, 'Default min_size is 1');
is($regex->{max_size}, 1, 'Default max_size is 1');

# ---( Basic tests, 6 )---
($length, $offset) = $regex->apply($data);
is($length, 1, 'Test::Range should match the maximum possible specified number of elements');
is($offset, 0, 'Test::Range should always have a matched offset of zero');
$regex->max_size(5);
($length, $offset) = $regex->apply($data);
is($length, 5, 'Test::Range should match the maximum possible specified number of elements');
is($offset, 0, 'Test::Range should always have a matched offset of zero');
$regex->max_size(12);
($length, $offset) = $regex->apply($data);
is($length, 10, 'Test::Range should match the maximum possible specified number of elements');
is($offset, 0, 'Test::Range should always have a matched offset of zero');

# ---( Min-length tests, 5 )---
$regex->min_size(10);
($length, $offset) = $regex->apply($data);
is($length, 10, 'Test::Range should match the maximum possible specified number of elements');
is($offset, 0, 'Test::Range should always have a matched offset of zero');
$regex->min_size(11);
($length, $offset) = eval{ $regex->apply($data) };
is($@, '', 'Failed Test::Range match does not throw an exception');
is($length, undef, 'Test::Range should not match if data is smaller than min');
is($offset, undef, 'Test::Range should not match if data is smaller than min');


###########################################################################
#                  Regex::Engine::Test::Exactly::Offset - 13                 #
###########################################################################

# ---( Build and make sure it builds properly, 5 )---
$regex = eval { Regex::Engine::Test::Exactly::Offset->new };
is($@, '', 'Test::Exactly::Offset constructor does not croak');
isa_ok($regex, 'Regex::Engine::Test::Exactly::Offset');
is($regex->{min_size}, 1, 'Default min_size is 1');
is($regex->{max_size}, 1, 'Default max_size is 1');
is($regex->{offset}, 0, 'Default offset is 0');

# ---( Compare with Test::Exactly, 1 )---
my $exact_regex = Regex::Engine::Test::Exactly->new(N => 5);
$regex = Regex::Engine::Test::Exactly::Offset->new(N => 5);
is_deeply([$exact_regex->apply($data)], [$regex->apply($data)],
	, 'Test::Exactly::Offset agrees with basic Test::Exactly');

# ---( Nonzero offset, 4 )---
$regex->set_offset(2);
($length, $offset) = $regex->apply($data);
is($length, 5, 'Test::Exactly::Offset matches specified length');
is($offset, 2, 'Test::Exactly::Offset matches specified offset');
# corner case:
$regex->set_offset(5);
($length, $offset) = $regex->apply($data);
is($length, 5, 'Test::Exactly::Offset matches specified corner-case length');
is($offset, 5, 'Test::Exactly::Offset matches specified corner-case offset');

# ---( Failing situations, 3 )---
$regex->set_offset(6);
($length, $offset) = $regex->apply($data);
is($length, undef, 'Test::Exactly::Offset fails at corner-case');
# make sure it doesn't croak if offset is huge
$regex->set_offset(20);
($length, $offset) = eval{$regex->apply($data)};
is($@, '', 'Huge offset does not make Test::Exactly::Offset croak');
is($offset, undef, 'Test::Exactly::Offset fails for overly large offset');
