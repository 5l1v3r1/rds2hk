#!/usr/bin/perl 
# Edit the line above for your perl path

# --------------------------------------------------------------------
# The software provided here is released by the National
# Institute of Standards and Technology (NIST), an agency of
# the U.S. Department of Commerce, Gaithersburg MD 20899,
# USA.  The software bears no warranty, either expressed or
# implied. NIST does not assume legal liability nor
# responsibility for a User's use of the software or the
# results of such use.
#
# Please note that within the United States, copyright
# protection, under Section 105 of the United States Code,
# Title 17, is not available for any work of the United
# States Government and/or for any works created by United
# States Government employees. User acknowledges that this
# software contains work which was created by NIST employees
# and is therefore in the public domain and not subject to
# copyright.  The User may use, distribute, or incorporate
# this software provided the User acknowledges this via an
# explicit acknowledgment of NIST-related contributions to
# the User's work. User also agrees to acknowledge, via an
# explicit acknowledgment, that any modifications or
# alterations have been made to this software before
# redistribution.
# --------------------------------------------------------------------
#
# Douglas White - douglas.white@nist.gov - February 7, 2003
#
# This script autosenses the version of the NIST NSRL RDS files
# (NSRLFile.txt, NSRLMfg.txt, NSRLOS.txt, NSRLProd.txt and
#  if needed, NSRLLang.txt) and allows the user to convert
# from RDS version 2.x to version 1.5,
# from RDS version 2.x to Hashkeeper format, or
# from RDS version 1.5 to Hashkeeper format.
#
# Options : perl rds2hk.pl -h            show help hints
#           perl rds2hk.pl -f format [-d RDS_directory] [-u] [-p product_id] [-l logfile] 
# Examples :
#     To convert the NSRL files in the D:\hashsets\NSRL directory
#     to Hashkeeper format, with unique products in the .HKE file, run
#         perl rds2hk.pl -d D:\hashsets\NSRL -f hk -u
#     This will create two Hashkeeper files in the directory where
#     the script was run and output messages to the screen.
#
#     To convert only the hashes pertaining to application 1556 in
#     the NSRL files in the D:\hashsets\NSRL directory
#     to Hashkeeper format, run
#         perl rds2hk.pl -d D:\hashsets\NSRL -f hk -p 1556 -u
#     This will create two Hashkeeper files in the directory where
#     the script was run and output messages to the screen.
#
#     To convert the NSRL files in the D:\hashsets\NSRL21 directory
#     to NSRL version 1.5 format, run
#         perl rds2hk.pl -d D:\hashsets\NSRL21 -f 1.5
#     This will create four RDS version 1.5 files in the directory where
#     the script was run and output messages to the screen.
#
#     To convert the NSRL files in the D:\hashsets\NSRL21 directory
#     to NSRL version 1.5 format and log the status messages, run
#         perl rds2hk.pl -d D:\hashsets\NSRL21 -f 1.5 -l logfile
#     This will create four RDS version 1.5 files in the directory where
#     the script was run and output messages to the file "logfile".
#
#
# Tested in Windows 2000, Mac OS X, and Red Hat Linux.
#
# --------------------------------------------------------------------

use strict;
use Getopt::Std;

use vars qw( $opt_h $opt_l $opt_d $opt_f $opt_p $opt_u
  $NSRLProd $NSRLOS $NSRLFile $NSRLMfg $NSRLLang
  $RDS_dir $RDS_version $out_format
  $hke_file $hsh_file $line $i $prod_codes $p
  @parts @time %manufacturer %product
  $HKE_hashset_id $HKE_name $HKE_vendor $HKE_package
  $HKE_version $HKE_authenicated_flag $HKE_notable_flag
  $HKE_initials $HKE_num_of_files $HKE_description $HKE_date_loaded
  $HSH_file_id $HSH_hashset_id $HSH_file_name $HSH_directory
  $HSH_hash $HSH_file_size $HSH_date_modified $HSH_time_modified
  $HSH_time_zone $HSH_comments $HSH_date_accessed $HSH_time_accessed
);

# defaults for RDS input
$NSRLFile = "NSRLFile.txt";
$NSRLMfg  = "NSRLMfg.txt";
$NSRLOS   = "NSRLOS.txt";
$NSRLProd = "NSRLProd.txt";
$NSRLLang = "NSRLLang.txt";
$RDS_dir  = "";

