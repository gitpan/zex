package msg;

# Instant Messaging zex plugin

use strict;
use warnings;
use Term::ANSIColor qw(:constants);

sub run {
	my ($heap, $wheel_id, $gref, $sref, $user, @message) = @_;
	my (@out);
	if (!$user) {
		push( @out, &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Need username to send message to" . RESET );
		return( @out );
	}
	if (!@message) {
		push( @out, &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Need a message to send" . RESET );
		return( @out );
	}
	foreach (keys %{$gref}) {
		next unless $gref->{$_}{uname};
		next unless $gref->{$_}{uname} eq $user;
		$heap->{client}->{$_}->put( &Term::ANSIScreen::locate(24,0) . &Term::ANSIScreen::clline() . BOLD . eval('WHITE') . "[ " . RESET . BOLD . eval('MAGENTA') . $gref->{$wheel_id}{uname} . RESET . BOLD . eval('WHITE') . " ]" . RESET . "-> " . BOLD . eval('GREEN') . join(" ", @message) . &Term::ANSIScreen::locate(23,0) );
		push( @out, &Term::ANSIScreen::locate(24,0) . BOLD . eval('GREEN') . "Success" . RESET . BOLD . eval('WHITE') . ": " . RESET . "message sent" );
		return( @out );
	}
	push (@out, &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "User is not currently logged in" . RESET . BOLD . eval('WHITE') . ": " . RESET . $user );
	return (@out);
}

1;
