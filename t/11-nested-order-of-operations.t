use PDL;
use strict;
use warnings;
use Test::More tests => 7;
use Scrooge;
use Data::Dumper;

# Load the tracker module:
my $module_name = 'Tracker.pm';
if (-f $module_name) {
	require $module_name;
}
elsif (-f "t/$module_name") {
	require "t/$module_name";
}
elsif (-f "t\\$module_name") {
	require "t\\$module_name";
}
else {
	die "Unable to load $module_name";
}

my $data = sequence(50);

#######################################################################
#                           Nested Prep - 1                           #
#######################################################################

# I want to use a slightly more complex set of functions, so I'm going to
# have the overridable functions call even more local functions. :-)

package Scrooge::Test::Tracker::Nested;
our @ISA = ('Scrooge');
Tracker::track(
	{
		_apply		=> q{ our $apply_returns->() },
		_cleanup	=> q{ our $cleanup_returns -> () },
		_prep		=> q{ our $prep_returns->() },
	},
	qw(_to_stash apply is_prepping prep cleanup)
);

sub _init {
	my $self = shift;
	$self->min_size(1);
	$self->max_size(1);
}


my $regex = __PACKAGE__->new;
our @call_structure = ();
our $apply_returns = sub {1};
our $cleanup_returns = sub {1};
our $prep_returns = sub {1};

my $prep_counter = 0;
my $prep_regex_length = 0;
my $single_recursive_prep = sub {
	# Alter the state data
	my $max_size = int rand($data->nelem);
	$regex->min_size(int rand($max_size));
	$regex->max_size($max_size);
	
	# Only one level of recursion here:
	return 1 if $prep_counter++;
	
	# If we are at the top level, call self:
	($prep_regex_length) = $regex->apply($data);
	return 1;
};
$prep_returns = $single_recursive_prep;
my @N_to_return;
$apply_returns = sub {
	# Returns a random number of elements:
	my $min = $regex->min_size;
	my $max = $regex->max_size;
	push @N_to_return, int(rand($max - $min)) + $min;
	return $N_to_return[-1];
};

my $expected = [
	-apply => [
		is_prepping => [],
		-prep			=> [
			-_prep 			=> [
				-apply			=> [
					-is_prepping => [],
					cleanup			=> [ _cleanup => [] ],
				],
			],
		],
		cleanup			=> [ _cleanup => [] ],
	]
];

@call_structure = ();
my ($length, $offset) = eval{$regex->apply($data)};
is_deeply(\@call_structure, $expected, 'Nested prep dies')
	or diag(Dumper (\@call_structure));

$prep_returns = sub {1};

########################################################################
#                           Nested Apply - 3                           #
########################################################################

@N_to_return = ();
my $apply_counter = 0;
$regex->min_size(1);
$regex->max_size(40);
my $internal_regex_length = -1;
$apply_returns = sub {
	# Only one level of recursion here:
	if ($apply_counter++ == 0) {
		($internal_regex_length) = $regex->apply($data);
	}
	
	# Returns a random number of elements:
	my $min = $regex->min_size;
	my $max = $regex->max_size;
	push @N_to_return, int(rand($max - $min)) + $min;
	return $N_to_return[-1];
};

$expected = [
	apply => [
		is_prepping		=> [],
		prep			=> [ _prep => [] ],
		_apply			=> [
			apply 			=> [
				is_prepping		=> [],
				prep			=> [ _to_stash => [], _prep => [] ],
				_apply			=> [],
				cleanup			=> [ _cleanup => [], _to_stash => [] ],
			],
		],
		cleanup			=> [ _cleanup => [] ],
	]
];

@call_structure = ();
($length) = $regex->apply($data);
is($length, $N_to_return[-1], 'Nesting does not mess up length');
is($internal_regex_length, $N_to_return[0], 'Nesting does not mess up length');
is_deeply(\@call_structure, $expected, 'Nested apply agrees with expectations')
	or diag(Dumper (\@call_structure));

$apply_returns = sub {1};

########################################################################
#                          Nested Cleanup - 2                          #
########################################################################

my $cleanup_counter = 0;
my $cleanup_length;
$cleanup_returns = sub {
	# Only one level of recursion here:
	return if $cleanup_counter++;
	
	# If not, apply this regex to the data!
	($cleanup_length) = $regex->apply($data);
	return;
};

$apply_returns = sub {
	# Returns a random number of elements:
	my $min = $regex->min_size;
	my $max = $regex->max_size;
	push @N_to_return, int(rand($max - $min)) + $min;
	return $N_to_return[-1];
};


$expected = [
	-apply => [
		is_prepping	=> [],
		prep		=> [ _prep => [] ],
		_apply		=> [],
		-cleanup	=> [
			-_cleanup	=> [
				-apply 		=> [
					-is_prepping	=> [],
					'cleanup'		=> [ '_cleanup' => [] ],
				],
			],
		],
	],
];

@N_to_return = ();
@call_structure = ();
($length) = eval{$regex->apply($data)};
is($length, undef, 'Nested cleanup did not mess up return value');
is_deeply(\@call_structure, $expected, 'Nested cleanup croaks')
	or diag(Dumper (\@call_structure));

$apply_returns = sub {1};

########################################################################
#                 Nested Apply with croaking Apply - 1                 #
########################################################################

$apply_counter = 0;
$apply_returns = sub {
	if ($apply_counter++ == 0) {
		my $result = $regex->apply($data);
		return $result;
	}
	die 'test';
};

$expected = [
	-apply => [
		is_prepping		=> [],
		prep			=> [ _prep => [] ],
		-_apply				=> [
			-apply				=> [
				is_prepping		=> [ ],
				prep			=> [ _to_stash => [], _prep => [] ],
				-_apply			=> [],
				cleanup			=> [ _cleanup => [], _to_stash => [] ],
			],
		],
		cleanup			=> [ _cleanup => [] ],
	]
];

@call_structure = ();
eval{$regex->apply($data)};
is_deeply(\@call_structure, $expected, 'Nested apply with croaking apply performs full cleanup')
	or diag(Dumper (\@call_structure));

$apply_returns = sub {1};
