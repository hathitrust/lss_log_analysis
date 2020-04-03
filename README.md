


## Files
* parseClicklog.pl. 
  * parses json line files from ls application
* clicklog2tsv.pl
  * converts output of parseClicklog.pl to tsv file with header listing fields.  
  * Order of fields output and choice of fields to output set in __DATA__ section
* process_cgi.pl
  * General program for pulling out cgi parameters from a get URL sent to a CGI program.  Required by parseClicklog.pl
