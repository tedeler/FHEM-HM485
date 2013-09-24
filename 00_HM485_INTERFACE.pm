=head1
	00_HM485_INTERFACE.pm

=head1 SYNOPSIS
	HomeMatic Wired (HM485) Modul for FHEM
	contributed by Dirk Hoffmann 10/2012 - 2013
	$Id$

=head1 DESCRIPTION
	00_HM485_INTERFACE is the interface for communicate with HomeMatic Wired (HM485) devices
	over USB / UART / RS232 -> RS485 Converter

=head1 AUTHOR - Dirk Hoffmann
	dirk@FHEM_Forum (forum.fhem.de)
=cut
 
package main;

use strict;
use warnings;

use Data::Dumper;    # for debugging only

use lib '..';
use HM485::lib::Constants;
use HM485::lib::Device;
use HM485::lib::Util;

use vars qw {%attr %defs %selectlist %modules}; #supress errors in Eclipse EPIC IDE

# Function prototypes

# FHEM Inteface related functions
sub HM485_INTERFACE_Initialize($);
sub HM485_INTERFACE_Define($$);
sub HM485_INTERFACE_Ready($);
sub HM485_INTERFACE_Undef($$);
sub HM485_INTERFACE_Read($);
sub HM485_INTERFACE_Write($$;$);
sub HM485_INTERFACE_Set($@);
sub HM485_INTERFACE_Attr(@);

# Helper functions
sub HM485_INTERFACE_Init($);
sub HM485_INTERFACE_parseIncommingCommand($$);
sub HM485_INTERFACE_Connect($);
sub HM485_INTERFACE_RemoveValuesFromAttrList($@);
sub HM485_INTERFACE_openDev($;$);
sub HM485_INTERFACE_checkAndCreateSerialServer($);
sub HM485_INTERFACE_getSerialServerPid($$);

use constant {
	SERIAL_SERVER_NAME => 'HM485_SerialServer.pl',
	SERIALNUMBER_DEF   => 'SGW0123456',
	KEEPALIVE_TIMER    => 'keepAlive:',
	KEEPALIVECK_TIMER  => 'keepAliveCk:',
	KEEPALIVE_TIMEOUT  => 25,                      # Todo: check if we need to modify the timeout via attribute
	KEEPALIVE_MAXRETRY => 3,
};

=head2
	Implements Initialize function
	
	@param	hash	hash of device addressed
=cut
sub HM485_INTERFACE_Initialize($) {
	my ($hash) = @_;
	my $dev  = $hash->{DEF};
	
	my $ret = HM485::Device::init();
	if (defined($ret)) {
		Log3 ($hash, 1, $ret);
	} else {

		require $attr{global}{modpath} . '/FHEM/DevIo.pm';

		$hash->{DefFn}     = 'HM485_INTERFACE_Define';
		$hash->{ReadyFn}   = 'HM485_INTERFACE_Ready';
		$hash->{UndefFn}   = 'HM485_INTERFACE_Undef';
		$hash->{ReadFn}    = 'HM485_INTERFACE_Read';
		$hash->{WriteFn}   = 'HM485_INTERFACE_Write';
		$hash->{SetFn}     = 'HM485_INTERFACE_Set';
		$hash->{AttrFn}    = "HM485_INTERFACE_Attr";
	
		$hash->{AttrList}  = 'hmwId do_not_notify:0,1 server_bind:0,1 ' .
		                     'server_startTimeout server_device ' . 
		                     'server_serialNum server_logfile ' .
		                     'server_detatch:0,1 server_logVerbose:0,1,2,3,4,5 ' . 
		                     'server_gpioTxenInit server_gpioTxenCmd0 ' . 
		                     'server_gpioTxenCmd1';
		
		my %mc = ('1:HM485' => '^.*');
		$hash->{Clients}    = ':HM485:';
		$hash->{MatchList}  = \%mc;
	}
}

=head2
	Implements DefFn function
	
	@param	hash    hash of device addressed
	@param	string  definition string
	
	@return string | undef
