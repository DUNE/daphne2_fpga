# dump.py -- dump DAPHNE INPUT spy buffers
# Jamieson Olsen <jamieson@fnal.gov> Python3

from oei import *

thing = OEI("10.73.137.110")

# ------------ OUTPUT STREAMING MODE (ONLY STREAMING MODE) ---------------------
# ------------ Does not apply to self-trigger mode
#    The following registers are used to determine which physical input channels 
#	    (which are numbered decimal 0-7, 10-17, 20-27, 30-37, and 40-47)
#	are connected to which core STREAMING sender inputs. These registers are read/write.
#	Each register must contain a valid input number (as listed above) otherwise it will 
#	set the corresponding mux output bus to all zeros. Applies only to STREAMING senders
#
#	0x00005000  StreamSender0 input0 channel select, default = 0  (AFE0 ch0)
#	0x00005001  StreamSender0 input1 channel select, default = 1  (AFE0 ch1)
#	0x00005002  StreamSender0 input2 channel select, default = 2  (AFE0 ch2)
#	0x00005003  StreamSender0 input3 channel select, default = 3  (AFE0 ch3)
#
#	0x00005004  StreamSender1 input0 channel select, default = 10 (AFE1 ch0)
#	0x00005005  StreamSender1 input1 channel select, default = 11 (AFE1 ch1)
#	0x00005006  StreamSender1 input2 channel select, default = 12 (AFE1 ch2)
#	0x00005007  StreamSender1 input3 channel select, default = 13 (AFE1 ch3)

#	0x00005008  StreamSender2 input0 channel select, default = 20 (AFE2 ch0)
#	0x00005009  StreamSender2 input1 channel select, default = 21 (AFE2 ch1)
#	0x0000500A  StreamSender2 input2 channel select, default = 22 (AFE2 ch2)
#	0x0000500B  StreamSender2 input3 channel select, default = 23 (AFE2 ch3)

#	0x0000500C  StreamSender3 input0 channel select, default = 30 (AFE3 ch0)
#	0x0000500D  StreamSender3 input1 channel select, default = 31 (AFE3 ch1)
#	0x0000500E  StreamSender3 input2 channel select, default = 32 (AFE3 ch2)
#	0x0000500F  StreamSender3 input3 channel select, default = 33 (AFE3 ch3)

thing.write(0x00005000, [0]) # Change this value to configure which channel is conected to StreamSender0 input0 
thing.write(0x00005001, [2]) # Change this value to configure which channel is conected to StreamSender0 input1
thing.write(0x00005002, [5]) # Change this value to configure which channel is conected to StreamSender0 input2
thing.write(0x00005003, [7]) # Change this value to configure which channel is conected to StreamSender0 input3

thing.write(0x00005004, [10]) # Change this value to configure which channel is conected to StreamSender1 input0 
thing.write(0x00005005, [11]) # Change this value to configure which channel is conected to StreamSender1 input1
thing.write(0x00005006, [12]) # Change this value to configure which channel is conected to StreamSender1 input2
thing.write(0x00005007, [13]) # Change this value to configure which channel is conected to StreamSender1 input3

thing.write(0x00005008, [20]) # Change this value to configure which channel is conected to StreamSender2 input0 
thing.write(0x00005009, [21]) # Change this value to configure which channel is conected to StreamSender2 input1
thing.write(0x0000500A, [22]) # Change this value to configure which channel is conected to StreamSender2 input2
thing.write(0x0000500B, [23]) # Change this value to configure which channel is conected to StreamSender2 input3

thing.write(0x0000500C, [30]) # Change this value to configure which channel is conected to StreamSender3 input0 
thing.write(0x0000500D, [31]) # Change this value to configure which channel is conected to StreamSender3 input1
thing.write(0x0000500E, [32]) # Change this value to configure which channel is conected to StreamSender3 input2
thing.write(0x0000500F, [33]) # Change this value to configure which channel is conected to StreamSender3 input3


