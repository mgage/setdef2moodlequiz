# setdef2moodlequiz
Tools and instructions for converting questions in a WeBWorK homework set into a format suitable for importing into a Moodle question bank.

```
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
```