=cut
sub HM485_INTERFACE_Define($$) {
	my ($hash, $def) = @_;
	my @a = split('[ \t][ \t]*', $def);

	my $ret = undef;
	my $name = $a[0];

	my $msg = '';
	if( (@a < 3)) {
		$msg = 'wrong syntax: define <name> HM485 {none | hostname:port}';
	}

	# create default hmwId on define, modify is possible e.g. via "attr <name> hmwId 00000002"
	$ret = CommandAttr(undef, $name . ' hmwId 00000001');

	if (!$ret) {
		$hash->{DEF} = $a[2];

		if($hash->{DEF} eq 'none') {
			Log3 ($hash, 1, 'HM485 device is none, commands will be echoed only');
		} else {
			# Make shure HM485_INTERFACE_Connect starts after HM485_INTERFACE_Define is ready 
			InternalTimer(gettimeofday(), 'HM485_INTERFACE_ConnectOrStartserver', $hash, 0);
		}
				
	} else {
		Log3 ($hash, 1, $ret);
	}

	$hash->{msgCounter} = 1;
	$hash->{STATE} = '';

	return $ret;
}

=head2
	Implements ReadyFn function.

	@param	hash    hash of device addressed
	@return mixed   return value of the HM485_INTERFACE_Init function
=cut
sub HM485_INTERFACE_Ready($) {
	my ($hash) = @_;

	return HM485_INTERFACE_openDev($hash, 1);
}

=head2
	Implements UndefFn function.

	Todo: maybe we must implement kill term for the serial server

	@param	hash    hash of device addressed
	@param	string  name of device

	@return undef
=cut
sub HM485_INTERFACE_Undef($$) {
	my ($hash, $name) = @_;

	DevIo_CloseDev($hash);

	return undef;
}

=head2
	Implements ReadFn function.
	called from the global loop, when the select for hash->{FD} reports data

	@param	hash    hash of device addressed
=cut
sub HM485_INTERFACE_Read($) {
	my ($hash) = @_;

	my $buffer = DevIo_SimpleRead($hash);

	if($buffer) {
		if ($buffer eq 'Connection refused. Only on Client allowed') {
			$hash->{ERROR} = $buffer;

		} else {
			my $msgStart = substr($buffer,0,1);
			if ($msgStart eq 'H') {
				# we got an answer to keepalive request
				my (undef, $msgCounter, $interfaceType, $version, $serial) = split(',', $buffer);
				$hash->{InterfaceType} = $interfaceType;
				$hash->{Version} = $version;
				$hash->{Serial} = $serial;
				$hash->{msgCounter} = hex($msgCounter);

				# initialize keepalive flags
				$hash->{keepalive}{ok}    = 1;
				$hash->{keepalive}{retry} = 0;
				
				my $name = $hash->{NAME};
				# Remove timer to avoid duplicates
				RemoveInternalTimer(KEEPALIVECK_TIMER . $name);
				RemoveInternalTimer(KEEPALIVE_TIMER   . $name);
			
				InternalTimer(
					gettimeofday() + 1, 'HM485_INTERFACE_KeepAlive', KEEPALIVE_TIMER . $name, 1
				);

			} elsif ($msgStart eq chr(0xFD)) {
				HM485_INTERFACE_parseIncommingCommand($hash, $buffer);

			}
		}
	}
}

=head2
	Implements WriteFn function.

	This function acts as the IOWrite function for the client module

	@param	hash      hash of device addressed
	@param	integer   the command @see lib/Constants.pm
	@param	hashref   aditional parameter
	
	@return integer   the message id of the sended message
