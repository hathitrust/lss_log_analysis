#
# parseClicklog.pl
# $Id: parseClicklog.pl,v 1.6 2020/04/02 17:43:16 tburtonw Exp tburtonw $
#

use JSON::XS;
use URI::Escape;
use Encode;
#require "process_cgi.pl";
#2020
require "/htapps/tburtonw.babel/analysis/bin/process_cgi.pl";


#XXX are these needed?
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';



# do we want to delete the hash and then put back into json?
# set this to the default "sz" param in effect when the log was written.  See default_records_per_page in ls/lib/Config/global.conf
my $DEFAULT_SZ = 20;

my $SKIP_ID_LIST = "true";
my $SKIP_ACCEPT = "true";
my $convert_URL_to_utf8 ="true";
my $error_file ="click_errors";
my $date_str=`date +"%m-%d-%Y"`;
$date_str =~s/\n//;
$error_file .=  '-'. $date_str;

#my $debug='X' . $error_file . 'X'. $date_str . 'X';

print STDERR "error file is $error_file\n";



my $FH;
      open ( $FH,'>>',$error_file) or die "couldn't open output file $error_file $!";

my $count=0;

my $line_num=0;
my $prev_file="";

while (<>)
{

    my $current_file =$ARGV;
    if ($current_file ne $prev_file)
    {
	print STDERR  "$line_num lines proccessed for $prev_file\n";
	
	$line_num=0;
	$prev_file = $current_file;
    }
    $line_num++; # start at 1

    next if /^\s*$/;
    chomp;
    $count++;
    my $in = $_;
    #
    my $json = clean_json($in);
    my $parsed=parse_json($json);
    my $global = $parsed->{'global'};
    my $item   = $parsed->{'item'};
    
    my $date = get_date_from_timestamp($global->{'timestamp'});
    my $SOURCE = '';  #XXX replace this with getopts long to be able to specify source
    my $lid = get_line_id($SOURCE, $current_file, $line_num,$date);
    #XXX check this or else just print it out
    output("lid", $lid);

    # get rank on page for item
    my $rank_on_page;
    if (exists( $item->{'rank_on_page'}) && defined($item->{'rank_on_page'}))
    {
	$rank_on_page = $item->{'rank_on_page'};
    }
	       
						  
    process_item($item);
    process_global($lid,$global, $rank_on_page);
    print "\n";
    
}
print STDERR "$count records processed\n";
close($FH);


#----------------------------------------------------------------------
sub  get_date_from_timestamp
{
    #2016-05-01 00:00:17
    my $timestamp = shift;
    my ($date,$time) = split(/\s+/,$timestamp);
    return $date;
}
#----------------------------------------------------------------------

sub get_line_id
{
    my $source = shift;
    my $file_name = shift;
    my $line_num = shift;
    my $date = shift;
    $file_name=`basename $file_name`;
    
    
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
    elsif ($file_name =~/^m/i)
    {
	$source_prefix='m';
    }

    elsif ($file_name =~/rootbeer/i)
    {
	$source_prefix='r';
    }
    elsif ($file_name =~/^r/i)
    {
	$source_prefix='r';
    }

    my $lid= $source_prefix .'_' . $date . '-' . $line_num;
       
    return $lid;
    
}
    
#----------------------------------------------------------------------
sub clean_json
{
    my $in = shift;
    # remove double escaped quotes ie \\"
    $in =~s/\\\\\"//g;
    #replace tabs with a space or two
    $in=~s/\t/ /g;
    #remove escaped space
    
    $in=~s/\\\s+/ /g;

    #following two work together 
    # remove beginning facet quote need all facet names here!
  #  $in =~s/facet=([^\:]+)\:\"/facet=$1\:/g;
    #XXX rule below probably needs to be specific to facet entry
    #replace double double quotes not preceeded by an escape with single double quote
   # $in =~s/(facet[^\"\\]+)\"\"/$1\"/g;
    return ($in);
}

