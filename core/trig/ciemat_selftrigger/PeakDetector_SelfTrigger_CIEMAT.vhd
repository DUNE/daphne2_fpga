----------------------------------------------------------------------------------
-- Company: CIEMAT
-- Engineer: Ignacio López de Rego Benedi
-- 
-- Create Date: 11.04.2024 14:08:05
-- Design Name: 
-- Module Name: PeakDetector_SelfTrigger_CIEMAT - Behavioral
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
--use ieee.std_logic_1164.all;
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

------------------------- DESCRIPTION -----------------------------------
-- This Block DETECTS peaks of a light pulse and activates a SELF-TRIGGER when required.   
--      + The detection is done with a CONFIGURABLE threshold over the slope signal:  x(n) - x(n-1) or   [x(n) - x(n-2)] / 2 depending on the configuration.
--      + Activate SELF_TRIGGER: Each detected peak / Only main (first) peaks (not those present in the undershoot)
--      + Posibility to activate Self-trigger to capture a waveforme that is not fully recorded in a data adquisition frame. 
--      + This block tends to be independent, so there is interface with PRIMITIVE CALCULATION Block


entity PeakDetector_SelfTrigger_CIEMAT is
port(
    clock:                          in  std_logic;                      -- AFE clock
    reset:                          in  std_logic;                      -- Reset signal. ACTIVE HIGH 
    din:                            in  std_logic_vector(13 downto 0);  -- Data coming from the Filter Block / Raw data from AFEs
    Sending_Data:                   in  std_logic;                      -- DATA is being sent. ACTIVE HIGH
    Config_Param:                   in  std_logic_vector(23 downto 0);  -- Config_Param[0] --> '0' = Peak detector as self-trigger  / '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
                                                                        -- Config_Param[1] --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames   
                                                                        --                 --> '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames
                                                                        -- Config_Param[2] --> '0' = Slope calculation with 16 consecutive samples --> x(n) - x(n-16)  / '1' = Slope calculation with 20 consecutive samples --> [x(n) - x(n-20)]  
                                                                        -- Config_Param[9 downto 3] --> Slope_Threshold for single PE (signed) 1(sign) + 6 bits, must be negative --> SINGLE PE to detect all peaks.
                                                                        -- Config_Param[23 downto 10] --> Slope_Threshold for TRIGGER (signed) 1(sign) + 13 bits, must be negative --> THRESHOLD FOR THE TRIGGER ALGOTRIHM.
    Interface_LOCAL_Primitves_IN:   in  std_logic_vector(23 downto 0);  -- Interface with Local Primitives calculation BLOCK --> DEPENDS ON SELF-TRIGGER ALGORITHM 
    Interface_LOCAL_Primitves_OUT:  out std_logic_vector(23 downto 0);  -- Interface with Local Primitives calculation BLOCK --> DEPENDS ON SELF-TRIGGER ALGORITHM 
    Self_trigger:                   out std_logic;                      -- ACTIVE HIGH when a Self-trigger events occurs
    Self_trigger_CFD:               out std_logic                       -- ACTIVE HIGH when a Self-trigger from CFD block occurs
);
end PeakDetector_SelfTrigger_CIEMAT;

architecture Behavioral of PeakDetector_SelfTrigger_CIEMAT is

-- CONSTANT FRACTION DISCRIMINATOR COMPONENT ---

COMPONENT Configurable_CFD is
port(
    clock:              in  std_logic;                       -- AFE clock
    reset:              in  std_logic;                       -- Reset signal. ACTIVE HIGH
    enable:             in  std_logic;                       -- Enable signal. ACTIVE HIGH
    trigger_threshold:  in  std_logic;                       -- ACTIVE HIGH when signal surpasses a threshold
    config_delay:       in  std_logic_vector(4 downto 0);    -- Delay config for the algorithm --> Delay over the original signal "din": 1 to 32 clk
                                                             -- "00000" = 0 clk
                                                             -- "11111" = 31 clk
    config_sign:        in  std_logic;                       -- Bit config describing the "din" signal --> Threshold over positive / negative signal
                                                             -- '0' --> Positive Signal
                                                             -- '1' --> Negative Signal
    din:                in  std_logic_vector(27 downto 0);   -- Input signal where the trigger over a threshold is performed
    trigger:            out std_logic                        -- Output trigger signal 
);
END component;

