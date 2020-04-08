#!/l/local/bin/perl -w
#$Id: parseQueryLogsNew.pl,v 1.21 2019/08/15 17:32:01 tburtonw Exp tburtonw $#

# hack for perl 5.24.1 security fix which removes working directory from @INC
# See https://perldoc.perl.org/5.24.1/perldelta.html#Core-modules-and-tools-no-longer-search-_%22.%22_-for-optional-modules


use strict;
use Getopt::Long qw(:config auto_version auto_help);
use Pod::Usage;
use Encode;

require "/htapps/tburtonw.babel/analysis/bin/process_cgi.pl";

#Use open qw(:std :utf8);

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';


# pod2usage settings
my $help = 0;
my $man = 0;
my $TESTROBOT_IP='141\.213\.128\.185'; #grog
my $DEV_IP='141\.211\.43\.191'; # tom ip

my $CONFIG_FILE='';

my $FIRST_QUERY_ONLY="TRUE";
my $SKIP_NEXT_PAGES='';
my $SKIP_ELAPSED = "TRUE";
my $SKIP_RIGHTS_QUERY = "TRUE";

my $FIELD_LIST = '';
my $SEP = "\t";
#$SEP= "\|";
#
my $SOURCE='';

my $rv=GetOptions(    'h|help|?'      =>\$help, 
                      'man'           =>\$man,
                      'n|next_page_skip'       =>\$SKIP_NEXT_PAGES,
		      "f|fields=s"    =>\$FIELD_LIST,
		      "sep=s"         =>\$SEP, 
		      "c|config=s"    =>\$CONFIG_FILE,
		      "s|sourse=s"    =>\$SOURCE,
		 );
#print usage if return value is false (i.e. problem processing options)
if (!($rv))
{
    pod2usage(1)
}
pod2usage(1) if $help;
pod2usage (-exitstatus=>0, -verbose =>2) if $man;

if ($SEP eq '\t')
{
    $SEP = "\t";
}

#======================================================================
# main
#======================================================================


my $logfile;
# not yet used
my $logfh =getOutFH($logfile);

# get dismax hash from yaml file


my $hashref={};
my $count=0;

my $query_count={};
my $buffer=[];  # array of lines to output in order
my $ip_count={};

my $flags ={};


my @fields;
if ($FIELD_LIST ne '')
{
    @fields=split(/\s+/,$FIELD_LIST);
}
else
{

    @fields= qw(lid session date time ip numfound query advanced has_facets has_dates  facet facet_lang facet_format   start pdate_start pdate_end yop q1 q2 q3 q4 field1 field2 field3 field4 cgi pn sz qtime all_facets url);
}

# Dec 192019
#@fields = qw(lid query qtime numfound cgi ip);
#79.110.72.175 35ddd02b573f555869609d3e39d3763d 24366 00:00:34
#Dec 20 2019

@fields = qw(ip session time  query  );
# Aug 14, 2019
# standard fields plus realstart and time
#@fields = qw( lid url  qtime numfound realStart realStart_timestamp);

#@fields = qw( lid url  qtime numfound);
#@fields = qw( lid  qtime  time timestamp_ms_date timestamp_ms_time);
# Aug6 2019  Standard format for input to solr_tester2.pl
#@fields = qw( lid url  qtime numfound);


# Aug 1 testing real starting time
#@fields = qw( lid realStart time qtime timestamp_ms_time AB rows);

# July 23, 2019 for Ryan
#@fields=qw(lid url qtime numfound); # cgi timestamp_ms AB)
#@fields=qw(timestamp_ms_time cgi );
#@fields=qw(lid url qtime numfound AB rows pid session );

# Nov 12, 2018
#@fields= qw(lid session date time ip );
# nov 12 2018 again for qtimes
#@fields= qw(qtime numfound lid date time ip);
# nov 28 2018
#@fields= qw(qtime numfound lid date time ip query cgi);
# dec 11
#@fields= qw(lid url cgi);



#@fields=qw(lid session query numfound cgi);

#@fields=qw(lid session date time ip has_facets facet all_facets facet_lang facet_format);

#@fields=qw(time pid numfound qtime query cgi);

#2017 Aug20
#@fields = qw(lid date time  cgi  qtime url)
# 2017 Aug 29
#@fields = qw(lid date time  cgi  qtime url numfound);
#Oct 26 for query language stuff
#@fields = qw(lid query q1 q2 q3 q4 facet_lang);
my $fields_ref;

