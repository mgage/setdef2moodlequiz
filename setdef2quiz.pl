#!/usr/bin/perl -w
use strict;
use warnings;
use v5.10;
use Cwd 'abs_path';
use Getopt::Long qw[:config no_ignore_case bundling];
use File::Find;
use FileHandle;
use Carp;
=head1 NAME
    
    setdef2quiz.pl

=head1 DESCRIPTION
  
    This converts a list or a directory of set definition files into an xml format list of 
    questions suitable for importing into a Moodle question bank.

=head1 SYNOPSIS

            setdef2quiz.pl file1.def file2.def ... > coursename.questions.xml
            setdef2quiz.pl dir_of_set_definition_files/* > coursename.questions.xml
		
	
	This works with the new format set definition files (since release 2.11)

=head1 DETAILS

	Options
	
	--courseName=s 
		Normally the course name is taken from the directory containing the definition files,
		but this overrides that choice.
	--category=s
		Often set to the course by default.
	--engine=s
		The name for the opaque engine, set to category by default.
	--server=s
		The URL of the webwork opaque server. e.g. https://hosted2.webwork.rochester.edu
	--servercourse=s
	    The name of the course rendering the problems on the opaque server. Default: daemon_course
	--qnum=s
	    The initial Question Number -- set to 1000 as a default
	--help
	     Print help message.
=cut

############################################################
# Read command line options
############################################################

our $engineName =''; # change this to correspond to the course name.
our $categoryName = '';
our $serverURL = 'https://hosted2.webwork.rochester.edu';    # 'https://hosted2.webwork.rochester.edu';
                # the actual call appends  /opaqueserver_wsdl 
                # 'https://hosted2.webwork.rochester.edu/opaqueserver_wsdl'
our $courseName = ''; 
our $serverCourseName = 'daemon_course';
our $initialQuestionNumber = 1000;
our $print_help_message='';


GetOptions(
	'category=s' 		=> \$categoryName,
	'engine=s'   		=> \$engineName,
	'course=s'   		=> \$courseName,
	'server=s'   		=> \$serverURL,
	'servercourse=s'    => \$serverCourseName,
	'qnum=s'            => \$initialQuestionNumber,
	'help'       		=> \$print_help_message,
);


print_help_message() if $print_help_message;

############################################################
# End Read command line options
############################################################

my $xmlQuestionNumber = $initialQuestionNumber;
my  $baseURL= "$serverURL/webwork2/$serverCourseName";
my @files_and_directories = @ARGV;

#print STDERR @files_and_directories, "\n";
# print help message if no arguments are given
print_help_message() and die unless @files_and_directories>0;


my $read_directory_mode=0;

if ( -d $files_and_directories[0] ) { #reading directory of .def files
	$read_directory_mode =1;
	print STDERR "setdef2quiz.pl: Reading set definition files 
	from directory '$files_and_directories[0]'\n";
	$courseName = $files_and_directories[0] unless $courseName;
} else { #reading list of .def files
	$courseName = "DefaultWWcategory" unless $courseName;
}

# initialize category and engine names.
$categoryName=$courseName unless $categoryName;
$engineName=$categoryName unless $engineName;

print <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<quiz>

EOF


if ($read_directory_mode ) { # process set definition files in the directory
	my $dir = abs_path($files_and_directories[0]); # read from directory of .def files
	find(\&wanted, ($dir));
} else { #  process each set definition file in list
	while(<@files_and_directories>) {
		my $item = $_;
		my $file_path = abs_path($item);
		next unless $file_path =~ /\.def$/;
		eval{
			process_def_file($file_path);
		};
		print STDERR "Error in processing $file_path: $@" if $@;
	}
}

sub wanted {
	return '' unless $File::Find::name =~ /\.def$/;
	eval{
		process_def_file($File::Find::name) if -f $File::Find::name;
	};
	print STDERR "Error in processing $File::Find::name: $@" if $@;
}

print "</quiz>\n";
print STDERR "Created category '$categoryName' for engine '$engineName' 
	which will render questions through the course '$serverCourseName' at the server '$serverURL'
	The full baseURL is '$baseURL'. 
	xmlQuestions: '$initialQuestionNumber' to '$xmlQuestionNumber'\n";





sub process_def_file  {
	my $filePath = shift;
	my $fileName = $filePath;
	$fileName =~s|^.*/set||;
	my $setName = $fileName;
	$setName =~s/.def//;
	print qq!
	<question type="category">
		<category>
			<text>$categoryName/set$setName</text>
		</category>
	  </question>
	!;
	my $line_number=0;
	# decide whether it is new or old set definition format
	my $format_type=1;
	my $fh;
	open($fh, "<", $filePath) || die "couldn't open $filePath";
		while(<$fh>) {
			next unless $_=~/^source\_file/;
			$format_type=2; # this is a new format set definition File
			last;
		}
	close($fh);
	open($fh, "<", $filePath) || die "couldn't open $filePath";
	my $xmlquestion='';
	if ($format_type == 2) {
		# warn "processing new definition format file $setName\n";
		$xmlquestion=read_new_def_format($setName, $fh); 
	} else {
		# warn "processing old definition format file $setName\n";
		$xmlquestion=read_old_def_format($setName, $fh);
	}
	print $xmlquestion;  # print collection of questions in the set definition file to STDOUT
	close($fh);
}
	
