# parseNewPT.pl
#$ID$#
# parses pt-201[567] logs not query logs or access logs
#
use CGI;
use URI::URL;

my $PREFIX_URL_FIELDS;  #="true";
my $PREFIX_REFERER_FIELDS = "true";

my $blank_count=0;
my $refer_count = 0;

my $fields_wanted = get_fields_wanted();
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

#XXX need to fix this to be able to change field sep from tab
output_header($fields_wanted);

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

    my @fields=split;
    my $hash={};
    $hash->{'lid'}=$lid;    
    $hash->{'ip'} = $fields[0];
    my $ip = $hash->{'ip'};
    
    #Filter known robots
    next if ($robots->{$ip} ==1);
        
    $hash->{'session'} = $fields[1];
    $hash->{'pid'} = $fields[2];
    $hash->{'timestamp'} = $fields[3];
    $hash->{'url'} = $fields[4];
    $hash->{'referer'} = clean_referer($fields[5]);
    #XXX temp hack for speed when just getting sessions with ls referer
    # if ($hash->{'referer'} =~/cgi\/ls/){
    # 	output_fields($hash, $fields_wanted);
    # }
    # else
    # {
    # 	next;
	
    # }
    #XXX temp hack for speed when just getting sessions with ls referer
    


    ($junk,$hash->{'logged_in'}) = split(/\=/,$fields[6]);
    $hash->{'date'} = my $date=getDateFromFilename($current_file);
   
    
    my $parsed_url     = parse_url($hash->{'url'});
    my $parsed_referer = parse_referer ($hash);#foobar
    #put parsed stuff above into hash so we have everything in hash with a key
    $hash = stuff_hash($hash, $parsed_url, 'url');
    $hash = stuff_hash($hash, $parsed_referer, 'ref');


    
#    $keys = count_keys($hash,$keys);
    # TODO: allow different field separator than a tab
    output_fields($hash, $fields_wanted);
    
    
				     

    #Move this special processing stuff somewhere
    #print stuff for non-blank referers
    #  my $r = $hash->{'referer'};
    
    #  if ($r !~/^\s*$/)
    #  {
    # 	 $refer_count++;
	 
    # 	# print "$r\n";
    #  }
    # else
    # {
    # 	$blank_count++;
    # }
    
#   print "$hash->{'session'}\n";
    
     # print "\n===\n";
    #print_hash($hash);
 #  print "$hash->{'url'}\n";
#   $t = parse_url($hash->{'url'});
   # print "$hash->{'timestamp'}\t$t->{'id'}\t$t->{'seq'}\n"
    
   # print "$hash->{'ip'}\t$hash->{'timestamp'}\t$t->{'id'}\t$t->{'seq'}\n";
   # print "\n--\nurl keys\n";
 #   print_keys($t);
    
#    print_hash($t);
#    print "$hash->{'referer'}$hash->{'ip'}\t$t->{'id'}\n";
#    print "$hash->{'referer'}\nprocess_referer says: ";
#    process_referer($hash->{'referer'});
 #   print "$hash->{'ip'}\n";
     $i++;
     if ($i % 10000 == 0)
     {
     	print STDERR "$i\n";
#	print_hash($keys);
#	$keys ={};
	
	# 	#redo to just print name of of files?
     }
    
    
}
print STDERR "$i\n";
#print_hash($keys);



#print "Count of keys\n";
#print_hash($keys);
# print "blank referer count = $blank_count\n";
# print "non blank count  = $refer_count\n";
# my $percent = 100 *($refer_count/($blank_count + $refer_count));
# print "percent non-blank = $percent\n";

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
	my $PREFIX;

	if (defined($PREFIX_URL_FIELDS) && $stuff_type eq "url"){
	    $PREFIX = "TRUE";
	}
	if (defined($PREFIX_REFERER_FIELDS) && $stuff_type eq "ref"){
	    $PREFIX = "TRUE";
	}
	
	
	if (defined($PREFIX))
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
    #my @fields = ('url');
    #return \@fields;
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



# XXX This needs to return values instead of printing!

sub process_referer
{
    die "process_referer should not be used without being rewritten";
    my $hash = shift;
    
    my $referer = $hash->{'referer'};
    my $filtered_ref = filter_referer($referer);

    
    if ($filtered_ref)
    {
	if ($filtered_ref !~/http/)
	{
	    print "NOHTTP $filtered_ref\n";
	}
	else
	{
	    
	    my $host = get_host($hash);
	    
	    if ($host=~/babel\.hathitrust/)
	    {
		if ($filtered_ref=~/cgi\/([^\?]+)\?/)
		{
		#    print "$host-$1\n";
		    
		}
		else
		{
		 #   print "$filtered_ref\n";
		}
		
	    }
	    else
	    { 
		    print "$host\n";
	    }
	    
	}
	
	
	if ($filtered_ref =~/\?/)
	{
	    #print "\n--\n$filtered_ref\n--\n";
	    $parsed_referer=parse_url($filtered_ref);
	#    print "$parsed_referer->{'host'}\n";
	    #print_hash($parsed_referer);
	}
	else
	{
#	    print "$filtered_ref\n";
	}
	
    }
}

#----------------------------------------------------------------------
sub filter_referer
{
    my $r = shift;
    #XXX WARNING currently no filtering happening
    return($r);

    my $TO_RETURN;
    
    
    
    if ($r=~/babel/)
    {
    }
    elsif($r=~/catalog\.hathitrust/)
    {
    }
    else
    {
	$TO_RETURN=$r;
    }
    
    return $TO_RETURN;
}


sub clean_referer
{
    my $r =shift;
    $r=~s/referer=//g;
    return $r;
}


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
