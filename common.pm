package common;

# Zex BBS common functions

use strict;
use Term::ANSIColor	qw( :constants );
use vars		qw( @ISA @EXPORT @EXPORT_OK $VERSION );
use Symbol		qw( delete_package );
use Exporter;
use POSIX;

$VERSION = 1.00;
@ISA =	qw(
	Exporter	);

@EXPORT_OK = qw(
	bar
	center
	sec_format
	e_log
	load_plugin
	unload_plugin
	run_plugin
	clear_status	);

@EXPORT = qw(
	bar
	center
	sec_format
	e_log
	clear_status	);

## Setup BBS parameters
our %bbs = (
	name	=>	'zex0r',
	logoff	=>	'Thank you for visiting, come back soon...'	);

## Setup configuration parameters
our %conf = (
	v4addy	=>	'0.0.0.0',
	port	=>	9001,
	dbtype	=>	'mysql',
	dbname	=>	'zex',
	dbuser	=>	'zex',
	dbpass	=>	'somepass'	);

## Create state, genhep and message passing 'quasi-heaps'
our %state = ();
our %msg = ();
our %genheap = ();

## Setup ANSI stuff
our %colors = (	'1'	=>	'RED',
		'2'	=>	'GREEN',
		'3'	=>	'YELLOW',
		'4'	=>	'BLUE',
		'5'	=>	'MAGENTA',
		'6'	=>	'CYAN',
		'7'	=>	'WHITE'	);

## Date mapping stuff
our %months = (	'01'	=>	'January',
		'02'	=>	'February',
		'03'	=>	'March',
		'04'	=>	'April',
		'05'	=>	'May',
		'06'	=>	'June',
		'07'	=>	'July',
		'08'	=>	'August',
		'09'	=>	'September',
		'10'	=>	'October',
		'11'	=>	'November',
		'12'	=>	'December'	);

sub bar {
	my $col = uc(shift);
	my $out;
	$out = eval($col) . "--" . RESET . BOLD . eval($col) . "-" . RESET . eval($col) . "-" . RESET . BOLD . eval($col) . "---" . RESET . BOLD . WHITE . "-" . RESET . BOLD . eval($col) . "-" . RESET . BOLD . WHITE . "----" . RESET . BOLD . eval($col) . "-" . RESET . BOLD . WHITE;
	$out .= "-"x52;
	$out .= RESET . BOLD . eval($col) . "-" . RESET . BOLD . WHITE . "----" . RESET . BOLD . eval($col) . "-" . RESET . BOLD . WHITE . "-". RESET . BOLD . eval($col) . "---" . RESET . eval($col) . "-" . RESET . BOLD . eval($col) . "-" . RESET . eval($col) . "--" . RESET . "\n";
	return ($out);
}

sub center {
	my $mg = shift;
	my $wl = length($mg);
	my $fs = 80-$wl;
	$mg = " "x ($fs / 2) . $mg;
	return ($mg);
}

sub sec_format {
	my $t = shift;
	my $fix = "secs";
	my $secs = sprintf( "%.2f", $t );
	if ( $secs < 60 ) {
		return ("$secs$fix");
	}
	elsif ( $secs > 60 && $secs < 3600 ) {
		my $tm = $secs / 60;
		my $mins = sprintf( "%.2f", $tm );
		$fix = "mins";
		return ("$mins$fix");
	}
	elsif ( $secs > 3600 && $secs < 86400 ) {
		my $th = $secs / 3600;
		my $hours = sprintf( "%.2f", $th );
		$fix = "hours";
		return ("$hours$fix");
	}
	elsif ( $secs > 86400 ) {
		my $td = $secs / 86400;
		my $days = sprintf( "%.2f", $td );
		$fix = "days";
		return ("$days$fix");
	}
}

sub e_log {
	my ($wheel_id, $msg) = @_;
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
	if ( $wheel_id == -255 ) {
		print STDERR "[$ts] Kernel: $msg\n";
		return;
	}
	else {
		$genheap{$wheel_id}{uname} = 'unknown' unless $genheap{$wheel_id}{uname};
		print STDERR "[$ts] $genheap{$wheel_id}{uname}\@$genheap{$wheel_id}{address}: $msg\n";
		return;
	}
}

sub run_plugin {
	my ( $heap, $wheel_id, $plugin, $input ) = @_;
	my @out = $heap->{dispatch}{$input}{run}->($heap, $wheel_id, $input);
	if ( @out ) {
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(21,0) );
		$heap->{client}->{$wheel_id}->put( @out );
		$heap->{client}->{$wheel_id}->put( "\n\n" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(23,0) );
	}
	return;
}

