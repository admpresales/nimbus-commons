#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp;
use File::Spec::Functions qw(catfile);
use File::Basename qw(fileparse);

use Net::FTP;
use Term::ReadKey;

sub usage {
    print qq"Usage: $0 { start | stop | restart | cmd <COMMAND> | import { <CONFIG_FILE> | ftp://<REMOTE_PATH> } }

    COMMAND         Arbitrary SoftEther client command
    REMOTE_PATH     FTP address - will retrieve and import the configuration
    CONFIG_FILE     Local .vpn configuration file to import

    Environment:
    VPN_DEBUG       Display output from all commands (default: 0)
    VPN_CLIENT_DIR  Directory where the VPN client is installed (default: /opt/vpnclient)
    FTP_USER        FTP Username
    FTP_PASS        FTP Password

";
    exit 1;
}

my $verbose = $ENV{VPN_DEBUG} // 0;
my $vpnClientDir = $ENV{VPN_CLIENT_DIR} // '/opt/vpnclient';
my $osname = $^O;

sub run {
    my @run = ( @_);
    
    print "\nRunning: @run\n\n" if $verbose;
    open my $out, '-|', @run or die "$!";
    
    while (<$out>) {
        print if $verbose;
    }

    close $out;

    print "\n$_[0] complete: $?\n" if $verbose;
}

sub vpnclient { run(catfile($vpnClientDir, 'vpnclient'), @_) }
sub vpncmd    { run(catfile($vpnClientDir, 'vpncmd'), qw(localhost /client /cmd), @_) }

my $action = shift // usage;
$verbose = 1 if $action eq 'cmd';

my %dispatch = (
    import => \&import_config,
    start => \&start_vpn,
    stop => \&stop_vpn,
    restart => \&restart_vpn,
    cmd => \&vpncmd,
);

usage "Unknown command: $action" unless $dispatch{$action};

$dispatch{$action}->(@ARGV);

sub start_vpn {
    print "Starting VPN...\n";
    
	if( $osname eq 'linux' ){{
		vpnclient('start');
	}}	
	else {{
		run("${vpnClientDir}/vpnclient /start /silent");
	}}

    return if grep { /noconnect/ } @_;

    print "Attempting to connect...\n";
    vpncmd('accountconnect', 'SAP-VPN');

	if( $osname eq 'linux' ){{
		print "Getting IP Address...\n";


		run(qw(sudo dhclient -x)) if qx(pgrep dhclient);
		run(qw(sudo dhclient vpn_vpn));
		system(qw(ip address show dev vpn_vpn));
	}}
}

sub stop_vpn {
    print "Stopping VPN...\n";
	if( $osname eq 'linux' ){{
		vpnclient('stop');
	}}
	else {{
		run("${vpnClientDir}/vpnclient /stop /silent");
	}}
}

sub restart_vpn {
    stop_vpn(@_);
    start_vpn(@_);
}

sub import_config {
    my $ftp_url_re = qr{
        ^(?: ftp:// )               # Protocol
            (?:   (?<user> .*? )    # Optional username
            (?: : (?<pass> .*? ))?  # Optional colon and password
        @)?                         # @ sign required if providing user/password
        (?<server>   .+? )          # Server address
        (?<path>   / .*  ) $        # Slash and path to file
    }x;

    my $path = shift;
    $path = ftp_download(%+) if $path =~ $ftp_url_re;

    die "No such file: $path" unless -f $path;

    my ($file, $dir) = fileparse($path);
    chdir $dir;

    start_vpn 'noconnect'; # Ensure VPN is started

    vpncmd('accountimport', $file);

    restart_vpn;
}

sub ftp_download {
    my %ftp = @_;
    
    my $ftpServer = $ftp{server} || usage "FTP Server not specified.";
    my $ftpUser   = $ftp{user}   || $ENV{FTP_USER};
    my $ftpPass   = $ftp{pass}   || $ENV{FTP_PASS};
    my $path      = $ftp{path}   || usage "FTP Path not specified.";

    while (!$ftpUser) {
        print "FTP Username: ";
        $ftpUser = ReadLine;
        chomp($ftpUser);
    }

    while (!$ftpPass) {
            print "FTP Password: ";
            ReadMode "noecho";
            $ftpPass = ReadLine;
            chomp($ftpPass);
            ReadMode "normal";
            print "\n";
    }

    my $ftp = Net::FTP->new($ftpServer) or die "Could not connect to FTP: $@\n";
    $ftp->login($ftpUser, $ftpPass) or die "Could not login: ", $ftp->message;
    $ftp->binary;
    
    my $temp = File::Temp->new(UNLINK => 0, SUFFIX => '.vpn');
    printf "Downloading '%s' to '%s'...\n", $path, $temp->filename;
    
    $ftp->get($path, $temp) or die "Could not get '$path': ", $ftp->message;
    $ftp->quit;
    close($temp);

    return $temp->filename;
}