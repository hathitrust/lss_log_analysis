# parseRogerLogs.pl
#$ID$#

#
use JSON::XS;
use CGI;
use URI::URL;

#XXX TODO:
# replace parsing of fields with simple json parsing!

my $PREFIX_URL_FIELDS;
my $PREFIX_REFERER_FIELDS = 'true';
my $blank_count=0;
my $refer_count = 0;

my $fields_wanted = get_fields_wanted();
#set to true to use robots_file to filter out ips in that list
my $FILTER_ROBOTS = "false"; #TRUE";
my $robots_file ="/htapps/tburtonw.babel/analysis/reports/UMSI2018_Robots/all_robots.anon";
   $robots_file ="/htapps/tburtonw.babel/analysis/reports/UMSI2018_Robots/all_robots";
my $robots = get_robots($robots_file);

my $keys ={};

my $i =0;

my $line_num=0;
my $prev_file="";
my $seen={};
my $SOURCE='';
my $file_count=0;
my $errors =[];

#XXX need to fix this to be able to change field sep from tab
output_header($fields_wanted);

my $coder = JSON::XS->new->utf8->pretty->allow_nonref;
   

while (<>)
{
    my $current_file =$ARGV;
    if ($current_file ne $prev_file)
    {

	$seen={};
	$line_num=0;
	$prev_file = $current_file;
	$file_count++ ;
	if ($file_count % 10 ==0)
	{
	    print STDERR "processing $current_file file count $file_count\n";
	}
	
    }
    
    $line_num++; # start at 1
    my $lid = get_line_id($SOURCE, $current_file, $line_num);
    chomp;

    my $hash;
    
    ($hash,$errors) = get_fields_json($lid,$_);
    next if $hash=~/bad json/;
    
    output_fields($hash, $fields_wanted);
    
    
     $i++;
     if ($i % 10000 == 0)
     {
     	print STDERR "$i\n";
    }
}
print STDERR "$i\n";
#
output_errors ($errors);


#----------------------------------------------------------------------
sub get_fields_json
{
    my $lid = shift;
    my $line =shift;

    my ($parsed, $errors)= parse_JSON($coder,$lid,\$line,$errors);
    if ($parsed =~/bad json/)
    {
	return $parsed;
    }
    
    my $hash = {};
    
    $hash->{'lid'}=$lid;    
    $hash->{'ip'} = $parsed->{'remote_addr'};
    my $ip = $hash->{'ip'};
    
    #Filter known robots
    if ($FILTER_ROBOTS eq "TRUE"){
	next if ($robots->{$ip} ==1);
    }
    
    # check user agent for robot type
    $hash->{'user-agent'} = $parsed->{'user_agent'};
    my $ua = $hash->{'user-agent'};
    if ($ua =~/bot|crawl/i)
    {
	$hash->{'maybe_robot'}="TRUE";
    }
    else
    {
	$hash->{'maybe_robot'}="NA";
    }
    
    
    
    $hash->{'session'} = $parsed->{'session'};
    $hash->{'pid'} = 'NA';
    $hash->{'timestamp'} = $parsed->{'datetime'};
    $hash->{'url'} = $parsed->{'request_uri'};
    $hash->{'referer'} = $parsed->{'http_referer'};
    
    $hash->{'date'} = my $date=getDateFromFilename($current_file);
    # TODO: use perl and get date from the json datetime field
    
    #XXX New stuff with Rogers new fields
    $hash->{'user-agent'} = $parsed->{'user_agent'};

    my $parsed_url     = parse_url($hash->{'url'});
    my $parsed_referer = parse_referer ($hash);#foobar
    #put parsed stuff above into hash so we have everything in hash with a key
    $hash = stuff_hash($hash, $parsed_url, 'url');
    $hash = stuff_hash($hash, $parsed_referer, 'ref');

    foreach my $field (@{$fields_wanted})
    {
	if (exists($parsed->{$field}))
	{
	    $hash->{$field} = $parsed->{$field};
	}
	    
    }
    

    
    return ($hash,$errors);
	
}

#----------------------------------------------------------------------
sub count_keys
{
    my $hash = shift;
    my $keys = shift;
    foreach my $key (keys %{$hash})
    {
	$keys->{$key}++;
    }
    return $keys;
}

#----------------------------------------------------------------------
sub output_header
{
    my $fields = shift;
    my $out = join("\t",@{$fields});
    print  "$out\n";
}

