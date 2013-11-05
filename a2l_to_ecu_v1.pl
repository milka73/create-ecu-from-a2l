# perl
#
# TODO - B_TRUE cases handled properly?
# TODO - Logic for columns 7, 8, 10. 8 and 19 appear to be always zero. 7 does change but not sure what the rule is

# Logic - read through the input file looking for blocks of measurements and methods. Diregard all other content in the file
# Each Measurement starts and ends with "/begin MEASUREMENT" and "/end MEASUREMENT"
# Each Method starts and ends with "/begin COMPU_METHOD" and "/end COMPU_METHOD"
#
# A Measurement Package and a Method Package have been created
# All the Measurements found are added to an array or Measurements and all the methods into a hash of methods
# Once they are all in, we process through all the measurements in the array. For each measurement look up the appropriate method
# Construct the appropriate output line and print it on the STDOUT.

use feature "switch"; # adds the "case" statement (for/when)
use Data::Dumper; # used for debugging
use strict; # variables must be declared

# check we got a good parameter. Give a message if not
my $infile = @ARGV[0];
if (!$infile)  {
	print STDERR "This script needs one file name as parameter. It should be the .A2L file to process\n";
	print STDERR "The output is written to standard out and can be redirected to a file\n";
	exit 0;
}

if (-s $infile) {
} else {
	print STDERR "Input file must exist\n";
	exit 0;
}

# declare a bunch of variables we use later
my (@measureArray,@measureValues,@methodValues); 
my %methods = ();
my $valueType = "N";
my $lookupMethod = "N";
my ($inline, $measureLine, $methodLine, $measure, $method, $methodValues, $method, $key);
my ($useMethod, $methodKey, $result, $outstring, $measureName);

# Start processing through the file
open(INFILE, $infile) || die ("can't open input file: $!"); 

