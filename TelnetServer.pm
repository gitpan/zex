package TelnetServer;
use base 'Exporter';
use Carp qw(croak);
our @EXPORT;

# see also:
#		RFC 854 -- Telnet protocol specification

# there are two types of codes: terminals, and nonterminals.
#
# Terminals don't need to be followed by anything; nonterminals require an additional argument.

# name (T|N) value [description]
# T=Terminal, N=Nonterminal
BEGIN {
# i could go one step further and make this a one-liner with map...
for (grep {!(/^\s*$/||/^\s*#/)} split /\n/, <<'END') {
		SE		T			240			End of subnegotiation parameters.
 		NOP   T	    241    No operation.
    DM		T			242    DATA MARK
    BRK		T			243    NVT character Break.
    IP		T			244    The function INTERRUPT PROCESS.
    AO		T     245    The function ABORT OUTPUT.
    AYT		T			246		 The function ARE YOU THERE.
    EC		T		  247    The function ERASE CHARACTER
    EL		T			248    The function ERASE LINE
    GA		T			249		 The GO AHEAD signal.
     SB   N     250    Indicates that what follows is subnegotiation of the indicated option.
     WILL N 		251    Indicates the desire to begin performing, or confirmation that you are now performing, the indicated option.
     WON'T N		252    Indicates the refusal to perform, or continue performing, the indicated option.
     WONT	N			252		 Another expression for WON'T.
     DO		N			253		 Indicates the request that the other party perform, or confirmation that you are expecting  the other party to perform, the indicated option.
     DON'T N		254    Indicates the demand that the other party stop performing, or confirmation that you are no longer expecting the other party to perform, the indicated option.
     DONT	N			254		Another expression for DON'T.
     IAC  N     255    Data Byte 255.

#		RFC 857
		ECHO	T			1				Telnet option concerning whether the server will echo characters back to the telnet client.
		
#		RFC 1091
		TT	N			24
		SEND	N			2
#		RFC 1184
		LINEMODE T 	34			Telnet option concerning whether the client will buffer input character-at-a-time or line-at-a-time.
		
END
	my ($name, $TN, $value) = split ' ';
	my ($proto, $catcode) = do { 
															if ($TN eq 'N') {
																('$', 'shift')
															} elsif ($TN eq 'T') {
																(';$', '(@_?shift:\'\')')
															} else {
																croak("can't grok whether '${_}' has a T or an N in the 2nd field!");
															}
													};
	eval "sub $name ($proto) { chr($value) . $catcode; };1" or croak "something went horribly wrong, $@";
	push @EXPORT, $name unless $name =~ /'/;	# handle DON'T and WON'T
}

};

1;
