package sysop_screen;

# Sysop menu zex plugin

use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use Time::HiRes qw( gettimeofday tv_interval );
use common;
#use POE qw( Filter::Block Filter::Stream );

my $sth;

sub run {
	my ($heap, $wheel_id, $input) = @_;

	if ( $common::genheap{$wheel_id}{priv} < 85 ) {
		boot( $heap, $wheel_id );
		return;
	}

	$common::genheap{$wheel_id}{where} = 'SysOp Menu';

	# Setup single-character input filter
	#$common::genheap{$wheel_id}{wheel}->set_input_filter( POE::Filter::Block->new( BlockSize => 1 ) );

	if ( !$input || $input eq "" ) {
		display( $heap, $wheel_id );
		return;
	}
	print "INSIDE sysop_screen, got input '$input'\n";
	if ( $input =~ m/^quit$/i || $input =~ m/^G$/i ) {
		my $delta = tv_interval($common::genheap{$wheel_id}{intime});
		e_log( $wheel_id, "quit after $delta seconds" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::cls(), &Term::ANSIScreen::locate(0,0) );
		$heap->{client}->{$wheel_id}->put( "$common::bbs{logoff}\n" );
		$heap->{disco}->{$wheel_id}++;
		return;
	}
	elsif ( $input =~ m/^K$/i ) {

	}
	else {
		display( $heap, $wheel_id );
	}
	return;
}

sub display {
	my ( $heap, $wheel_id ) = @_;
	my $sth = $main::dbh->prepare("SELECT file FROM screens WHERE id = ?");
	$sth->execute('sysop_menu');
	if ( my $lans = $sth->fetchrow_hashref ) {
		if ( -e "screens/$lans->{file}" ) {
			open ANSI, "<screens/$lans->{file}";
			my @ansi = <ANSI>;
			close ANSI;
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate( 20,0 ) );
			$heap->{client}->{$wheel_id}->put( "\n" x 50 );
			$heap->{client}->{$wheel_id}->put( @ansi );
		}
	}
	$sth->finish;
	return;
}

sub boot {
	my ( $heap, $wheel_id ) = @_;
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate( 24,0 ) );
	$heap->{client}->{$wheel_id}->put( BOLD . RED . 'Access denied' . RESET );
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate( 23,0 ) );
	$common::state{$wheel_id} = 'main_screen';
	return;
}

1;
