
use strict;
use warnings;
use Carp;


BEGIN 
{

    eval { require Encode; };
    
    if ($@) {
        print "1..0 #  Skip: Encode is not available\n";
        exit 0;
    }
}


require "dbm_filter_util.pl";

use Test::More tests => 26;

BEGIN { use_ok('DBM_Filter') };
my $db_file;
BEGIN {
    use Config;
    foreach (qw/SDBM_File ODBM_File NDBM_File GDBM_File DB_File/) {
        if ($Config{extensions} =~ /\b$_\b/) {
            $db_file = $_;
            last;
        }
    }
    use_ok($db_file);
};
BEGIN { use_ok('Fcntl') };
BEGIN { use_ok('charnames', qw{greek})};

use charnames qw{greek};

unlink <Op_dbmx*>;
END { unlink <Op_dbmx*>; }

my %h1 = () ;
my $db1 = tie(%h1, $db_file,'Op_dbmx', O_RDWR|O_CREAT, 0640) ;

ok $db1, "tied to $db_file";

eval { $db1->Filter_Push('encode' => 'blah') };
like $@, qr/^Encoding 'blah' is not available/, "push an illegal filter" ;

eval { $db1->Filter_Push('encode') };
is $@, '', "push an 'encode' filter (default to utf-8)" ;


{
    no warnings 'uninitialized';
    StoreData(\%h1,
	{	
		undef()	=> undef(),
		'alpha'	=> "\N{alpha}",
		"\N{gamma}"=> "gamma",
		"beta"	=> "\N{beta}",
	});

}

VerifyData(\%h1,
	{
		'alpha'	=> "\N{alpha}",
		"beta"	=> "\N{beta}",
		"\N{gamma}"=> "gamma",
		""		=> "",
	});

eval { $db1->Filter_Pop() };
is $@, '', "pop the 'utf8' filter" ;

eval { $db1->Filter_Push('encode' => 'iso-8859-16') };
is $@, '', "push an 'encode' filter (specify iso-8859-16)" ;

use charnames qw{:full};
StoreData(\%h1,
	{	
		'euro'	=> "\N{EURO SIGN}",
	});

undef $db1;
{
    use warnings FATAL => 'untie';
    eval { untie %h1 };
    is $@, '', "untie without inner references" ;
}

# read the dbm file without the filter
my %h2 = () ;
my $db2 = tie(%h2, $db_file,'Op_dbmx', O_RDWR|O_CREAT, 0640) ;

ok $db2, "tied to $db_file";

if (ord('A') == 193) { # EBCDIC.
    VerifyData(\%h2,
	   {
	    'alpha'	=> "\xB4\x58",
	    'beta'	=> "\xB4\x59",
	    "\xB4\x62"=> "gamma",		
	    "\x65\x75\x72\x6F" => "\xA4",                           
	    ""		=> "",
	   });
} else {
    VerifyData(\%h2,
	   {
	    'alpha'	=> "\xCE\xB1",
	    'beta'	=> "\xCE\xB2",
	    "\xCE\xB3"=> "gamma",
	    'euro'	=> "\xA4",
	    ""		=> "",
	   });
}

undef $db2;
{
    use warnings FATAL => 'untie';
    eval { untie %h2 };
    is $@, '', "untie without inner references" ;
}