# defaults for HashKeeper conversion output
$out_format = "hk";
$hke_file   = "outfile.hke";
$hsh_file   = "outfile.hsh";

# deal with command line options
getopts('hl:d:f:p:u');

# deal with the format the user wants
if ($opt_f) {
    if (   ( index( lc($opt_f), "hk" ) == 0 )
        || ( $opt_f eq "1.5" )
        || ( $opt_f eq "2.0" ) )
    {
        $out_format = lc($opt_f);
    }
    else {
        print STDERR "Output format $opt_f is invalid.\n";
        $opt_h = 1;
    }
}
else {
    # must give an output format. If none, display help.
    $opt_h = 1;
}

# if someone wants help, display help and exit
if ($opt_h) {
    print STDERR "\nUsage : $0 [-h] -f format [-d RDS_directory] \n\t\t[-l logfile] [-p product_id] [-u] \n";
    print STDERR "\t-h : help with command line options\n";
    print STDERR "\t-f format : one of hk , 1.5 , 2.0 (MANDATORY)\n";
    print STDERR "\t-l logfile : print log info to a file\n";
    print STDERR "\t-d dir : directory holding NSRLProd.txt, NSRLFile.txt\n\t\tNSRLOS.txt and NSRLMfg.txt\n";
    print STDERR "\t-p integer : use one ProductCode from NSRLProd.txt\n";
    print STDERR "\t-u : guarantee a unique product line in hk output\n";
    exit;
}

# other directory where RDS input resides
# if no directory given, default is the current working directory
if ($opt_d) {
    $RDS_dir = $opt_d;
    if (   ( substr( $opt_d, -1, 1 ) ne "\\" )
        && ( substr( $opt_d, -1, 1 ) ne "/" ) )
    {
        $RDS_dir = $opt_d . "/";
    }
}

# if a specific productcode was used, snag the number for use later
if ($opt_p) {
    $p = scalar $opt_p;
}

# if user did not want a log file, log to STDOUT
if ( !$opt_l ) {
    $opt_l = "-";
}

# check the time for the log
@time = localtime(time);
if ( $time[5] < 2000 ) {
    $time[5] += 1900;
}

open( LOG, ">$opt_l" ) or die "\n$0 : cannot create log file $opt_l\n";
printf LOG "%2d-%02d-%02d %02d:%02d:%02d", $time[5], $time[4] + 1, $time[3],
  $time[2], $time[1], $time[0];
print LOG "\n$0 : preparing to use RDS files in $RDS_dir\n";

# if the RDS files are unavailable, exit
if ( !-e "$RDS_dir$NSRLProd" ) {
    die "\n$0 : cannot read NSRL file $RDS_dir$NSRLProd\n";
}

if ( !-e "$RDS_dir$NSRLMfg" ) {
    die "\n$0 : cannot read NSRL file $RDS_dir$NSRLMfg\n";
}

if ( !-e "$RDS_dir$NSRLFile" ) {
    die "\n$0 : cannot read NSRL file $RDS_dir$NSRLFile\n";
}

if ( !-e "$RDS_dir$NSRLOS" ) {
    die "\n$0 : cannot read NSRL file $RDS_dir$NSRLOS\n";
}

print LOG "\n$0 : RDS files are available\n";

if ($opt_p) {
    print LOG "Only product ID $p will be converted.\n";
}

# -u should become a default in future...
if ($opt_u) {
    print LOG "Unique product IDs from NSRLProd.txt will be converted.\n";
}

# read the first line of NSRLFile.txt to determine the version
open( FIN, "<$RDS_dir$NSRLFile" )
  or die "\n$0 : cannot open $RDS_dir$NSRLFile\n";
$line = readline(*FIN);
close(FIN);
if ( substr( $line, 0, 13 ) eq "\"SHA-1\",\"MD5\"" ) {
    $RDS_version = "2.0";
}
else {
    $RDS_version = "1.0";
}

# read the first line of NSRLProd.txt to determine the version
open( FIN, "<$RDS_dir$NSRLProd" )
  or die "\n$0 : cannot open $RDS_dir$NSRLProd\n";
$line = readline(*FIN);
close(FIN);
if ( index( $line, "Language" ) > 0 ) {
    if ( $RDS_version eq "1.0" ) {
        $RDS_version = "1.5";
    }
}

print LOG "RDS files appear to be version $RDS_version\n";
print LOG "Output format will be $out_format\n";

if ( $RDS_version eq $out_format ) {
    print LOG "Input format is same as output, exiting.\n";
    close(LOG);
    exit;
}

