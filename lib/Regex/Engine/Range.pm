package Regex::Engine::Intersect;
use strict;
use warnings;
use Regex::Engine;
use Carp;
use PDL;

use Exporter;

our @ISA=qw(Regex::Engine::Quantified Exporter);
our @EXPORT = qw(re_intersect);

=head1 NAME

Regex::Engine::Range - a module built to find matches inside a given numeric range

=cut

our $VERSION = 0.01;

=head1 VERSION

This documentation discusses version 0.01 of Regex::Engine::Range

=head1 SYNOPSIS

 use Regex::Engine::Range;
 
 
=head1 DESCRIPTION

This module allows the user to match data in sections, rather than just matching the whole set of data. This
should mainly be used for finding data outside of certain ranges, for example outside 2 standard deviations
from the mean of the data. 

=cut

#Override _init: Ignoring for now
###########################################################
# Name       : _init
# Usage      : $self->_init
# Purpose    : parse the range strings into an op tree
# Returns    : nothing
# Parameters : $self (implicit)
# Throws     : no exceptions
# Notes      : expects keys 'above' and 'below'

#sub _init {
#   Parent class handles quantifiers
#   $_[0]->SUPER::_init;
  
#   XXX 
#}


###########################################################
# Name       : _prep
# Usage      : $self->_prep($data)
# Purpose    : create an anonymous subroutine that performs the condition check
# Returns    : a True value
# Parameters : $self (implicit), $data
# Throws     : no exceptions
# Notes      : none atm

sub _prep {
  my ($self, $data) = @_;
  my $original_above = my $above = $self->{ above };
  my $original_below = my$below = $self->{ below };
 
  my ($mean, $st_dev) = $data->stats;
  my ($min, $max) = $data->minmax;
  my $pct = ($max - $min) / 100;
  
  for my $entry ($above, $below){
    # Replace ... 5@ ... with ... 5 * $st_dev ...
    $entry =~ s/(\d)\s*\@/$1 * \$st_dev/g;
    
    # Replace ... 5% ... with ... 5 * $pct ...  
    $entry =~ s/(\d)\s*\%/$1 * \$pct/g;
    
    # Replace ... avg ... with ... $mean ...  
    $entry =~ s/avg/\$mean/g;
    
  }
  
  #Evaluate the expression
  $above = eval($above);
  if ($@){
    # If they give junk
    croak("Had trouble with above specification: $original_above");
  }
  
  $below = eval($below);
  if ($@){
    croak("Had trouble with below specification: $original_below");
  }
  
  # It could be the case that the intersection could be null if above is under below.
  # We retrun false to signify to the Regex Engine that it never needs to evaluate this. 
  if ($above > $below){
    return '';
  }
  # Build the subroutine reference
  $self->{ subref } = sub {
    my ($left, $right) = @_;
    
    # Zero width assertions are trivially true.
    return '0 but true' if ($left > $right);

    my $sub_piddle = $data->slice("$left:$right");

    # Return a failed match if the match doesn't occur
    # at the given left offset 
    return 0 if $data->at($left) >= $below or $data->at($left) <= $above;

    # Return the length of the whole segment if
    # all of data is within the range. 
    return ($right - $left +1) 
        if all ( ($sub_piddle > $above) & ($sub_piddle < $below) );
    
    # Returns the index of the first point outside the range, which is equal to the length
    # of the match.
    return which( ($sub_piddle < $above) | ($sub_piddle > $below))->at(0);     
    
  };
  
  return $self->SUPER::_prep($data);
}

###########################################################
# Name       : _apply
# Usage      : $self->_init
# Purpose    : invoke the subroutine from prep with left and right offsets
# Returns    : nothing
# Parameters : $self (implicit)
# Throws     : no exceptions
# Notes      : expects keys 'above' and 'below'

sub _apply {
  my $self = shift;
  return $self->{subref}->(@_);
  
}


###########################################################
# Name       : re_intersect
# Usage      : re_intersect(above=>'5', below=>'9@')
# Purpose    : create an intersect regular expression
# Returns    : the regex object
# Parameters : key value pairs: name, quantifiers, above, below
# Throws     : if given an odd number of arguments
#            : if not given an 'above' or 'below'
# Notes      : defaults to quantifier of length 1

sub re_intersect {
  
  croak("re_intersect takes key-value pairs. You gave an odd number of arguments")
    if @_ % 2 == 1;

  my %args = @_;

  # Check to see if 'above' and 'below' exist
  croak("re_intersect expects an 'above' key.")
    unless exists $args{ above };
    
  croak("re_intersect expects a 'below' key.")
    unless exists $args{ below };
    
  # XXX add check for valid keys
  
  # Defaults to matching 1 element
  $args{ quantifiers } = [1,1]
    unless exists $args{ quantifiers };
    
  return Regex::Engine::Intersect->new(%args);
}

package main;

use strict;
use warnings;
use PDL;

my $data = sin(sequence(100)/10);
$data->slice('37') .= 100;

my $regex = Regex::Engine::Intersect::re_intersect(above => 2, below => 1000);
my ($matched, $offset) = $regex->apply($data);
print "not " if not defined $offset or $offset != 37;
print "ok - offset finds crazy value\n";

$regex = Regex::Engine::Intersect::re_intersect(above => 'avg + 2@', below => 1000);
($matched, $offset) = $regex->apply($data);
print "not " if not defined $offset or $offset != 37;
print "ok - offset finds crazy value\n";

#'5 - 2@'
#'5 - 2%'