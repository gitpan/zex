#!/usr/bin/perl -w

use strict;
use Socket;
use POE qw(Wheel::SocketFactory Wheel::ReadWrite Filter::Stream Filter::Block);
use DBI;
use Term::ANSIColor qw( :constants );
use Term::ANSIScreen;
use Time::HiRes qw( gettimeofday tv_interval time );
use POSIX;
use Symbol qw( delete_package );
use common qw( :DEFAULT load_plugin unload_plugin run_plugin );
use tpc qw( do_echo no_echo );

### Define modules that will automatically loaded upon startup
my @AUTOLOAD = (
	'main_screen',
	'sysop_screen',
	'chat',
	'msg'	);

## Setup persistant DBI connection
our $dbh = DBI->connect("dbi:$common::conf{dbtype}:$common::conf{dbname}",$common::conf{dbuser},$common::conf{dbpass}) || die "Failed to establish database connection: $DBI::errstr\n";
our ($sth,$rv,$rc);

POE::Session->create(
	inline_states		=>	{
		_start		=>	sub {
						&setup_server;
						$_[KERNEL]->delay( tick => 300 );
					},
		tick		=>	sub {
						$rc = $main::dbh->ping;
						$common::genheap{-255}{tick}++;
						if ( $rc == 1 ) {
							e_log( -255, "Tick: $common::genheap{-255}{tick}" );
						}
						else {
							e_log( -255, "Error: Tick failed: $DBI::errstr" );
						}
						$_[KERNEL]->delay( tick => 300 );
					},
		server_accept	=>	\&server_accept,
		client_read	=>	\&client_read,
		client_write	=>	\&client_write,
		client_error	=>	\&client_error,
		client_disco	=>	\&client_disco,
		server_error	=>	\&server_error
	}
);

POE::Kernel->run();

exit;

sub setup_server {
	my ($kernel,$heap) = @_[KERNEL, HEAP];
	$heap->{server} = POE::Wheel::SocketFactory->new(
		BindPort	=>	$common::conf{port},
		SuccessEvent	=>	'server_accept',
		FailureEvent	=>	'server_error'
	) or die "Can not make server socket: $@\n";
	($common::genheap{server}{ts_start_s},$common::genheap{server}{ts_start_us}) = gettimeofday;
	$common::genheap{-255}{priv} = 255;
	foreach (@AUTOLOAD) {
		load_plugin( $_[HEAP], -255, $_ );
	}
	e_log( -255, "Server setup complete, accepting connections" );
}

sub server_accept {
	my ($kernel,$heap,$client) = @_[KERNEL, HEAP, ARG0];
	my $wheel = POE::Wheel::ReadWrite->new(
		Handle		=>	$client,
		InputEvent	=>	'client_read',
		ErrorEvent	=>	'client_error',
		FlushedEvent	=>	'client_disco'	);
	$wheel->set_output_filter(	POE::Filter::Stream->new()	);
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
	$heap->{client}->{$wheel->ID()} = $wheel;
	$common::genheap{$wheel->ID()}{address} = inet_ntoa($_[ARG1]);
	$common::genheap{$wheel->ID()}{intime} = [gettimeofday];
	e_log( -255, "Recieved connection from $common::genheap{$wheel->ID()}{address}" );
	$common::state{$wheel->ID()} = 'need_login';

	#$heap->{client}->{$wheel->ID()}->put( &tpc::init() );

	$sth = $main::dbh->prepare("SELECT file FROM screens WHERE id = ?");
	$sth->execute('login');
	if ( my $ans = $sth->fetchrow_hashref ) {
		if (-e "screens/$ans->{file}") {
			open ANSI, "<screens/$ans->{file}";
			my @ansi = <ANSI>;
			close ANSI;
			$heap->{client}->{$wheel->ID()}->put( @ansi );
		}
	}
	$sth->finish;
	do_login( $heap, $wheel->ID() );
	$common::genheap{$wheel->ID()}{wheel} = $wheel;
}

