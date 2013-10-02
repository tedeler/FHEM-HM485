package HM485::Devices;

our %definition = (
	'HMW-IO12-SW7'	=> {
		'version'		=> 11,
		'eeprom-size'	=> 1024,
		'models'	=> {
			'HMW_IO_12_Sw7_DR'	=> {
				'name'	=> 'RS485 I/O module 12-channel in and switch actuator 7-channel (DIN rails)',
				'type'		=> 18,
			},
		},
		'params' => {
			'master'	=> {
				'logging_time'	=> {											# parameter id
					'logical'		=> {										# time after state changes reeported by device via message
						'type'		=> 'float',									# parameter value type
						'min'		=> 0.5,
						'max'		=> 25.5,
						'default'	=> 2.0,
						'unit'		=> 's',
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 1.0,										# 1 byte
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0001,									# location of central adress in device
					},
					'conversion'	=> {
						'type'		=> 'float_integer_scale', 					# wert wird beim speichern mit <factor> mutipliziert, beim lesen dividiert
						'factor'	=> 10,										# conversion factor
						'offset'	=> 0.0,										# ???
					},
				},
				'central_address'	=> {
					'hidden'		=> 1,
					'enforce'		=> 0x00000001,
					'logical'		=> {
						'type'		=> 'int',
					},
					'physical'		=> {
						'type'		=> 'int',
						'size'		=> 4,
						'interface'	=> 'eeprom',
						'address'	=> 0x0002,
					},
				},
				'direct_link_deactivate'	=> {								# no direct link available
					'hidden'		=> 1,										# should not vidible in ui ???
					'enforce'		=> 1,										# sould always set to this value ???
					'logical'		=> {
						'type'		=> 'boolean',								# parameter value type
						'default'	=> 0,
					},
					'physical'		=> {
						'type'		=> 'int',									# parameter value type
						'size'		=> 0.1,										# 1 bit
						'interface'	=> 'eeprom',								# 4 bytes
						'address'	=> 0x0006,									# location of central adress in device
					},
				},
			},
		},
		'frames'	=> {
			'level_set'	=> {			# parameter id, must match to chanel/parameter/physical/value_id
				'type'		=> 0x78,											# x
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {											# aditional frame parameter (state)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 1											# value length
					},
				},
			},
			'level_get'	=> {													# frame id
				'type'		=> 0x73,											# s
				'dir'		=> '<',												# prefered communication direction < means to-device, we need them??? 
				'ch_field'	=> 10,												# position in frame ??? we need them???
			},
			'info_level'	=> {
				'type'		=> 0x69,											# i
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'state'		=> {											# aditional frame parameter (state)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 1											# value length
					},
					'state_flags'	=> {										# aditional frame parameter (state flags)
						'type'	=> 'int',										# value type
						'index'	=> 12.4,										# position in frame ???
						'size'	=> 0.3											# value length
					},
				},
			},
			'key_event_short'	=> {
				'type'		=> 0x4B,											# K
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_event_long'	=> {
				'type'		=> 0x4B,											# K
				'dir'		=> '>',												# prefered communication direction > means from-device, we need them???
				'event'		=> 1,												# frame should triger event???
				'ch_field'	=> 10,
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# parameter set always tu this value,short (0) long keypress (1)
					},
					'counter'	=> {											# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_short'	=> {
				'type'			=> 0x4B,										# K
				'dir'			=> '>',											# prefered communication direction > means from-device, we need them???
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 0									# parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (sim_counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'key_sim_long'	=> {
				'type'			=> 0x4B,										# K
				'dir'			=> '>',											# prefered communication direction > means from-device, we need them???
				'ch_field'		=> 10,											# ???
				'rec_ch_field'	=> 11,											# ???
				'params'	=> {
					'key'	=> {												# aditional frame parameter (state)
						'type'			=> 'int',								# value type
						'index'			=> 12.0,								# position in frame ???
						'size'			=> 0.1,									# value length
						'const_value'	=> 1									# parameter set always tu this value,short (0) long keypress (1)
					},
					'sim_counter'	=> {										# aditional frame parameter (counter)
						'type'	=> 'int',										# value type
						'index'	=> 12.2,										# position in frame ???
						'size'	=> 0.6											# value length
					},
				},
			},
			'set_lock'	=> {
				'type'		=> 0x6C,											# l
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'ch_field'	=> 10,												# ???
				'params'	=> {
					'inhibit'	=> {											# aditional frame parameter (inhibit)
						'type'	=> 'int',										# value type
						'index'	=> 12.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
			'toggle_install_test'	=> {
				'type'		=> 0x78,											# x
				'dir'		=> '<',												# prefered communication direction > means from-device, we need them???
				'ch_field'	=> 10,												# ???
				'params'	=> {
					'toggle_flag'	=> {										# aditional frame parameter (toggle_flag)
						'type'	=> 'int',										# value type
						'index'	=> 11.0,										# position in frame ???
						'size'	=> 1,											# value length
					},
				},
			},
		},
		'channels'	=> {
			'maintenance' => {
				'id'		=> 0,
				'ui-flags'	=> 'internal',										# flages for ui rendering ???
				'class'		=> 'maintenance',
				'count'	=> 1,													# count of channels of this type it the device
				'params'	=> {
					'maint_ch_master'	=> {									# paramset id
						'type'	=> 'master',
					},
					'maint_ch_values'	=> {									# paramset id
						'type'	=> 'values',
						'unreach'	=> {										# this parameter is set when device is not reachable
							'operations'	=> 'read,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							},
						},
						'sticky_unreach'	=> {								# this parameter is set when device is not reachable again
							'operations'	=> 'read,write,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							}
						},
						'config_pending'	=> {								# not used this time with fhem
							'operations'	=> 'read,event',
							'ui-flags'		=> 'service',
							'logical'		=> {
								'type'		=> 'boolean',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'internal',
							}
						},
					},
				},
			},
			'key'	=> {
				'id'	=> 1,
				'count'	=> 12,													# count of channels of this type it the device
				'physical_index_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 0
				'link_roles'	=> {
					'source'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x07,
						'address_step'	=> 2,
						'input_type'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'switch, pushbutton',
								'default'	=> 'pushbutton',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
						'input_locked'	=> {
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'size'		=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.1
								},
							},
							'conversion'	=> {
								'type'	=> 'boolean_integer',
								'invert'	=> 1
							},
						},
						'long_press_time'	=> {
							'logical'	=> {
								'type'		=> 'float',
								'min'		=> 0.4,
								'max'		=> 5,
								'default'	=> 1.0,
								'unit'		=> 's',
							},
							'physical'	=> {
								'type'		=> 'int',
								'size'		=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 1
								},
							},
							'conversion'	=> {
								'type'	=> 'float_integer_scale',
								'factor'	=> 10
							},
							# todo: conversion integer_integer_map @see xml file
						},
					},
					'link'	=> {
						'peer_param'	=> 'actuator',
						'channel_param'	=> 'channel',
						'count'			=> 27,
						'address_start'	=> 0x359,
						'address_start'	=> 0x359,
						'address_step'	=> 6,
						'channel'	=> {
							'operations'	=> 'none',							# which type of actions supports the channel ??? 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'int',
								'min'		=> 0,
								'max'		=> 255,
								'default'	=> 255,
							},
							'physical'		=> {
								'type'		=> 'int',
								'size'		=> 1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0,
								},
							},
						},
						'actuator'	=> {
							'operations'	=> 'none',							# which type of actions supports the channel ??? 
							'hidden'		=> 1,
							'logical'		=> {
								'type'		=> 'address',
							},
							'physical'		=> {
								'array'		=> {
									'size'		=> 1,
									'interface'	=> 'eeprom',
									'address'	=> {
										'index'	=> 0,
									},
								},
								'integer'	=> {
									'size'		=> 1,
									'interface'	=> 'eeprom',
									'address'	=> {
										'index'	=> 5,
									},
								},
							},
						}
					},
					'values'	=> {
						'press_short'	=> {
							'operations'	=> 'event,read,write', 
							'control'		=> 'button.short',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'event'		=> {
									'frame'	=> 'key_event_short',
								},
								'set'		=> {
									'request'	=> 'key_sim_short',
								},
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'sim_counter',
								'counter_size'	=> 6,
							},
						},
						'press_long'	=> {
							'operations'	=> 'event,read,write', 
							'control'		=> 'button.long',
							'logical'		=> {
								'type'		=> 'action',
							},
							'physical'		=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'counter',
								'event'		=> {
									'frame'	=> 'key_event_long',
								},
								'set'		=> {
									'request'	=> 'key_sim_long',
								},
							},
							'conversion'	=> {
								'type'			=> 'action_key_counter',
								'sim_counter'	=> 'sim_counter',
								'counter_size'	=> 6,
							},
						},
					},
				}
			},
			'switch' => {
				'id'	=> 13,
				'count'	=> 7,
				'physical_index_offset'	=> -1,									# channel in device starts from index + physical_index_offset => 0
				'link_roles'	=> {
					'target'	=> 'switch',
				},
				'params'	=> {
					'master'	=> {
						'address_start'	=> 0x1f,
						'address_step'	=> 2,
						'logging'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'on,off',
								'default'	=> 'on',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
					},
					'link'	=> {
						'peer_param'	=> 'sensor',
						'channel_param'	=> 'channel',
						'count'			=> 29,
						'address_start'	=> 0x2d,
						'address_step'	=> 28,
						'logging'	=> {
							'logical'	=> {
								'type'	=> 'option',
								'options' 	=> 'on,off',
								'default'	=> 'on',
							},
							'physical'	=> {
								'type'	=> 'int',
								'size'	=> 0.1,
								'interface'	=> 'eeprom',
								'address'	=> {
									'index'	=> 0.0
								},
							},
						},
					},
					'values' => {
						'state'	=> {
							'operations'=> 'read,write,event',
							'control'	=> 'switch.state',
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state',
								'set'	=> {
									'request'	=> 'level_set',
								},
								'get'	=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level',
								},
								'event'	=> {
									'frame'	=> 'info_level',
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
								'threshold'	=> 1,
								'false'		=> 0,
								'true'		=> 200,
							},
						},
						'working' => {
							'operations'=> 'read,event',
							'ui_flags'	=> 'internal',
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'state_flags',
								'get'	=> {
									'request'	=> 'level_get',
									'response'	=> 'info_level',
								},
								'event'	=> {
									'frame_1'	=> 'info_level',
									'frame_2'	=> 'ack_status',
								},
							},
							'conversion'	=> {
								'type'		=> 'boolean_integer',
							},
						},
						'inhibit' => {
							'operations'=> 'read,write,event',
							'control'	=> 'none',
							'loopback'	=> 1,
							'logical'	=> {
								'type'	=> 'boolean',
								'default'	=> 0,
							},
							'physical'	=> {
								'type'		=> 'int',
								'interface'	=> 'command',
								'value_id'	=> 'inhibit',
								'set'	=> {
									'request'	=> 'set_lock',
								},
							},
						},
					},
				},
			},
		}
	}
);

1;