#----------------------------------------------------------------------
sub stuff_hash
{
    my $hash         = shift;
    my $parsed_stuff = shift;
    my $stuff_type   = shift;
    
    foreach my $key (keys %{$parsed_stuff})
    {

	my $new_key;
	if (defined($PREFIX_URL_FIELDS))
	{
	    $new_key = $stuff_type . '_' . $key;
	     $hash->{$new_key} = $parsed_stuff->{$key};
	}
	elsif (defined($PREFIX_REFERER_FIELDS) && $stuff_type eq'ref')
	{
	    $new_key = $stuff_type . '_' . $key;
	     $hash->{$new_key} = $parsed_stuff->{$key};
	}
 
	else
	{
	    # # if key name already in hash qualify it
	    if (exists($hash->{$key})) #XXX check this is right
	    {
		$new_key = $stuff_type . '_' . $key;
		$hash->{$new_key} = $parsed_stuff->{$key};
	    }
	    else
	    {
		$hash->{$key} = $parsed_stuff->{$key};
	    }
	}
    }
    return $hash;
}

#----------------------------------------------------------------------
sub parse_referer
{
    my $hash = shift;
    my $referer = $hash->{'referer'};
    my $parsed ={};
        
    if (!defined($referer))
    {
	$parsed->{'error'}= "Missing referer";
	return $parsed;
    }
    else
    {
	if ($referer !~/http/)
	{
	    $parsed->{'error'}= "NOHTTP $referer";
	}
	else
	{
	    my $host = get_host($hash);
	    
	    
		$parsed->{'hostname'} = $host;
	    
	    if ($host=~/babel\.hathitrust/)
	    {
		$parsed->{'HT'}="true";
		
		if ($referer=~/cgi\/([^\?]+)\?/)
		{
		    $parsed->{'HTAPP'} = "$1";
		}
	    }
	    else
	    {
		$parsed->{'HT'} ="false";
	    }
	}

	# don't do this because unknown number of fields
	# later programs can do this
	# if ($referer =~/\?/)
	# {
	#     $parsed_referer=parse_url($referer);
	#     #copy stuff to $parsed
	#     # XXX this is inefficient and we need better name
	#     foreach my $key (%{$parsed_referer}) {
	# 	$parsed->{$key} = $parsed_referer->{$key};
	#     }
	# }
    }
    return $parsed;
   }
    
    
#----------------------------------------------------------------------
sub output_fields
{
    my $hash   = shift;
    my $fields_wanted = shift;
    my @out;

    #print_keys($hash);
    #return;
    my $value;
    
    foreach my $field (@{$fields_wanted})
    {
	$value = $hash->{$field};
	if (!defined($value) || $value =~/^\s+$/)
	{
	    $value = 'NA';
	}
	push(@out, $value);
    }
    my $out = join("\t",@out);
    print "$out\n";
}

#----------------------------------------------------------------------
sub get_fields_wanted
{

    #XXX hack
    #Note is_partial, mode, seq,  content_length are unique to the downloads file

    # put generic fields we want from all files
    # list what we want from pt files and imgserv_download
    # do pt logs roger contain searches?
    
#    my @fields = ('session','ip','maybe_robot','timestamp','app','id','ic','remote_user_processed','sdrinst', 'role','seq' ,  'is_partial', 'content_length','mode','size','request_uri','referer');
    

    
#    my @img_download_fields = ('session','ip','maybe_robot','timestamp', 'is_partial', 'content_length','mode','size','Id','request_uri');
 #   my @fields=@img_download_fields;

    my @fields = ('maybe_robot','session');

    
    return \@fields;
    #X end hack
    my @fields = (
		  'id',
		  'lid',
		  'ip',
		  'session',
		  'pid',
		  'timestamp',
		  'date',
		  'url',
		  'referer',
		  'logged_in',
		  # referer fields
		  'ref_error',
		  'ref_hostname',
		  'ref_HT',
		  'ref_HTAPP'

		 );

    my @url_fields = (
		  "a",  "debug", "host", "index", "num",
		  "orient", "page", "ptsop", "q1", "seq", "size", "skin", "start",
		  "sz", "u", "ui", "url", "view" 
		     );
    #XXX width  "attr",occurs infrequently

    #
    if (defined($PREFIX_URL_FIELDS))
    {
	
	my $prefixed_field;
	foreach my $field (@url_fields)
	{
	    $prefixed_field = 'url_' . $field;
	    push (@fields, $prefixed_field);
	}
    }
    else
    {
	@fields=(@fields,@url_fields);
    }
    #XXX
   # @fields=(id, ip);
    
    return \@fields;
}