print LOG "Converting from $RDS_version to $out_format\n";

#
# Convert from RDS 1.5 or 2.x to Hashkeeper
#
if (   ( ( $RDS_version eq "1.5" ) || ( $RDS_version eq "2.0" ) )
    && ( $out_format eq "hk" ) )
{

    open( FIN, "<$RDS_dir$NSRLMfg" )
      or die "\n$0 : cannot read $RDS_dir$NSRLMfg\n";
    while (<FIN>) {
        chomp;
        @parts = split (/\,/);
        $line  = shift @parts;
        $_     = $parts[1];
        if ( scalar @parts > 1 ) {
            $_ = join "\,", @parts;
        }
        if ( substr( $line, 0, 9 ) ne "\"MfgCode\"" ) {
            $manufacturer{ substr( $line, 1, -1 ) } = $_;
        }
    }
    close(FIN);

    # close the logfile because this next step can take a loooong time
    close(LOG);

# version 2 format
# "SHA-1","MD5","CRC32","FileName","FileSize","ProductCode","OpSystemCode","SpecialCode"
# "0000004DA6391F7F5D2F7FCCF36CEBDA60C6EA02","0E53C14A3E48D94FF596A2824307B492","AA6A7B16","00br2026.gif",2226,228,"WIN",""

# version 1 format
# sha-1,filename-combined,filesize,productcode,opsystemcode,md4,MD5,CRC32,SpecialCode

    open( FIN, "<$RDS_dir$NSRLFile" )
      or die "\n$0 : cannot convert $RDS_dir$NSRLFile\n";
    if ($opt_p) { $hsh_file = "$p$hsh_file"; }
    open( FOUT, ">$hsh_file" ) or die "\n$0 : cannot write to $hsh_file\n";
    print FOUT "\"file_id\",\"hashset_id\",\"file_name\",\"directory\",\"hash\",\"file_size\",\"date_modified\",\"time_modified\",\"time_zone\",\"comments\",\"date_accessed\",\"time_accessed\"\n";
    $i          = 0;
    $prod_codes = "\t";
    while (<FIN>) {
        chomp;
        @parts = split (/\,/);
# print STDERR "\t" . scalar @parts . " parts for $RDS_version \n";

        $HSH_file_id = $i;

        # SHA
        shift @parts;
        if ( $RDS_version eq "2.0" ) {

            # MD5
            $HSH_hash = shift @parts;

            # CRC32
            shift @parts;

            # filename
            $HSH_file_name = shift @parts;
            while ( substr( $HSH_file_name, -1, 1 ) ne "\"" ) {
                $HSH_file_name = $HSH_file_name . "," . shift @parts;
            }
            $HSH_directory = "\"C:\"";

            # file size
            $HSH_file_size = shift @parts;

            # prod code
            $HSH_hashset_id = shift @parts;
        }

        if ( $RDS_version eq "1.5" ) {

            # filename
            $HSH_file_name = shift @parts;
            while ( substr( $HSH_file_name, -1, 1 ) ne "\"" ) {
                $HSH_file_name = $HSH_file_name . "," . shift @parts;
            }

            # file size
            $HSH_file_size = shift @parts;

            # prod code
            $HSH_hashset_id = shift @parts;

            # OS code
            $HSH_hash = shift @parts;

            # MD4
            $HSH_hash = shift @parts;

            # MD5
            $HSH_hash = shift @parts;

            # CRC32
            shift @parts;
        }

        $HSH_date_modified = "1/1/03 21:12:00";
        $HSH_time_modified = "1/1/03 21:12:00";
        $HSH_time_zone     = "\"EST\"";
        $HSH_comments      = "";
        $HSH_date_accessed = "";
        $HSH_time_accessed = "";

# print STDERR "\t" . scalar @parts . " parts from $RDS_version \n";

        $line = "$HSH_file_id,$HSH_hashset_id,$HSH_file_name,$HSH_directory,$HSH_hash,$HSH_file_size,$HSH_date_modified,$HSH_time_modified,$HSH_time_zone,$HSH_comments,$HSH_date_accessed,$HSH_time_accessed";
        if ( $i > 0 ) {
            if ($opt_p) {
                if ( $p == scalar $HSH_hashset_id ) {
                    print FOUT "$line\n";
                    $prod_codes .= "$HSH_hashset_id\t";
                }
            }
            else {
                print FOUT "$line\n";
                $prod_codes .= "$HSH_hashset_id\t";
            }
        }
        $i++;
    }
    close(FIN);
    close(FOUT);

    open( LOG, ">>$opt_l" ) or die "\n$0 : cannot create log file $opt_l\n";
    print LOG "Processed $i lines from $RDS_dir$NSRLFile \n";

# "ProductCode","ProductName","ProductVersion","OpSystemCode","MfgCode","Language","ApplicationType"
# 1,"Norton Utilities","2.0 WinNT 4.0","WINNT","SYM","English","Utility"

    open( FIN, "<$RDS_dir$NSRLProd" )
      or die "\n$0 : cannot convert $RDS_dir$NSRLProd\n";
    if ($opt_p) { $hke_file = "$p$hke_file"; }
    open( FOUT, ">$hke_file" ) or die "\n$0 : cannot write to $hke_file\n";
    print FOUT "\"hashset_id\",\"name\",\"vendor\",\"package\",\"version\",\"authenicated_flag\",\"notable_flag\",\"initials\",\"num_of_files\",\"description\",\"date_loaded\"\n";
    $i = 0;
    while (<FIN>) {
        chomp;
        @parts = split (/\,/);
# print STDERR "\t" . scalar @parts . " parts with $RDS_version \n";

        # ProductCode
        $HKE_hashset_id = scalar $parts[0];
        shift @parts;

        # ProductName
        $HKE_package = shift @parts;
        while ((scalar @parts > 7) && ( substr( $HKE_package, -1, 1 ) ne "\"" )) {
            $HKE_package = $HKE_package . "," . shift @parts;
        }
# print STDERR "\t" . scalar @parts . " parts with $RDS_version \n";

        # ProductVersion
        $HKE_version = shift @parts;
        while ((scalar @parts > 7) && ( substr( $HKE_version, -1, 1 ) ne "\"" )) {
            $HKE_version = $HKE_version . "," . shift @parts;
        }
# print STDERR "\t" . scalar @parts . " parts with $RDS_version \n";

        $HKE_initials = "\"NSRL\"";
        $HKE_name     = $HKE_initials . $HKE_package . $HKE_version;
        $HKE_name =~ s/\"\"//g;
        $HKE_description = $HKE_package . $HKE_version;
        $HKE_description =~ s/\"\"//g;

        # OpSystemCode
        shift @parts;

        # MfgCode
        my $HKE_vendcode = shift @parts;
        if (! defined $manufacturer{ substr( $HKE_vendcode, 1, -1 ) } )  {
        $HKE_vendor = "UNKNOWN";
        } else {
        $HKE_vendor = $manufacturer{ substr( $HKE_vendcode, 1, -1 ) };
        }

        $HKE_authenicated_flag = 1;
        $HKE_notable_flag      = 0;
        $HKE_num_of_files      = 0;
        $HKE_date_loaded       = "1/1/03 21:12:00";

        if (! defined $HKE_hashset_id ) { print STDERR " undefined HKE id \n"; }
        if (! defined $HKE_name ) { print STDERR " undefined HKE name \n"; }
        if (! defined $HKE_vendor ) { print STDERR " undefined HKE vend \n"; }
        if (! defined $HKE_package ) { print STDERR " undefined HKE pack \n"; }
        if (! defined $HKE_version ) { print STDERR " undefined HKE ver \n"; }
        if (! defined $HKE_authenicated_flag ) { print STDERR " undefined HKE af \n"; }
        if (! defined $HKE_notable_flag ) { print STDERR " undefined HKE nf \n"; }
        if (! defined $HKE_initials ) { print STDERR " undefined HKE init \n"; }
        if (! defined $HKE_num_of_files ) { print STDERR " undefined HKE num \n"; }
        if (! defined $HKE_description ) { print STDERR " undefined HKE desc \n"; }
        if (! defined $HKE_date_loaded ) { print STDERR " undefined HKE dl \n"; }

        $line = "$HKE_hashset_id,$HKE_name,$HKE_vendor,$HKE_package,$HKE_version,$HKE_authenicated_flag,$HKE_notable_flag,$HKE_initials,$HKE_num_of_files,$HKE_description,$HKE_date_loaded";
# if (scalar @parts < 7) { print STDERR "   $line \n"; }
        if ( $i > 0 ) {
            if ( index( $prod_codes, "\t$HKE_hashset_id\t" ) > -1 ) {
                if ($opt_u) {
                    if ( !defined $product{$HKE_hashset_id} ) {
                        $product{$HKE_hashset_id} = 1;
                        print FOUT "$line\n";
                    }
                }
                else {
                    print FOUT "$line\n";
                }
            }
        }
        $i++;

    }
    close(FIN);
    close(FOUT);
    print LOG "Processed $i lines from $RDS_dir$NSRLProd \n";
}