# ------------ OUTPUT LINKS CONFIG ---------------------

# 0x00003001  Output link control byte. used to select streaming or self triggered mode sender, 
#  			or idle. This register defaults to 0, all output links idle. When an output link 
# 			is disabled it sends FELIX style idle words (D0.0 & D0.0 & D0.0 & K28.5)
# 
# 			bits 1:0: output link0 mode. 
# 			"0X" = link disabled, send idles
# 			"10" = streaming mode sender
# 			"11" = self triggered mode sender
# 
# 			bits 3:2: output link1 mode. 
# 			"0X" = link disabled, send idles
# 			"10" = streaming mode sender
# 			"11" = self triggered mode sender
# 
# 			bits 5:4: output link2 mode. 
# 			"0X" = link disabled, send idles
# 			"10" = streaming mode sender
# 			"11" = self triggered mode sender
# 
# 			bits 7:6: output link0 mode. 
# 			"0X" = link disabled, send idles
# 			"10" = streaming mode sender
# 			"11" = self triggered mode sender

Link0=int('11',2) # Change this value to configure Ouput1 sender mode 
Link1=int('10',2) # Change this value to configure Ouput2 sender mode
Link2=int('10',2) # Change this value to configure Ouput3 sender mode
Link3=int('10',2) # Change this value to configure Ouput4 sender mode

Config=Link0+(Link1*4)+(Link2*16)+(Link3*64)

thing.write(0x00003001, [Config])

print("Output CONFIGURED")

# ------------ ENABLE SELF-TRIGGER CHANNELS ---------------------
Chn0=int('1',2) # 1 ENABLE / 0 DISABLE
Chn1=int('0',2) # 1 ENABLE / 0 DISABLE
Chn2=int('1',2) # 1 ENABLE / 0 DISABLE
Chn3=int('0',2) # 1 ENABLE / 0 DISABLE
Chn4=int('0',2) # 1 ENABLE / 0 DISABLE
Chn5=int('1',2) # 1 ENABLE / 0 DISABLE
Chn6=int('0',2) # 1 ENABLE / 0 DISABLE
Chn7=int('1',2) # 1 ENABLE / 0 DISABLE
Chn8=int('0',2) # 1 ENABLE / 0 DISABLE
Chn9=int('0',2) # 1 ENABLE / 0 DISABLE
Chn10=int('0',2) # 1 ENABLE / 0 DISABLE
Chn11=int('0',2) # 1 ENABLE / 0 DISABLE
Chn12=int('0',2) # 1 ENABLE / 0 DISABLE
Chn13=int('0',2) # 1 ENABLE / 0 DISABLE
Chn14=int('0',2) # 1 ENABLE / 0 DISABLE
Chn15=int('0',2) # 1 ENABLE / 0 DISABLE
Chn16=int('0',2) # 1 ENABLE / 0 DISABLE
Chn17=int('0',2) # 1 ENABLE / 0 DISABLE
Chn18=int('0',2) # 1 ENABLE / 0 DISABLE
Chn19=int('0',2) # 1 ENABLE / 0 DISABLE
Chn20=int('0',2) # 1 ENABLE / 0 DISABLE
Chn21=int('0',2) # 1 ENABLE / 0 DISABLE
Chn22=int('0',2) # 1 ENABLE / 0 DISABLE
Chn23=int('0',2) # 1 ENABLE / 0 DISABLE
Chn24=int('0',2) # 1 ENABLE / 0 DISABLE
Chn25=int('0',2) # 1 ENABLE / 0 DISABLE
Chn26=int('0',2) # 1 ENABLE / 0 DISABLE
Chn27=int('0',2) # 1 ENABLE / 0 DISABLE
Chn28=int('0',2) # 1 ENABLE / 0 DISABLE
Chn29=int('0',2) # 1 ENABLE / 0 DISABLE
Chn30=int('0',2) # 1 ENABLE / 0 DISABLE
Chn31=int('0',2) # 1 ENABLE / 0 DISABLE
Chn32=int('0',2) # 1 ENABLE / 0 DISABLE
Chn33=int('0',2) # 1 ENABLE / 0 DISABLE
Chn34=int('0',2) # 1 ENABLE / 0 DISABLE
Chn35=int('0',2) # 1 ENABLE / 0 DISABLE
Chn36=int('0',2) # 1 ENABLE / 0 DISABLE
Chn37=int('0',2) # 1 ENABLE / 0 DISABLE
Chn38=int('0',2) # 1 ENABLE / 0 DISABLE
Chn39=int('0',2) # 1 ENABLE / 0 DISABLE

