#----------------------------------------------------------------------
# $Id: process_cgi.pl,v 1.4 2020/04/03 16:41:26 tburtonw Exp tburtonw $
#----------------------------------------------------------------------
sub process_cgi
{
    my $cgi   = shift;
    my $log   = shift;
    my $flags = shift;

    if (! exists($log->{'lid'}))
    {
	die "no lid in log for sub process_cgi\n";
    } 
    my $parsed_cgi = parse_cgi($cgi);

    my $pn =$parsed_cgi->{'pn'};
    $log->{'pn'}=$pn;

    my $sz;
    if (exists($parsed_cgi->{'sz'}))
    {
	$sz = $parsed_cgi->{'sz'};
	$log->{'sz'}=$sz;
    }
    
    #get adv search and facets info

    my $p = $parsed_cgi;
    #boolean features
    foreach my $feature ('has_facets','has_dates')
    {
	$log->{$feature}="false";
    }
    
    if (exists ($p->{'facet'})||exists ($p->{'facet_format'})||exists ($p->{'facet_lang'}))
    {
	$log->{'has_facets'}="true";
	$log = parseFacets($p,$log,$flags);
	
    }
    if (exists ($p->{'pdate_start'}) || exists ($p->{'pdate_end'}))
    {
	$log->{'has_dates'}="true";	
	$log =parseDateQ($p,$log);
    }
    if (exists ($p->{'lmt'}))
    {
	$log->{'limit'}= $p->{'lmt'};
    }
    #set default to log advanced = false
    $log->{'advanced'}='false';
    my $ADV ='false';
    my $field_count=0;
    my $field;
    
    # The checks below triggers advanced search flag if there is field greater than 1
    # this code triggers advanced search flag if there is an anyall1 param or
    # if field1 is not ocr (the default).
   
    if (exists($p->{'anyall1'}))
    {
     	$ADV='true';
     	$log->{advanced} = 'true';
    }
    elsif  (exists($p->{'q1'}) &&  exists($p->{'field1'}) && $p->{'field1'} ne 'ocr')
    
    {
      	$ADV='true';
      	$log->{advanced} = 'true';
    }
    
    for my $field_num (1..4){
	$field='field' . $field_num;
	my $query='q' . $field_num;
	my $anyall='anyall' . $field_num;
	
	#	my $op =  'op' . $field_num;  # we only have ops 1-3 since they are between q1-4
	#	my $anyall = 'anyall . $field_num;
	
	if (exists($p->{$field}))
	{
	    #XXX what about an advanced search that uses field1?
	    if ($field_num > 1){
		$ADV='true';
		$log->{advanced} = 'true';
	    }
	    
	    #  only count the field if the corresponding query is populated!
	    if (exists($p->{$query}))
	    {
		$log->{$query} = normalizeQuery($p->{$query});
		$log->{$field}=$p->{$field};
		if (exists($p->{$anyall}))
		{
		    $log->{$anyall}= $p->{$anyall};
		}
		$field_count++;
	    }
	}
    }
    $log->{field_count} = $field_count;
    # logic for grapping op
    # # if there is a query one or two and 3 or 4 then the op3 is actually doing something
     if  (
	  exists($p->{'op3'})
	  &&
	  (exists($p->{'q1'}) ||exists($p->{'q2'})) 
	  && 
	  (exists($p->{'q3'}) ||exists($p->{'q4'}))
     	)
     {
	 $log->{'op3'} =$p->{'op3'};
     }
    
     if	 (exists($p->{'op2'}) && exists($p->{'q1'})&& exists($p->{'q2'})) 
     {
     	$log->{'op2'} =$p->{'op2'};
     }
     if (exists($p->{'op4'}) && exists($p->{'q3'})&& exists($p->{'q4'})) 
     {
     	$log->{'op4'} =$p->{'op4'};
     }
    
    return $log;
}


#----------------------------------------------------------------------