=cut
sub HM485_INTERFACE_Write($$;$) {
	my ($hash, $cmd, $params) = @_;
	my $name = $hash->{NAME};
	my $msgId = 0;

	if ($cmd == HM485::CMD_SEND || $cmd == HM485::CMD_DISCOVERY || $cmd == HM485::CMD_KEEPALIVE) {
		$msgId = ($hash->{msgCounter} >= 0xFF) ? 1 : ($hash->{msgCounter} + 1);
		$hash->{msgCounter} = $msgId;

		my $sendData = '';
		if ($cmd == HM485::CMD_SEND) {
			# Todo: We must set valit ctrl byte
			my $ctrl = (exists($params->{ctrl})) ? $params->{ctrl} : '98';

			my $source = (exists($params->{source})) ? $params->{source} : AttrVal($name, 'hmwId', '00000001');
			my $target = $params->{target};
			my $data = $params->{data};

			$hash->{Last_Sent_RAW_CMD} = sprintf (
				'%s %s %s %s', $target, $ctrl, $source, $data
			);

			$sendData = pack('H*',
				sprintf(
					'%02X%02X%s%s%s%s%s', $msgId, $cmd, 'C8', $target, $ctrl, $source, $data
				)
			);

			my %logData = (
				start     => HM485::FRAME_START_LONG,
				target    => $target,
				cb        => $ctrl,
				sender    => $source,
				data      => $data,
				formatHex => 1
			);
#			HM485::Util::logger($name, 3, 'TX: ', \%logData);

		} elsif ($cmd == HM485::CMD_DISCOVERY) {
			$sendData = pack('H*',sprintf('%02X%02X00FF', $msgId, $cmd));

		} elsif ($cmd == HM485::CMD_KEEPALIVE) {
			$sendData = pack('H*',sprintf('%02X%02X', $msgId, $cmd));
		}

		if ($sendData) {
			DevIo_SimpleWrite(
				$hash, chr(0xFD) . chr(length($sendData)) . $sendData, 0
			);
		} 
	}

	return $msgId;
}

=head2
	Implements SetFn function.

	@param	hash    hash of device addressed
	@param	array   argument array
	
	@return    return error message on failure
=cut
sub HM485_INTERFACE_Set($@) {
	my ($hash, @a) = @_;

	# All allowed set commands
	my %sets = (
		'RAW'                => '',
		'discovery'          => 'start',
		'broadcastSleepMode' => 'off',
	);

	my $name = $a[0];
	my $cmd  = $a[1];
	my $msg  = '';
	
	if (@a < 2) {
		$msg = '"set ' . $name . '" needs one or more parameter';
	
	} else {
		if(!defined($sets{$cmd})) {
			my $arguments = ' ';
			foreach my $arg (sort keys %sets) {
				$arguments.= $arg . ($sets{$arg} ? (':' . $sets{$arg}) : '') . ' ';
			}
			$msg = 'Unknown argument ' . $cmd . ', choose one of ' . $arguments;

		} elsif ($cmd && exists($hash->{discoveryRunning}) && $hash->{discoveryRunning} > 0) {
			$msg = 'Discovery is running. Pleas wait for finishing.';

		} elsif ($cmd eq 'RAW') {
			my $paramError = 0;
			if (@a == 6 || @a == 7) {
				if ($a[2] !~ m/^[A-F0-9]{8}$/i || $a[3] !~ m/^[A-F0-9]{2}$/i ||
				    $a[4] !~ m/^[A-F0-9]{8}$/i || $a[5] !~ m/^[A-F0-9]{1,251}$/i ) {
	
					$paramError = 1
				}
			} else {
				$paramError = 1;
			}
	
			if (!$paramError) {
				my %params = (
					target => $a[2],
					ctrl   => $a[3],
					source => $a[4],
					data   => $a[5]
				);
				HM485_INTERFACE_Write($hash, HM485::CMD_SEND, \%params);
	
			} else {
				$msg = '"set HM485 raw" needs 5 parameter Sample: TTTTTTTT CC SSSSSSSS D...' . "\n" .
				       'Set sender address to 00000000 to use address from configuration.' . "\n\n" . 
				       '   T: 8 byte target address, C: Control byte, S: 8 byte sender address, D: data bytes' . "\n"
			}

		} elsif ($cmd eq 'discovery' && $a[2] eq 'start' ) {
			HM485_INTERFACE_discoveryStart($hash);

		} elsif ($cmd eq 'broadcastSleepMode' && $a[2] eq 'off') {
			HM485_INTERFACE_setBroadcastSleepMode($hash, 0)
		}
	}	

	return $msg;
}