sub client_read {
	my ($kernel,$heap,$input,$wheel_id) = @_[KERNEL, HEAP, ARG0, ARG1];
	chomp $input;
	if ( !$input ) {
		clear_status( $heap, $wheel_id );
		return;
	}
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;

	### Authentication states

	if ($common::state{$wheel_id} eq 'need_login') {
		do_login( $heap, $wheel_id, $input );

	}
	elsif ($common::state{$wheel_id} eq 'need_pass') {
		do_login( $heap, $wheel_id, $input );
	}

	### Main function triggers

	elsif ( $heap->{dispatch}{$common::state{$wheel_id}} ) {
		print STDERR "Sending input to loaded function '$common::state{$wheel_id}'\n";
		$heap->{dispatch}{$common::state{$wheel_id}}{run}->( $heap, $wheel_id, $input );
		clear_status( $heap, $wheel_id );
	}

	### Sub-function triggers
	
	elsif ($common::state{$wheel_id} eq 'need_new_luser_name') {
		if ( $input !~ m/\w+/ ) {
			$common::state{$wheel_id} = 'new_luser';
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "Invalid handle" . RESET . BOLD . eval('WHITE') . ": " . RESET . "'$input'\n" );
			return;
		}
		$common::state{$wheel_id} = 'need_new_luser_pass';
		$common::genheap{$wheel_id}{lusername} = $input unless $common::genheap{$wheel_id}{lusername};
		$heap->{client}->{$wheel_id}->put( "Password: " );
	}
	elsif ($common::state{$wheel_id} eq 'need_new_luser_pass') {
		if ( $input eq "" ) {
			$common::state{$wheel_id} = 'need_new_luser_name';
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "Password can not be blank\n" . RESET );
			return;
		}
		$common::state{$wheel_id} = 'need_new_luser_fname';
		$common::genheap{$wheel_id}{luserpass} = $input unless $common::genheap{$wheel_id}{luserpass};
		$heap->{client}->{$wheel_id}->put( "First name: " );
	}
	elsif ($common::state{$wheel_id} eq 'need_new_luser_fname') {
		if ( $input eq "" ) {
			$common::state{$wheel_id} = 'need_new_luser_pass';
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "You dont have a first name?!\n" . RESET );
			return;
		}
		$common::state{$wheel_id} = 'need_new_luser_lname';
		$common::genheap{$wheel_id}{luserfname} = $input unless $common::genheap{$wheel_id}{luserfname};
		$heap->{client}->{$wheel_id}->put( "Last name: " );
	}
	elsif ($common::state{$wheel_id} eq 'need_new_luser_lname') {
		if ( $input eq "" ) {
			$common::state{$wheel_id} = 'need_new_luser_fname';
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "You dont have a last name?!\n" . RESET );
			return;
		}
		$common::state{$wheel_id} = 'need_new_luser_cc';
		$common::genheap{$wheel_id}{luserlname} = $input unless $common::genheap{$wheel_id}{luserlname};
		$heap->{client}->{$wheel_id}->put( "Country code [US]: " );
	}
	elsif ($common::state{$wheel_id} eq 'need_new_luser_cc') {
		$input = "US" unless $input;
		$input = "US" unless $input =~ m/^\w{2}$/;
		$common::state{$wheel_id} = 'need_new_luser_email';
		$common::genheap{$wheel_id}{cc} = $input unless $common::genheap{$wheel_id}{cc};
		$heap->{client}->{$wheel_id}->put( "Email: " );
	}
	elsif ($common::state{$wheel_id} eq 'need_new_luser_email') {
		if ($input eq "" || $input !~ m/^\w+\@\w+/) {
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "Invalid email address: '$input'" . RESET . "\n" );
			$common::state{$wheel_id} = 'need_new_luser_cc';
			return;
		}
		$common::genheap{$wheel_id}{email} = $input;
		my $datestamp = strftime "%Y-%m-%d", localtime;
		$sth = $main::dbh->prepare('INSERT INTO users VALUES("",5,?,?,MD5(?),"","","",?,?,"","")');
		if ( my $result = $sth->execute($datestamp, $common::genheap{$wheel_id}{lusername}, $common::genheap{$wheel_id}{luserpass}, $common::genheap{$wheel_id}{cc}, $common::genheap{$wheel_id}{email}) ) {
			$heap->{client}->{$wheel_id}->put( BOLD . eval('GREEN') . "Success! Log back in" );
			e_log( $wheel_id, "Added new user: $common::genheap{$wheel_id}{lusername}" );
			delete $common::genheap{$wheel_id}{lusername};
			delete $common::genheap{$wheel_id}{luserpass};
			delete $common::genheap{$wheel_id}{email};
			delete $common::genheap{$wheel_id}{cc};
			$heap->{disco}->{$wheel_id}++;
		}
		else {
			$heap->{client}->{$wheel_id}->put( BOLD . eval('RED') . "Failed: $DBI::errstr\n" . RESET );
			delete $common::genheap{$wheel_id}{new_user_name};
			delete $common::genheap{$wheel_id}{new_user_pass};
			delete $common::genheap{$wheel_id}{new_user_priv};
			delete $common::genheap{$wheel_id}{new_user_email};
			delete $common::genheap{$wheel_id}{new_user_cc};
			$heap->{disco}->{$wheel_id}++;
		}
		$sth->finish;
		return;
	}
	elsif ($common::state{$wheel_id} eq 'need_new_user_name') {
		if ($common::genheap{$wheel_id}{priv} < 85) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Insufficient privileges" . RESET . &Term::ANSIScreen::locate(23,0) );
			return;
		}
		if ($input =~ m/^\w+$/i) {
			$common::state{$wheel_id} = 'need_new_user_password';
			$heap->{client}->{$wheel_id}->put( 'Password: ' );
			$common::genheap{$wheel_id}{new_user_name} = $input;
			return;
		}
		else {
			$common::state{$wheel_id} = 'main_screen';
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . 'Invalid user name' . RESET . &Term::ANSIScreen::locate(23,0) );
			return;
		}
	}
	elsif ($common::state{$wheel_id} eq 'need_new_user_password') {
		if ($input eq "") {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Bad password" . RESET . &Term::ANSIScreen::locate(23,0) );
			$common::state{$wheel_id} = 'main_screen';
			return;
		}
		$common::genheap{$wheel_id}{new_user_pass} = $input;
		$heap->{client}->{$wheel_id}->put( "Privilege level 0-$common::genheap{$wheel_id}{priv} [5]: " );
		$common::state{$wheel_id} = 'need_new_user_priv';
		return;
	}
	elsif ($common::state{$wheel_id} eq 'need_new_user_priv') {
		if ($input eq "") {
			$input = 5;
		}
		if ($input !~ m/^\d{1,2}$/) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Invalid privilege level: '$input'" . RESET . &Term::ANSIScreen::locate(23,0) );
			$common::state{$wheel_id} = 'main_screen';
			return;
		}
		if ( $input > $common::genheap{$wheel_id}{priv} ) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Cannot add user with higher privileges than yourself" . RESET . &Term::ANSIScreen::locate(23,0) );
			$common::state{$wheel_id} = 'main_screen';
			return;
		}
		$common::genheap{$wheel_id}{new_user_priv} = $input;
		$heap->{client}->{$wheel_id}->put( 'Country code [US]: ' );
		$common::state{$wheel_id} = 'need_new_user_cc';
		return;
	}
	elsif ($common::state{$wheel_id} eq 'need_new_user_cc') {
		if ($input eq "") {
			$input = 'US';
		}
		$input = uc($input);
		if ($input !~ m/^[A-Z]{2}$/) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Invalid country code: '$input'" . RESET . &Term::ANSIScreen::locate(23,0) );
			$common::state{$wheel_id} = 'main_screen';
			return;
		}
		$common::genheap{$wheel_id}{new_user_cc} = $input;
		$heap->{client}->{$wheel_id}->put( 'Email: ');
		$common::state{$wheel_id} = 'need_new_user_email';
		return;
	}
	elsif ($common::state{$wheel_id} eq 'need_new_user_email') {
		if ($input eq "" || $input !~ m/^\w+\@\w+/) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Invalid email address: '$input'" . RESET . &Term::ANSIScreen::locate(23,0) );
			$common::state{$wheel_id} = 'main_screen';
			return;
		}
		$common::genheap{$wheel_id}{new_user_email} = $input;
		my $datestamp = strftime "%Y-%m-%d", localtime;
		$sth = $main::dbh->prepare('INSERT INTO users VALUES("",?,?,?,MD5(?),"","","",?,?,"","")');
		if ( my $result = $sth->execute($datestamp, $common::genheap{$wheel_id}{new_user_priv}, $common::genheap{$wheel_id}{new_user_name}, $common::genheap{$wheel_id}{new_user_pass}, $common::genheap{$wheel_id}{new_user_cc}, $common::genheap{$wheel_id}{new_user_email}) ) {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('GREEN') . "Success" . RESET . BOLD . eval('WHITE') . ": " . RESET . "new user added" . &Term::ANSIScreen::locate(23,0) );
			e_log( $wheel_id, "Added new user: $common::genheap{$wheel_id}{new_user_name}" );
			delete $common::genheap{$wheel_id}{new_user_name};
			delete $common::genheap{$wheel_id}{new_user_pass};
			delete $common::genheap{$wheel_id}{new_user_priv};
			delete $common::genheap{$wheel_id}{new_user_email};
			delete $common::genheap{$wheel_id}{new_user_cc};
			$common::state{$wheel_id} = 'main_screen';
		}
		else {
			$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0) . BOLD . eval('RED') . "Failed to add new user: $DBI::errstr" . RESET . &Term::ANSIScreen::locate(23,0) );
			delete $common::genheap{$wheel_id}{new_user_name};
			delete $common::genheap{$wheel_id}{new_user_pass};
			delete $common::genheap{$wheel_id}{new_user_priv};
			delete $common::genheap{$wheel_id}{new_user_email};
			delete $common::genheap{$wheel_id}{new_user_cc};
			$common::state{$wheel_id} = 'main_screen';
		}
		$sth->finish;
	}
	
	## Catch-all -- input that has not matched yet gets thrown away
	
	else {
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(23,0) );
		return;
	}
}

