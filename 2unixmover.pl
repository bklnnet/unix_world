#!/usr/bin/perl
##########################################################
# Unixmover - takes raw mainframe data files
# and enters them into automation system
# makes entry into logentry table
#
# Usage: ./unixmover.pl long_mainframe_name
#
# Mark.G.Naumowicz@verizon.com  516.797.3803
##########################################################

use DBI();
use File::Basename;
use File::stat;
use Net::FTP;

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdat)=localtime(time);

# --- Definitions time ----

$timestamp	= "$hour;$min;$sec";
$mon 		= sprintf("%02d", $mon+1);
$mday		= sprintf("%02d", $mday);
$year		= 1900+$year;
$stime1		= $year.$mon.$mday." ".$hour.":"."00".":".$sec;
$stime2		= $year.$mon.$mday." ".$hour.":"."10".":".$sec;
$stime3		= $year.$mon.$mday." ".$hour.":"."12".":".$sec;
$stime4         = $year.$mon.$mday." ".$hour.":"."20".":".$sec;
$stime5         = $year.$mon.$mday." ".$hour.":"."40".":".$sec;
$f_name 	= $ARGV[0];
$daystamp       ="$mon-$mday-$year";
$basedir       = "/licdns19/prod";
chomp $basedir;
$srcfile	= $ARGV[0];
$mynumber       = "0";
$newyear        = sprintf("%04d", $mynumber);
$newdaystamp    = "$mon-$mday-$newyear";

# -----------------------------------------------------------------------
	&start_check;
# -----------------------------------------------------------------------


$bar = 0;
       if ($f_name=~/\.((?:(?!\.).)*)$/xi){			# Get the name of the file without generation name
       my $foo = "$'";						# I love regex :-)
       $bar = "$`";
       $bar=~s/^\.|\///g;
       $fname = $bar;
}

# --- Connect to the database to get filename and jobname ---

$dbh = DBI->connect("DBI:mysql:database=ndm;host=localhost",
                         "root", "licd123",
                         {'RaiseError' => 1});

# Now retrieve data from the table.
  my $sth = $dbh->prepare("SELECT * FROM names WHERE source =\"$fname\"");
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref()) {

$source 	= $ref->{'source'};
$filename 	= $ref->{'filename'};
$jobname 	= $ref->{'jobname'};

    print "$ref->{'source'} | $ref->{'filename'} | $ref->{'jobname'}\n";
  }
  $sth->finish();

  # Disconnect from the database.
  $dbh->disconnect();

if(!$filename){
	print "
------------------------------------------------------------------------------------------------
   The associated filename not found! - skipping $f_name
------------------------------------------------------------------------------------------------\n";
	&mailme ($f_name);
	system("mv $f_name unknown");
	exit;
	}

# -----------------------------------------------------------------------
####       &ctd ($f_name);
# -----------------------------------------------------------------------



# --- Get JobFileID from DBase ---

$dbh = DBI->connect("DBI:mysql:database=ndm;host=localhost",
                         "root", "licd123",
                         {'RaiseError' => 1});
 
# Now retrieve data from the table.

  my $sth = $dbh->prepare("SELECT * FROM filename WHERE name =\"$filename\"");
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref()) {
 
$jobfileid       = $ref->{'jobfileid'};
 
    print "JobFileID - $ref->{'jobfileid'} \n";
  }
  $sth->finish();
 
  # Disconnect from the database.
  $dbh->disconnect();


# --------------------------------

$filename1 	= lc($filename); 				# Convert file name into lowercase
$filesize 	= -s $f_name;					# Get the filesize
$filedir        = "/licdns19/prod/$jobname/$daystamp";
$srcfile	= $filename1;
# ---------------------------------------------------------------------------------------------------

	&find_file;

# ---------------------------------------------------------------------------------
# --------------------------- Subs and procedures ---------------------------------
# ---------------------------------------------------------------------------------


