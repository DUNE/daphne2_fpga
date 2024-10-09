# Memory Map

	0x00000000 - 0x00000064 Reserved for OEI internal settings

	0x00001974  Status vector for the Xilinx GbE PCS/PMA IP Core, read-only, 16 bit

	0x00001975  SFP module status bits (all should be zero)

			0:  DAQ0 SFP absent (ABS)
			1:  DAQ0 SFP loss of signal (LOS)
			8:  DAQ1 SFP ABS
			9:  DAQ1 SFP LOS
			16: DAQ2 SFP ABS
			17: DAQ2 SFP LOS
			24: DAQ3 SFP ABS
			25: DAQ3 SFP LOS
			32: GbE SFP ABS
			33: GbE SFP LOS
			40: Timing Endpoint SFP ABS
			41: Timing Endpoint SFP LOS

	0x00002000  Write anything to trigger spy buffers
	0x00002001  Write anything to force front end alignment recalibration
	0x00002002  Read the status of the AFE automatic alignment front end, lower 5 bits should be HIGH
	0x00002010  Number of errors observed for AFE0 frame marker, stops at 255.
	0x00002011  Number of errors observed for AFE1 frame marker, stops at 255.
	0x00002012  Number of errors observed for AFE2 frame marker, stops at 255.
	0x00002013  Number of errors observed for AFE3 frame marker, stops at 255.
	0x00002014  Number of errors observed for AFE4 frame marker, stops at 255.

	0x00003000  Output record header parameters, read-write, bits 25 to 6, bits 5 to 0 are read only, 26 bits defined as:

			bits 25..22 = slot_id(3..0), default "0010"
			bits 21..12 = crate_id(9..0), default is "0000000001"
			bits 11..6  = detector_id(5..0), default is "000010"
			bits 5..0   = version_id(5..0), default is "000010"
				
	0x00003001  Output link control byte. used to select streaming or self triggered mode sender, 
			or idle. This register defaults to 0, all output links idle. When an output link 
			is disabled it sends FELIX style idle words (D0.0 & D0.0 & D0.0 & K28.5)

			bits 1:0: output link0 mode. 
			"0X" = link disabled, send idles
			"10" = streaming mode sender
			"11" = self triggered mode sender

			bits 3:2: output link1 mode. 
			"0X" = link disabled, send idles
			"10" = streaming mode sender
			"11" = self triggered mode sender

			bits 5:4: output link2 mode. 
			"0X" = link disabled, send idles
			"10" = streaming mode sender
			"11" = self triggered mode sender

			bits 7:6: output link0 mode. 
			"0X" = link disabled, send idles
			"10" = streaming mode sender
			"11" = self triggered mode sender

	0x00004000  Master Clock and Timing Endpoint Status Register (read only)

			bit 0: MMCM0 locked status
			bit 1: MMCM1 locked status
			bit 2: reserved, 0
			bit 3: reserved, 0
			bit 4: CDR chip LOS, should be 0
			bit 5: CDR chip LOL, should be 0
			bit 6: Timing SFP LOS, should be 0
			bit 7: Timing SFP ABS, should be 0 if present
			bits 11..8: Timing endpoint state bits, defined as:

				"0000" Starting state after reset
				"0001" Waiting for SFP LOS to go low
				"0010" Waiting for good frequency check
				"0011" Waiting for phase adjustment to complete
				"0100" Waiting for comma alignment, stable 62.5MHz phase
				"0101" Waiting for 8b10 decoder good packet
				"0110" Waiting for phase adjustment command
				"0111" Waiting for time stamp initialization
				"1000" Good to go!!!
				"1100" Error in rx
				"1101" Error in time stamp check
				"1110" Physical layer error after lock

			bit 12: Timing endpoint timestamp valid (Rdy)

	0x00004001  Master Clock and Timing Endpoint Control Register (read write)
			
			bit 0: MMCM1 master clock input select (0=local-default, 1=endpoint)

	0x00004002  Write anything to reset master clock MMCM1
	0x00004003  Write anything to reset timing endpoint

	The following registers are used to determine which physical input channels 
	    (which are numbered decimal 0-7, 10-17, 20-27, 30-37, and 40-47)
	are connected to which core STREAMING sender inputs. These registers are read/write.
	Each register must contain a valid input number (as listed above) otherwise it will 
	set the corresponding mux output bus to all zeros. Applies only to STREAMING senders

	0x00005000  StreamSender0 input0 channel select, default = 0  (AFE0 ch0)
	0x00005001  StreamSender0 input1 channel select, default = 1  (AFE0 ch1)
	0x00005002  StreamSender0 input2 channel select, default = 2  (AFE0 ch2)
	0x00005003  StreamSender0 input3 channel select, default = 3  (AFE0 ch3)

	0x00005004  StreamSender1 input0 channel select, default = 10 (AFE1 ch0)
	0x00005005  StreamSender1 input1 channel select, default = 11 (AFE1 ch1)
	0x00005006  StreamSender1 input2 channel select, default = 12 (AFE1 ch2)
	0x00005007  StreamSender1 input3 channel select, default = 13 (AFE1 ch3)

	0x00005008  StreamSender2 input0 channel select, default = 20 (AFE2 ch0)
	0x00005009  StreamSender2 input1 channel select, default = 21 (AFE2 ch1)
	0x0000500A  StreamSender2 input2 channel select, default = 22 (AFE2 ch2)
	0x0000500B  StreamSender2 input3 channel select, default = 23 (AFE2 ch3)

	0x0000500C  StreamSender3 input0 channel select, default = 30 (AFE3 ch0)
	0x0000500D  StreamSender3 input1 channel select, default = 31 (AFE3 ch1)
	0x0000500E  StreamSender3 input2 channel select, default = 32 (AFE3 ch2)
	0x0000500F  StreamSender3 input3 channel select, default = 33 (AFE3 ch3)
	
	There is only one self triggered sender module and it connects to all forty
	input channels. Use this register to enable which channels you want the self
	triggered sender to see. The default value is for this register is all inputs DISABLED

	0x00006001  Self Trigger sender input enables, 40 bits R/W

	Specify the value of the command that generates the adhoc trigger. Default is 7
	This register is read/write
	
	0x00006010 Ad hoc Trigger command value, 8 bits R/W

	Specify the self trigger configuration values to be used for each self-triggered 
	mode senders. Note that this register is 64 bits of width where the whole self-trigger
	core is configurated. The word is distributed as follows:
	-> Bits [1:0] self trigger core filters configuration (Default is '01')
	-> Bits [2] self trigger core trigger primitives configuration (Default is '1')
				--> '0' = Peak detector as self-trigger  
				--> '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
	-> Bits [3] self trigger core trigger primitives configuration (Default is '1')
				--> '0' = Self-Trigger with light pulse between 2 data adquisition frames Not Allowed  
                --> '1' = Self-Trigger with light pulse between 2 data adquisition frames Allowed
	-> Bits [4] self trigger core trigger primitives configuration (Default is '0')
				--> '0' = Slope calculation with 2 consecutive samples --> x(n) - x(n-1)  
				--> '1' = Slope calculation with 3 consecutive samples --> [x(n) - x(n-2)] / 2 
	-> Bits [11:5] self trigger core trigger primitives configuration (Default is '1110110' or -10)
				--> Slope_Threshold (signed) 1(sign) + 6 bits, must be negative
	-> Bits [25:12] self trigger core primitives configuration (Default is '1110110' or -10)
				--> SPE threshold (signed) 1(sign) + 6 bits, must be negative	
	-> Bits [49:26] self trigger core matching trigger configuration (Default is or '000000000000000100101100' 300)
				--> Lower limit of detection, minimum value to detect by the trigger, measured in correlation value
				--> Signed, however it should be set positive for intended functionality
	-> Bits [63:50] self trigger core matching trigger configuration (Default is '11111110110000' or -80)
				--> Upper limit of detection, maximum value allowed of the peak relative to baseline
				--> Signed - 1(sign) + 13 bits, must be negative

	0x00006100  Self Trigger channel  1 configuration, 64 bits R/W
	0x00006101  Self Trigger channel  2 configuration, 64 bits R/W
	0x00006102  Self Trigger channel  3 configuration, 64 bits R/W
	0x00006103  Self Trigger channel  4 configuration, 64 bits R/W
	0x00006104  Self Trigger channel  5 configuration, 64 bits R/W
	0x00006105  Self Trigger channel  6 configuration, 64 bits R/W
	0x00006106  Self Trigger channel  7 configuration, 64 bits R/W
	0x00006107  Self Trigger channel  8 configuration, 64 bits R/W
	0x00006108  Self Trigger channel  9 configuration, 64 bits R/W
	0x00006109  Self Trigger channel 10 configuration, 64 bits R/W
	0x0000610A  Self Trigger channel 11 configuration, 64 bits R/W
	0x0000610B  Self Trigger channel 12 configuration, 64 bits R/W
	0x0000610C  Self Trigger channel 13 configuration, 64 bits R/W
	0x0000610D  Self Trigger channel 14 configuration, 64 bits R/W
	0x0000610E  Self Trigger channel 15 configuration, 64 bits R/W
	0x0000610F  Self Trigger channel 16 configuration, 64 bits R/W
	0x00006110  Self Trigger channel 17 configuration, 64 bits R/W
	0x00006111  Self Trigger channel 18 configuration, 64 bits R/W
	0x00006112  Self Trigger channel 19 configuration, 64 bits R/W
	0x00006113  Self Trigger channel 20 configuration, 64 bits R/W
	0x00006114  Self Trigger channel 21 configuration, 64 bits R/W
	0x00006115  Self Trigger channel 22 configuration, 64 bits R/W
	0x00006116  Self Trigger channel 23 configuration, 64 bits R/W
	0x00006117  Self Trigger channel 24 configuration, 64 bits R/W
	0x00006118  Self Trigger channel 25 configuration, 64 bits R/W
	0x00006119  Self Trigger channel 26 configuration, 64 bits R/W
	0x0000611A  Self Trigger channel 27 configuration, 64 bits R/W
	0x0000611B  Self Trigger channel 28 configuration, 64 bits R/W
	0x0000611C  Self Trigger channel 29 configuration, 64 bits R/W
	0x0000611D  Self Trigger channel 30 configuration, 64 bits R/W
	0x0000611E  Self Trigger channel 31 configuration, 64 bits R/W
	0x0000611F  Self Trigger channel 32 configuration, 64 bits R/W
	0x00006120  Self Trigger channel 33 configuration, 64 bits R/W
	0x00006121  Self Trigger channel 34 configuration, 64 bits R/W
	0x00006122  Self Trigger channel 35 configuration, 64 bits R/W
	0x00006123  Self Trigger channel 36 configuration, 64 bits R/W
	0x00006124  Self Trigger channel 37 configuration, 64 bits R/W
	0x00006125  Self Trigger channel 38 configuration, 64 bits R/W
	0x00006126  Self Trigger channel 39 configuration, 64 bits R/W
	0x00006127  Self Trigger channel 40 configuration, 64 bits R/W

	0x00009000  Read the FW version aka git commit hash ID, read-only, 28 bits

	0x0000AA55  Test register R/O always returns 0xDEADBEEF, read-only, 32 bit

	0x00070000 - 0x703FF  Test BlockRam read-write, 36 bit

	0x12345678 Simple test register, read-write, 64 bit

	0x40000000 - 0x400003FF Spy Buffer AFE0 data0 
	0x40010000 - 0x400103FF Spy Buffer AFE0 data1
	0x40020000 - 0x400203FF Spy Buffer AFE0 data2
	0x40030000 - 0x400303FF Spy Buffer AFE0 data3
	0x40040000 - 0x400403FF Spy Buffer AFE0 data4
	0x40050000 - 0x400503FF Spy Buffer AFE0 data5
	0x40060000 - 0x400603FF Spy Buffer AFE0 data6
	0x40070000 - 0x400703FF Spy Buffer AFE0 data7
	0x40080000 - 0x400803FF Spy Buffer AFE0 frame

	0x40100000 - 0x401003FF Spy Buffer AFE1 data0
	0x40110000 - 0x401103FF Spy Buffer AFE1 data1
	0x40120000 - 0x401203FF Spy Buffer AFE1 data2
	0x40130000 - 0x401303FF Spy Buffer AFE1 data3
	0x40140000 - 0x401403FF Spy Buffer AFE1 data4
	0x40150000 - 0x401503FF Spy Buffer AFE1 data5
	0x40160000 - 0x401603FF Spy Buffer AFE1 data6
	0x40170000 - 0x401703FF Spy Buffer AFE1 data7
	0x40180000 - 0x401803FF Spy Buffer AFE1 frame

	0x40200000 - 0x402003FF Spy Buffer AFE2 data0
	0x40210000 - 0x402103FF Spy Buffer AFE2 data1
	0x40220000 - 0x402203FF Spy Buffer AFE2 data2
	0x40230000 - 0x402303FF Spy Buffer AFE2 data3
	0x40240000 - 0x402403FF Spy Buffer AFE2 data4
	0x40250000 - 0x402503FF Spy Buffer AFE2 data5
	0x40260000 - 0x402603FF Spy Buffer AFE2 data6
	0x40270000 - 0x402703FF Spy Buffer AFE2 data7
	0x40280000 - 0x402803FF Spy Buffer AFE2 frame

	0x40300000 - 0x403003FF Spy Buffer AFE3 data0
	0x40310000 - 0x403103FF Spy Buffer AFE3 data1
	0x40320000 - 0x403203FF Spy Buffer AFE3 data2
	0x40330000 - 0x403303FF Spy Buffer AFE3 data3
	0x40340000 - 0x403403FF Spy Buffer AFE3 data4
	0x40350000 - 0x403503FF Spy Buffer AFE3 data5
	0x40360000 - 0x403603FF Spy Buffer AFE3 data6
	0x40370000 - 0x403703FF Spy Buffer AFE3 data7
	0x40380000 - 0x403803FF Spy Buffer AFE3 frame

	0x40400000 - 0x404003FF Spy Buffer AFE4 data0
	0x40410000 - 0x404103FF Spy Buffer AFE4 data1
	0x40420000 - 0x404203FF Spy Buffer AFE4 data2
	0x40430000 - 0x404303FF Spy Buffer AFE4 data3
	0x40440000 - 0x404403FF Spy Buffer AFE4 data4
	0x40450000 - 0x404503FF Spy Buffer AFE4 data5
	0x40460000 - 0x404603FF Spy Buffer AFE4 data6
	0x40470000 - 0x404703FF Spy Buffer AFE4 data7
	0x40480000 - 0x404803FF Spy Buffer AFE4 frame

	0x40500000 - 0x405003FF Spy Buffer for Timestamp (64 bits)

	0x40600000 - 0x406003FF Spy Buffer for Core Sender0 OUTPUT (32 bits)

	0x40800000   Trig Counter0, read-write, 64 bit
	0x40800008   Trig Counter1, read-write, 64 bit
	0x40800010   Trig Counter2, read-write, 64 bit
	0x40800018   Trig Counter3, read-write, 64 bit
	0x40800020   Trig Counter4, read-write, 64 bit
	0x40800028   Trig Counter5, read-write, 64 bit
	0x40800030   Trig Counter6, read-write, 64 bit
	0x40800038   Trig Counter7, read-write, 64 bit
	0x40800040   Trig Counter8, read-write, 64 bit
	0x40800048   Trig Counter9, read-write, 64 bit
	0x40800050   Trig Counter10, read-write, 64 bit
	0x40800058   Trig Counter11, read-write, 64 bit
	0x40800060   Trig Counter12, read-write, 64 bit
	0x40800068   Trig Counter13, read-write, 64 bit
	0x40800070   Trig Counter14, read-write, 64 bit
	0x40800078   Trig Counter15, read-write, 64 bit
	0x40800080   Trig Counter16, read-write, 64 bit
	0x40800088   Trig Counter17, read-write, 64 bit
	0x40800090   Trig Counter18, read-write, 64 bit
	0x40800098   Trig Counter19, read-write, 64 bit
	0x408000A0   Trig Counter20, read-write, 64 bit
	0x408000A8   Trig Counter21, read-write, 64 bit
	0x408000B0   Trig Counter22, read-write, 64 bit
	0x408000B8   Trig Counter23, read-write, 64 bit
	0x408000C0   Trig Counter24, read-write, 64 bit
	0x408000C8   Trig Counter25, read-write, 64 bit
	0x408000D0   Trig Counter26, read-write, 64 bit
	0x408000D8   Trig Counter27, read-write, 64 bit
	0x408000E0   Trig Counter28, read-write, 64 bit
	0x408000E8   Trig Counter29, read-write, 64 bit
	0x408000F0   Trig Counter30, read-write, 64 bit
	0x408000F8   Trig Counter31, read-write, 64 bit
	0x40800100   Trig Counter32, read-write, 64 bit
	0x40800108   Trig Counter33, read-write, 64 bit
	0x40800110   Trig Counter34, read-write, 64 bit
	0x40800118   Trig Counter35, read-write, 64 bit
	0x40800120   Trig Counter36, read-write, 64 bit
	0x40800128   Trig Counter37, read-write, 64 bit
	0x40800130   Trig Counter38, read-write, 64 bit
	0x40800138   Trig Counter39, read-write, 64 bit

	0x40800140   Pack Counter0, read-write, 64 bit
	0x40800148   Pack Counter1, read-write, 64 bit
	0x40800150   Pack Counter2, read-write, 64 bit
	0x40800158   Pack Counter3, read-write, 64 bit
	0x40800160   Pack Counter4, read-write, 64 bit
	0x40800168   Pack Counter5, read-write, 64 bit
	0x40800170   Pack Counter6, read-write, 64 bit
	0x40800178   Pack Counter7, read-write, 64 bit
	0x40800180   Pack Counter8, read-write, 64 bit
	0x40800188   Pack Counter9, read-write, 64 bit
	0x40800190   Pack Counter10, read-write, 64 bit
	0x40800198   Pack Counter11, read-write, 64 bit
	0x408001A0   Pack Counter12, read-write, 64 bit
	0x408001A8   Pack Counter13, read-write, 64 bit
	0x408001B0   Pack Counter14, read-write, 64 bit
	0x408001B8   Pack Counter15, read-write, 64 bit
	0x408001C0   Pack Counter16, read-write, 64 bit
	0x408001C8   Pack Counter17, read-write, 64 bit
	0x408001D0   Pack Counter18, read-write, 64 bit
	0x408001D8   Pack Counter19, read-write, 64 bit
	0x408001E0   Pack Counter20, read-write, 64 bit
	0x408001E8   Pack Counter21, read-write, 64 bit
	0x408001F0   Pack Counter22, read-write, 64 bit
	0x408001F8   Pack Counter23, read-write, 64 bit
	0x40800200   Pack Counter24, read-write, 64 bit
	0x40800208   Pack Counter25, read-write, 64 bit
	0x40800210   Pack Counter26, read-write, 64 bit
	0x40800218   Pack Counter27, read-write, 64 bit
	0x40800220   Pack Counter28, read-write, 64 bit
	0x40800228   Pack Counter29, read-write, 64 bit
	0x40800230   Pack Counter30, read-write, 64 bit
	0x40800238   Pack Counter31, read-write, 64 bit
	0x40800240   Pack Counter32, read-write, 64 bit
	0x40800248   Pack Counter33, read-write, 64 bit
	0x40800250   Pack Counter34, read-write, 64 bit
	0x40800258   Pack Counter35, read-write, 64 bit
	0x40800260   Pack Counter36, read-write, 64 bit
	0x40800268   Pack Counter37, read-write, 64 bit
	0x40800270   Pack Counter38, read-write, 64 bit
	0x40800278   Pack Counter39, read-write, 64 bit

	0x40800280   Send Counter, read-write, 64 bit

	0x80000000   Test FIFO, 512 x 64, read-write (64-bit)

	0x90000000   Micocontroller Access via SPI FIFO, 2k x 8, read-write (8-bit ASCII strings )

	0xFFFFFFFF   Reserved for OEI internal settings

## Memory Map Notes:

* Address space is 32 bits, Data width is 64-bits (A32D64)
* AFE Spy Buffers are 14 bits wide and are read-only
* When properly aligned, every word in the frame marker spy buffers should read "11111110000000"  (0x3F80)
