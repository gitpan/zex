package tpc;

use strict;
use Exporter;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
use TelnetServer;

$VERSION = "1.00";
@ISA = qw ( Exporter );
@EXPORT = qw( );
@EXPORT_OK = qw( no_echo do_echo no_line do_line );

sub init {
	my $output = &TelnetServer::IAC &TelnetServer::SB &TelnetServer::TT &TelnetServer::SEND &TelnetServer::IAC &TelnetServer::SE;
	return ($output);
}

sub no_echo {
	my $output = &TelnetServer::IAC &TelnetServer::DONT &TelnetServer::ECHO . &TelnetServer::IAC &TelnetServer::WONT &TelnetServer::ECHO;
	return ($output);
}

sub do_echo {
	my $output = &TelnetServer::IAC &TelnetServer::DO &TelnetServer::ECHO . &TelnetServer::IAC &TelnetServer::WILL &TelnetServer::ECHO;
	return ($output);
}

sub no_line {
	my $output = IAC DONT LINEMODE;
	return ($output);
}

sub do_line {
	my $output = IAC DO LINEMODE;
	return ($output);
}

1;