# XXX don't know what this is supposed to do but its not working tbw Dec 2018
#($fields_ref,$flags)=check_for_all_facets(\@fields,$flags);
#@fields =@{$fields_ref};			     


print_header(@fields);

my $line_num=0;
my $prev_file="";
my $seen={};

while (<>)
{
    my $current_file =$ARGV;
    if ($current_file ne $prev_file)
    {

	$seen={};
	$line_num=0;
	$prev_file = $current_file;
    }
    $line_num++; # start at 1
    my $lid = get_line_id($SOURCE, $current_file, $line_num);

    chomp;
    my @junk;

    # handle STDIN
    if ($current_file eq "-")
    {
        # reading stdin so assume we used a grep across multiple files
        ($current_file, @junk) = split;
    }
    
    #skip tom's desktop
    next if /$DEV_IP/;
    # skip pilsner queries
    next if  /141\.211\.175\.164/;
    # skip grog queries 
    next if /141\.213\.128\.185/;
    #test if we are reading STDIN and if so assume it might be a grep output and current file is listed before line
    #
    $count++;

    if ($SKIP_ELAPSED)
    {
	next if /\s+elapsed=/;
    }
    
    my $pl = parseLogLine($_, $current_file,$lid,$flags);

    if (!defined($pl))
    {
	print STDERR "Bad log line $lid\n";
	next;
    }
    
    #printHashref($pl);#XXX debug
    
    $pl->{'date'} = getDateFromFilename($current_file);
    $pl->{'linenum'} =$count;
    $pl->{'lid'} = $lid;
    
    
    

    # skip tbw queries already implemented above as $DEV_IP
    #    next if ($pl->{'url'}=/141\.211\.43\.191/);

    # code here to skip rows=0 
    
    #skip extra rows=0 query we generate for counts
    if ($SKIP_RIGHTS_QUERY)
    {
	next if (defined($pl->{'rows'}) && ($pl->{'rows'} eq 0));
    }
    
    # if flag set skip when start not 0 i.e. next page results
    if ($SKIP_NEXT_PAGES ne '')
    {
	print STDERR "skipping next pages\n";
	next if (defined($pl->{'start'}) && ($pl->{'start'} ne 0));
    }
    
 # XXX do we still need the line below?
    $query_count->{$pl->{'date'}}++;
    #($url =~/rows=0/)
    # for debugging  
    #printHashref($pl);
    my $out;
    my $pn=$pl->{'pn'};
    
       
    if (defined($pl->{'query'}) && $pl->{'query'} eq "undef bug")
    {
        print STDERR "undef bug\n";
    }
    else
    {
	#printHashref($pl);
      
	$out =formatFields(\@fields,$pl);
	#XXX temp hack assumes tab separated, need regex that takes SEP argument
	if ($SEP eq "\t"){
	    $out=~s/\|/\t/g;
	}


	# if $FIRST_QUERY_ONLY then only output the first query suppress B query and/or elapsed line
	#test for dupes based on assumpton only 1 pid/session
	# so second entery is unlabled A/B query

	#create key from pid and session
	my $key = $pl->{'pid'} . '-' . $pl->{'session'};

	if (exists($seen->{$key}) && defined($FIRST_QUERY_ONLY))
	{
	    #its a dupe so skip it
	}
	else
	{
	    $seen->{$key}=$out;
	    print "$out\n";
	}
	
    }
    
    if ($count % 10000 eq 0)
    {
        print STDERR "$current_file $count\n";
    }
}
#----------------------------------------------------------------------
sub check_for_all_facets
{
    my $fields = shift;
    my $flags;
    
    my $ALL_FACETS;
    my @out=();
        
    my @all_facets_list = qw (r_facet_authorStr r_facet_bothPublishDateRange r_facet_countryOfPubStr r_facet_format r_facet_htsource r_facet_language r_facet_topicStr);
    
    foreach my $f (@{$fields})
    {
	if ($f =~/all_facets/)
	{
	    $ALL_FACETS = "TRUE";
	    $flags->{'all_facets'}=1;
	}
	else
	{
	    push (@out,$f)
	}
    }

    if ($ALL_FACETS)
    {
	push(@out, @all_facets_list);
	
    }
    return (\@out,$flags);
}
#----------------------------------------------------------------------
sub get_line_id
{
    my $source = shift;
    my $file_name = shift;
    my $line_num = shift;
    my $date=getDateFromFilename($file_name);
    $date=~s/\s+/\-/;
    
    #WARNING   will break when names of app servers change!
    my 	$source_prefix;
    if ($source =~/rootbeer/i)
    {
	$source_prefix='r';
    }
    elsif ($source =~/moxie/i)
    {
	$source_prefix='m';
    }
    elsif ($file_name =~/moxie/i)
    {
	$source_prefix='m';
    }
    elsif ($file_name =~/m_q/i)
    {
	$source_prefix='m';
    }
    elsif ($file_name =~/r_q/i)
    {
	$source_prefix='r';
    }

    elsif ($file_name =~/rootbeer/i)
    {
	$source_prefix='r';
    }
    #ictc
    elsif ($file_name =~/i_q/i)
    {
	$source_prefix='i';
    }
    #macc
    elsif ($file_name =~/m_q/i)
    {
	$source_prefix='m';
    }
    
    else
    {
	#unknown
	$source_prefix ='u';
    }
    
    my $lid= $source_prefix . $date . '-' . $line_num;
    return $lid;
}