=head2
	Implements AttrFn function.
	Here we validate user values of some attr's

	Todo: Add some more attr's

	@param	undev
	@param	string  name of device
	@param	string  attr name
	@param	string  attr value

	@return undef | string    if attr value was wrong
=cut
sub HM485_INTERFACE_Attr (@) {
	my (undef, $name, $attr, $val) =  @_;
	my $hash = $defs{$name};
	my $msg = '';

	if ($attr eq 'hmwId') {
		$hash->{hmwId} = $val;
		my $hexVal = (defined($val)) ? hex($val) : 0;
		if (!defined($val) || $val !~ m/^[A-F0-9]{8}$/i || $hexVal > 255 || $hexVal < 1) {
			$msg = 'Wrong hmwId defined. hmwId must be 8 digit hex address within 00000001 and 000000FF';
		} else {
			
			foreach my $d (keys %defs) {
				next if($d eq $name);
		
				if($defs{$d}{TYPE} eq 'HM485_INTERFACE') {
					if(AttrVal($d, 'hmwId', '00000001') eq $val) {
						$msg = 'hmwId ' . $val . ' already used. Please use another one.';
					}
				}
			}
		}
		
	}

	return ($msg) ? $msg : undef;
}

sub HM485_INTERFACE_discoveryStart($) {
	my ($hash) =  @_;

	$hash->{discoveryRunning} = 1;
	HM485_INTERFACE_setBroadcastSleepMode($hash, 1);
	InternalTimer(gettimeofday() + 1, 'HM485_INTERFACE_doDiscovery', $hash, 0);
}

sub HM485_INTERFACE_doDiscovery($) {
	my ($hash) =  @_;
	HM485_INTERFACE_Write($hash, HM485::CMD_DISCOVERY);
}

# Todo: We should set timer for discovery must have finish
sub HM485_INTERFACE_discoveryEnd($) {
	my ($hash) =  @_;
	my $name = $hash->{NAME};

	if (exists($hash->{discoveryFound})) {
		foreach my $discoverdAddress (keys $hash->{discoveryFound}) {
			my $message = pack('H*',
				sprintf(
					'FD0E00%02X%s%s%s%s', HM485::CMD_EVENT,
					$hash->{hmwId}, '98', $discoverdAddress, '690000'
				)
			);
	
				### Debug ###
			my $m = $message;
			my $l = uc( unpack ('H*', $m) );
			$m =~ s/^.*CRLF//g;
	
 			Log3 ('', 1, 'Dispatch: ' . $discoverdAddress);
			Log3 ('', 1, $l . ' (RX: ' . $m . ')' . "\n");
	
			Dispatch($hash, $message, '');
		}
		delete ($hash->{discoveryFound});
	}

	$hash->{discoveryRunning} = 0;
}

sub HM485_INTERFACE_setBroadcastSleepMode($$) {
	my ($hash, $value) =  @_;
	
	my %params = (
		target => 'FFFFFFFF',
		ctrl   => '98',
		source => $hash->{hmwId},
		data   => int($value) ? '7A' : '5A'
	);
	HM485_INTERFACE_Write($hash, HM485::CMD_SEND, \%params);
	HM485_INTERFACE_Write($hash, HM485::CMD_SEND, \%params);
}

=head2
	Implements DoInit function. Initialize the serial device

	@param	hash    hash of device addressed
	@return undef
=cut
sub HM485_INTERFACE_Init($) {
	my ($hash) = @_;

	my $dev  = $hash->{DEF};
	my $name = $hash->{NAME};

	Log3 ($hash, 3, $name . ' connected to device ' . $dev);
	$hash->{STATE} = 'open';
	delete ($hash->{serverStartTimeout});

	return undef;
}

=head2
	Parse HM485 frame and dispatch to the client entyty

	@param	hash    hash of device addressed
	@param	string  the binary message to parse
