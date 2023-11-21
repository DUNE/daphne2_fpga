----------------------------------------------------------------------------------
-- Company: CIEMAT
-- Engineer: Ignacio López de Rego Benedi
-- 
-- Create Date: 14.09.2023 12:47:33
-- Design Name: 
-- Module Name: Self_Trig_CIEMAT - Self_Trig_CIEMAT_Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Self_Trig_CIEMAT is
port(
    clock: in  std_logic;                           -- AFE clock 
    din:   in  std_logic_vector(13 downto 0);       -- Raw AFE data
    Config_Param: in std_logic_vector(63 downto 0);    -- Trigger threshold relative to baseline
    triggered: out std_logic;                       -- Self-Trigger Signal. Active HIGH
    Data_Available: out std_logic;                  -- Primitives calculation available. Active HIGH
    Time_Peak: out  std_logic_vector(7 downto 0);   -- Time in Samples to achieve de Max peak
    Time_Pulse_UB: out  std_logic_vector(9 downto 0);  -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
    Time_Pulse_OB: out  std_logic_vector(10 downto 0);  -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
    Max_Peak: out  std_logic_vector(15 downto 0);    -- Amplitude in ADC counts od the peak
    Charge: out  std_logic_vector(19 downto 0);      -- Charge of the light pulse (without undershoot) in ADC*samples
    Number_Peaks_UB: out  std_logic_vector(3 downto 0);-- Number of peaks detected when signal is UNDER BASELINE (without undershoot). 
    Number_Peaks_OB: out  std_logic_vector(3 downto 0);-- Number of peaks detected when signal is OVER BASELINE (undershoot).     
    -- Variables that will be removed before debugging
    peak: out std_logic;                            -- Peak detection. Active HIGH
    trigsample: out std_logic_vector(13 downto 0);  -- The sample that caused the trigger
    slope: out std_logic_vector(13 downto 0);       -- Actual value of slope
    amplitude: out std_logic_vector(14 downto 0);   -- Actual value of amplitude
    baseline: out std_logic_vector(13 downto 0)     -- Baseline that caused the trigger
);
end Self_Trig_CIEMAT;

architecture Self_Trig_CIEMAT_Behavioral of Self_Trig_CIEMAT is

-- The algorithm just needs the actual and previous values of: AFE signal, Filtered AFE signal, Baseline, Amplitude, Slope and Trigger signal.
signal reset: std_logic :='0'; -- Reset Signal. Active HIGH
signal AFE_Current, AFE_Previous: std_logic_vector(15 downto 0) := (others=>'0');
signal Config_Param_Reg: std_logic_vector(63 downto 0) := (others=>'0');
-- Config_Param_Reg (15 downto 0) --> Amplitude_Threshold (Signed) 16 bits.
-- Config_Param_Reg (31 downto 16) --> Slope_Threshold (signed) 16 bits, must be negative.
-- Config_Param_Reg (42 down to 32) --> Time_Pulse_OB_Estimation (unsigned) 11 bits, time of undershoot.
-- Config_Param_Reg (63) --> Logic RESET
signal AFE_Filtered_Current: std_logic_vector(15 downto 0) := (others=>'0');
signal AFE_Filtered_Add: std_logic_vector(16 downto 0) := (others=>'0');
signal Baseline_Current, Baseline_Previous, Baseline_Previous2,Baseline_Previous3, Baseline_Aux1,Baseline_Aux2: std_logic_vector(15 downto 0) := (others=>'0');
signal Baseline_Add: std_logic_vector(15 downto 0) := (others=>'0');
signal Amplitude_Current, Amplitude_Aux: std_logic_vector(15 downto 0) := (others=>'0');
signal Amplitude_Threshold: signed (15 downto 0):= (others=>'0');-- :=to_signed(0,16); --Threshold over the slope to detect peaks.
signal Slope_Current, Slope_Aux: std_logic_vector(15 downto 0) := (others=>'0');
signal Slope_Threshold: signed (15 downto 0):= (others=>'0');-- :=to_signed(-12,16); --Threshold over the slope to detect peaks.  
signal Slope_Sign_Current, Slope_Sign_Previous: std_logic :='0';
signal Peak_Current: std_logic :='0';
-- Primitve calculation
signal Time_Peak_Current:   std_logic_vector(7 downto 0):= (others=>'0');   -- Time in Samples to achieve de Max peak
signal Time_Pulse_UB_Current: std_logic_vector(9 downto 0):= (others=>'0');    -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
signal Time_Pulse_OB_Current: std_logic_vector(10 downto 0):= (others=>'0');    -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
signal Time_Pulse_OB_Estimation: unsigned (10 downto 0):= (others=>'0');-- :=to_unsigned(344,11); -- Time in Samples of the UNDERSHOOT (Experiment Results) --> 5,5us with sampling 16 ns
signal Max_Peak_Current:   std_logic_vector(15 downto 0):= (others=>'0');    -- Amplitude in ADC counts od the peak
signal Charge_Current:   std_logic_vector(19 downto 0):= (others=>'0');      -- Charge of the light pulse (without undershoot) in ADC*samples
signal Number_Peaks_UB_Current:   std_logic_vector(3 downto 0):= (others=>'0');-- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
signal Number_Peaks_OB_Current:   std_logic_vector(3 downto 0):= (others=>'0');-- Number of peaks detected when signal is OVER BASELINE (undershoot).  

