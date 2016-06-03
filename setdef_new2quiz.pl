#!/usr/bin/perl -w
use strict;
use v5.10;

=head1 Convert set definition files to moodle question quiz .xml format

	setdef2quiz.pl file1.pg file2.pg  > coursename.questions.xml

=cut



my @setdefinition_files = @ARGV;
my $engineName ='spring16mth162'; # change this to correspond to the course name.
my $serverURL ='http:/localhost/opaqueserver_wsdl';
my $categoryName = 'spring16mth162';
print <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<quiz>
<!-- question: 0  -->
  <question type="category">
    <category>
        <text>$categoryName</text>
    </category>
  </question>
EOF

my $xmlQuestionNumber = 2000;
while (<@setdefinition_files>) {
	my $filePath = $_;
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
	open(my $fh, "<", $filePath) || die "couldn't open $filePath";
	my $questionNumber = 0;
	while (<$fh>) {
	    #print "$line_number ,", $_ ;
		next unless $_ =~/^source\_file/;
		#print "$_";
		$questionNumber++;
		$xmlQuestionNumber++;
		my $probPath = $_;
		chomp($probPath);
		$probPath =~ s/^source_file\s*=\s*//;
		$probPath =~ s|\-|\_\_\_|g;
		$probPath =~ s|/|\_\_|g;
		$probPath =~ s/^L/l/;
        $questionNumber = sprintf('%02d', $questionNumber); #use leading zeros for problem number
        if ( $setName =~ /(^\d+)(.*)/ ) { #set name begins with a number make sure it has at least two digits.
        	my $num = $1; my $name = $2;
        	$setName = sprintf('%02d',$num) . $name; #use preceeding zeros
        }		



		my $xmlquestion = <<EOQ;
		
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
        <text>$serverURL</text>
      </qe>
    </engine>
    <tags>
      <tag><text>ODE</text>
</tag>
      <tag><text>IC</text>
</tag>
    </tags>
  </question>
  
EOQ
	print $xmlquestion;
	}
	close($fh);
}

print "</quiz>\n";