=cut
sub HM485_INTERFACE_parseIncommingCommand($$) {
	my ($hash, $message) = @_;
	
	my $name           = $hash->{NAME};
	my $msgId          = ord(substr($message, 2, 1));
	my $msgLen         = ord(substr($message, 1, 1));
	my $msgCmd         = ord(substr($message, 3, 1));
	my $msgData        = uc( unpack ('H*', substr($message, 4, $msgLen)));
	my $canDispatch    = 1;
	my $logTxtResponse = '';
	
	if ($msgCmd == HM485::CMD_DISCOVERY_END) {
		my $foundDevices = hex($msgData);
		Log3 ($hash, 4, 'Do action after discovery Found Devices: ' . $foundDevices);
		
		HM485_INTERFACE_setBroadcastSleepMode($hash, 0);
		InternalTimer(gettimeofday() + 1, 'HM485_INTERFACE_discoveryEnd', $hash, 0);
		$canDispatch = 0;

	} elsif ($msgCmd == HM485::CMD_DISCOVERY_RESULT) {
		Log3 ($hash, 3, 'Discovery - found device: ' . $msgData);
		$canDispatch = 0;
		$hash->{discoveryFound}{$msgData} = 1;

	} elsif ($msgCmd == HM485::CMD_RESPONSE) {
		$hash->{Last_Sent_RAW_CMD_State} = 'ACK';
		Log3 ($hash, 3, 'ACK: ' . $msgId . ' ' . $msgData);
		$logTxtResponse = ' Response';

	} elsif ($msgCmd == HM485::CMD_ALIVE) {
		my $alifeStatus = substr($msgData, 0, 2);
		if ($alifeStatus == '00') {
			# we got a response from keepalive
			$hash->{keepalive}{ok}    = 1;
			$hash->{keepalive}{retry} = 0;
			$canDispatch = 0;
		} else {
			$hash->{Last_Sent_RAW_CMD_State} = 'NACK';
			Log3 ($hash, 3, 'NACK: ' . $msgId);
		}
		
	} elsif ($msgCmd == HM485::CMD_EVENT) {
		Log3 ($hash, 3, 'Event: '. $msgData . ' ' . $msgData);

	} else {
		$canDispatch = 0;
	}		

	if ($canDispatch) {

#			my $start     => HM485::FRAME_START_LONG,
#			my $target    => substr($msgData, 0,7),
#			my $cb        => substr($msgData, 8,2),
#			my $sender    => substr($msgData, 10,7),
#			my $data      => substr($msgData, 18),

		
#		my %logData = (
#			start     => HM485::FRAME_START_LONG,
#			target    => substr($msgData, 0,7),
#			cb        => substr($msgData, 8,2),
#			sender    => substr($msgData, 10,7),
#			data      => substr($msgData, 18),
#			formatHex => 1
#		);
		
#		HM485::Util::logger($name, 3, 'RX: ' . $logTxtResponse, \%logData);
		Dispatch($hash, $message, '');
	}
}

=head2
	Connect to the defined device or start the serial server
	
	@param	hash    hash of device addressed
=cut
sub HM485_INTERFACE_ConnectOrStartserver($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $dev  = $hash->{DEF};

	if (!AttrVal($name, 'server_bind',0)) {
		HM485_INTERFACE_RemoveValuesFromAttrList(
			$hash,
			('server_detatch', 'server_device', 'server_serialNum',
			 'server_logfile', 'server_logVerbose:0,1,2,3,4,5', 'server_startTimeout',
			 'server_gpioTxenInit', 'server_gpioTxenCmd0', 'server_gpioTxenCmd1')
		);
		
		HM485_INTERFACE_openDev($hash);
		
	} else {
		HM485_INTERFACE_checkAndCreateSerialServer($hash);
	}
}

=head2
	Keepalive check of the interface  
	
	@param	string    name of keepalive timer