while (<INFILE>) {
  $inline = $_;
  # Trim of leading and trailing spaces
  $inline =~ s/^\s+//;
  $inline =~ s/\s+$//;

  # skip until we hit "/begin MEASUREMENT"
  if ($inline eq "/begin MEASUREMENT") {
	# found the start of a measurement. Set up to start collecting it
    @measureValues = ();
    $valueType = "M";
    $measureLine = 0;
	# nothing else to do for this line
    next;
  }
 
  if ($inline eq "/end MEASUREMENT") {
	# we are at the end of a measurement. Construct the Measurement object
	my $measure = Measurement->new(@measureValues);
	# and put it in the array
    push(@measureArray, $measure);
	# reset so we start looking for the next one
    $valueType = "N";
	# nothing else to do for this line
	next;
  }

  if ($inline eq "/begin COMPU_METHOD") {
	# found the start of a method. Set up to start collecting it
	@methodValues = ();
	$valueType = "C";
    $methodLine = 0;
	# nothing else to do for this line
	next;
  }

  if ($inline eq "/end COMPU_METHOD") {
	# we are at the end of a method. Construct the Measurement object
	if ($lookupMethod eq "Y") {
		# if it was one we didn't want just skip it
		$lookupMethod = "N";
	} else {
		# add the method to the hash (key is the method name)
		$key = $methodValues[0];
		$methods{$key} =  Method->new(@methodValues);
	};
	# reset so we start looking for the next one
	$valueType = "N";
	# nothing else to do for this line
	next;
  }

  if ("$inline" eq "/begin RECORD_LAYOUT FkfNoShNoOffWUb") {
	last; # we don't care about the record layouts - skip the rest
  }
  if ($valueType eq "M") {
	# process entries for measurement
	# pull out the relevant bit from each line and massage to get the appropriate bit to store
	$measureLine++;
	for ($measureLine) {
	  when ([1,10,13,15]) { } # do nothing for these lines
	  when ([2..9]) { push (@measureValues, $inline); } # just take the value "as is"
	  when ([11,12,14,15]) {
		  my $lastword = (split(/\s+/,$inline))[-1]; # get the last word on the line
		  # if (!$lastword) { $lastword = " "};
		  push (@measureValues, $lastword);
		}
	  when ([16]) {
		  # grab the two words that we need 
	      my $bit = (split(/\s+/,$inline))[5];
		  push (@measureValues, $bit);
		  $bit = (split(/\s+/,$inline))[6];
		  push (@measureValues, $bit);
		}
	  default { print "Line is: $inline\nwoah! how did we get here?\n Line is $measureLine\n"; 
				print Dumper(@measureValues); }
	}
  }
  if ($valueType eq "C") {
	# process entries for method
	# pull out the relevant bit from each line and massage to get the appropriate bits to store
	my $coeff;
	my $methodtype;
	$methodLine++;
	for ($methodLine) {
	  when ([1,7,9]) { } # do nothing for these lines
	  when ([2]) {
			if (($inline eq "\"boolsche Zustände, positive Logik\"") | ($inline eq "zk10msxs_uw_b2p55T")) {
				# These ones are the lookup table ones just ignore - we brute force the bool and the other isn't used
				$lookupMethod = "Y";
			} else {
				push (@methodValues, $inline); # just take the value "as is"
			}  
		}
	  when ([3..6]) { push (@methodValues, $inline); }  # just take the value "as is"
	  when ([8]) {
		  # see what type it is 
		  $methodtype = (split(/\s+/,$inline))[0];
		  if ($methodtype eq "COEFFS") {
	        # grab the values that we need 
		    $coeff = (split(/\s+/,$inline))[1];
		    push (@methodValues, $coeff);
		    $coeff = (split(/\s+/,$inline))[2];
		    push (@methodValues, $coeff);
		    $coeff = (split(/\s+/,$inline))[3];
		    push (@methodValues, $coeff);
		    $coeff = (split(/\s+/,$inline))[4];
		    push (@methodValues, $coeff);
		    $coeff = (split(/\s+/,$inline))[5];
		    push (@methodValues, $coeff);
		    $coeff = (split(/\s+/,$inline))[6];
		    push (@methodValues, $coeff);
		  } else {
		    # It doesn't look like we need these but just in case($methodtype = COMPU_TAB_REF)
			 push (@methodValues, "table"); #1
			 push (@methodValues, "table"); #2
			 push (@methodValues, "table"); #3
			 push (@methodValues, "table"); #4
			 push (@methodValues, "table"); #5
			 push (@methodValues, "table"); #6
		  }
		}
	  default { print "Line is: $inline\nwoah! how did we get here?\n Line is $measureLine\n"};
				# print Dumper(@methodValues);}
	}
  }
     
}

# finished with the file
close (INFILE) || die "can't close input file: $!";

# Add an extra method for the B_TRUE Case
$methods{'B_TRUE'} =  Method->new('B_TRUE',,,,,,,,,);

# We now have all the Measures and Methods. Time to process them. For each measure we need to calculate additional values, 
# then format output line with all values and write it out.

# Anything we can't handle - just skip. At present it seems there is only one: dezsub1
my @exceptions = ("dezsub1", "lastone");

# Loop through getting every measure out of the array
foreach $measure(@measureArray) {
	# for each one we have to look up the method to use
	$methodKey = $measure->getFormula()."\n";
	chomp($methodKey);
	$measureName = $measure->getName();

	if ( $methodKey ~~ @exceptions) {
		# skip it if it is one of the exceptions
	} else {
		# calculate the magic number!
		my ($result,$offset) = $methods{$methodKey}->getResult($measure->getFactor());
		# construct the output string
		$outstring = sprintf("%-17s",$measure->getName()).", {}                    , ".sprintf("%-9s",$measure->getEcu()).",  ".substr($measure->getHex2(),-1,1).",  ".sprintf("%-8s",$measure->getBitmask()).", ".sprintf("%-10s",$methods{$methodKey}->getMeasureType()).",".$measure->getSigned().", 0, ".sprintf("%13s",$result).", ".sprintf("%13s",$offset).", ".$measure->getDescription();
		print "$outstring\n";
	}	
}
exit;


