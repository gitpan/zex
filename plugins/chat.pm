package chat;

# Chatroom zex plugin
# Copyleft 2004 Bryce Porter

use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use Text::Wrap;
use common qw( bar );
use POE qw( Filter::Stream Filter::Block );

my $it = "";
my $st = "\t";

sub run {
	my ($heap, $wheel_id, @input) = @_;
	my $message = join(" ", @input);

	# Clear input and status bar lines
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . &Term::ANSIScreen::clline() . &Term::ANSIScreen::locate(23,0) . &Term::ANSIScreen::clline() );

	# Ladies and gentlemen, luser has entered the building
	if ( !$common::genheap{$wheel_id}{$common::state{$wheel_id}}{init} ) {
		init( $heap, $wheel_id );
		return;
	}

	# I tried so hard, and got so far, but in the end, the input was blank...
	return unless $message;

	# See if we were passed a command (e.g. line starting with a '/')
	if ( my ($cmd) = $message =~ m/^\/(\w+)$/i ) {
		# Indeed we were, see if we recognize it
		if ( $cmd =~ m/^quit$/i ) {
			# Poor sport wants to quit
			get_out( $heap, $wheel_id );
			return;
		}
		elsif ( $cmd =~ m/^who$/i || $cmd =~ m/^names$/i || $cmd =~ m/^w$/i ) {
			# See who all is in the chatroom
			who( $heap, $wheel_id );
			return;
		}
		elsif ( $cmd =~ m/^help$/i || $cmd =~ m/^\?$/ ) {
			# Show help
			help( $heap, $wheel_id );
			return;
		}
		else {
			# Uh, sorry dude
			notice( $heap, $wheel_id, 'Invalid command' );
			return;
		}
	}

	# Finally, if all else fails, let the lamer flood the chatroom
	send_msg( $heap, $wheel_id, $message );
	return;
}

sub init {
	my ($heap, $wheel_id) = @_;
	#$common::genheap{$wheel_id}{wheel}->set_input_filter( POE::Filter::Stream->new() );
	$common::genheap{$wheel_id}{$common::state{$wheel_id}}{init}++;
	help( $heap, $wheel_id );
	$heap->{client}->{$wheel_id}->put( "\n" );
	who( $heap, $wheel_id );
	announce( $heap, $wheel_id, 'joined' );
	$heap->{client}->{$wheel_id}->put( "\n" );
	$common::genheap{$wheel_id}{where} = 'Chatroom';
	return;
}

sub who {
	my ($heap, $wheel_id) = @_;
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(21,0) );
	$heap->{client}->{$wheel_id}->put( "\n" . BOLD . WHITE . "Current chatters" . RESET . "\n" );
	$heap->{client}->{$wheel_id}->put( &bar('GREEN') );
	my (@users);
	$common::state{$wheel_id} = 'regress';
	foreach (keys %common::state) {
		next unless $common::state{$_} eq 'chat';
		push( @users, BOLD . YELLOW . "[" . RESET . $common::genheap{$_}{uname} . BOLD . YELLOW . "]" . RESET );
	}
	$common::state{$wheel_id} = 'chat';
	push( @users, BOLD . YELLOW . "[" . RESET . $common::genheap{$wheel_id}{uname} . BOLD . YELLOW . "]" . RESET );
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(21,0) . RESET . wrap($it, "", @users) . "\n" );
	return;
}

sub announce {
	my ($heap, $wheel_id, $what) = @_;
	foreach (keys %common::state) {
		next unless $common::state{$_} eq 'chat';
		$heap->{client}->{$_}->put( &Term::ANSIScreen::savepos . &Term::ANSIScreen::locate(21,0) . RESET . "--" . BOLD . eval('WHITE') . "> " . RESET . BOLD . eval('GREEN') . $common::genheap{$wheel_id}{uname} . RESET . " has $what the chatroom\n" . &Term::ANSIScreen::loadpos );
	}
	return;
}

sub send_msg {
	my ($heap, $wheel_id, $message) = @_;
	foreach (keys %common::state) {
		next unless $common::state{$_} eq 'chat';
		$heap->{client}->{$_}->put( &Term::ANSIScreen::savepos );
		$heap->{client}->{$_}->put( &Term::ANSIScreen::locate(21,0) );
		$heap->{client}->{$_}->put( BOLD . eval('MAGENTA') . $common::genheap{$wheel_id}{uname} . RESET . BOLD . eval('WHITE') . "> " . RESET );
		$heap->{client}->{$_}->put( wrap($it, $st, split( / /, $message ) ) . "\n" );
		$heap->{client}->{$_}->put( &Term::ANSIScreen::loadpos );
	}
	return;
}

sub get_out {
	my ($heap, $wheel_id, $message) = @_;
	delete $common::genheap{$wheel_id}{$common::state{$wheel_id}}{init};
	announce( $heap, $wheel_id, 'left' );
	$common::state{$wheel_id} = 'main_screen';
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('GREEN') . 'Left chatroom' . RESET . &Term::ANSIScreen::locate(23,0) );
	#$common::genheap{$wheel_id}{wheel}->set_input_filter( POE::Filter::Block( BlockSize => 1 ) );
	return;
}

sub notice {
	my ( $heap, $wheel_id, $message ) = @_;
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::savepos . &Term::ANSIScreen::locate(21,0) . BOLD . eval('RED') . 'Hmm' . RESET . BOLD . WHITE . ': ' . RESET . "Invalid command\n" . RESET . &Term::ANSIScreen::loadpos );
	return;
}

sub help {
	my ( $heap, $wheel_id ) = @_;
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::savepos() . &Term::ANSIScreen::locate(21,0) );
	$heap->{client}->{$wheel_id}->put( BOLD . WHITE . "Chatroom Commands\n" . RESET );
	$heap->{client}->{$wheel_id}->put( &bar('RED') );
	$heap->{client}->{$wheel_id}->put( BOLD . GREEN . "/" . RESET . BOLD . WHITE . "who" . RESET . " - show who is currently chatting\n" );
	$heap->{client}->{$wheel_id}->put( BOLD . GREEN . "/" . RESET . BOLD . WHITE . "msg" . RESET . " " . BOLD . WHITE . "[" . RESET . BOLD . YELLOW . "handle" . RESET . BOLD . WHITE . "]" . RESET . " " . BOLD . YELLOW . "message to send" . RESET. " - send someone a private message\n" );
	$heap->{client}->{$wheel_id}->put( BOLD . GREEN . "/" . RESET . BOLD . WHITE . "help" . RESET . " - show this help message\n" );
	$heap->{client}->{$wheel_id}->put( BOLD . GREEN . "/" . RESET . BOLD . WHITE . "quit" . RESET . " - quit the chatroom\n" );
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::loadpos() );
}

1;