#----------------------------------------------------------------------
sub print_header
{
    my @fields = @_;
    #debug print "sep is $SEP\n";
    #XXX TODO : don't hardcode tab or pipe use regex for sep that will work!
    
    my $header;
    
    foreach my $field (@fields)
    {
	$header .= "$field" . $SEP;
    }
    #remove last sep

    if ($SEP eq "\t")
    {
	$header =~s/\t$//;
    }
    else
    {
        $header =~s/\|$//;
    }
    
    print "$header\n";
}


#----------------------------------------------------------------------
sub outputLines{
    my $buffer = shift;
    my $ip_count =shift;
    my $MAX=10;
    my $MIN = 0;
    my $ip;
    
    # print field for ips with count (condition)
    foreach my $line (@{$buffer}){
	my ($date_ip_key,$content)=split(/\t/,$line);
	print "$content\n";
	
	#XXX Make condition explicit and print it to STDERR
	#if ($ip_count->{$date_ip_key} >= $MIN && $ip_count->{$date_ip_key} <= $MAX){
	 #   print "$content\n";
	#}
    }
}


#----------------------------------------------------------------------
sub  saveFields{
    my $date_ip_key = shift;
    my $buffer = shift;
    my $fields = shift;
    my $pl= shift;
        
    my $formatted = formatFields($fields,$pl);
    $formatted = "$date_ip_key\t" . $formatted; 
    push (@{$buffer},$formatted);
	  
}
# 
#----------------------------------------------------------------------

#----------------------------------------------------------------------
#XXX   Needs implementation!
sub sanityCheck
{
    my $entry=shift;
    # confirm same ip for all types
    # confirm query same for q1 and q1
    # confirm apphost/filename same
    return "true";
    
}

#----------------------------------------------------------------------
sub outputQuery 
{
    my $entry = shift;
    my $query   =  $entry->{'q1'}->{'query'};
    print "$query\n";
}
#----------------------------------------------------------------------
sub getAddInfo
{
    my $entry = shift;
    my $q1 =$entry->{'q1'};
    my $q2 =$entry->{'q2'};
    my $e =$entry->{'etime'};
    my $head=$q1->{'head'};
    my $date = $entry->{'q1'}->{'date'};
    my $time=$q1->{'time'};
    my $apphost = $q1->{'apphost'};
    
   # my $head=$q1->{''};
   # my $head=$q1->{''};
    my @add=($date, $time, $apphost, $head);
    return \@add;     
}


#----------------------------------------------------------------------
sub parseLogLine