sub parse_cgi
{
    my $cgi = shift;
    my $phash={};
    
    
    # XXX do we use cgi.pm to parse or hand-parse?
    my ($host,@rest)=split(/\?/,$cgi);
    my $rest=join('?',@rest);
    my @params=split(/[\;\&]/,$rest);
    foreach my $par (@params)
    {
	my ($key,$value)=split(/\=/,$par);
	if (exists($phash->{$key}))
	{
	    #concatenate repeating vlaues like facet=foo&facet=bar
	    #$phash->{$key}.= " " . $value; #XXX will this break anything
	       $phash->{$key}.= "\|" . $value;
	}
	else
	{
	    $phash->{$key}=$value;
	}
	
    }
    return $phash;
}
#----------------------------------------------------------------------
#  sub parseFacets
# 'facet' => 'topicStr%3A%22United%20States%22'
#   'facet_lang' => 'language%3AEnglish'
#
#
sub parseFacets
{
    my $p = shift;
    my $log = shift;
    my $flags = shift;
    
    # check for pseudo-facets (these are multi-select
    if (exists ($p->{'facet_lang'}))
    {
	my $lang=$p->{'facet_lang'};
	$lang=~s/\%3A/\:/g;
	$log->{'facet_language'}= $lang;
    }
    if (exists ($p->{'facet_format'}))
    {
	my $f = $p->{'facet_format'};
	$f=~s/\%3A/\:/g;
	$log->{'facet_format'}= $f;
    }
    if (exists ($p->{'facet'}))
    {
	$log->{'facet'} = normalizeQuery($p->{'facet'});
    
	# add field for each type of facet with lots of NAs
	if (exists($flags->{'all_facets'}) && $flags->{'all_facets'} eq 1){
	    $log =split_facets($log);
	}
    }
    
    return $log;
}

#----------------------------------------------------------------------
sub split_facets
{
    my $log = shift;
    
    #handle regular facets
    my $facet_list= {
		     authorStr            => "NA",
		     bothPublishDateRange => "NA",
		     publishDateRange     => "NA",
		     countryOfPubStr      => "NA",
		     format               => "NA",
		     htsource             => "NA",
		     language             => "NA",
		     topicStr             => "NA",
		    };
    
    
    my @facets = split(/\|\s*/,$log->{'facet'});
    foreach my $f (@facets)
    {
	my ($type,$value)=split(/\:/,$f);
	if (!defined($value))
	{
	    print STDERR "parse error for value field=  $f lid=$log->{'lid'}\n";
	}
	else
	{
	    $facet_list= process_facet_type_value($type,$value,$facet_list);
	}
    }
    output_facets($facet_list,$log);
    #XXX handle facet_format and facet_lang	
}
#----------------------------------------------------------------------
sub process_facet_type_value
{
    my $type       = shift;
    my $value      = shift;
    my $facet_list = shift;
    
    #do we need to clean type or value
    # add quote if needed
    if ($value !~/.\"$/)
    {
	$value .= '"';
    }
    if (!exists($facet_list->{$type}))
    {
	print STDERR "error facet type: type=$type\nlid=$log->{'lid'}\n\t$log->{'facet'}\n\n";
    }
    else
    {    
	if ($facet_list->{$type} eq 'NA')
	{
	    $facet_list->{$type} = $value;
	}
	else
	{
	    $facet_list->{$type} .= "\," . $value;
	}
    }
    return ($facet_list);
     
}
#----------------------------------------------------------------------
sub output_facets
{
    my $facet_list = shift;
    my $log = shift;
    foreach my $key (sort keys %{$facet_list})
    {
	my $log_name = "r_facet_" . $key;
	
	$log->{$log_name} =$facet_list->{$key};
    }
    
    return $log;
    
}

#----------------------------------------------------------------------
#
# sub parseDateQ
#
# 'pdate_end' => 1930
# 'pdate_start' => 1880
# 'yop' => 'between'

sub parseDateQ
{
    my $p = shift;
    my $log = shift;

    if (exists $p->{'pdate_start'})
    {
	$log->{'pdate_start'} = $p->{'pdate_start'};
    }
    if (exists $p->{'pdate_end'})
    {
	$log->{'pdate_end'} = $p->{'pdate_end'};
    }
    if (exists $p->{'yop'})
    {
	$log->{'yop'} = $p->{'yop'};
    }
    return $log;
}

#-------------------------------------------------------------------
sub normalizeQuery
{
    my $q=shift;
#   print "debug query=$q\n";
    #routine to decode hex percent encoded characters
# IS this UTF8 safe?
# XXXconsider using     use URI::Escape; uri_unescape

    $q =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    $q = Encode::decode_utf8($q); #XXX new
    $q =~s/\+/ /g;
    $q =~s/%20/ /g;
    $q =~s/%22/\"/g;
    # replace "+" with spaces
   #WARNING what about the plus operator in a query
    $q=~s/\+/ /g;
    #
    #remove leading and trailing space
    $q=~s/\s+$//g;
    $q=~s/^\s+//g;
    # are plus  logged?
    #are minuses logged
    return $q;
}
#-------------------------------------------------------------------

1;