sub ms_entry {

$dsn = "DBI:Sybase:licdns03:1433";
$dbh = DBI->connect($dsn, "sa", "glaus1");

die "Unable to connect to server $DBI::errstr" unless $dbh;

my $rc;
my $sth;

$dbh->do("use autosys"); 		# select database to work with

$ms_stmt = "INSERT INTO DataFile ( Path, Size, ReceiptStartTime, ReceiptEndTime, CopyStartTime, CopyEndTime, ProcessName, ProcessNumber, Submitter, StepName, CheckPointing, ExtCompression, StdCompression, SourceFile, ImportTime, JobFileID, IndexServerID ) VALUES ( '$filepath', $filesize, '$stime1', '$stime2', '$stime3', '$stime4', 'SENDRECV', 9999, 'UNIXMOVER', NULL, 'Y', 'N', 'N', '$ARGV[0]', '$stime5', $jobfileid, 49 )";

$sth = $dbh->prepare("$ms_stmt");
$sth->execute;

# ------------------------------------------------------------------------
# --- Statement into DataFile table M$SQL Server ---

print "Entered into DataFile:
	Path			'$filepath',
	Size			'$filesize',
	ReceiptStartTime	'$stime1',
	ReceiptEndTime		'$stime2',
	CopyStartTime		'$stime3',
	CopyEndTime		'$stime4',
	ProcessName		'SENDRECV',
	ProcessNumber		'9999',
	Submitter		'FILEMOVER',
	StepName		'NULL',
	CheckPointing		'Y',
	ExtCompression          'N',
	StdCompression          'N',
	SourceFile		'$ARGV[0]',
	ImportTime		'$stime5',
	JobFileID		'$jobfileid',
	IndexServerID		'49'
	---------------------------------------------------------------------------\n";

}

# ---------------------------------------------------------------------------------

sub start_check {
if(!$ARGV[0]){
        print "ERROR! Give me an argument $0 filename\n";
        exit;
        }
$file = "$ARGV[0]";
if (-e $file){
        # do nothing
} else {
print "$!\n";
        exit;
        }
}

# ---------------------------------------------------------------------------------

$newfiledir = "$basedir/$jobname/$newdaystamp";

sub find_file {

  if  (-d $filedir){
 
        print "dir $filedir exist, is the file there ?\n";
        $destfile = "$filedir/$srcfile";
 
                if (-e $destfile){
                print "$filedir exists, file also exists, must create new dir...\n";
 
                        my_freaking_label:      # What are you laughing at ? You gotta problem with my label ?

			$newfiledir = "$basedir/$jobname/$newdaystamp"; 

                        if (-d $newfiledir){
                                print "new $newfiledir exist, is the file $srcfile there ?\n";
                                $destfile = "$newfiledir/$srcfile";
				$filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$newdaystamp";
 
                                        if (-e $destfile){
					another_label:
                                        print "$newfiledir exists, file also exists (or existed), must create new dir...\n";
                                        $newyear++;
                                        $newdaystamp    = "$mon-$mday-$newyear";
                                        $newfiledir     = "$basedir/$jobname/$newdaystamp";
                                        print "will create $newfiledir\n";
					if (-d $newfiledir){
					print "Oops, dir already exists...!\n";
					} else {
					system("mkdir $newfiledir");
					}
					$destfile = "$newfiledir/$srcfile";
                                	print "$newfiledir exists now, will try to move file $srcfile over...\n";
                                	if (-e $destfile){
					# go loop
					goto another_label;
					} else {
					# check the stats dbase for previous entry
					&check_stats;
					system("mv $f_name $destfile");
                                	print "done...!\n";
                                	$filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$newdaystamp";
                                	print "filepath - $filepath\n";
                                	&ms_entry;
                                	&stats_entry;
                                	exit;
					}

                                                } else {
 
                                        print "print $newfiledir exists, file does not...\n";
                                        print "moving file $srcfile over...\n";
					# check stats dbase here
					&check_stats;
                                        system ("mv $f_name $destfile");
                                        print "done !\n";
					$filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$newdaystamp";
					print "filepath - $filepath\n";
                                        &ms_entry;
					&stats_entry;
					exit;
 
                                                }
 
                                        goto my_freaking_label;

 
                                        } else {
				$newfiledir = "$basedir/$jobname/$newdaystamp"; 
                                print "new $newfiledir doesn't exist, creating it now...\n";
                                system("mkdir $newfiledir");
                                $destfile = "$newfiledir/$srcfile";
                                print "$newfiledir exists now, moving file $srcfile over...\n";
				# check stats dbase here
				&check_stats;
                                system("mv $f_name $destfile");
                                print "done...!\n";
				$filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$newdaystamp";
                                print "filepath - $filepath\n";
                                &ms_entry;
				&stats_entry;
				exit;
 
                                }
 
 
                        } else {
                        $destfile = "$filedir/$srcfile";
                        print "$filedir exist, file $srcfile doesn't, moving file over...\n";
			#check stats dbase here
			&check_stats;
                        system("mv $f_name $destfile");
                        print "done...!\n";
			$filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$daystamp";
                        print "filepath - $filepath\n";
			&ms_entry;
			&stats_entry;
                        exit;
 
                        }
 
} else {
 
   print "dated dir $filedir doesn't exist, creating it now...\n";
   system("mkdir $filedir");
   $filepath = "\\\\licds2k01\\ndmrecv\\prod\\$jobname\\$daystamp";
   print "filepath - $filepath\n";
   $destfile = "$filedir/$srcfile";
   print "moving $srcfile over...\n";
   # check stats dbase here
   &check_stats; 
   system("mv $f_name $destfile");
   print "done...!\n";
   &ms_entry;
   &stats_entry;
   exit;
 
  }
}
 
