#!/usr/bin/perl -w
# nagios: -epn

#########################################################
#                                                       #
#  Name:    check_satellite_sync                        #
#                                                       #
#  Version: 0.1.0                                       #
#  Created: 2016-09-14                                  #
#  Last Update: 2016-10-14                              #
#  License: GPL - http://www.gnu.org/licenses           #
#  Copyright: (c)2016 Rene Koch                         #
#  Author:  Rene Koch <rkoch@rk-it.at>                  #
#  URL: https://github.com/scrat14/check_satellite_sync #
#                                                       #
#########################################################

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw(POST);
use Getopt::Long;
use JSON::PP;

# for debugging only
use Data::Dumper;

# Configuration
# all values can be overwritten via command line options
my $satellite_port    = 443;          # default port
my $satellite_timeout = 15;           # default timeout

# create performance data
# 0 ... disabled
# 1 ... enabled
my $perfdata   = 1;


# Variables
my $prog       = "check_satellite_sync";
my $version    = "0.1.0";
my $projecturl = "https://github.com/scrat14/check_satellite_sync";

my $o_verbose        = undef;   # verbosity
my $o_help           = undef;   # help
my $o_satellite_host = undef;   # satellite hostname
my $o_satellite_port = undef;   # satellite port
my $o_ca_file        = undef;   # certificate authority
my $o_satellite_user = undef;   # satellite user
my $o_satellite_pwd  = undef;   # satellite user password
my $o_organization   = undef;   # satellite organization 
my $o_version        = undef;   # version
my $o_timeout        = undef;   # timeout

my %status  = ( ok => "OK", warning => "WARNING", critical => "CRITICAL", unknown => "UNKNOWN");
my %ERRORS  = ( "OK" => 0, "WARNING" => 1, "CRITICAL" => 2, "UNKNOWN" => 3);
my ($satellite_user,$satellite_pwd) = undef;


#***************************************************#
#  Function: parse_options                          #
#---------------------------------------------------#
#  parse command line parameters                    #
#                                                   #
#***************************************************#
sub parse_options(){
  Getopt::Long::Configure ("bundling");
  GetOptions(
    'v+'    => \$o_verbose,         'verbose+'   => \$o_verbose,
    'h'     => \$o_help,            'help'       => \$o_help,
    'H:s'   => \$o_satellite_host,  'hostname:s' => \$o_satellite_host,
    'p:i'   => \$o_satellite_port,  'port:i'     => \$o_satellite_port,
    'u:s'   => \$o_satellite_user,  'username:s' => \$o_satellite_user,
    'P:s'   => \$o_satellite_pwd,   'password:s' => \$o_satellite_pwd,
    'o:s'   => \$o_organization,    'organization:s' => \$o_organization,
    'V'     => \$o_version,         'version'    => \$o_version,
    't:i'   => \$o_timeout,         'timeout:i'  => \$o_timeout,
                                    'ca-file:s'  => \$o_ca_file
  );

  # process options
  print_help()      if defined $o_help;
  print_version()   if defined $o_version;

  if (! defined( $o_satellite_host )){
    print "Satellite hostname is missing.\n";
    print_usage();
    exit $ERRORS{$status{'unknown'}};
  }

  $o_verbose         = 0                  if (! defined $o_verbose);
  $o_verbose         = 0                  if $o_verbose <= 0;
  $o_verbose         = 3                  if $o_verbose >= 3;
  $satellite_port    = $o_satellite_port  if defined $o_satellite_port;
  $satellite_timeout = $o_timeout         if defined $o_timeout;
  $satellite_user    = $o_satellite_user  if defined $o_satellite_user;
  $satellite_pwd     = $o_satellite_pwd   if defined $o_satellite_pwd;
  
  if (! $satellite_user || ! $satellite_pwd){
    print "Missing Satellite API username or password!\n";
    exit $ERRORS{$status{'unknown'}};
  }

  if (defined $o_ca_file){
    if (! -r $o_ca_file){
      print "Can't read Certificate Authority file: $o_ca_file!\n";
      exit $ERRORS{$status{'unknown'}};
    }
  }
  
}


#***************************************************#
#  Function: print_usage                            #
#---------------------------------------------------#
#  print usage information                          #
#                                                   #
#***************************************************#
sub print_usage(){
  print "Usage: $0 [-v] -H <hostname> [-p <port>] -u <username> -P <password> [--ca-file <ca-file> \n";
  print "       [-o <organization> ] [-t <timeout>] [-V] \n";
}


