-- trig_prim_calc.vhd
-- local primitive calculation module for the self trigger
--
-- This module is a modified version of the CIEMAT's local primitive trigger calculations
-- it changes a few parts of the calculation method in order to match the self trigger based on
-- the matching trigger designed at the EIA University.
-- All credit of the base of the design goes to Ignacio Lopez from CIEMAT
--
-- Ignacio Lopez de Rego Benedi <Ignacio.LopezdeRego@ciemat.es> & Daniel Avila Gomez <daniel.avila@eia.edu.co>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trig_prim_calc is
port ( 
    reset: in std_logic; -- reset signal. Active HIGH
    clock: in std_logic; -- AFE clock 62.500 MHz
    --din: in std_logic_vector(13 downto 0); -- AFE filtered data
    din_processed: in std_logic_vector(13 downto 0); -- AFE filtered data
    din_processed_mm: in std_logic_vector(13 downto 0); -- moving average of the AFE filtered data (64 samples window size)
    self_trigger: in std_logic; -- self trigger signal coming from the peak detector module
--    baseline: in std_logic_vector(13 downto 0); -- current calculated baseline (using Milano's lpf) of the signal
    interface_local_primitives_in: in  std_logic_vector(28 downto 0); -- interface with Local Primitives calculation block --> set for matching trigger self trigger algorithm 
    interface_local_primitives_out: out std_logic_vector(28 downto 0); -- interface with Local Primitives calculation block --> set for matching trigger self trigger algorithm 
    data_available: out std_logic; -- active HIGH when local primitives are done being calculated
    time_peak: out std_logic_vector(8 downto 0); -- time in samples to achieve the max peak
    time_pulse_ub: out std_logic_vector(8 downto 0); -- amount of time in samples where the light pulse signal is Under Baseline (without undershoot)
    time_pulse_ob: out std_logic_vector(9 downto 0); -- amount of time in samples where the light pulse signal is Over Baseline (undershoot)
    max_peak: out std_logic_vector(13 downto 0); -- amplitude in ADC counts of the peak
    charge: out std_logic_vector(22 downto 0); -- charge of the light pulse (without undershoot) in ADC*samples
    number_peaks_ub: out std_logic_vector(3 downto 0); -- number of peaks detected when signal is Under Baseline (without undershoot) 
    number_peaks_ob: out std_logic_vector(3 downto 0); -- number of peaks detected when signal is Over Baseline (undershoot)
    amplitude: out std_logic_vector(13 downto 0) -- current amplitude of the signal
);
end trig_prim_calc;

architecture trig_prim_calc_arch of trig_prim_calc is

    -- baseline calculation signals
    signal amplitude_aux: std_logic_vector(13 downto 0) := (others => '0'); 
    signal amplitude_current: std_logic_vector(13 downto 0) := (others => '0'); 

    -- interface with self-trigger module signals
    signal interface_local_primitives_in_reg: std_logic_vector(28 downto 0);
    signal peak_current: std_logic := '0'; -- active HIGH when a peak is detected
    signal din_processed_delay1, din_processed_delay2, din_processed_delay3: std_logic_vector(13 downto 0) := (others => '0'); -- input data delays registers
    signal din_processed_mm_delay1, din_processed_mm_delay2, din_processed_mm_delay3: std_logic_vector(13 downto 0) := (others => '0'); -- input data moving average delays registers
    signal xcorr_current: std_logic_vector(27 downto 0) := (others => '0'); -- real value of the correlation of the signal 

    -- local trigger primitives calculation FSM signals
    type detection_state_type is (no_detection, detection_UB, detection_OB, detection_UB_2, data);
    signal current_state, next_state: detection_state_type;
    signal peak_detection: std_logic := '0';
    signal detection_time: integer := 2048; 
    signal event_length: integer := 1024; -- event length should not take more than a full window
    constant min_time_undershoot: integer := 100; -- 5*Minimum_Time_UB, 1600 ns
    constant min_event_length: integer := 24; -- at least 24 consecutive samples Under the baseline
    constant base_event_length: integer := 0; -- event length initial value
    constant max_detection_time : integer := 2048; -- maximun time allowed in detection mode --> 2 frames (2*1024). 
    
    -- local trigger primitives calculation main signals
    signal last_positive_time: std_logic_vector(8 downto 0) := (others => '0');
    signal last_known_positive_charge: std_logic_vector(22 downto 0) := (others => '0');
    signal time_peak_current: std_logic_vector(8 downto 0) := (others => '0'); -- time in Samples to achieve the Max peak
    signal time_pulse_UB_current: std_logic_vector(8 downto 0) := (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
    signal time_pulse_OB_current: std_logic_vector(9 downto 0) := (others => '0'); -- time in Samples where the light pulse signal is Over the baseline (undershoot)
    signal time_pulse_UB_2_current: std_logic_vector(9 downto 0) := (others => '0'); -- time in Samples where the light pulse signal is Under the baseline for the second time
    signal max_peak_current: std_logic_vector(13 downto 0) := (others => '0'); -- amplitude in ADC counts of the peak
    signal charge_current: std_logic_vector(22 downto 0) := (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
    signal number_peaks_UB_current: std_logic_vector(3 downto 0) := (others => '0'); -- number of peaks detected when signal is Under baseline (without undershoot)  
    signal number_peaks_OB_current: std_logic_vector(3 downto 0) := (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)

begin

    -- baseline calculation process
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- baseline arithmetic calculations    
--    amplitude_aux <= std_logic_vector(signed('0' & din) - signed('0' & baseline));
    amplitude_aux <= std_logic_vector(signed(din_processed));
    amplitude <= amplitude_current; -- TO BE REMOVED AFTER DEBUGGING
    
    -- baseline delays
    baseline_amplitude_proc: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                amplitude_current <= (others=>'0');  
            else
                amplitude_current <= amplitude_aux;
            end if;
        end if;
    end process baseline_amplitude_proc;

    -- local primitives calculation
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- FSM DETECTION: This Finite Sate Machine determines if there is a light detection or not
    --      * No_Detection --> Continous Baseline Calculation 
    --      * Detection_UB --> Baseline is constant, Primitives calculation (Max _Amplitude, Time to max, Charge, Width_UB, number of peaks UB)
    --      * Detection_OB --> Baseline is constant, Primitives calculation (Width_OB, number of peaks OB)
    --      * Detection_UB_2 --> Baseline is constant. Only the time during this stage is calculated
    --      * Data --> Shows data of primitives calculated in previous stage  
    
    -- process to sync change the states of the FSM
    reg_states: process(clock, reset, next_state)
    begin         
        if (reset='1') then
            current_state <= no_detection;
        elsif rising_edge(clock) then
            current_state <= next_state;
        end if;
    end process reg_states;
    
    -- process to define why the states change
    mod_state: process(current_state, self_trigger, event_length, amplitude_current, time_pulse_OB_current, time_pulse_UB_2_current, detection_time, peak_current, din_processed, din_processed_mm_delay1, din_processed_mm_delay2, din_processed_mm_delay3) 
    begin
        next_state <= current_state; -- declare default state for next_state to avoid latches, default is to stay in current state
        case (current_state) is
            when no_detection =>
                if (self_trigger='1') then
                    next_state <= detection_UB;
                end if;
            when detection_UB =>
                if ( ( ( signed(din_processed_mm_delay1)>0 ) and ( signed(din_processed_mm_delay2)<=0 ) and ( signed(din_processed_mm_delay3)<0 ) ) 
                       or ( ( signed(din_processed)>=0 ) and ( event_length>=min_event_length ) ) ) then
                    next_state <= detection_OB;
                elsif (detection_time<=0) then
                    next_state <= no_detection;                    
                end if;
            when Detection_OB => 
                if ( ( signed(din_processed_mm_delay1)<=0 ) and ( signed(din_processed_mm_delay2)<=0 ) and ( signed(din_processed_mm_delay3)<=0 )                         
                       and ( signed(din_processed_delay3)>=0 ) and ( signed(din_processed_delay2)>=0 ) and ( signed(din_processed_delay1)<0 )
                       and ( unsigned(time_pulse_OB_current)>=min_time_undershoot ) ) then
                    next_state <= detection_UB_2;
                elsif (detection_time<=0) then
                    next_state <= no_detection;
                end if;
            when detection_UB_2 => 
                if ( ( signed(din_processed_mm_delay1)>=0 ) and ( signed(din_processed_mm_delay2)<=0 ) and ( signed(din_processed_mm_delay3)<0 )
                       and ( unsigned(time_pulse_UB_2_current)>=min_time_undershoot ) ) then
                    next_state <= data;
                elsif (detection_time<=0) then
                    next_state <= no_detection;
                end if;  
            when data =>
                if (self_trigger='1') then
                    next_state <= detection_UB;
                else
                    next_state <= no_detection; 
                end if;   
            when others =>
                -- do nothing     
        end case;
    end process mod_state;   
    
    -- finite state machine outputs (calculated primitives)
    do_states: process(current_state, time_pulse_OB_current, max_peak_current, number_peaks_UB_current, number_peaks_OB_current)
    begin
        case (current_state) is
            when no_detection => 
                peak_detection <= '0';
                data_available <= '0'; -- primitives calculation available. Active HIGH
                time_peak <= (others => '0'); -- time in Samples to achieve the Max peak
                time_pulse_ub <= (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= (others => '0'); -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= (others => '0'); -- amplitude in ADC counts of the Max peak
                charge <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_ub <= (others => '0'); -- number of peaks detected when signal is Uder baseline (without undershoot)
                number_peaks_ob <= (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)
            when detection_UB =>        
                peak_detection <= '1'; 
                data_available <= '0'; -- primitives calculation available. Active HIGH
                time_peak <= (others => '0'); -- time in Samples to achieve the Max peak
                time_pulse_ub <= (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= (others => '0'); -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= (others => '0'); -- amplitude in ADC counts of the Max peak
                charge <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_ub <= (others => '0'); -- number of peaks detected when signal is Uder baseline (without undershoot)
                number_peaks_ob <= (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)       
            when detection_OB =>        
                peak_detection <= '1'; 
                data_available <= '0'; -- primitives calculation available. Active HIGH
                time_peak <= (others => '0'); -- time in Samples to achieve the Max peak
                time_pulse_ub <= (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= (others => '0'); -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= (others => '0'); -- amplitude in ADC counts of the Max peak
                charge <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_ub <= (others => '0'); -- number of peaks detected when signal is Uder baseline (without undershoot)
                number_peaks_ob <= (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)      
            when detection_UB_2 =>        
                peak_detection <= '1'; 
                data_available <= '0'; -- primitives calculation available. Active HIGH
                time_peak <= (others => '0'); -- time in Samples to achieve the Max peak
                time_pulse_ub <= (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= (others => '0'); -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= (others => '0'); -- amplitude in ADC counts of the Max peak
                charge <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_ub <= (others => '0'); -- number of peaks detected when signal is Uder baseline (without undershoot)
                number_peaks_ob <= (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)      
           when data => 
                peak_detection <= '0';
                data_available <= '1'; -- primitives calculation available. Active HIGH
                time_peak <= std_logic_vector(unsigned(time_peak_current) - unsigned(last_positive_time)); -- time in Samples to achieve the Max peak
                time_pulse_ub <= std_logic_vector(unsigned(time_pulse_UB_current) - unsigned(last_positive_time)); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= time_pulse_OB_current; -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= std_logic_vector(- signed(max_peak_current(13 downto 0))); -- amplitude in ADC counts of the Max peak
                charge <= std_logic_vector(unsigned(charge_current) - unsigned(last_known_positive_charge)); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_UB <= std_logic_vector(unsigned(number_peaks_UB_current) - 1); -- number of peaks detected when signal is Uder baseline (without undershoot)  
                number_peaks_OB <= number_peaks_OB_current; -- number of peaks detected when signal is Over baseline (undershoot)                 
            when others =>
                -- just in case...
                peak_detection <= '0';
                data_available <= '0'; -- primitives calculation available. Active HIGH
                time_peak <= (others => '0'); -- time in Samples to achieve the Max peak
                time_pulse_ub <= (others => '0'); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
                time_pulse_ob <= (others => '0'); -- time in Samples where the light pulse signal is Over baseline (undershoot)
                max_peak <= (others => '0'); -- amplitude in ADC counts of the Max peak
                charge <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                number_peaks_ub <= (others => '0'); -- number of peaks detected when signal is Uder baseline (without undershoot)
                number_peaks_ob <= (others => '0'); -- number of peaks detected when signal is Over baseline (undershoot)
        end case;
    end process do_states;
    
    -- signal study process
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- used to store important values to allow the local primitives calculation
    val_calc_proc: process(clock, reset, current_state, next_state, amplitude_current, charge_current, detection_time, time_pulse_UB_current, peak_current, number_peaks_UB_current, time_pulse_OB_current, number_peaks_OB_current, time_pulse_UB_2_current) -- , event_length
    begin
        if (reset='1')  then
            event_length <= base_event_length; -- length of a supposed peak
            last_positive_time <= (others => '0'); -- last time where the signal was positive
            last_known_positive_charge <= (others => '0'); -- last known charge before the ignal got to positive values
            time_peak_current <= (others => '0'); -- time in Samples to achieve the Max peak
            time_pulse_UB_current <= (others => '0'); -- time in Samples of the light pulse (without undershoot)
            time_pulse_OB_current <= (others => '0');
            time_pulse_UB_2_current <= (others => '0'); 
            max_peak_current <= (others => '0'); -- amplitude in ADC counts od the peak
            charge_current <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
            number_peaks_UB_current <= (others => '0');
            number_peaks_OB_current <= (others => '0');
            detection_time <= max_detection_time;         
        else
            if rising_edge(clock) then
                if (current_state=no_detection) then               -- Primitives calculation available. Active HIGH
                    event_length <= base_event_length; -- length of a supposed peak
                    last_positive_time <= (others => '0'); -- last time where the signal was positive
                    last_known_positive_charge <= (others => '0'); -- last known charge before the ignal got to positive values
                    time_peak_current <= (others => '0'); -- time in Samples to achieve the Max peak
                    time_pulse_UB_current <= "000000001"; -- time in Samples of the light pulse (without undershoot)
                    time_pulse_OB_current <= "0000000001";
                    time_pulse_UB_2_current <= "0000000001"; 
                    max_peak_current <= (others => '0'); -- amplitude in ADC counts of the peak
                    charge_current <= (others => '0'); -- charge of the light pulse (without undershoot) in ADC*samples
                    number_peaks_UB_current <= "0001";
                    number_peaks_OB_current <= "0000";
                    detection_time <= max_detection_time; 
                elsif (current_state=detection_UB) then
                    -- the event is only recognized when the amplitude is negative, if the signal is positive, then the event counter should restart
                    if (signed(amplitude_current)<0) then
                        event_length <= event_length + 1;
                        -- the charge will be only increased when the date is under the baseline
                        charge_current <= std_logic_vector(signed(charge_current) - signed(amplitude_current));               
                    else
                        event_length <= base_event_length;
                    end if;
                    detection_time <= detection_time - 1;                
                    time_pulse_UB_current <= std_logic_vector(unsigned(time_pulse_UB_current) + 1);
                    
                    -- and when we are above the baseline
                    if ( ( signed(amplitude_current)>=0 ) and not(next_state=detection_OB) ) then
                        -- save the last positive amplitud we had so that we can recognize later this as a starting point of time to count
                        last_positive_time <= time_pulse_UB_current;
                        -- if the amplitude comes back to positive values, keep an idea of what the value of the charge is at this time
                        last_known_positive_charge <= charge_current;
                    end if;
                    
                    -- if a new minimum value is found, store it
                    if ( signed(max_peak_current) > signed(amplitude_current) ) then 
                        time_peak_current <= time_pulse_UB_current; 
                        max_peak_current <= std_logic_vector(signed(amplitude_current));
                    end if;        
                    
                    -- another peak was detected, add it
                    if (peak_current='1') then 
                        number_peaks_UB_current <= std_logic_vector(unsigned(number_peaks_UB_current) + 1);  
                    end if;
                elsif (current_state=detection_OB) then
                    event_length <= base_event_length;
                    time_pulse_OB_current <= std_logic_vector(unsigned(time_Pulse_OB_current) + 1);
                    detection_time <= detection_time - 1;            
                    if (peak_current='1') then 
                        number_peaks_OB_current <= std_logic_vector(unsigned(number_peaks_OB_current) + 1); 
                    end if;
                    elsif (current_state=detection_UB_2 ) then
                    time_pulse_UB_2_current <= std_logic_vector(unsigned(time_pulse_UB_2_current) + 1);
                    detection_time <= detection_time - 1;
                end if;
            end if;
        end if;
    end process val_calc_proc;
    
    -- data input register process
----------------------------------------------------------------------------------------------------------------------------------------------------------
    data_delay_proc: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                din_processed_delay1 <= (others => '0');
                din_processed_delay2 <= (others => '0');
                din_processed_delay3 <= (others => '0'); 
                din_processed_mm_delay1 <= (others => '0');
                din_processed_mm_delay2 <= (others => '0'); 
                din_processed_mm_delay3 <= (others => '0');
            else
                din_processed_delay1 <= din_processed;
                din_processed_delay2 <= din_processed_delay1;
                din_processed_delay3 <= din_processed_delay2; 
                din_processed_mm_delay1 <= din_processed_mm;
                din_processed_mm_delay2 <= din_processed_mm_delay1; 
                din_processed_mm_delay3 <= din_processed_mm_delay2;
            end if;
        end if;
    end process data_delay_proc;

    -- interface with self trigger calculation block
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- data coming from self trigger module
    
    get_interface_params_proc: process(clock)
    begin
        if rising_edge(clock) then
            interface_local_primitives_in_reg <= interface_local_primitives_in;
        end if;
    end process get_interface_params_proc;
    
    peak_current <= interface_local_primitives_in_reg(0);
    xcorr_current <= interface_local_primitives_in_reg(28 downto 1);    
    
    -- Data being sent to self trigger calculation block
    interface_local_primitives_out(0) <= peak_detection;
    interface_local_primitives_out(28 downto 1) <= (others => '0');

end trig_prim_calc_arch;