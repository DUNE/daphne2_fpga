# dumpout.py -- dump DAPHNE OUTPUT spy buffer(s) Python3
# 
# Jamieson Olsen <jamieson@fnal.gov>

from oei import *
import numpy
import matplotlib.pyplot as plt

thing = OEI("10.73.137.110")

# write anything to register 0x0000_2000 to trigger all spy buffers

thing.write(0x2000, [1234])

# output spy buffer starts at 0x4060_0000 and is 4k deep

print()

buffer_size=4096 # 4k
block_size=128 # 2^7
iteration=buffer_size/block_size
starting_address=int('0x40600000',16) 
doutrec = thing.read(0x40600000,block_size)


for i in range(int(iteration-1)):
    starting_address=starting_address+block_size
    doutrec_aux = thing.read(starting_address,block_size)
    doutrec=doutrec + doutrec_aux[2:]
    doutrec2=numpy.array(doutrec[:])

print("\n\t ------- NUMERO 1 ------")
for word in doutrec[2:]:
    print("%08X " % word,end="")
print("\n\t -----------------------")
    
SOF_Position=numpy.array(numpy.where(doutrec2==0x0000003C))
SOF_Number=numpy.size(SOF_Position)
Header = {'Link': 0, 'Slot': 0, 'CreateID': 0,'DetectorID': 0,'Version': 0,'TimeStamp': 0, 'TriggerSample': 0, 'RI': 0, 'Algorithm': 0, 'Channel': 0, 'Baseline': 0, 'Threshold': 0}

Peak1 = {'Charge': 0, 'Num_Peak_OB': 0, 'Num_Peak_UB': 0,'Time_Pulse_OB': 0,'Time_Pulse_UB': 0,'Time_Peak': 0, 'Max_Peak': 0}
Peak2 = {'Charge': 0, 'Num_Peak_OB': 0, 'Num_Peak_UB': 0,'Time_Pulse_OB': 0,'Time_Pulse_UB': 0,'Time_Peak': 0, 'Max_Peak': 0}
Peak3 = {'Charge': 0, 'Num_Peak_OB': 0, 'Num_Peak_UB': 0,'Time_Pulse_OB': 0,'Time_Pulse_UB': 0,'Time_Peak': 0, 'Max_Peak': 0}
Peak4 = {'Charge': 0, 'Num_Peak_OB': 0, 'Num_Peak_UB': 0,'Time_Pulse_OB': 0,'Time_Pulse_UB': 0,'Time_Peak': 0, 'Max_Peak': 0}
Peak5 = {'Charge': 0, 'Num_Peak_OB': 0, 'Num_Peak_UB': 0,'Time_Pulse_OB': 0,'Time_Pulse_UB': 0,'Time_Peak': 0, 'Max_Peak': 0}
Peaks = [Peak1,Peak2,Peak3,Peak4,Peak5]