sub read_new_def_format {
	my $setName = shift;
	my $fh= shift;
	my $questionNumber=0;
	my $xmlquestions='';
	while (<$fh>) {
		#print "$line_number ,", $_ ;
		next unless $_ =~/^source\_file/;
		#print "$_";
		$questionNumber++;
		$questionNumber = sprintf('%02d', $questionNumber); #use leading zeros for problem number
		$xmlQuestionNumber++;
		my $probPath = $_;
		chomp($probPath);
		if ( $setName =~ /(^\d+)(.*)/ ) { #set name begins with a number make sure it has at least two digits.
			my $num = $1; my $name = $2;
			$setName = sprintf('%02d',$num) . $name; #use preceeding zeros
		}		
		$xmlquestions .= print_xml_formatted_question($xmlQuestionNumber, $setName, 
	                      $questionNumber, $probPath, $engineName, $serverURL);
	    return $xmlquestions;
	
	}

	return $xmlquestions;
}

sub read_old_def_format {
	my $setName = shift;
	my $fh= shift;
	my $questionNumber=0;
	my $xmlquestions='';
	while (<$fh>) { # skip lines before the problemList line
		next unless $_ =~/\S/;
		last if $_ =~ /problemList/i;
	}
	while (<$fh>) { # read remaining lines as paths to problems
		next unless $_ =~/\S/;
		$questionNumber++;		
		$questionNumber = sprintf('%02d', $questionNumber); #use leading zeros for problem number
		$xmlQuestionNumber++;
		my $probPath = $_;
		chomp($probPath);
		$probPath =~ s/\.pg.*/.pg/; # don't read after the end of the name.
		# print STDERR "setName: $setName, problemPath: $probPath\n";
		$xmlquestions .= print_xml_formatted_question($xmlQuestionNumber, $setName, 
	                      $questionNumber, $probPath, $engineName, $serverURL);
	}
	return $xmlquestions;

}	

sub print_xml_formatted_question {
	my ($xmlQuestionNumber, $setName, $questionNumber, $probPath, $engineName, $serverURL,) = @_;

	$probPath =~ s/,.*$//;
	$probPath =~ s|\-|\_\_\_|g;
	$probPath =~ s|/|\_\_|g;
	$probPath =~ s/^L/l/;

	return <<EOQ;
		
<!-- question: $xmlQuestionNumber  -->
  <question type="opaque">
    <name>
      <text>${setName}Prob$questionNumber</text>
    </name>
    <questiontext format="moodle_auto_format">
      <text></text>
    </questiontext>
    <generalfeedback format="moodle_auto_format">
      <text></text>
    </generalfeedback>
    <defaultgrade>1.0000000</defaultgrade>
    <penalty>0.0000000</penalty>
    <hidden>0</hidden>
    <remoteid>$probPath</remoteid>
    <remoteversion>1.0</remoteversion>
    <engine>
      <name>
        <text>$engineName</text>
      </name>
      <passkey>
        <text></text>
      </passkey>
      <timeout>10</timeout>
      <qe>
        <text>$serverURL/opaqueserver_wsdl</text>
      </qe>
      <qb>
        <text>$serverURL/webwork2/$serverCourseName</text>
      </qb>
    </engine>
    <tags>
      <tag><text>ODE</text>
</tag>
      <tag><text>IC</text>
</tag>
    </tags>
  </question>
  
EOQ




}



sub print_help_message {
print <<'EOT';
=head1 NAME
    
    setdef2quiz.pl

=head1 DESCRIPTION

	This works with the new format set definition files (since release 2.11)
    
    This converts a directory of 

=head1 SYNOPSIS

            setdef2quiz.pl file1.def file2.def ... > coursename.questions.xml
            setdef2quiz.pl dir_of_set_definition_files/* > coursename.questions.xml
		
	
	This works with the new format set definition files (since release 2.11)

=head1 DETAILS

	Options
	
	--courseName=s 
		Normally the course name is taken from the directory containing the definition files,
		but this overrides that choice.
	--category=s
		Often set to the course by default.
	--engine=s
		The name for the opaque engine, set to category by default.
	--server=s
		The URL of the webwork opaque server. e.g. https://hosted2.webwork.rochester.edu
	--servercourse=s
	    The name of the course rendering the problems on the opaque server. Default: daemon_course
	--qnum=s
	    The initial Question Number -- set to 1000 as a default

=cut

EOT
}

1;