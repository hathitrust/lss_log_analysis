#$Id: clicklog2tsv.pl,v 1.3 2020/04/03 16:39:55 tburtonw Exp tburtonw $#
my $fields_ary=get_fields_array();
my $hashref ={};
my $SEP ="\t";

output_header($fields_ary,$SEP);

my $c=0;

while (<>)
{
    chomp;
    $c++;
#    print STDERR "debug line $c\n";

    my $hashref = {};
    
    my @kv=split(/\|/,$_);
    foreach my $kv (@kv)
    {
	my ($key,$value)=split(/\t/,$kv);
	#remove leading/trailing whitespace
	$value=~s/^\s*//g;
	$value=~s/\s*$//g;
	#replace blank values with 'NA'
	if ($value eq '')
	{
	    $value='NA';
	}
	$hashref->{$key}=$value;
    }
    output($c,$fields_ary,$SEP,$hashref);
    # Uncomment below and also set  PRINT_KEYS=true to filter
    #my @ary=qw(AB_label pn sz starting_result_no rank_on_page);
    #output($c,\@ary,$SEP,$hashref);
    
}


sub output
{
    my $line_num=shift;
    my $fields_ary = shift;
    my $SEP = shift;
    my $hashref =shift;
    my $out;
    my $PRINT_KEYS;#="true";
    
    
    foreach my $field (@{$fields_ary})
    {
	my $value = "NA";
	if (exists ($hashref->{$field}) && defined($hashref->{$field}))
	{
	    $value=$hashref->{$field};
	}
	
	#	my $temp = $line_num . $SEP .  $value . $SEP;
	my $temp;
	
	if ($PRINT_KEYS)
	{
	    $temp =  "$field = $value" . $SEP;
#	    print STDERR "debug $temp\n";
	}
	else
	{
	    $temp =  $value . $SEP;
	}
	
	$out .= $temp;
    }
    # remove last sep
    $out=~s/$SEP$//;
#    $out = "$line_num\t$out";
    
    print "$out\n";
}



sub output_header
{
    my $ary = shift;
    my $SEP = shift;
    
    my $header = join ("$SEP",@{$ary});
    print "$header\n";
}




sub get_fields_array
{
    my @ary;
    
    while (<DATA>)
    {
	next if /\#/;
	next if /^\s*$/;
	chomp;
	push(@ary,$_);
    }
    return \@ary;
}




__DATA__

# use these for detecting robots
#ip
#timestamp
#session
#user_agent

ip
timestamp
session
id
query_string
abs_rank
#AB_label
#rank_on_page
pn
sz
#lid
cgi


#ip

#id
#AB_label
#rank_on_page
#click_type
#query_string
#lid
#type
#cgi
#user_agent
# current list of fields
#lid
# A_qtime
# B_num_found
# B_qtime
#cgi
#click_type
#id
# ip
# logged_in
# num_found
# pid
#query_string
# rank_on_page
# referer
# session
# starting_result_no
# test_type
# timestamp
#type
#user_agent
# #test cgi fields
# advanced
# q1
# field1
# anyall1
# q2
# field2
# anyall2
# q3
# field3
# anyall3
# q4
# field4
# anyall4
# facet
# facet_lang
# facet_format
# pdate
# edate
# yop
# pn
# sz
# has_facets
# has_dates