###############################################
# Packages: Definition of Measurement and Method
###############################################
package Measurement;
use Data::Dumper;
sub new {
	
	my $class = shift;
	# constructor relies on all these values existing in the this order
	my $self = {
	_name	=> shift,
	_desc	=> shift,
	_type	=> shift,
	_formula => shift,
	_value1	=> shift,
	_value2	=> shift,
	_value3	=> shift,
	_value4	=> shift,
	_bitmask => shift,
	_format	=> shift,
	_ecu	=> shift,
	_hex1	=> shift,
	_hex2	=> shift,
	};
	bless $self, $class;
	return $self;
};
sub getName {
	my ( $self ) = @_;
	return $self->{_name};
};
sub getSigned {
	my ( $self ) = @_;
	my $signed;
	my $signedChar = substr($self->{_type},0,1);
	if ($signedChar eq "S") {
		$signed = 1;
	} else {
		if ($signedChar eq "U") {
			$signed = 0;
		} else {
			# should not be any others!
			print "Type was not Signed or Unsigned: $signedChar\n";
			exit;
		}
	}
			
	return $signed;
};
sub getEcu {
	my ( $self ) = @_;
	return $self->{_ecu};
};

sub getOffset {
	my ( $self ) = @_;
	return $self->{_value3}*-1;
};

sub getFactor {
	my ( $self ) = @_;
	return $self->{_value2};
};

sub getHex2 {
	my ( $self ) = @_;
	return $self->{_hex2};
};
sub getFormula {
	my ( $self ) = @_;
	return $self->{_formula};
};

sub getBitmask {
	my ( $self ) = @_;
	my $result;
	$result = "".$self->{_bitmask};

	# format it correctly for output
	my $bitLength = length($result);
	for ($bitLength) {
		when ([4]) { $result = "0x00".substr($result,-2,2) } ;
		when ([3]) { $result = "0x000".substr($result,-1,1) };
		when ([0]) { $result = "0x0000" };
	}
	return $result;
}
sub getDescription {
	# Description came in as a string surrounded by quotes. return surrounded by braces
	my ( $self ) = @_;
	my $outstring = $self->{_desc};
	return "{".substr($outstring,1,-1)."}";
};

package Method;
sub new {
	my $class = shift;
	# constructor relies on all these values existing in the this order
	my $self = {
	  _name		=> shift,
	  _blank1	=> shift,
	  _type		=> shift,
	  _format 	=> shift,
	  _measureType => shift,
	  _coeff1	=> shift,
	  _coeff2	=> shift,
	  _coeff3	=> shift,
	  _coeff4	=> shift,
	  _coeff5	=> shift,
	  _coeff6   => shift,
	};
	bless $self, $class;
	return $self;
};

sub getResult {
	my ( $self ) = @_;
	my $result;
	my $offset;
	if ($self->{_name} eq 'B_TRUE') {
		$result = 1;
		$offset = 0;
	} else {
		# calculate the result
		if ($self->{_coeff2} eq 0) {
			$result = 1;
			$offset = 0;
		}
			else	{
			$result = $self->{_coeff6} / $self->{_coeff2};
			$offset = $self->{_coeff3} / $self->{_coeff2};
			# $result = (($self->{_coeff4} + $self->{_coeff5} + $self->{_coeff6} )/($self->{_coeff1}  + $self->{_coeff2} + $self->{_coeff3}));
			# format it if necessary
			# if it is just digits after the decimal place round to 9 maximum
			# if there is an exponent after the decimal place round to 5 maximum
			# TODO
			my $decPos = index($result,".");
			if ($decPos > 0) {
				# we have one - now what type
				my $decimalBit = substr($result,$decPos+1);
				my $ePos = index($decimalBit,"e");
				if ($ePos > 0) {
					# It is an exponent - round to 5 max
					$result = sprintf "%12.5e", $result;
				} else {
					# It is all digits - round to 9 max
					if (length($decimalBit) > 9) {
						$result = sprintf "%12.9f", $result;
					} # otherwise leave as is	
				}
			}
		}
	}
	return ($result, $offset);
};

sub getMeasureType {
	# measure came in as a string surrounded by quotes. return surrounded by braces
	my ( $self ) = @_;
	my $outstring = $self->{_measureType};
	return "{".substr($outstring,1,-1)."}";
};

		
	
	


