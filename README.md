# README.md

## Usage and background

For background see Confluence pages [Log Analysis] (https://tools.lib.umich.edu/confluence/display/HAT/Log+Analysis)  and for usage examples see [Example of "interesting sessions" from click logs] (https://tools.lib.umich.edu/confluence/pages/viewpage.action?pageId=84934715)


## Files
* parseClicklog.pl. 
  * parses json line files from ls application
* clicklog2tsv.pl
  * converts output of parseClicklog.pl to tsv file with header listing fields.  
  * Order of fields output and choice of fields to output set in __DATA__ section
* process_cgi.pl
  * General program for pulling out cgi parameters from a get URL sent to a CGI program.  Required by parseClicklog.pl
* parseJSON_logs.pl
  *  Program to parse application logs roger created in attempt to unify logging.  These logs contain one json document per line.  Note this was based on an earlier log program and needs a rewrite

## TODO:   Write down location of the app logs that are the one json per line files