#***************************************************#
#  Function: print_help                             #
#---------------------------------------------------#
#  print help text                                  #
#                                                   #
#***************************************************#
sub print_help(){
  print "\nRed Hat Satellite 6 Content View Sync checks for Icinga/Nagios version $version\n";
  print "GPL license, (c)2016   - Rene Koch <rkoch\@rk-it.at>\n\n";
  print_usage();
  print <<EOT;

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -H, --hostname
    Host name or IP Address of Satellite server
 -p, --port=INTEGER
    port number (default: $satellite_port)
 -u, --username=STRING
    Username required for login to REST-API
 -P, --password=STRING
    Password required for login to REST-API
 --ca-file=CA_FILE
    Path to Satellite CA for SSL certificate verification
 -o, --organization=STRING
    Satellite organization to check (default: all organizations)
 -t, --timeout=INTEGER
    Seconds before connection times out (default: $satellite_timeout)
 -v, --verbose
    Show details for command-line debugging
    (Icinga/Nagios may truncate output)

Send email to rkoch\@rk-it.at if you have questions regarding use
of this software. To submit patches of suggest improvements, send
email to rkoch\@rk-it.at
EOT

  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: print_version                          #
#---------------------------------------------------#
#  Display version of plugin and exit.              #
#                                                   #
#***************************************************#

sub print_version{
  print "$prog $version\n";
  exit $ERRORS{$status{'unknown'}};
}


#***************************************************#
#  Function: main                                   #
#---------------------------------------------------#
#  The main program starts here.                    #
#                                                   #
#***************************************************#

# parse command line options
parse_options();
print "[V] Starting the main script.\n" if $o_verbose >= 2;
print "[V] This is $prog version $version.\n" if $o_verbose >= 2;

# get organizations
my $api_path = "/katello/api/organizations?per_page=1000";
my $rref = api_connect($api_path);
print "[D] main: \$rref: " if $o_verbose == 3; print Dumper(%{ $rref }) if $o_verbose == 3;

my $org_id = undef;
my @org_ids;

# get organization id if organization is specified
if (defined $o_organization){
  print "[V] main: Organization given, trying to find matching label or title.\n" if $o_verbose >= 2;
  for (my $i=0;$i<scalar @{ $rref->{'results'} };$i++){
  	# try to find a match for title
  	$org_id = $rref->{'results'}->[$i]->{'id'} if $rref->{'results'}->[$i]->{'title'} eq $o_organization;
  }
  if (! defined $org_id){
  	print "Satellite Sync $status{'unknown'}: Given organization not found on Satellite!\n";
  	exit $ERRORS{'UNKNOWN'};
  }else{
  	print "[V] main: Found organization id: $org_id\n" if $o_verbose >= 2;
  }
}else{
  # we need all organization ids
  for (my $i=0;$i<scalar @{ $rref->{'results'} };$i++){
    push @org_ids, $rref->{'results'}->[$i]->{'id'};
  }
}

undef $rref;
# get repositories
if (defined $org_id){
  # get repositories for specifc organization 
  $api_path = "/katello/api/repositories?organization_id=" . $org_id . "&per_page=1000";
  $rref = api_connect($api_path);
  print "[D] main: \$rref: " if $o_verbose == 3; print Dumper(%{ $rref }) if $o_verbose == 3;
}else{
  # get repositories for all organizations
  for (my $i=0;$i<=$#org_ids;$i++){
  	$api_path = "/katello/api/repositories?organization_id=" . $org_ids[$i] . "&per_page=1000";
  	if (defined $rref){
  	  $rref = { %$rref, %{ api_connect($api_path) } };
  	}else{
  	  $rref = api_connect($api_path);
  	}
    print "[D] main: \$rref: " if $o_verbose == 3; print Dumper(%{ $rref }) if $o_verbose == 3;
  }
}

if (! defined $rref){
  print "Satellite Sync $status{'unknown'}: No repositories found!\n";
  exit $ERRORS{'UNKNOWN'};
}

my $exit_status = "ok";
my %sync_failed;
# verify sync status for repositories
for (my $i=0;$i< scalar @{ $rref->{'results'} };$i++){
  # get never synced repositories
  if (! defined $rref->{'results'}->[$i]->{'last_sync'}->{'result'}){
  	print "[V] Repository $rref->{'results'}->[$i]->{'name'} was never synced - skipping.\n" if $o_verbose >= 1;
  }else{
  	# The following sync stati will result in this Icinga/Nagios results:
  	# success              => OK
  	# warning              => WARNING
  	# pending              => WARNING
  	# error                => CRITICAL
  	# other (if possible?) => UNKNOWN
  	#
  	# We prioritize Icinga/Nagios stati in the following order:
  	# CRITICAL -> UNKNOWN -> WARNING -> OK
  	if ($rref->{'results'}->[$i]->{'last_sync'}->{'result'} eq "success"){
  	  $exit_status = "ok" unless $exit_status eq 'warning' or $exit_status eq 'critical' or $exit_status eq 'unknown';
  	}elsif ($rref->{'results'}->[$i]->{'last_sync'}->{'result'} eq "warning" || $rref->{'results'}->[$i]->{'last_sync'}->{'result'} eq "pending"){
  	  $exit_status = "warning" unless $exit_status eq 'critical' or $exit_status eq 'unknown';
  	  $sync_failed{ $rref->{'results'}->[$i]->{'name'} } = $rref->{'results'}->[$i]->{'last_sync'}->{'result'};
  	}elsif ($rref->{'results'}->[$i]->{'last_sync'}->{'result'} eq "error"){
  	  $exit_status = "critical";
  	  $sync_failed{ $rref->{'results'}->[$i]->{'name'} } = $rref->{'results'}->[$i]->{'last_sync'}->{'result'};
  	}else{
  	  $exit_status = "unknown" unless $exit_status eq 'critical';
  	  $sync_failed{ $rref->{'results'}->[$i]->{'name'} } = $rref->{'results'}->[$i]->{'last_sync'}->{'result'};
  	}
    print $rref->{'results'}->[$i]->{'name'} . ": " . $rref->{'results'}->[$i]->{'last_sync'}->{'result'} . "\n" if $o_verbose >= 2;
  }
}

print "Satellite Sync $status{$exit_status}: ";
if ($exit_status eq "ok"){
  print "all repositories synced sucessfully.\n";
}else{
  print "sync failed for ";
  for my $repo_name (keys %sync_failed){
  	print "$repo_name (" . $sync_failed{ $repo_name } . "), ";
  }
  print "\n";
}
exit $ERRORS{$status{$exit_status}};


#***************************************************#
#  Function: api_connect                            #
#---------------------------------------------------#
#  Connect to Satellite Server via REST-API and get #
#  values.                                          #
#  ARG1: API path                                   #
#***************************************************#

sub api_connect{
  print "[D] api_connect: Called function api_connect.\n" if $o_verbose == 3;
  print "[V] REST-API: Connecting to REST-API.\n" if $o_verbose >= 2;
  print "[D] api_connect: Input parameter: $_[0].\n" if $o_verbose == 3;

  # construct URL
  my $satellite_url = "https://" . $o_satellite_host . ":" . $satellite_port . $_[0];
  print "[V] REST-API: REST-API URL: $satellite_url\n" if $o_verbose >= 2;
  print "[V] REST-API: REST-API User: $satellite_user\n" if $o_verbose >= 2;
  #print "[V] REST-API: REST-API Password: $satellite_pwd\n" if $o_verbose >= 2;
  
  # connect to REST-API
  my $ra = LWP::UserAgent->new();
     $ra->timeout($satellite_timeout);
     $ra->env_proxy;				# read proxy information from env variables
     
  # handle no_proxy settings for old LWP::UserAgent versions
  if ((LWP::UserAgent->VERSION < 6.0) && (defined $ENV{no_proxy})){
    if ($ENV{no_proxy} =~ $o_satellite_host){
      delete $ENV{https_proxy} if defined $ENV{https_proxy};
      delete $ENV{HTTPS_PROXY} if defined $ENV{HTTPS_PROXY};
    }
  }

  # SSL certificate verification
  if (defined $o_ca_file){
    # check certificate
    $ra->ssl_opts(verfiy_hostname => 1, SSL_ca_file => $o_ca_file);
  }else{
    # disable SSL certificate verification
    if (LWP::UserAgent->VERSION >= 6.0){
      $ra->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);     # disable SSL cert verification
    }
  }

  my $rr = HTTP::Request->new(GET => $satellite_url);
  # authentication with username and password
  print "[D] api_connect: using username and password\n" if $o_verbose == 3;
  $rr->authorization_basic($satellite_user,$satellite_pwd);
  my $re = rest_api_connect($rr, $ra);

  # decode JSON output into Hash
  my $result = eval{ decode_json $re->content };
  print "Satellite Sync $status{'unknown'}: Error in JSON returned from Satellite - enable debug mode for details.\n" if $@;
  exit $ERRORS{'UNKNOWN'} if $@;
  
  return $result;

}


#***************************************************#
#  Function: rest_api_connect                       #
#---------------------------------------------------#
#  Connect to Satellite Server via REST-API         #
#  ARG1: HTTP::Request                              #
#  ARG2: LWP::Useragent                             #
#***************************************************#

sub rest_api_connect{
  print "[D] rest_api_connect: Called function rest_api_connect.\n" if $o_verbose == 3;
  print "[V] REST-API: Connecting to REST-API.\n" if $o_verbose >= 2;
  print "[D] rest_api_connect: Input parameter: $_[0].\n" if $o_verbose == 3;
  print "[D] rest_api_connect: Input parameter: $_[1].\n" if $o_verbose == 3;
  
  my $rr = $_[0];
  my $ra = $_[1];
  
  my $re = $ra->request($rr);
  print "[V] REST-API: " . $re->headers_as_string if $o_verbose >= 2;
  print "[D] rest_api_connect: " . $re->content if $o_verbose >= 3;
  if (! $re->is_success){   
    print "Satellite Sync $status{'unknown'}: Failed to connect to Satellite-API or received invalid response.\n"; 
    exit $ERRORS{'UNKNOWN'};    
  }
  
  return $re;
  
}


exit $ERRORS{$status{'unknown'}};
