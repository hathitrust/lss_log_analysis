# README.md

## Usage and background

For background see Confluence pages [Log Analysis](https://tools.lib.umich.edu/confluence/display/HAT/Log+Analysis)  and for usage examples see [Example of "interesting sessions" from click logs](https://tools.lib.umich.edu/confluence/pages/viewpage.action?pageId=84934715)


## Files
* files for parsing HT full-text search logs "ls"
  * parseQueryLogsNew.pl
    * Program to parse ls logs (not JSON not click logs).
  * parseClicklog.pl. 
    * parses json line files from ls application
  * clicklog2tsv.pl
    * converts output of parseClicklog.pl to tsv file with header listing fields.  
    * Order of fields output and choice of fields to output set in __DATA__ section
  * process_cgi.pl
    * General program for pulling out cgi parameters from a get URL sent to a CGI program.  Required by parseClicklog.pl and parseQueryLogsNew.pl


* parseJSON_logs.pl
  *  Program to parse application logs roger created in attempt to unify logging.  These logs contain one json document per line and are in /htapps/babel/logs/access.  Note this program was a quick and dirty modification to  an earlier log program and needs a rewrite
* parseNewPT.pl
  * Program to parse pt logs (not the json acces logs).
  
  

## General conventions
Most of the programs parse the log files and then have a @fields_wanted array that controls what fields are output and their order. Most of them output tsv files with "NA"s for empty fields.  This format is for ease of importing into R or other datamining software. Note that  the output of parseClicklogs.pl needs to be run through clicklog2tsv.pl to provide tab delimieted output and to specify the order of the desired fields.

Many of the programs have commented out quick hacks for improving efficiency if you want to just extract one field.