-- FSM: This Finite Sate Machine determines if peak detection is allowed or not. Avoids contious detection when slope is under a threshold. 
--      * Allow_Peak --> Peak detection is allowed 
--      * Not_Allow_Peak --> When a peak is detected, no more peaks are allowed until slope changes sign (from negative to positive)
type Peak_State is   (Allow_Peak_Detection, Not_Allow_Peak_Detection);
signal CurrentState_Peak, NextState_Peak: Peak_State;
signal Allow_Peak: std_logic :='0';

-- FSM: This Finite Sate Machine determines if there is a light detection or not.
--      * No Detection --> Continous Baseline Calculation 
--      * Detection_UB --> Baseline is constant, Primitives calculation (Max _Amplitude, Time to max, Charge, Width_UB, number of pekas UB)
--      * Detection_OB --> Baseline is constant, Primitives calculation (Width_OB, number of pekas OB)
--      * Data --> Shows data of primitives calculated in previous stage 
type Detection_State is   (No_Detection, Detection_UB, Detection_OB,Data);
signal CurrentState_Detection, NextState_Detection: Detection_State;
signal Peak_Detection: std_logic :='0';

begin

-- Combinational operations 
AFE_Filtered_Add <= std_logic_vector(unsigned("0" & AFE_Current) + unsigned("0" & AFE_Previous));
Baseline_Add <= std_logic_vector(signed(AFE_Filtered_Current)- signed(Baseline_Current));
Baseline_Aux1 <= std_logic_vector(signed(Baseline_Current) + signed(std_logic_vector(resize(signed(Baseline_Add(15 downto 3)),16))));
Amplitude_Aux <= std_logic_vector(signed(AFE_Filtered_Current)- signed(Baseline_Previous3));
--Slope_Aux <=std_logic_vector(signed(Amplitude_Aux)- signed(Amplitude_Current));
Slope_Aux <=std_logic_vector(signed(AFE_Filtered_Add(16 downto 1))- signed(AFE_Filtered_Current));
triggered <= ((Peak_Current) and (not(Peak_Detection)));