#

#
#----------------------------------------------------------------------

sub extract_data_from_url
{
    my $hash =shift;
    my $url = $hash->{'url'};
    my $url_ref=parse_url($url);
}

sub parse_url
{
    my $url = shift;
    my $hashref={};
    
    my ($h,$rest)=split(/\?/,$url);
    my @fields=split(/[\&\;]/,$rest);
    
    foreach my $field (@fields)
    {
        my ($key,$value)=split(/\=/,$field);
        $hashref->{$key}=$value;
    }
    $hashref->{'host'}=$h;
    return $hashref;

}

sub parse_cgi
{
    my $url = shift;
    my $temp_cgi = CGI::new($url);
    my $host= $temp_cgi->url(-base=>1);
    my $path= $temp_cgi->url(-path_info=>1);
    print "host=$host\n";
    print "path=$path\n";
    
}


# 0       133.209.44.239
# 1       87f780c94febe32d533817830fcdba0a
# 2       18280
# 3       00:00:00
# 4       http://babel.hathitrust.org/cgi/pt?id=uc2.ark%3A%2F13960%2Ft6d21tc03;view=1up;seq=10;a=-;page=root;size=100
# 5       referer=http://babel.hathitrust.org/cgi/pt?id=uc2.ark:/13960/t6d21tc03;view=1up;seq=9
# 6       logged_in=NO

sub print_hash
{
    my $hash = shift;
    foreach my $key (sort(keys %{$hash}))
    {
	print "$key\t$hash->{$key}\n";
	
    }

}

sub print_keys
{
    my $hash = shift;
    foreach my $key (sort(keys %{$hash}))
    {
	print "$key\n";
	
    }

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
    elsif ($file_name =~/m_[qp]t*/i)
    {
	$source_prefix='m';
    }
    elsif ($file_name =~/r_[qp]t*/i)
    {
	$source_prefix='r';
    }

    elsif ($file_name =~/rootbeer/i)
    {
	$source_prefix='r';
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
sub getDateFromFilename{
    my $current_filename=shift;
    my $date=$current_filename . "_no_date";
    
    
    if ($current_filename =~/.*pt-20(1[1-9])-(\d+-\d+)/)
    {
        $date = "20" . $1 ." " . $2;
    }
    return $date;
}


#----------------------------------------------------------------------

#----------------------------------------------------------------------
#----------------------------------------------------------------------
sub get_robots
{
    my $robots_file = shift;
    my $hash ={};
    
    open ( $fh,'<',$robots_file) or die "couldn't open input file $robots_file $!";

    while(<$fh>)
    {
	chomp;
	my ($anon_ip,$name) = split(/\t/,$_);
	$hash->{$anon_ip} = 1;
    }
    return $hash;
}

#----------------------------------------------------------------------
sub get_host
{
    my $hash = shift;
    my $referer =$hash->{'referer'};
    my $host;
    
    #my $url = new URI::URL $referer;
    #XXX this method doesn seem to work with URI::URL but maybe with plain URI?
	    #Can't locate object method "host" via package "URI::_generic" at /usr/share/perl5/URI/WithBase.pm line 52

    eval
    {
	my $url = new URI::URL $referer;
        $host = $url->host;
    };
    
    if ($@ ne '')
    {
	print "ERROR $@\t$hash->{'lid'}\t$referer\n";
    }
    else
    {
	return $host;
    }
    
}

#----------------------------------------------------------------------
sub parse_JSON
{   
    my $coder = shift;
    my $lid = shift;
    my $ref = shift;
    my $errors = shift;
    

    # Warning json won't escape xml entities such as "&" ">" etc.
    #XXX reread docs should we instantiate a new coder for each line?
    
    #XXX wrap this in an eval and report offending file and line if there is an issue
    my $parsed;
    
    eval {
	$parsed = $coder->decode ($$ref);
    };
    
    if ($@) {
	print STDERR "lid $lid json error\n\n---\n$$ref\n";
	$parsed="bad json";
	push (@{$errors},$lid);
    }
    
    return $parsed,$errors;
    
}
#----------------------------------------------------------------------
sub output_errors
{
    my $errors = shift;
    my $total = scalar(@{$errors});
    print "$total json parsing errors\n========\n";
    foreach my $lid (@{$errors})
    {
	print "$lid\n";
    }
}