sub load_plugin {
	my ( $heap, $wheel_id, $plugin ) = @_;
	if ( $common::genheap{$wheel_id}{priv} > 94 ) {
		if ( $heap->{dispatch}{$plugin} ) {
			e_log( $wheel_id, "Attempted to load plugin '$plugin' which is already loaded" );
			if ( $wheel_id != -255 ) {
				$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Plugin is already loaded" . RESET . BOLD . eval('WHITE') . ": " . RESET . "$plugin" . &Term::ANSIScreen::locate(23,0) );
			}
			return;
		}
		if ( -e "plugins/$plugin.pm" ) {
			delete_package( $plugin );
			do "plugins/$plugin.pm";
			if (!$heap->{dispatch}{$plugin} && $@) {
				e_log( $wheel_id, "Plugin '$plugin' failed to load: $! [$@]" );
				if ( $wheel_id != -255 ) {
					$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Plugin didnt load" . RESET . BOLD . eval('WHITE') . ": " . RESET . "$! [$@]" . &Term::ANSIScreen::locate(23,0) );
				}
				return;
			}
			if ( my $run = $plugin->can("run") ) {
				e_log( $wheel_id, "Plugin '$plugin' loaded" );
				$heap->{dispatch}{$plugin}{run} = $run;
				if ( $wheel_id != -255 ) {
					$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('GREEN') . "Success" . RESET . BOLD . WHITE . ": " . RESET . "plugin loaded" . RESET . &Term::ANSIScreen::locate(23,0) );
				}
			}
			else {
				e_log( $wheel_id, "Attempted to load invalid plugin '$plugin'" );
				if ( $wheel_id != -255 ) {
					$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Plugin does not contain a run() method" . RESET . &Term::ANSIScreen::locate(23,0) );
				}
			}
		}
		else {
			e_log( $wheel_id, "Plugin '$plugin' not found" );
			if ( $wheel_id != -255 ) {
				$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Plugin not found" . RESET . &Term::ANSIScreen::locate(23,0) );
			}
		}
	}
	else {
		e_log( $wheel_id, "Attempted to load plugin with insufficient privileges" );
		if ( $wheel_id != -255 ) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Insufficient privileges" . RESET . &Term::ANSIScreen::locate(23,0) );
		}
	}
	return;
}

sub unload_plugin {
	my ( $heap, $wheel_id, $plugin ) = shift;
	if ( $common::genheap{$wheel_id}{priv} > 94 ) {
		if ( $heap->{dispatch}{$plugin} ) {
			delete_package( $plugin );
			delete $heap->{dispatch}{$plugin};
			if ( $! ) {
				e_log( $wheel_id, "Problems unloading plugin '$plugin': $!" );
				if ( $wheel_id != -255 ) {
					$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Problems unloading module" . RESET . BOLD . WHITE . ": " . RESET . "$!" . &Term::ANSIScreen::locate(23,0) );
				}
			}
			else {
				e_log( $wheel_id, "Unloaded plugin: $plugin" );
				if ( $wheel_id != -255 ) {
					$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('GREEN') . "Success" . RESET . BOLD . WHITE . ": " . RESET . "plugin un-loaded" . RESET . &Term::ANSIScreen::locate(23,0) );
				}
			}
		}
		else {
			e_log( $wheel_id, "Attempted to unload plugin '$plugin' that is not already loaded" );
			if ( $wheel_id != -255 ) {
				$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Plugin not loaded" . RESET . BOLD . WHITE . ": " . RESET . "$plugin" . &Term::ANSIScreen::locate(23,0) );
			}
		}
	}
	else {
		e_log( $wheel_id, "Attempted to unload plugin with insufficient privileges" );
		if ( $wheel_id != -255 ) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Insufficient privileges" . RESET . &Term::ANSIScreen::locate(23,0) );
		}
	}
	return;
}

sub clear_status {
	my ($heap, $wheel_id) = @_;
	$heap->{client}->{$wheel_id}->put(
		&Term::ANSIScreen::locate(25,0),
		&Term::ANSIScreen::clline(),
		&Term::ANSIScreen::locate(24,0),
		&Term::ANSIScreen::clline(),
		&Term::ANSIScreen::locate(23,0),
		&Term::ANSIScreen::clline() );
	return;
}

1;