PEAK_FINDER: process(clock, reset, din, Amplitude_Current, Slope_Current,Peak_Detection, Allow_Peak)
begin
    if (clock'event and clock='1') then
        AFE_Current <= std_logic_vector(resize(unsigned(din),16));
        AFE_Previous <= AFE_Current;
        Config_Param_Reg <= Config_Param;
        Slope_Sign_Previous <= Slope_Sign_Current;
        if (reset='1') then
            -- Algorithm signals
            AFE_Filtered_Current <= std_logic_vector(resize(unsigned(din),16));
            Baseline_Current <= std_logic_vector(resize(unsigned(din),16));
            Baseline_Previous <= std_logic_vector(resize(unsigned(din),16));
            Baseline_Previous2 <= std_logic_vector(resize(unsigned(din),16));
            Baseline_Previous3 <= std_logic_vector(resize(unsigned(din),16));
            Amplitude_Current <= (others=>'0'); 
            Slope_Current <= (others=>'0');
            Slope_Sign_Current <= '0'; 
            Slope_Sign_Previous <= '0'; 
            -- Module Outputs
            trigsample <= (others=>'0'); 
            slope <= (others=>'0'); 
            amplitude <= (others=>'0');         
            baseline <= din; 
            
        
        else
            -- Saving previous cycle data
            baseline <= Baseline_Previous3(13 downto 0); -- previous sample                 
            amplitude <= Amplitude_Current(14 downto 0); -- previous sample
            slope <= Slope_Current(13 downto 0); -- previous sample
            peak <= Peak_Current; -- previous sample
            
            -- Actual values calculation
            AFE_Filtered_Current <= AFE_Filtered_Add(16 downto 1); -- Filtering the AFE signal
            if (Peak_Detection='1')then -- Baseline calculation. Baseline remains constant when pulse is detected;
                Baseline_Current <= Baseline_Previous3;
                Baseline_Previous <= Baseline_Previous3;
                Baseline_Previous2 <= Baseline_Previous3;
                Baseline_Previous3 <= Baseline_Previous3;
            else
                Baseline_Previous3 <= Baseline_Previous2;
                Baseline_Previous2 <= Baseline_Previous;
                Baseline_Previous <= Baseline_Current;
                Baseline_Current <= Baseline_Aux1;                
            end if;
            Amplitude_Current <= Amplitude_Aux; -- Amplitude calculation (Removes baseline to the filtered data)
            Slope_Current <= Slope_Aux; -- Slope calculation (Calculate the variation between successive samples of amplitude)
            Slope_Sign_Current <= Slope_Aux(15);
            if((signed(Slope_Current)<=Slope_Threshold) and (Allow_Peak = '1')) then -- Calulate trigger signal based on a threshold over the Slope
                Peak_Current <= '1'; 
            else
                Peak_Current <= '0';
            end if;
        end if;
    end if;
end process PEAK_FINDER;

-- FSM ALLOW PEAK DETECTION. 
Next_State_Allow: process(CurrentState_Peak,Slope_Sign_Previous, Slope_Sign_Current, Slope_Current, Slope_Threshold)
begin
    case CurrentState_Peak is
        when Allow_Peak_Detection =>
            if(signed(Slope_Current)<=Slope_Threshold)then
                NextState_Peak <= Not_Allow_Peak_Detection;
            else
                NextState_Peak <= Allow_Peak_Detection; 
            end if;
        when Not_Allow_Peak_Detection =>
            if((Slope_Sign_Previous='1') and (Slope_Sign_Current='0')) then
                NextState_Peak <= Allow_Peak_Detection;
            else
                NextState_Peak <= Not_Allow_Peak_Detection;
            end if;        
    end case;
end process Next_State_Allow;

FFs_Allow: process(clock, reset)
begin
    if (reset='1')  then
        CurrentState_Peak <= Allow_Peak_Detection;
    elsif(clock'event and clock='1') then
        CurrentState_Peak <= NextState_Peak;
    end if;
end process FFs_Allow;

Output_Allow: process(CurrentState_Peak)
begin
    case CurrentState_Peak is
        when Allow_Peak_Detection => 
            Allow_Peak <= '1';
        when Not_Allow_Peak_Detection =>        
            Allow_Peak <= '0';        
    end case;
end process Output_Allow;

-- FSM DETECTION. 
Next_State_Detection: process(CurrentState_Detection, Peak_Current, Amplitude_Current,Time_Pulse_OB_Current,Time_Pulse_OB_Estimation,Amplitude_Threshold)
begin
    case CurrentState_Detection is
        when No_Detection =>
            if(Peak_Current='1')then
                NextState_Detection <= Detection_UB;
            else
                NextState_Detection <= No_Detection; 
            end if;
        when Detection_UB =>
            if(signed(Amplitude_Current)>=Amplitude_Threshold) then
                NextState_Detection <= Detection_OB;
            else
                NextState_Detection <= Detection_UB;
            end if;
        when Detection_OB =>
            if ((signed(Amplitude_Current)<=Amplitude_Threshold) and (unsigned(Time_Pulse_OB_Current)>=Time_Pulse_OB_Estimation)) then
                NextState_Detection <= Data;
            else
                NextState_Detection <= Detection_OB;
            end if;
        when Data =>
            if(Peak_Current='1')then
                NextState_Detection <= Detection_UB;
            else
                NextState_Detection <= No_Detection; 
            end if;        
    end case;
end process Next_State_Detection;

FFs_Detection: process(clock, reset, Amplitude_Current, Peak_Current)
begin
    if (reset='1')  then
        CurrentState_Detection  <= No_Detection;                 -- Primitives calculation available. Active HIGH
        Time_Peak_Current       <= (others=>'0');       -- Time in Samples to achieve de Max peak
        Time_Pulse_UB_Current      <= (others=>'0');       -- Time in Samples of the light pulse (without undershoot)
        Time_Pulse_OB_Current      <= (others=>'0'); 
        Max_Peak_Current        <= (others=>'0');       -- Amplitude in ADC counts od the peak
        Charge_Current          <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
        Number_Peaks_UB_Current    <= (others=>'0');
        Number_Peaks_OB_Current    <= (others=>'0');
    elsif(clock'event and clock='1') then
        CurrentState_Detection <= NextState_Detection;
        if (CurrentState_Detection=No_Detection) then               -- Primitives calculation available. Active HIGH
            Time_Peak_Current       <= (others=>'0');       -- Time in Samples to achieve de Max peak
            Time_Pulse_UB_Current      <= "0000000001";       -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB_Current      <= "00000000001"; 
            Max_Peak_Current        <= (others=>'0');       -- Amplitude in ADC counts od the peak
            Charge_Current          <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB_Current    <= "0001";
            Number_Peaks_OB_Current    <= "0000";
        elsif(CurrentState_Detection=Detection_UB) then
            Time_Pulse_UB_Current <= std_logic_vector(unsigned(Time_Pulse_UB_Current) + to_unsigned(1,10));
            Charge_Current<= std_logic_vector(signed(Charge_Current) - signed(Amplitude_Current));
            if (signed(Max_Peak_Current)<= (- signed(Amplitude_Current))) then 
                Time_Peak_Current <= Time_Pulse_UB_Current(7 downto 0); 
                Max_Peak_Current <= std_logic_vector(- signed(Amplitude_Current)); 
            else
                Time_Peak_Current <= Time_Peak_Current; 
                Max_Peak_Current <= Max_Peak_Current; 
            end if;
            
            if (Peak_Current='1') then 
                Number_Peaks_UB_Current <= std_logic_vector(unsigned(Number_Peaks_UB_Current) + to_unsigned(1,4)); 
            else
                Number_Peaks_UB_Current <= Number_Peaks_UB_Current; 
            end if;
        elsif(CurrentState_Detection=Detection_OB) then
            Time_Pulse_OB_Current <= std_logic_vector(unsigned(Time_Pulse_OB_Current) + to_unsigned(1,10));            
            if (Peak_Current='1') then 
                Number_Peaks_OB_Current <= std_logic_vector(unsigned(Number_Peaks_OB_Current) + to_unsigned(1,4)); 
            else
                Number_Peaks_OB_Current <= Number_Peaks_OB_Current; 
            end if;
        end if;
    end if;
end process FFs_Detection;

Output_Detection: process(CurrentState_Detection,Time_Peak_Current,Time_Pulse_UB_Current, Time_Pulse_OB_Current,Max_Peak_Current, Charge_Current, Number_Peaks_UB_Current,Number_Peaks_OB_Current)
begin
    case CurrentState_Detection is
        when No_Detection => 
            Peak_Detection <= '0';
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');    -- Time in Samples to achieve de Max peak
            Time_Pulse_UB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Max_Peak <= (others=>'0');    -- Amplitude in ADC counts od the peak
            Charge <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0'); -- Number of peaks detected.
            Number_Peaks_OB<= (others=>'0'); -- Number of peaks detected.   
        when Detection_UB =>        
            Peak_Detection <= '1'; 
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');    -- Time in Samples to achieve de Max peak
            Time_Pulse_UB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Max_Peak <= (others=>'0');    -- Amplitude in ADC counts od the peak
            Charge <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0'); -- Number of peaks detected. 
            Number_Peaks_OB<= (others=>'0'); -- Number of peaks detected. 
        when Detection_OB =>        
            Peak_Detection <= '1'; 
            Data_Available <= '0';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= (others=>'0');    -- Time in Samples to achieve de Max peak
            Time_Pulse_UB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB <= (others=>'0');   -- Time in Samples of the light pulse (without undershoot)
            Max_Peak <= (others=>'0');    -- Amplitude in ADC counts od the peak
            Charge <= (others=>'0');       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= (others=>'0'); -- Number of peaks detected.
            Number_Peaks_OB<= (others=>'0'); -- Number of peaks detected.  
       when Data => 
            Peak_Detection <= '0';
            Data_Available <= '1';                  -- Primitives calculation available. Active HIGH
            Time_Peak <= Time_Peak_Current;    -- Time in Samples to achieve de Max peak
            Time_Pulse_UB <= Time_Pulse_UB_Current;   -- Time in Samples of the light pulse (without undershoot)
            Time_Pulse_OB <= Time_Pulse_OB_Current;   -- Time in Samples of the light pulse (without undershoot)
            Max_Peak <= Max_Peak_Current;    -- Amplitude in ADC counts od the peak
            Charge <= Charge_Current;       -- Charge of the light pulse (without undershoot) in ADC*samples
            Number_Peaks_UB<= Number_Peaks_UB_Current; -- Number of peaks detected.
            Number_Peaks_OB<= Number_Peaks_OB_Current; -- Number of peaks detected.         
    end case;
end process Output_Detection;

-- UPDATE CONFIG PARAMETERS 
Update_Config_Params: process(Config_Param_Reg)
begin
-- Config_Param_Reg (15 downto 0) --> Amplitude_Threshold (Signed) 16 bits.
-- Config_Param_Reg (31 downto 16) --> Slope_Threshold (signed) 16 bits, must be negative.
-- Config_Param_Reg (42 down to 32) --> Time_Pulse_OB_Estimation (unsigned) 11 bits, time of undershoot.
-- Config_Param_Reg (63) --> Logic RESET
Amplitude_Threshold <= signed(Config_Param_Reg (15 downto 0));
Slope_Threshold <= signed(Config_Param_Reg (31 downto 16));
Time_Pulse_OB_Estimation <= unsigned(Config_Param_Reg (42 downto 32));
reset <= Config_Param_Reg (63); 

end process Update_Config_Params;


end Self_Trig_CIEMAT_Behavioral;