{
    my $line=shift;
    my $current_file = shift;
    my $lid = shift;
    my $flags = shift;
    
    my $log={};
    my @params;
    my $params;
    my $server;
    my $phash; # parameter hash
    my $junk;
    my $elapsed;
    
    $log = parseFormat($line,$current_file);
    $log->{'lid'} = $lid;
    
    if ( exists($log->{'url'})&&  defined($log->{'url'}))
    {
	$log = handle_query_url($log, $lid,$line);
    }
    elsif( exists($log->{'elapsed'})&&  defined($log->{'elapsed'}))
    {
	# ok its an elapsed line not a url line
    }
    else
    {
	return(undef);
    }
    
    # Need to deal with PID when change gets made to production and 
    #XXX  should have robust way of dealing with previous format!
    
    # clean ip and add bancha/lassi
    if ($log->{'ip'}=~/\:/)
    {
        my ($file,$ip) = split(/\:/,$log->{'ip'});                             
        if ($file =~/moxie/)
        {
            $log->{'apphost'}='MACC';       
        }
        else
        {
            $log->{'apphost'}='ICTC';       
        }
    }

    if (! exists($log->{'lid'}))
    {
	die "no lid in log just before process_cgi\n";
    } 

    
    if (exists($log->{'cgi'}))
    {
	$log = process_cgi($log->{'cgi'},$log,$flags);
    }
    # check for errors move to subroutine later
    if(! $log->{'advanced'}=~/(true|false)/)
    {
	print STDERR "bad value for advanced: $log->{'advanced'}\n\t$line\n";
    } 
    
    return $log;
}


#----------------------------------------------------------------------
# XXX todo: clean up
#  figure out how to  get old formats out from cluttering up logic
#
#----------------------------------------------------------------------
sub parseFormat
{
    my $line = shift;
    my $current_file = shift;
    my $log= {};
    my $junk;
    my $junk2;
    my $elapsed;

#   if ($line=~/^n\d+\s+/){
 #  }
    

    if ($line !~/url=/)
    {
	print STDERR "line ne url\n";
	
	
        #/2010/bancha/q-2010-01-28.log:141.211.175.164 24b7b990d8e595644b30a7836955c9ef 12:11:40 total elapsed=3.56 sec. 
	
        my @fields = split(/\s+/,$line);
        if (scalar (@fields) <3 )
        {
            print STDERR "PROBLEM:$current_file  $line\n";
        }

	# handle elapsed
	if ($line=~/elapsed/)
	{
	    $log = handle_elapsed($line);
	    
	}
	

    }
    

    elsif ($line =~/url=/)
    {
            
        my @fields = split(/\s+/,$line);
	#clean up grep results
	
        if ($fields[2]=~/\d\d\:\d\d\:\d\d/)
        {
            
        #new format around 9-26-09
        ($log->{'ip'},$log->{'session'},$log->{'time'},$log->{'qtime'},$log->{'numfound'},$log->{'url'}) = split(/\s+/,$line);
        }

	elsif ($line =~ /cgi/)
	{
	    # new format added July 31, 2019 get actual starting time app received query
	    if($line=~/realStart/)
	    {
		($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$log->{'qtime'},$log->{'numfound'},$log->{'url'}, $log->{'cgi'}, $log->{'referer'},$log->{'logged_in'},$log->{'timestamp_ms_date'},$log->{'timestamp_ms_time'},$log->{'AB'}, $log->{'realStart'}  ) = split(/\s+/,$line);
		($junk,$log->{'realStart'})=split(/\=/,$log->{'realStart'});
		# add timestamp based on realStart
		$log->{'realStart_timestamp'} = localtime($log->{'realStart'});
						      }
	    
	    elsif ($line=~/timestamp/)
	    {
		#newer format check when we added. As of sometime in 2018 this format has been used
		($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$log->{'qtime'},$log->{'numfound'},$log->{'url'}, $log->{'cgi'}, $log->{'referer'},$log->{'logged_in'},$log->{'timestamp_ms_date'},$log->{'timestamp_ms_time'},$log->{'AB'}) = split(/\s+/,$line);
	    }
	
	
	    else
	    {
		#new format 10-05-2012 included cgi params as url i.e. cgi=http....
		
		($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$log->{'qtime'},$log->{'numfound'},$log->{'url'}, $log->{'cgi'}) = split(/\s+/,$line);
	    }
       	}
	else
        {
            #even newer format around 2010-01-30
            ($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$log->{'qtime'},$log->{'numfound'},$log->{'url'}) = split(/\s+/,$line);
        }
        #fix ip if file name got concatenated as a result of grep
	if (exists($log->{'ip'}) && $log->{'ip'}=~/\:/){
	    my( $junk,$ip)=split(/\:/,$log->{'ip'});
	    $log->{'ip'}=$ip;
	}
    }
    return $log;
}	
#----------------------------------------------------------------------
# we need to capture
# query operator
# parens if more than two rows
# type of search i.e. title/author etc  can we assume first field in dismax is a clue?