-- CONFIGURATION signals 
signal Config_Param_Reg :                   std_logic_vector(23 downto 0);
signal Main_Peak_Self_Trigger:              std_logic ; -- '0' = All detected peaks ACTIVATE self-trigger  / '1' = ONLY MAIN peaks ACTIVATE self-trigger(Undershoot peaks will not trigger)
signal Allow_PartialWavefrom_Self_Trigger:  std_logic ; --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames / '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames    
signal Slope_Config_Calculation:            std_logic ;-- '0' = Slope calculation with 2 consecutive samples --> x(n) - x(n-1)  / '1' = Slope calculation with 3 consecutive samples --> [x(n) - x(n-2)] / 2 
signal Slope_Threshold_PE:                  std_logic_vector(6 downto 0); -- Slope_Threshold for single PE (signed) 1(sign) + 6 bits, must be negative. 
signal Slope_Threshold_TRIGGER:             std_logic_vector(13 downto 0); -- Slope_Threshold for TRIGGER (signed) 1(sign) + 13 bits, must be negative. 
-- INTERFACE with LOCAL TRIGGER PRIMITVE calculation block signals 
signal Interface_LOCAL_Primitves_IN_reg:    std_logic_vector(23 downto 0);
signal Detection:                           std_logic; -- ACTIVE HIGH During detection and Local primitives calculation 
-- PEAK DETECTION signals
signal din_delay1, din_delay2, din_delay3, din_delay4, din_delay5, din_delay6, din_delay7, din_delay8, din_delay9, din_delay10: std_logic_vector (13 downto 0); -- Delayed values of the incomming signal
signal din_delay11, din_delay12, din_delay13, din_delay14, din_delay15, din_delay16, din_delay17, din_delay18, din_delay19, din_delay20: std_logic_vector (13 downto 0); -- Delayed values of the incomming signal
signal Slope_Current:                       std_logic_vector(13 downto 0) := (others=>'0'); -- Current value of slope
signal Slope_Current_Reg:                       std_logic_vector(13 downto 0) := (others=>'0'); -- Registered value of slope
signal Slope_Current_Aux:                   std_logic_vector(27 downto 0) := (others=>'0'); -- Current value of slope
signal Slope_select:                        std_logic_vector(14 downto 0) := (others=>'0'); -- Depending on the Slope calculatin signal which delayed signal to select x(n-16) or x(n-20)
signal Slope_Aux:                           std_logic_vector(14 downto 0) := (others=>'0'); -- Final value calculated. Depending on the Slope calculatin signal which delayed signal to select [x(n) - x(n-1)] or [x(n) - x(n-2)] / 2  
--signal Slope_Sign_Current, Slope_Sign_Previous: std_logic :='0'; -- sign of the slope noy and delayed 1 cycle. 

signal Peak_Current:                        std_logic :='0';-- ACTIVE HIGH when a single PE peak is detected. 
type Peak_State is   (Allow_Peak_Detection, Not_Allow_Peak_Detection);
signal CurrentState_Peak, NextState_Peak:   Peak_State; 
signal Allow_Peak:                          std_logic :='0';

signal Peak_Trigger:                        std_logic :='0';-- ACTIVE HIGH when a TRIGGER peak is detected. 
type Trigger_Peak_State is   (Trigger_Allow_Peak_Detection, Trigger_Not_Allow_Peak_Detection);
signal Trigger_CurrentState_Peak, Trigger_NextState_Peak:   Trigger_Peak_State; 
signal Trigger_Allow_Peak:                          std_logic :='0';
-- SELF-TRIGGER signals
signal self_trigger_aux:                    std_logic := '0'; -- Self-Trigger signal. ACTIVE HIGH