=cut
sub HM485_INTERFACE_KeepAlive($) {
	my($param) = @_;

	my(undef,$name) = split(':',$param);
	my $hash = $defs{$name};

	my $msgCounter = $hash->{msgCounter};
	
	$hash->{keepalive}{ok} = 1;

	if ($hash->{FD}) {
		Log3($hash, 3, $name . ' keepalive msgNo: ' . $msgCounter);
		HM485_INTERFACE_Write($hash, HM485::CMD_KEEPALIVE);

		# Remove timer to avoid duplicates
		RemoveInternalTimer(KEEPALIVE_TIMER . $name);

		# Timeout where foreign device must response keepalive commands
		my $responseTime = AttrVal($name, 'respTime', 1);

		# start timer to check keepalive response
		InternalTimer(
			gettimeofday() + $responseTime, 'HM485_INTERFACE_KeepAliveCheck', KEEPALIVECK_TIMER . $name, 1
		);

		# start timeout for next keepalive check
		InternalTimer(
			gettimeofday() + KEEPALIVE_TIMEOUT ,'HM485_INTERFACE_KeepAlive', KEEPALIVE_TIMER . $name, 1
		);
	}
}

=head2
	Check keepalive response.
	If keepalive response is missing, retry keepalive up to KEEPALIVE_MAXRETRY count. 
	
	@param	string    name of keepalive timer
=cut
sub HM485_INTERFACE_KeepAliveCheck($) {
	my($param) = @_;

	my(undef,$name) = split(':', $param);
	my $hash = $defs{$name};

	if (!$hash->{keepalive}{ok}) {
		# we got no keepalive answer 
		if ($hash->{keepalive}{retry} >= KEEPALIVE_MAXRETRY) {
			# keepalive retry count reached. Disonnect.
			DevIo_Disconnected($hash);
		} else {
			$hash->{keepalive}{retry} ++;

			# Remove timer to avoid duplicates
			RemoveInternalTimer(KEEPALIVE_TIMER . $name);

			# start timeout for repeated keepalive check
			HM485_INTERFACE_KeepAlive(KEEPALIVE_TIMER . $name);
		}
	} else {
		$hash->{keepalive}{retry} = 0;
	}
}

=head2
	Remove values from $hash->{AttrList}
	
	@param	hash    hash of device addressed
	@param	array   array of values to remove
=cut
sub HM485_INTERFACE_RemoveValuesFromAttrList($@) {
	my ($hash, @removeArray) = @_;
	my $name = $hash->{NAME};

	foreach my $item (@removeArray){
		$modules{$defs{$name}{TYPE}}{AttrList} =~ s/$item//;
		delete($attr{$name}{$item});
	}
}

=head2
	Open the device
	
	@param	hash    hash of device addressed
=cut
sub HM485_INTERFACE_openDev($;$) {
	my ($hash, $reconnect) = @_;
	
	my $retVal = undef;
	$reconnect = defined($reconnect) ? $reconnect : 0;
	$hash->{DeviceName} = $hash->{DEF}; 

	if ($hash->{STATE} ne 'open') {
		# if we must reconnect, connection can reappered after 60 seconds 
		$retVal = DevIo_OpenDev($hash, $reconnect, 'HM485_INTERFACE_Init');
	}

	return $retVal;
}
	
=head2
	Check if serial server running.
	Start the Server if no matchig pid exists
	
	Todo: Bulletproof Startr and restart
	      Maybe this can move to Servertools
	
	@param	hash    hash of device addressed