#
# Convert from RDS 2.x to RDS 1.5
#
if ( ( $RDS_version eq "2.0" ) && ( $out_format eq "1.5" ) ) {

    $i = 0;
    open( FIN, "<$RDS_dir$NSRLMfg" )
      or die "\n$0 : cannot read $RDS_dir$NSRLMfg\n";
    open( FOUT, ">$NSRLMfg" ) or die "\n$0 : cannot create $NSRLMfg\n";
    while (<FIN>) {
        print FOUT $_;
        $i++;
    }
    close(FOUT);
    close(FIN);
    print LOG "Processed $i lines from $RDS_dir$NSRLMfg \n";

    $i = 0;
    open( FIN, "<$RDS_dir$NSRLOS" )
      or die "\n$0 : cannot read $RDS_dir$NSRLOS\n";
    open( FOUT, ">$NSRLOS" ) or die "\n$0 : cannot create $NSRLOS\n";
    while (<FIN>) {
        print FOUT $_;
        $i++;
    }
    close(FIN);
    close(FOUT);
    print LOG "Processed $i lines from $RDS_dir$NSRLOS \n";

    $i = 0;
    open( FIN, "<$RDS_dir$NSRLProd" )
      or die "\n$0 : cannot read $RDS_dir$NSRLProd\n";
    open( FOUT, ">$NSRLProd" ) or die "\n$0 : cannot create $NSRLProd\n";
    while (<FIN>) {
        print FOUT $_;
        $i++;
    }
    close(FIN);
    close(FOUT);
    print LOG "Processed $i lines from $RDS_dir$NSRLProd \n";

    # close the logfile because this next step can take a loooong time
    close(LOG);

# version 2 header and example line
# "SHA-1","MD5","CRC32","FileName","FileSize","ProductCode","OpSystemCode","SpecialCode"
# "0000004DA6391F7F5D2F7FCCF36CEBDA60C6EA02","0E53C14A3E48D94FF596A2824307B492","AA6A7B16","00br2026.gif",2226,228,"WIN",""
    open( FIN, "<$RDS_dir$NSRLFile" )
      or die "\n$0 : cannot convert $RDS_dir$NSRLFile\n";
    open( FOUT, ">$NSRLFile" ) or die "\n$0 : cannot create $NSRLFile\n";

    print FOUT "\"SHA-1\",\"FileName\",\"FileSize\",\"ProductCode\",\"OpSystemCode\",\"MD4\",\"MD5\",\"CRC32\",\"SpecialCode\"\n";

    $i = <FIN>;    # ignore the header line
    $i = 0;
    while (<FIN>) {
        chomp;
        @parts = split (/\,/);

#sha-1,filename-combined,filesize,productcode,opsystemcode,md4,MD5,CRC32,SpecialCode
        if ( $#parts == 7 ) {    # expected separator use
            print FOUT "$parts[0],$parts[3],$parts[4],$parts[5],$parts[6],\"00000000000000000000000000000000\",$parts[1],$parts[2],$parts[7]\n";
        }
        else {                   # unexpected - comma in filename, etc.

            #	    print STDOUT "\n$0 : correcting data for SHA $parts[0]\n";
            while ( ( $#parts > 7 ) && ( substr( $parts[3], -1, 1 ) ne "\"" ) )
            {
                $parts[3] .= $parts[4];
                my $p = 4;
                while ( $p < $#parts ) {
                    $parts[$p] = $parts[ $p + 1 ];
                    $p++;
                }
                pop @parts;
            }
            if ( $#parts == 7 ) {    # expected separator use
                print FOUT "$parts[0],$parts[3],$parts[4],$parts[5],$parts[6],\"00000000000000000000000000000000\",$parts[1],$parts[2],$parts[7]\n";
            }
            else {                   # unexpected - comma in filename, etc.
                print STDOUT "\n$0 : unexpected data in $RDS_dir$NSRLFile for SHA $parts[0]\n";
            }
        }
        $i++;
    }
    close(FIN);
    close(FOUT);

    open( LOG, ">>$opt_l" ) or die "\n$0 : cannot create log file $opt_l\n";
    print LOG "Processed $i lines from $RDS_dir$NSRLFile \n";

# "ProductCode","ProductName","ProductVersion","OpSystemCode","MfgCode","Language","ApplicationType"
# 1,"Norton Utilities","2.0 WinNT 4.0","WINNT","SYM","English","Utility"

}

# other conversions to follow here

#
# Convert from RDS 2.x to RDS 1.5
#
if ( ( $RDS_version eq "1.5" ) && ( $out_format eq "2.0" ) ) {
    print LOG "Conversion from $RDS_version to $out_format is not implemented yet.\n";
}

#
# Convert from RDS 1.0 to later versions
#
if (   ( $RDS_version eq "1.0" )
    && ( ( $out_format eq "1.5" ) || ( $out_format eq "2.0" ) ) )
{
    print LOG "Conversion from $RDS_version to $out_format is not implemented yet.\n";
    print LOG "Version $RDS_version input must use $NSRLLang for conversion.\n";

    if ( !-e "$RDS_dir$NSRLLang" ) {
        print LOG "$RDS_dir$NSRLLang is missing. \nPlease download it from www.nsrl.nist.gov\n";
        close(LOG);
        die "\n$0 : cannot read NSRL file $RDS_dir$NSRLLang\n";
    }

}

# clean up and exit
@time = localtime(time);
if ( $time[5] < 2000 ) {
    $time[5] += 1900;
}
printf LOG "\n%2d-%02d-%02d %02d:%02d:%02d\n", $time[5], $time[4] + 1, $time[3],
  $time[2], $time[1], $time[0];
close(LOG);

exit;

__END__

Douglas.White@nist.gov   February 2003

Building a .hke file:

HKE.hashset_id = NSRLProd.ProductCode
HKE.name  = "NSRL" + NSRLProd.ProductName + NSRLProd.ProductVersion
HKE.vendor = NSRLMfg.MfgName
HKE.package = NSRLProd.ProductName
HKE.version = NSRLProd.ProductVersion
HKE.authenicated_flag = 1
HKE.notable_flag = 0             may be special code?
HKE.initials = "NSRL"
HKE.num_of_files = CALCULATED_FIELD
HKE.description = NSRLProd.ProductName + NSRLProd.ProductVersion
HKE.date_loaded = DATE_FIELD

Building a .hsh file:

HSH.file_id = CALCULATED_FIELD
HSH.hashset_id = NSRLProd.ProductCode
HSH.file_name = NSRLFile.FileName
HSH.directory = "C:"
HSH.hash = NSRLFile.MD5
HSH.file_size = NSRLFile.FileSize
HSH.date_modified = DATE_FIELD
HSH.time_modified = DATE_FIELD
HSH.time_zone = "EST"
HSH.comments = ""
HSH.date_accessed = ""
HSH.time_accessed = ""

hashset.hke
-----------
"hashset_id","name","vendor","package","version","authenicated_flag","notable_flag","initials","num_of_files","description","date_loaded"
5,"Z00002   Windows 95A","Microsoft","Windows 95","A",1,0,"NDIC",0,"Windows 95A",6/11/98 10:35:21

hashset.hsh
-----------
"file_id","hashset_id","file_name","directory","hash","file_size","date_modified","time_modified","time_zone","comments","date_accessed","time_accessed"
29294,5,"MSFS.HLP","C:\WINDOWS\HELP","0EAF18E13DB816C8EAE885BAA2B0503B",34832,7/11/95 0:00:00,12/30/99 9:50:00,"PST",,,

==> NSRLProd.txt <==
"ProductCode","ProductName","ProductVersion","OpSystemCode","MfgCode","Language","ApplicationType"
1,"Norton Utilities","2.0 WinNT 4.0","WINNT","SYM","English","Utility"

==> NSRLFile.txt <==
"SHA-1","MD5","CRC32","FileName","FileSize","ProductCode","OpSystemCode","SpecialCode"
"0000004DA6391F7F5D2F7FCCF36CEBDA60C6EA02","0E53C14A3E48D94FF596A2824307B492","AA6A7B16","00br2026.gif",2226,228,"WIN",""

==> NSRLMfg.txt <==
"MfgCode","MfgName"
"3Com","3Com"

==> NSRLOS.txt <==
"OpSystemCode","OpSystemName","OpSystemVersion","MfgCode"
"AIX","AIX","Generic","Unknown"