sub client_write {
	my ($kernel,$heap,$output,$wheel_id) = @_[KERNEL,HEAP,ARG0,ARG1];
	$heap->{client}->{$wheel_id}->put($output);
}

sub client_error {
	my ($kernel,$heap,$wheel_id) = @_[KERNEL,HEAP,ARG0];
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
	e_log( $wheel_id, "closed client connection" );
	delete $heap->{client}->{$wheel_id};
	delete $common::genheap{$wheel_id};
	delete $common::state{$wheel_id};
}

sub server_error {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
	print STDERR "[$ts] Server error, shutting down\n";
	delete $heap->{server};
	$main::dbh->disconnect;
}

sub client_disco {
	my ( $kernel,$heap,$wheel_id ) = @_[KERNEL,HEAP,ARG0];
	return unless $heap->{disco}->{$wheel_id};
	my $ts = strftime "%Y-%m-%d %H:%M:%S", localtime;
	e_log( $wheel_id, "closed client connection" );
	delete $heap->{client}->{$wheel_id};
	delete $common::genheap{$wheel_id};
	delete $common::state{$wheel_id};
}

sub do_login {
	my ( $heap, $wheel_id, $input ) = @_;
	$input =~ s/\W+//g if $input;
	if ( !$common::genheap{$wheel_id}{login} && !$input ) {
		$common::state{$wheel_id} = 'need_login';
		$heap->{client}->{$wheel_id}->put( "Handle: ");
		return;
	}
	if ( $common::state{$wheel_id} eq 'need_login' ) {
		$common::genheap{$wheel_id}{login} = $input;
		if ( $common::genheap{$wheel_id}{login} =~ m/^new$/i ) {
			$common::state{$wheel_id} = 'new_luser';
			new_luser( $heap, $wheel_id );
		}
		else {
			$common::state{$wheel_id} = 'need_pass';
			#$heap->{client}->{$wheel_id}->put( &tpc::no_echo );
			$heap->{client}->{$wheel_id}->put( "Password: " );
		}
		return;
	}
	$heap->{client}->{$wheel_id}->put( &tpc::do_echo );
	$common::genheap{$wheel_id}{pass} = $input;
	chomp($common::genheap{$wheel_id}{login});
	chomp($common::genheap{$wheel_id}{pass});
	$sth = $main::dbh->prepare("SELECT seq,priv,uname,fn,ln FROM users WHERE uname = ? AND sec = MD5(?)");
	$sth->execute($common::genheap{$wheel_id}{login},$common::genheap{$wheel_id}{pass}) or die "Failed to execute: $DBI::errstr\n:";
	if ($rv = $sth->fetchrow_hashref) {
		$common::state{$wheel_id} = 'main_screen';
		delete $common::genheap{$wheel_id}{pass};
		($common::genheap{$wheel_id}{seq},$common::genheap{$wheel_id}{priv},$common::genheap{$wheel_id}{uname},$common::genheap{$wheel_id}{fn},$common::genheap{$wheel_id}{ln}) = ($rv->{seq},$rv->{priv},$rv->{uname},$rv->{fn},$rv->{ln});
		$sth->finish;
		e_log( $wheel_id, "user logged in" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::cls() );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(0,0) );
		if ( $common::genheap{$wheel_id}{fn} ) {
			$heap->{client}->{$wheel_id}->put( &center( "Welcome back, $common::genheap{$wheel_id}{fn}" ) );
		}
		else {
			$heap->{client}->{$wheel_id}->put( &center( "Welcome back, $common::genheap{$wheel_id}{uname}" ) );
		}
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(2,0) );
		$heap->{client}->{$wheel_id}->put( &bar('BLUE') );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(22,0) );
		$heap->{client}->{$wheel_id}->put( &bar('BLUE') );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::setscroll(4,21) );
		$heap->{dispatch}{main_screen}{run}->( $heap, $wheel_id ) || e_log( $wheel_id, "Failed to call plugin '$common::state{$wheel_id}': $!" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::locate(24,0), &Term::ANSIScreen::clline(), &Term::ANSIScreen::locate(23,0), &Term::ANSIScreen::clline() );
	}
	else {
		e_log( $wheel_id, "Invalid login attempt: '$common::genheap{$wheel_id}{login}' '$common::genheap{$wheel_id}{pass}'" );
		$heap->{client}->{$wheel_id}->put( &Term::ANSIScreen::cls(), &Term::ANSIScreen::locate(0,0) );
		$heap->{client}->{$wheel_id}->put( "Invalid username/password\n" );
		$heap->{disco}->{$wheel_id}++;
	}
	return;
}

sub new_luser {
	my ( $heap, $wheel_id ) = @_;
	if ( $common::state{$wheel_id} eq 'new_luser' ) {
		$sth = $main::dbh->prepare("SELECT file FROM screens WHERE id = ?");
		$sth->execute('new_luser');
		if ( my $lans = $sth->fetchrow_hashref ) {
			if ( -e "screens/$lans->{file}" ) {
				open ANSI, "<screens/$lans->{file}";
				my @ansi = <ANSI>;
				close ANSI;
				$heap->{client}->{$wheel_id}->put( @ansi );
			}
		}
		$sth->finish;
		e_log( $wheel_id, "Attempt new_luser" );
		$common::state{$wheel_id} = 'need_new_luser_name';
		$heap->{client}->{$wheel_id}->put( "Handle [A-Z,a-z,0-9]: ");
	}
}