Channel_Self= Chn0 + (Chn1*(2**1))+ (Chn2*(2**2))+ (Chn3*(2**3))+ (Chn4*(2**4))+ (Chn5*(2**5))+ (Chn6*(2**6))+ (Chn7*(2**7))+ (Chn8*(2**8))+ (Chn9*(2**9))+ (Chn10*(2**10))+ (Chn11*(2**11))+ (Chn12*(2**12))+ (Chn13*(2**13))+ (Chn14*(2**14))+ (Chn15*(2**15))+ (Chn16*(2**16))+ (Chn17*(2**17))+ (Chn18*(2**18))+ (Chn19*(2**19))+ (Chn20*(2**20))+ (Chn21*(2**21))+ (Chn22*(2**22))+ (Chn23*(2**23))+ (Chn24*(2**24))+ (Chn25*(2**25))+ (Chn26*(2**26))+ (Chn27*(2**27))+ (Chn28*(2**28))+ (Chn29*(2**29))+ (Chn30*(2**30))+ (Chn31*(2**31))+ (Chn32*(2**32))+ (Chn33*(2**33))+ (Chn34*(2**34))+ (Chn35*(2**35))+ (Chn36*(2**36))+ (Chn37*(2**37))+ (Chn38*(2**38))+ (Chn39*(2**39))

thing.write(0x00006001, [Channel_Self])

print("Self-trigger Channel CONFIGURED")
# ------------ SELF-TRIGGER CONFIG PARAM ---------------------

# Config_Param_FILTER[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
# Config_Param_FILTER[1] --> '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
# Config_Param_FILTER[3 downto 2] --> '00' = 2 Samples Window / '01' = 4 Samples Window / '10' = 8 Samples Window / '11' = 16 Samples Window
# Config_Param_SELF[4] --> '0' = Peak detector as self-trigger  / '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
# Config_Param_SELF[5] --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames   
#                      --> '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames
# Config_Param_SELF[6] --> '0' = Slope calculation with 2 consecutive samples --> x(n) - x(n-1)  / '1' = Slope calculation with 3 consecutive samples --> [x(n) - x(n-2)] / 2 
# Config_Param_SELF[13 downto 7] --> Slope_Threshold (signed) 1(sign) + 6 bits, must be negative.

Enable_Filt=int('1',2) 
Truncated=int('0',2) 
Filtered_Window=int('01',2) 
Self_Main_Peak=int('1',2)
Allow_Peak_Between_Frames=int('0',2)
Slope_Calculation=int('0',2)
Slope_Threshold=int('1111100',2) # -10


Config=Enable_Filt+(Truncated*2)+(Filtered_Window*4)+(Self_Main_Peak*16)+(Allow_Peak_Between_Frames*32)+(Slope_Calculation*64)+(Slope_Threshold*128)

# Amplitude_Threshold=int(0) # (16 bits) 
# Slope_Threshold=int(65524) # -12 (16 bits)
# Time_Pulse_OB=int(344) # (11 bits)
# Reset=int(0) # (1 bits) ACTIVE HIGH

# Config=int(Amplitude_Threshold+(Slope_Threshold*(2**16))+(Time_Pulse_OB*(2**32))+(Reset*(2**63)))
# Config_Max=int((2**64)-1)

thing.write(0x00007001, [Config])

print("Self-Trigger CONFIGURED")
       
thing.close()