# --------------------------------------------------------------------------------------------------

sub ctd {
my $tmpfile = ".tmpfile$$.dat";
  open (IN,"<$_[0]") || die "Can't open IN file!\n";
  open (OUT,">$tmpfile") || die "Can't open OUT file!\n";
  print "Now converting to DOS text... please wait\n";
 
  binmode (IN);
  binmode (OUT);
  while(read( IN, $buff, 2048 )){
        $data=$buff;
        $data=~ s/\x0A/\x0D\x0A/g;
        print OUT $data;
  }
 
  close(IN);
  close(OUT);
  print "\nFile converted!\n";
system("mv $_[0] done/$_[0].orig");
system("mv -f $tmpfile $_[0]");
print "done...!\n";

}
# ----------------------------------------------------------------------------------------------------
sub stats_entry {

$filepath =~s/\\/\\\\/g; 
 
$dbh = DBI->connect("DBI:mysql:database=ndm;host=localhost",
                         "root", "licd123",
                         {'RaiseError' => 1});
 
$stmt = "INSERT INTO stats \( source_file, filename, jobname, filesize, path \) VALUES \(\"$f_name\", \"$filename\", \"$jobname\", \"$filesize\", \"$filepath\"\)";
 
$dbh->do($stmt) or die $DBI::errstr;
 
  # Disconnect from the database.
  $dbh->disconnect();
}

# --------------------------------------------------------------------------------------------------------

sub mailme {

require Mail::Send;
 
    $msg = new Mail::Send;
 
    $msg = new Mail::Send Subject=>'example subject', To=>'Me';
 
    $msg->to('mark.g.naumowicz@verizon.com');
    $msg->subject('Unixmover alert message');
    $msg->set($header, @values);
    $msg->add($header, @values);
    $msg->delete($header);
 
    $fh = $msg->open;               # some default mailer
    print $fh "Associated filename not found - $_[0]";
    $fh->close;         # complete the message and send it
} 


sub check_stats {

($s,$n,$p,$j,$dt,$fl) = split ("/", $destfile);
 
print "job - $j | date - $dt | file - $fl\n";
 
# --- Connect to the database to check stats ---
 
$dbh = DBI->connect("DBI:mysql:database=ndm;host=localhost",
                         "root", "licd123",
                         {'RaiseError' => 1});
 
# Now retrieve data from the table.
  my $sth = $dbh->prepare("SELECT * FROM stats WHERE path like \"%$j%$dt\" ");
  $sth->execute();
  while (my $ref = $sth->fetchrow_hashref()) {
 
        $myfn       = $ref->{'filename'};
        if($myfn =~/$fl/i){
    print "filename $fl was alreday entered, skipping this destination\n";
	goto another_label; 
        }
  }
  $sth->finish();
  # Disconnect from the database.
  $dbh->disconnect();
}