Raw_Data_Frame = numpy.zeros(1024)
#Raw_data_aux=numpy.zeros(1024)
for i in range(SOF_Number):
    # Only full frames are taken into account
    if ((SOF_Position[0,i]+466)<=buffer_size):
        Header0_FullBit= str()
        Header1_FullBit= str()
        Header2_FullBit= str()
        Header3_FullBit= str()
        Header4_FullBit= str()
        Raw_data_FullBit= str()
        Trailer0_FullBit= str()
        Trailer1_FullBit= str()
        Trailer2_FullBit= str()
        Trailer3_FullBit= str()
        Trailer4_FullBit= str()
        Trailer5_FullBit= str()
        Trailer6_FullBit= str()
        Trailer7_FullBit= str()
        Trailer8_FullBit= str()
        Trailer9_FullBit= str()
        Trailer10_FullBit= str()
        Trailer11_FullBit= str()
        Trailer12_FullBit= str()
        
        # Get all data from the frame
        for j in range(466):
            bits=bin(doutrec2[SOF_Position[0,i]+j+1])[2:]
            word_bits=bits.zfill(32)
            if (j==0):
                Header0_FullBit=word_bits[:]
            elif (j==1):
                Header1_FullBit=word_bits[:]
            elif (j==2):
                Header2_FullBit=word_bits[:]
            elif (j==3):
                Header3_FullBit=word_bits[:]
            elif (j==4):
                Header4_FullBit=word_bits[:]
            elif ((j>4) and (j<=452)) :
                Raw_data_FullBit=word_bits+Raw_data_FullBit
            elif (j==453):                
                Trailer0_FullBit=word_bits[:]
            elif (j==454):                
                Trailer1_FullBit=word_bits[:]
            elif (j==455):                
                Trailer2_FullBit=word_bits[:]
            elif (j==456):                
                Trailer3_FullBit=word_bits[:]
            elif (j==457):                
                Trailer4_FullBit=word_bits[:]
            elif (j==458):                
                Trailer5_FullBit=word_bits[:]
            elif (j==459):                
                Trailer6_FullBit=word_bits[:]
            elif (j==460):                
                Trailer7_FullBit=word_bits[:]
            elif (j==461):                
                Trailer8_FullBit=word_bits[:]
            elif (j==462):                
                Trailer9_FullBit=word_bits[:]
            elif (j==463):                
                Trailer10_FullBit=word_bits[:]
            elif (j==464):                
                Trailer11_FullBit=word_bits[:]
            else:                
                Trailer12_FullBit=word_bits[:]
              
        # TRANSLATE DATA FROM THE FRAME
        Header['Link']=int(Header0_FullBit[0:6],2)
        Header['Slot']=int(Header0_FullBit[6:10],2)
        Header['CreateID']=int(Header0_FullBit[10:20],2)
        Header['DetectorID']=int(Header0_FullBit[20:26],2)
        Header['Version']=int(Header0_FullBit[26:32],2)
        Header['TimeStamp']=int((Header2_FullBit+Header1_FullBit),2)
        Header['RI']=int(Header3_FullBit[16],2)
        Header['Algorithm']=int(Header3_FullBit[22:26],2)
        Header['Channel']=int(Header3_FullBit[26:32],2)
        Header['Baseline']=int(Header4_FullBit[2:16],2)
        
        for j in range(Raw_Data_Frame.size):
            Raw_Data_Frame[j]=int(Raw_data_FullBit[len(Raw_data_FullBit)-j*14-14:len(Raw_data_FullBit)-j*14],2)
            
        Peaks[0]['Charge']=int(Trailer0_FullBit[1:24],2)
        Peaks[0]['Max_Peak']=int(Trailer1_FullBit[18:32],2)
        Peaks[0]['Num_Peak_OB']=int(Trailer0_FullBit[24:28],2)
        Peaks[0]['Num_Peak_UB']=int(Trailer0_FullBit[28:32],2)
        Peaks[0]['Time_Peak']=int(Trailer1_FullBit[9:18],2)
        Peaks[0]['Time_Pulse_OB']=int(Trailer10_FullBit[0:10],2)
        Peaks[0]['Time_Pulse_UB']=int(Trailer1_FullBit[0:9],2)
        
        Peaks[1]['Charge']=int(Trailer2_FullBit[1:24],2)
        Peaks[1]['Max_Peak']=int(Trailer3_FullBit[18:32],2)
        Peaks[1]['Num_Peak_OB']=int(Trailer2_FullBit[24:28],2)
        Peaks[1]['Num_Peak_UB']=int(Trailer2_FullBit[28:32],2)
        Peaks[1]['Time_Peak']=int(Trailer3_FullBit[9:18],2)
        Peaks[1]['Time_Pulse_OB']=int(Trailer10_FullBit[10:21],2)
        Peaks[1]['Time_Pulse_UB']=int(Trailer3_FullBit[0:9],2)
        
        Peaks[2]['Charge']=int(Trailer4_FullBit[1:24],2)
        Peaks[2]['Max_Peak']=int(Trailer5_FullBit[18:32],2)
        Peaks[2]['Num_Peak_OB']=int(Trailer4_FullBit[24:28],2)
        Peaks[2]['Num_Peak_UB']=int(Trailer4_FullBit[28:32],2)
        Peaks[2]['Time_Peak']=int(Trailer5_FullBit[9:18],2)
        Peaks[2]['Time_Pulse_OB']=int(Trailer10_FullBit[21:31],2)
        Peaks[2]['Time_Pulse_UB']=int(Trailer5_FullBit[0:9],2)
        
        Peaks[3]['Charge']=int(Trailer6_FullBit[1:24],2)
        Peaks[3]['Max_Peak']=int(Trailer7_FullBit[18:32],2)
        Peaks[3]['Num_Peak_OB']=int(Trailer6_FullBit[24:28],2)
        Peaks[3]['Num_Peak_UB']=int(Trailer6_FullBit[28:32],2)
        Peaks[3]['Time_Peak']=int(Trailer7_FullBit[9:18],2)
        Peaks[3]['Time_Pulse_OB']=int(Trailer11_FullBit[0:10],2)
        Peaks[3]['Time_Pulse_UB']=int(Trailer7_FullBit[0:9],2)
        
        Peaks[4]['Charge']=int(Trailer8_FullBit[1:24],2)
        Peaks[4]['Max_Peak']=int(Trailer9_FullBit[18:32],2)
        Peaks[4]['Num_Peak_OB']=int(Trailer8_FullBit[24:28],2)
        Peaks[4]['Num_Peak_UB']=int(Trailer8_FullBit[28:32],2)
        Peaks[4]['Time_Peak']=int(Trailer9_FullBit[9:18],2)
        Peaks[4]['Time_Pulse_OB']=int(Trailer11_FullBit[10:21],2)
        Peaks[4]['Time_Pulse_UB']=int(Trailer9_FullBit[0:9],2)
         
        # if (i==0):
        #     Raw_Data_Frame[:] = Raw_data_aux[:]
        # else: 
        #     Raw_Data_Frame = numpy.column_stack((Raw_Data_Frame, Raw_data_aux)) 
            

plt.plot(Raw_Data_Frame,'b')
plt.plot(Header['Baseline']*numpy.ones(1024),'r')
plt.grid()



thing.close()

