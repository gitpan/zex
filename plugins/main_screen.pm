package main_screen;

# Main menu zex plugin

use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use Time::HiRes qw( gettimeofday tv_interval );
use common;
#use POE qw( Filter::Block Filter::Stream );

my $sth;

sub run {
	my ($heap, $wheel_id, $input) = @_;

	$common::genheap{$wheel_id}{where} = 'Main';

	# Setup single-character input filter
	#$common::genheap{$wheel_id}{wheel}->set_input_filter( POE::Filter::Block->new( BlockSize => 1 ) );

	if ( !$input || $input eq "" ) {
		display( $heap, $wheel_id );
		return;
	}
	print "INSIDE main_screen, got input '$input'\n";
	if ( $input =~ m/^quit$/i || $input =~ m/^G$/i ) {
		my $delta = tv_interval($common::genheap{$wheel_id}{intime});
		e_log( $wheel_id, "quit after $delta seconds" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::cls(), &Term::ANSIScreen::locate(0,0) );
		$heap->{client}->{$wheel_id}->put( "$common::bbs{logoff}\n" );
		$heap->{disco}->{$wheel_id}++;
		return;
	}
	elsif ( $input =~ m/^who$/i || $input =~ m/^W$/i ) {
		whos_online( $heap, $wheel_id );

		return;
	}
	elsif ( $input =~ m/^chat$/i || $input =~ m/^C$/i ) {
		$common::state{$wheel_id} = 'chat';
		$heap->{dispatch}{$common::state{$wheel_id}}{run}->( $heap, $wheel_id );
	}
	elsif ( $input =~ m/^sysop$/i || $input =~ m/^S$/i ) {
		$common::state{$wheel_id} = 'sysop_screen';
		$heap->{dispatch}{$common::state{$wheel_id}}{run}->( $heap, $wheel_id );
	}
	else {
		display( $heap, $wheel_id );
	}
	return;
}

sub display {
	my ( $heap, $wheel_id ) = @_;
	my $sth = $main::dbh->prepare("SELECT file FROM screens WHERE id = ?");
	$sth->execute('main_menu');
	if ( my $lans = $sth->fetchrow_hashref ) {
		if ( -e "screens/$lans->{file}" ) {
			open ANSI, "<screens/$lans->{file}";
			my @ansi = <ANSI>;
			close ANSI;
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate( 20,0 ) );
			$heap->{client}->{$wheel_id}->put( @ansi );
		}
	}
	$sth->finish;
	return;
}

sub whos_online {
	my ( $heap, $wheel_id ) = @_;
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(20,0) . "\n" . BOLD . eval('WHITE') . 'Whos Online' . RESET . "\n" );
	$heap->{client}->{$wheel_id}->put( &bar('GREEN') );
	foreach (keys %common::genheap) {
		next unless $common::genheap{$_}{uname};
		next if $common::genheap{$_}{uname} eq 'unknown';
		my $len = sec_format( tv_interval( $common::genheap{$_}{intime} ) );
		my $so = 16 - length( $common::genheap{$_}{uname} );
		my $st = 16 - length( $len );
		$heap->{client}->{$wheel_id}->put( $common::genheap{$_}{uname} . " " x $so . $len . " " x $st . $common::genheap{$_}{where} . "\n" );
	}
	$heap->{client}->{$wheel_id}->put( "\n" );
	$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate( 23,0 ) );
	return;
}
1;