=cut
sub HM485_INTERFACE_checkAndCreateSerialServer($) {
	my ($hash) = @_;
	my $name = $hash->{NAME};
	my $dev  = $hash->{DEF};

	my $serverBind   = AttrVal($name, 'server_bind', 0);
	my $serverDevice = AttrVal($name, 'server_device'   , undef);

	if ($serverBind && $serverDevice) {
		my (undef, $serverPort) = split(',', $hash->{DEF});
		
		my $serverSerial       = AttrVal($name, 'server_serialNum',    SERIALNUMBER_DEF);
		my $serverDetatch      = AttrVal($name, 'server_detatch',      undef);
		my $serverGpioTxenInit = AttrVal($name, 'server_gpioTxenInit', undef);
		my $serverGpioTxenCmd0 = AttrVal($name, 'server_gpioTxenCmd0', undef);
		my $serverGpioTxenCmd1 = AttrVal($name, 'server_gpioTxenCmd1', undef);
		my $serverLogfile      = AttrVal($name, 'server_logfile',      undef);
		my $serverLogVerbose   = AttrVal($name, 'server_logVerbose',   undef);
		my $serverPid          = undef;
	
		my $serverCommandLine = SERIAL_SERVER_NAME;
		$serverCommandLine.= ($serverSerial)       ? ' --serialNumber ' . $serverSerial       : '';
		$serverCommandLine.= ($serverDevice)       ? ' --serialDevice ' . $serverDevice       : '';
		$serverCommandLine.= ($serverPort)         ? ' --localPort '    . $serverPort         : '';
		$serverCommandLine.= ($serverDetatch)      ? ' --daemon '       . $serverDetatch      : '';
		$serverCommandLine.= ($serverGpioTxenInit) ? ' --gpioTxenInit ' . $serverGpioTxenInit : '';
		$serverCommandLine.= ($serverGpioTxenCmd0) ? ' --gpioTxenCmd0 ' . $serverGpioTxenCmd0 : '';
		$serverCommandLine.= ($serverGpioTxenCmd1) ? ' --gpioTxenCmd1 ' . $serverGpioTxenCmd1 : '';
		$serverCommandLine.= ($serverLogfile)      ? ' --logfile '      . $serverLogfile      : '';
		$serverCommandLine.= ($serverLogVerbose)   ? ' --verbose '      . $serverLogVerbose   : '';
	
		$serverPid = HM485_INTERFACE_getSerialServerPid($hash, $serverCommandLine);
		$serverCommandLine = $attr{global}{modpath} . '/FHEM/HM485/SerialServer/' .
		                     $serverCommandLine;

		my $serverStartTimeout = 0.1; 
		if ($serverPid) {
			Log3($hash, 1, 'HM485 serial server already running with PID ' . $serverPid. '. We re use this process!');
		} else {
			# Start the serial server
			Log3($hash, 3, 'Start HM485 serial server with command line: ' . $serverCommandLine);
			system($serverCommandLine . '&');

			$serverStartTimeout = int(AttrVal($name, 'server_startTimeout', '2'));
			if ($serverStartTimeout) {
				Log3($hash, 3, 'Connect to HM485 serial server delayed for ' . $serverStartTimeout . ' seconds');
				$hash->{serverStartTimeout} = $serverStartTimeout;
			}
		}

		InternalTimer(gettimeofday() + $serverStartTimeout, 'HM485_INTERFACE_openDev', $hash, 0);

	} elsif ($serverBind && !$serverDevice) {
		my $msg = 'Serial server not started. Attr "server_device" for serial server is not set!';
		Log3 ($hash, 1, $msg);
		$hash->{ERROR} = $msg;
	} else {

		DevIo_CloseDev($hash);
		HM485_INTERFACE_openDev($hash);
	}
}

=head2
	Get the PID of a running serial server depends on the commandline

	Todo: maybe the server sould identifyed on its serial number only?	

	@param	hash    hash of device addressed
	@param	string    $serverCommandLine

	@return integer   PID of a running server, else 0
=cut
sub HM485_INTERFACE_getSerialServerPid($$) {
	my ($hash, $serverCommandLine) = @_;
	my $retVal = 0;
	
	my $ps = 'ps ao pid,args | grep "' . $serverCommandLine . '" | grep -v grep';
	my @result = `$ps`;
	foreach my $psResult (@result) {
		$psResult =~ s/[\n\r]//g;

		if ($psResult) {
			$psResult =~ /(^.*)\s.*perl.*/;
			$retVal = $1;
			last;
		}
	}
	
	return $retVal;
}

1;

=pod
=begin html

<a name="HM485"></a>
	<h3>HM485</h3>
	<p> FHEM module to commmunicate with HM485 devices</p>
	<ul>
		<li>...</li>
		<li>...</li>
		<li>...</li>
	</ul>

=end html
=cut