sub extractFromDismax
{
    #'0.9'+}+derrida+and+husserl"&foo
    my $query=shift;
    $query=~s/^[\+\s]+//g;# remove leading plus and/or spaces


     
    my $q="undef debug";
    my $nextOp;
    my $toReturn;
    
    my @queries =split(/_query_/,$query);
    
    # find end of dismax by looking for the tie param 
    foreach my $query (@queries)
    {
        next if ($query=~/^\s*$/);
        $nextOp="";

        #urlUnescape escaped quotes
        $query=~s/\%5C\%22/\"/g;
            
        # change escaped quotes to quotes
        $query=~s/\\\"/\"/g;

        
        # detect operator if used advanced form
        if ($query =~/(AND|OR)[\+\s]+$/)
        {
            $nextOp=$1;
        }

        #need to detect type of search i.e. title/author etc from dismax params
        my $firstQF;
        
        if ($query=~/qf=([^\^]+)/)
        {
            $firstQF=$1;
            
        }
        
        
        # extract query from dismax expression
        if ($query =~/tie=\'\d+\.\d+\'\+\}(.+)\"[\s\+]*(AND|OR)*[\s\+]*$/)
        {
            $q=$1;
        }
        $toReturn .= $q; 

        if (defined($nextOp))
        {
            $toReturn .=  " " . $nextOp . " " ;
        }
        

    }
    return $toReturn
}

#----------------------------------------------------------------------
sub getDateFromFilename{
    my $current_filename=shift;
    my $date=$current_filename . "_no_date";
    
    
    if ($current_filename =~/q-20(1[1-9])-(\d+-\d+)/)
    {
        $date = "20" . $1 ." " . $2;
    }
    return $date;
}

#----------------------------------------------------------------------
sub getInFH{
    my $Filename = shift;
    my $in;
    
    if ($Filename)
    {
        open ( $in,'>>',$Filename) or die "couldn't open input file $Filename $!";
    }
    else
    {
        open ( $in,'>-') or die "couldn't open $Filename file STDIN $!";
    }
    return $in;
}
#----------------------------------------------------------------------

sub getOutFH{
    my $Filename = shift;
    
    my $out;
    
    if ($Filename)
    {
        open ( $out,'>>:encoding(UTF-8)',$Filename) or die "couldn't open output file $Filename $!";
    }
    else
    {
        open ( $out,'>-:encoding(UTF-8)') or die "couldn't open output file STDOUT $!";
    }
    return $out;
}

#-------------------------------------------------------------------

sub parseURL
{
    my $url = shift;
    my $hash={};
    my $server;
    my @rest;
    
    ($server,@rest)= split (/\?/,$url);
    $hash->{'params'}=join('?',@rest);
    $hash->{'head'}=getHead($server);
    return $hash;
}
#-------------------------------------------------------------------
sub parseParams
{
    my $params=shift;
    my $phash={};
    # remove empty params
    $params=~s/\&\&/\&/g;
    

    my @params=split(/[&;]/,$params);
    foreach my $p (@params)
    {
        
        my ($key,@rest)=split(/=/,$p);# should check that there is an equals in p or else below gives undef
        my $value=join('=',@rest);
        if (defined ($key))
        {
            $phash->{$key}=$value;
        }
        else
        {
            print STDERR "undefined key for $p\n";
            
        }
        
        #        print "$key $value\n";
    }

    return $phash;
}

#-------------------------------------------------------------------
sub getHead
{
    my $server = shift;
    if ($server =~/serve-([0-9]+)/)
    {
        return $1;
    }
    else
    {
        return "head format unknown";
    }
}
#-------------------------------------------------------------------
sub formatFields
{
    my $fields = shift;
    my $ref=shift;
    my $out;
    
    foreach my $field (@{$fields})
    {
        if (exists ($ref->{$field}))
        {
	    my $temp =$ref->{$field};
	    my $cleaned=$temp;
	    #replace any pipes with  _PIPE_
	    $cleaned=~s/\|/ _PIPE_ /g;
	    #replace tabs with space
	    $cleaned=~s/\t/ /g;
	    
	    if (scalar(@{$fields}) == 1)
	    {
		$out = "$cleaned";
	    }
	    else
	    {
		$out.= "$cleaned\|";
		#$out.= "$ref->{$field}\t";
	    }
	}
        elsif(1)
	{
	    $out .= "NA\|"
	}
	
    }
    #remove last sep
    $out=~s/\|$//;
    return $out;
} 


#-------------------------------------------------------------------
sub ipLocal
{
    my $ip =shift;
    if ($ip=~/141\.211\.43\./)
    {
         return "true";
     }
    else
    {
        return 0;
    }
    
}

#----------------------------------------------------------------------
#    'year' => HASH(0x20681c70)
#      'mm' => '100%'
#      'qf' => ARRAY(0x208e8dd0)
#         0  ARRAY(0x20a1c7e0)
#            0  'publishDateRange'
#            1  25000



#-------------------------------------------------------------------
sub handle_elapsed
{
    my $line = shift;
    my $junk;
    my $junk2;
    my $elapsed;
    my $log ={};
    


    my @fields = split(/\s+/,$line);
    if ($line =~/realStart/)
    {
	# format as of July 31, 2019
	#73.164.175.8 33755f908e874f5f6c30c9445bbd6f07 16472 00:00:19 realStart=1564632016.96491  elapsed=2.54 sec.
    	($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$log->{'realStart'},$elapsed,$junk2) = split(/\s+/,$line);
    }
    # older formats	
    elsif ($fields[2]=~/\d\d\:\d\d\:\d\d/)
    {
	($log->{'ip'},$log->{'session'},$log->{'time'},$junk,$elapsed,$junk2) = split(/\s+/,$line);
    }
    else
    {
	($log->{'ip'},$log->{'session'},$log->{'pid'},$log->{'time'},$junk,$elapsed,$junk2) = split(/\s+/,$line);
    }
    if (exists($log->{'realStart'})){
	($junk,$log->{'realStart'})=split(/\=/,$log->{'realStart'});
    }
    if (exists($log->{'elapsed'}))
    {
	($junk,$log->{'elapsed'})=split(/\=/,$elapsed);
	#convert to milliseconds
	$log->{'elapsed'}=int($log->{'elapsed'} * 1000);
    }
    
    return ($log);
    
}
#-------------------------------------------------------------------
sub printHashref
{
    my $ref=shift;
    foreach my $key (sort (keys %{$ref}))
    {
        print "$key\t$ref->{$key}\n"
    }
    print "\n---\n";
    
} 


#-------------------------------------------------------------------
sub handle_query_url
{
    my $log = shift;
    my $lid = shift;
    my $line = shift;
    my $junk;
    
    my $hashref = parseURL($log->{'url'});
    my $phash=parseParams($hashref->{'params'});
    my $query = $phash->{'q'};
    if (! defined ($query))
    {
	$query="undef bug";
	print "undef_bug lid $lid \n $line\n";
	#	exit;
	
    }
    
    if ($query =~/_query_/)
    {
	$query = extractFromDismax($query);
    }
    
    $log->{'query'}= normalizeQuery($query);
    $log->{'head'} = $hashref->{'head'};
    $log->{'start'} = $phash->{'start'};
    $log->{'rows'} =  $phash->{'rows'};
    #XXX why not just store phash on $log
    # better yet lets make a logentry object!
    
    
    # fix qtime
    my $qtime;
    ($junk,$qtime)=split(/\=/,$log->{'qtime'});
    $log->{'qtime'}= int(1000 * $qtime);  #convert back to milliseconds
    
    #fix numfound
    ($junk,$log->{'numfound'})=split(/\=/,$log->{'numfound'});
    
    return ($log);
    
}
  
#-------------------------------------------------------------------

__END__

=head1 SYNOPSIS

parseQuerylogs.pl [options] 

    processlog.pl -s



processlog.pl --man    Full manual page

=head1 Options:

=over 8

=item B<-s,--skip_next>  

skip next page queries i.e start > 0


=item B<-h,--help>

Prints this help


=item B<--version>

Prints version and exits.

=back

=head1 DESCRIPTION

B<This program reads a specified query log and produces tab delimited output with "na" for missing values>

=head1 ENVIRONMENT

=cut

__DATA__
# ip range list from Cory
# 141.211.43.128/25
#  141.211.86.128/25
#  141.211.168.128/26
#  141.211.173.64/28
#  141.211.173.80
#  141.211.173.81
#  141.211.173.83
#  141.211.173.85
#  141.211.173.88
#  141.211.173.113
#  141.211.173.212
#  141.213.128.128/25