-- post reset stabilization signals --> 64 clk cylcles so all the delays are properly filled
signal Reset_Timer:                         integer:=64; -- 64 clk
signal Not_allow_Trigger:                   std_logic;
CONSTANT Reset_Timer_cnt :                  integer := 64; -- 64 clk

begin

----------------------- GET (Synchronous) AND UPDATE CONFIGURATION PARAMETERS     -----------------------

Get_Config_Params: process(clock)
begin
    if (clock'event and clock='1') then
        Config_Param_Reg <= Config_Param;
    end if;
end process Get_Config_Params;
-- Config_Param[0] --> '0' = Peak detector as self-trigger  / '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
-- Config_Param[1] --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames   
--                 --> '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames
-- Config_Param[2] --> '0' = Slope (More likely to be an Amplitude) calculation with 16 consecutive samples --> x(n) - x(n-1)  / '1' = Slope calculation with 20 consecutive samples --> [x(n) - x(n-20)] 
-- Config_Param[9 downto 3] --> Slope_Threshold for single PE (signed) 1(sign) + 6 bits, must be negative --> SINGLE PE to detect all peaks.
-- Config_Param[23 downto 10] --> Slope_Threshold for TRIGGER (signed) 1(sign) + 13 bits, must be negative --> THRESHOLD FOR THE TRIGGER ALGOTRIHM.
Main_Peak_Self_Trigger              <= Config_Param_Reg(0);
Allow_PartialWavefrom_Self_Trigger  <= Config_Param_Reg(1);
Slope_Config_Calculation            <= Config_Param_Reg(2);
Slope_Threshold_PE                  <= Config_Param_Reg(9 downto 3);
Slope_Threshold_TRIGGER             <= Config_Param_Reg(23 downto 10);

----------------------- PEAK DETECTOR    -----------------------

-- Slope Calculation --> Looking for the full SPE slope (Depending on filter ti takes between 16 and 20 clk tics to have it) 
-- [x(n) - x(n-16)]  or    [x(n) - x(n-20)]  
Slope_Aux <=std_logic_vector(signed('0' & din_delay1)- signed(Slope_select));
Slope_Calculation_Arithmetic: process(Slope_Config_Calculation, din_delay16, din_delay20)
begin
    if (Slope_Config_Calculation ='0') then
        Slope_select <= '0' & din_delay16; 
    else
        Slope_select <= '0' & din_delay20;
    end if;
end process Slope_Calculation_Arithmetic;

Slope_Calculation_Synch: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            din_delay1          <= din;
            din_delay2          <= din;
            din_delay3          <= din;
            din_delay4          <= din;
            din_delay5          <= din;
            din_delay6          <= din;
            din_delay7          <= din;
            din_delay8          <= din;
            din_delay9          <= din;
            din_delay10         <= din;
            din_delay11         <= din;
            din_delay12         <= din;
            din_delay13         <= din;
            din_delay14         <= din;
            din_delay15         <= din;
            din_delay16         <= din;
            din_delay17         <= din;
            din_delay18         <= din;
            din_delay19         <= din;
            din_delay20         <= din;
            Slope_Current       <= (others=>'0');
            Slope_Current_Reg   <= (others=>'0'); 
        else
            din_delay1          <= din;
            din_delay2          <= din_delay1;
            din_delay3          <= din_delay2;
            din_delay4          <= din_delay3;
            din_delay5          <= din_delay4;
            din_delay6          <= din_delay5;
            din_delay7          <= din_delay6;
            din_delay8          <= din_delay7;
            din_delay9          <= din_delay8;
            din_delay10         <= din_delay9;
            din_delay11         <= din_delay10;
            din_delay12         <= din_delay11;
            din_delay13         <= din_delay12;
            din_delay14         <= din_delay13;
            din_delay15         <= din_delay14;
            din_delay16         <= din_delay15;
            din_delay17         <= din_delay16;
            din_delay18         <= din_delay17;
            din_delay19         <= din_delay18;
            din_delay20         <= din_delay19;
            Slope_Current_Reg   <= Slope_Current;
            Slope_Current       <= Slope_Aux(13 downto 0);
        end if;
    end if;
end process Slope_Calculation_Synch;

Slope_Current_Aux <= std_logic_vector(resize(signed(Slope_Current),28));
-- PEAK DETECTOR
-- If Current_Slope <= Slope_Threshold_PE --> Peak_detected

Peak_Detection: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if (reset='1') then
            Peak_Current <= '0';
        else
            if((signed(Slope_Current)<=signed(std_logic_vector(resize(signed(Slope_Threshold_PE),14)))) and (Allow_Peak = '1')) then -- Calulate trigger signal based on a threshold over the Slope
                Peak_Current <= '1'; 
            else
                Peak_Current <= '0';
            end if;
        end if;
    end if;
end process Peak_Detection;

-- FSM ALLOW PEAK DETECTION. 
-- This Finite Sate Machine determines if peak detection is allowed or not. Avoids contious detection when slope is under a threshold. 
--      * Allow_Peak --> Peak detection is allowed 
--      * Not_Allow_Peak --> When a peak is detected, no more peaks are allowed until slope changes sign (from negative to positive)
--Next_State_Allow: process(CurrentState_Peak,Slope_Sign_Previous, Slope_Sign_Current, Slope_Current, Slope_Threshold)
Next_State_Allow: process(CurrentState_Peak, Slope_Current, Slope_Threshold_PE)
begin
    case CurrentState_Peak is
        when Allow_Peak_Detection =>
            if((signed(Slope_Current)<=signed(std_logic_vector(resize(signed(Slope_Threshold_PE),14))))) then
                NextState_Peak <= Not_Allow_Peak_Detection;
            else
                NextState_Peak <= Allow_Peak_Detection; 
            end if;
        when Not_Allow_Peak_Detection =>
            --if((Slope_Sign_Previous='1') and (Slope_Sign_Current='0')) then
            if(signed(Slope_Current)>(signed(std_logic_vector(resize(signed(Slope_Threshold_PE),14)))+5)) then
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

-- TRIGGER
-- If Current_Slope <= Slope_Threshold_TRIGGER --> Trigger_Peak_detected

Trigger_Peak_Detection: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if (reset='1') then
            Peak_Trigger <= '0';
        else
            if((signed(Slope_Current)<=signed(std_logic_vector(Slope_Threshold_TRIGGER))) and (Trigger_Allow_Peak = '1')) then -- Calulate trigger signal based on a threshold over the Slope
                Peak_Trigger    <= '1'; 
            else
                Peak_Trigger    <= '0';
            end if;
        end if;
    end if;
end process Trigger_Peak_Detection;

-- FSM ALLOW PEAK DETECTION. 
-- This Finite Sate Machine determines if peak detection is allowed or not. Avoids contious detection when slope is under a threshold. 
--      * Allow_Peak --> Peak detection is allowed 
--      * Not_Allow_Peak --> When a peak is detected, no more peaks are allowed until slope changes sign (from negative to positive)
--Next_State_Allow: process(CurrentState_Peak,Slope_Sign_Previous, Slope_Sign_Current, Slope_Current, Slope_Threshold)
Trigger_Next_State_Allow: process(Trigger_CurrentState_Peak, Slope_Current, Slope_Threshold_TRIGGER)
begin
    case Trigger_CurrentState_Peak is
        when Trigger_Allow_Peak_Detection =>
            if((signed(Slope_Current)<=signed(std_logic_vector(Slope_Threshold_TRIGGER)))) then
                Trigger_NextState_Peak <= Trigger_Not_Allow_Peak_Detection;
            else
                Trigger_NextState_Peak <= Trigger_Allow_Peak_Detection; 
            end if;
        when Trigger_Not_Allow_Peak_Detection =>
            --if((Slope_Sign_Previous='1') and (Slope_Sign_Current='0')) then
            if(signed(Slope_Current)>(signed(std_logic_vector(Slope_Threshold_TRIGGER))+5)) then
                Trigger_NextState_Peak <= Trigger_Allow_Peak_Detection;
            else
                Trigger_NextState_Peak <= Trigger_Not_Allow_Peak_Detection;
            end if;        
    end case;
end process Trigger_Next_State_Allow;

Trigger_FFs_Allow: process(clock, reset)
begin
    if (reset='1')  then
        Trigger_CurrentState_Peak <= Trigger_Allow_Peak_Detection;
    elsif(clock'event and clock='1') then
        Trigger_CurrentState_Peak <= Trigger_NextState_Peak;
    end if;
end process Trigger_FFs_Allow;

Trigger_Output_Allow: process(Trigger_CurrentState_Peak)
begin
    case Trigger_CurrentState_Peak is
        when Trigger_Allow_Peak_Detection => 
            Trigger_Allow_Peak <= '1';
        when Trigger_Not_Allow_Peak_Detection =>        
            Trigger_Allow_Peak <= '0';        
    end case;
end process Trigger_Output_Allow;



----------------------- SELF TRIGGER LOGIC    -----------------------

self_trigger_aux <= (((Peak_Trigger) and (not(Main_Peak_Self_Trigger))) or ((Main_Peak_Self_Trigger) and (Peak_Trigger) and (not(Detection))) or ((Allow_PartialWavefrom_Self_Trigger) and (Detection) and (not(Sending_Data))))and (not(Not_allow_Trigger));
Self_trigger <= self_trigger_aux;
----------------------- CFD LOGIC             -----------------------

CFD: Configurable_CFD
    PORT MAP (
        clock                   => clock,
        reset                   => reset,
        enable                  => '1',
        trigger_threshold       => self_trigger_aux,
        config_delay            => "11010",
        config_sign             => '1',
        din                     => Slope_Current_Aux,
        trigger                 => Self_trigger_CFD);

----------------------- INTERFACE WITH LOCAL PRIMITIVES CALCULATION BLOCK    -----------------------

-- Data coming from LOCAL PRIMITVE Calculation Block
Get_Interface_Params: process(clock)
begin
    if (clock'event and clock='1') then
        Interface_LOCAL_Primitves_IN_reg <= Interface_LOCAL_Primitves_IN;
    end if;
end process Get_Interface_Params;
-- Interface_LOCAL_Primitves_IN[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
-- Interface_LOCAL_Primitves_IN[3 downto 1] --> TBD
Detection <= Interface_LOCAL_Primitves_IN_reg(0);
-- Data being sent to LOCAL PRIMITVE Calculation Block
Interface_LOCAL_Primitves_OUT(0) <= Peak_Current;
--Interface_LOCAL_Primitves_OUT(1) <= Sending;
--Interface_LOCAL_Primitves_OUT(2) <= Previous_Frame;
Interface_LOCAL_Primitves_OUT(14 downto 1) <= Slope_Current;
Interface_LOCAL_Primitves_OUT(23 downto 15) <= (others=>'0');

----------------------- TIMER AFTER RESET       -----------------------

Timer_Reset_Stage: process(clock, reset)
begin
    if (clock'event and clock='1') then
        if(reset='1')then
            Reset_Timer <= Reset_Timer_cnt;
            Not_allow_Trigger <= '1';
        else
            if(Reset_Timer>0)then
                Reset_Timer <= Reset_Timer - 1;
                Not_allow_Trigger <= '1';
            else
                Reset_Timer <= Reset_Timer;
                Not_allow_Trigger <= '0';
            end if;
        end if;
    end if;
end process Timer_Reset_Stage;

end Behavioral;