#----------------------------------------------------------------------
sub process_item
{
    my $hashref= shift;
        
   # print "\n--\nITEM DATA:\n$hashref->{'id'}\n";
    # clean up data missing click_type
    my $CLICK_TYPE;
    my $count=0;    
    foreach my $key (sort (keys %{$hashref}))
    {

	if ($key eq 'click_type')
	{
	    $CLICK_TYPE = $hashref->{$key};
	}
	output($key,$hashref->{$key});
	$count++;
    }
    if (!defined($CLICK_TYPE)&& $count > 1)
    {
	$hashref->{'click_type'} = 'click';
	$key='click_type';
	output($key,$hashref->{$key});
    }
    
}
#----------------------------------------------------------------------
sub process_global
{
    my $lid = shift;
    my $global = shift;
    my $rank_on_page = shift;
    
    #print "\n---\nGLOBAL DATA\n";
    my $seen={};
    
    
    foreach my $key (sort (keys %{$global}))
    {
	my $value;
	$seen->{$key}++;
		
	if ($SKIP_ID_LIST && $key =~/._rs/)
	{
	    #skip outputting the id lists for each result set
	}
	elsif ($SKIP_ACCEPT && $key=~/accept/)
	{
	    
	}
	
	else
	{
	    if ($convert_URL_to_utf8)
	    {
		if ($key eq 'cgi' || $key eq 'referer')
		{
		    my $temp  = $global->{$key};
		    $value = uri_unescape($temp);
		}
	    }
	    if (!defined($value))
	    {
		$value=$global->{$key}
	    }
	    
	    # fix type=intl to test_type=intl
	    if ($key eq 'type' && $global->{$key} eq 'intl')
	    {
		$key = 'test_type';
		$value = 'intl';
		output($key, $value);
	    }
	    else
	    {
		output($key, $value);
	    }
		
	}
    }
    # fix missing user agent
    if (!exists($global->{'user_agent'}))
    {
	$key= 'user_agent';
	$value='NA';
	output($key, $value);
    }
#    print "\n";
    #process cgi
    my $cgi_hash={};
    $cgi_hash->{'lid'}=$lid;
    $cgi_hash = process_cgi($global->{'cgi'}, $cgi_hash);
    #2020 add absolute rank XXX check off by one errors
    my $abs_rank = get_abs_rank($DEFAULT_SZ,$rank_on_page,$cgi_hash);
    $cgi_hash->{'abs_rank'} = $abs_rank;
    
    foreach my $key (sort (keys %{$cgi_hash}))
    {
	my $value=$cgi_hash->{$key};
	output($key,$value);
    }
    
			     
			     
		
}	
#----------------------------------------------------------------------
sub get_abs_rank
{
    my $DEBUG; # ="true";
    my $DEFAULT_SZ = shift;
    my $rank_on_page = shift;
    my $cgi_hash = shift;
    #defaults if no cgi params present
    my $pn = 1 ;
    my $sz = $DEFAULT_SZ;

    
    if (exists ($cgi_hash->{'pn'}) &&  defined ($cgi_hash->{'pn'}) )
    {
	$pn  = $cgi_hash->{'pn'};
    }
    
    if (exists ($cgi_hash->{'sz'}) && defined ($cgi_hash->{'sz'}))
    {
	$sz = $cgi_hash->{'sz'};
    }
    # offset for page starts at pn -1 times sz  i.e. if size =20 and pn =3 the page starts at 40, 
    my $offset  = (($pn -1) * $sz);
    my $abs_rank = $rank_on_page + $offset;

    if ($DEBUG){
	print "\n===========DEBUG=====\n size= $sz, pn = $pn, rank_on_page = $rank_on_page, offset = $offset, abs_rank = $abs_rank\n";
	
    }
    
    
    return $abs_rank;
    
}

#----------------------------------------------------------------------
sub output
{
    # need to determine what kind of data structure we have
    # its either just plain key/value or key/arrary ref
    my $key= shift;
    my $value=shift;
    
    if (ref($value) eq 'ARRAY')
    {
	my $i=0;
	
	foreach my $el (@{$value})
	{
	    $i++;
	    print "should not be array\n" ;#$i\t$el\n";
	}
    }
    else
    {
	#print "$key\t$value\n";
	print "$key\t$value\|";
    }
}    

#----------------------------------------------------------------------
sub parse_json
{
    my $json = shift;
    #XXX check re allow_non_ref
    my $coder = JSON::XS->new->utf8->pretty->allow_nonref;

    my $parsed;
    eval
    {    
	$parsed = $coder->decode ($json)
    };
    
    if ( $@ )
    {
	print STDERR "json xs error $@ \n";
	print $FH "json xs error $@ \n$json\n\n";

    }
    
    return $parsed;
}
#----------------------------------------------------------------------


