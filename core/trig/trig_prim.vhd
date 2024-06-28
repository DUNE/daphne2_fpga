-- trig_prim.vhd
-- local primitives calculation and self trigger generator 
--
-- This module is a modified version of the CIEMAT's top main module that
-- generates the main self trigger signal and also calculates the local primitives 
-- associated with its waveform. The module generates the trailer words used 
-- in the self trigger frame.
-- All credit of the base of the design goes to Ignacio Lopez from CIEMAT
--
-- Ignacio Lopez de Rego Benedi <Ignacio.LopezdeRego@ciemat.es> & Daniel Avila Gomez <daniel.avila@eia.edu.co>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity trig_prim is
port ( 
    reset: in std_logic; -- reset signal. Active HIGH
    clock: in std_logic; -- AFE Clock 62.500 MHz
    din: in std_logic_vector(13 downto 0); -- AFE raw data
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    trig_prim_config: in std_logic_vector(1 downto 0); --(5 downto 0); -- local primitives calculation configuration
    triggered: out std_logic; -- self trigger signal
    data_available: out std_logic; -- active HIGH when local primitives are calculated
    time_peak: out std_logic_vector(8 downto 0); -- time in Samples to achieve the Max peak
    time_pulse_ub: out std_logic_vector(8 downto 0); -- time in Samples where the light pulse signal is Under baseline (without undershoot)
    time_pulse_ob: out std_logic_vector(9 downto 0); -- time in Samples where the light pulse signal is Over baseline (undershoot)
    max_peak: out std_logic_vector(13 downto 0); -- amplitude in ADC counts of the peak
    charge: out std_logic_vector(22 downto 0); -- charge of the light pulse (without undershoot) in ADC*samples
    number_peaks_ub: out std_logic_vector(3 downto 0); -- number of peaks detected when signal is Under baseline (without undershoot)  
    number_peaks_ob: out std_logic_vector(3 downto 0); -- number of peaks detected when signal is Over baseline (undershoot)  
--    dout_filtered: out std_logic_vector (13 downto 0); -- filtered signal
    baseline: out std_logic_vector(13 downto 0); -- real time calculated baseline
    amplitude: out std_logic_vector(13 downto 0); -- real time calculated amplitude
    peak_current: out std_logic; -- active HIGH when a peak is detected
    xcorr_current: out std_logic_vector(27 downto 0); -- current cross correlation calculated value
    detection: out std_logic; -- active HIGH when primitives are being calculated (during light pulse)
    sending: out std_logic; -- active HIGH when colecting data for self-trigger frame
    info_previous: out std_logic; -- active HIGH when self-trigger is produced by a waveform between two frames 
    data_available_trailer: out std_logic; -- active HIGH when metadata is ready
    trailer_word_0: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_1: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_2: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_3: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_4: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_5: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_6: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_7: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_8: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_9: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_10: out std_logic_vector(31 downto 0); -- trailer word with metada (Local Trigger Primitives)
    trailer_word_11: out std_logic_vector(31 downto 0)  -- trailer word with metada (Local Trigger Primitives)
--    dout_filt_delayed128: out std_logic_vector(13 downto 0);
--    dout: out std_logic_vector(13 downto 0);
--    dout_mm: out std_logic_vector(13 downto 0)
);
end trig_prim;

architecture trig_prim_arch of trig_prim is

    component k_low_pass_filter is
    port(
        clk: in std_logic;
        reset: in std_logic;
	    enable: in std_logic;
	    x: in signed(15 downto 0);
        y: out signed(15 downto 0));
    end component;
    
    component trig_prim_peak is
    port (
        reset: in std_logic;
        clock: in std_logic;
        din: in std_logic_vector(13 downto 0);
        din_delayed: in std_logic_vector(13 downto 0); 
        threshold: in std_logic_vector(41 downto 0);
        sending_data: in std_logic;
        trig_prim_config: in std_logic_vector(1 downto 0);
        interface_local_primitives_in: in std_logic_vector(28 downto 0);
        interface_local_primitives_out: out std_logic_vector(28 downto 0);
        self_trigger: out std_logic;
        dout: out std_logic_vector(13 downto 0);
        dout_mm: out std_logic_vector(13 downto 0));
    end component;
    
    component trig_prim_calc is
    port (
        reset: in std_logic;
        clock: in std_logic;
        --din: in std_logic_vector(13 downto 0);
        din_processed: in std_logic_vector(13 downto 0); -- AFE filtered data
        din_processed_mm: in std_logic_vector(13 downto 0); -- moving average of the AFE filtered data (64 samples window size)
        self_trigger: in std_logic;
        interface_local_primitives_in: in std_logic_vector(28 downto 0);
        interface_local_primitives_out: out std_logic_vector(28 downto 0);
        data_available: out std_logic;
        time_peak: out std_logic_vector(8 downto 0);
        time_pulse_ub: out std_logic_vector(8 downto 0);
        time_pulse_ob: out std_logic_vector(9 downto 0);
        max_peak: out std_logic_vector(13 downto 0);
        charge: out std_logic_vector(22 downto 0);
        number_peaks_ub: out std_logic_vector(3 downto 0);
        number_peaks_ob: out std_logic_vector(3 downto 0);
--        baseline: out std_logic_vector(13 downto 0);
        amplitude: out std_logic_vector(13 downto 0));
    end component;
    
    -- configuration signals
--    signal trig_prim_config_filt: std_logic_vector(3 downto 0) := (others => '0');
    signal trig_prim_config_peak: std_logic_vector(1 downto 0) := (others => '0');

    -- filter signals
    signal din_aux: signed(15 downto 0) := to_signed(0,16);
--    signal dout_filt, dout_filt_reg: std_logic_vector(13 downto 0) := (others => '0');
--    signal dout_filt32, dout_filt64, dout_filt96, dout_filt128: std_logic_vector(13 downto 0) := (others => '0');

    -- peak finder/self trigger core signals
    signal peak_self_trigger: std_logic := '0';
    signal dout_delayed, dout_delayed_mm, dout_delayed32, dout_delayed32_mm, dout_delayed64, dout_delayed64_mm: std_logic_vector(13 downto 0) := (others => '0');
    signal interface_local_primitives_in: std_logic_vector(28 downto 0) := (others => '0');
    signal interface_local_primitives_out: std_logic_vector(28 downto 0) := (others => '0');
    
    -- local primitives calculation signals
    signal data_available_aux: std_logic := '0';
    signal time_peak_aux, time_peak_reg: std_logic_vector(8 downto 0) := (others => '0');
    signal time_pulse_ub_aux, time_pulse_ub_reg: std_logic_vector(8 downto 0) := (others => '0');
    signal time_pulse_ob_aux, time_pulse_ob_reg: std_logic_vector(9 downto 0) := (others => '0');
    signal max_peak_aux, max_peak_reg: std_logic_vector(13 downto 0) := (others => '0');
    signal charge_aux, charge_reg: std_logic_vector(22 downto 0) := (others => '0');
    signal number_peaks_ub_aux, number_peaks_ub_reg: std_logic_vector(3 downto 0) := (others => '0');
    signal number_peaks_ob_aux, number_peaks_ob_reg: std_logic_vector(3 downto 0) := (others => '0');
    signal baseline_signed: signed(15 downto 0) := to_signed(0,16);
    signal baseline_aux: std_logic_vector(15 downto 0) := (others => '0');
    signal amplitude_aux: std_logic_vector(13 downto 0) := (others => '0');
    
    -- important information auxiliary signals
    signal xcorr_current_aux: std_logic_vector(27 downto 0) := (others => '0');
    signal detection_aux, peak_current_aux: std_logic := '0';
    signal allow_previous_info, info_previous_reg: std_logic := '0';
    
    -- sending data control signals
    type data_state_type is (not_sending_data, sending_data);
    signal current_state_data, next_state_data: data_state_type;
    signal sending_data_aux: std_logic := '0';
    signal data_sent_count: integer := 960; -- 1024 total samples - 64 pretrigger samples
    constant frame_size : integer := 960; -- 1024 total samples - 64 pretrigger samples
    
    -- self-trigger frame format signals
    type frame_state_type is (idle, one, two, three, four, five, no_more_peaks, data);
    signal current_state_frame, next_state_frame: frame_state_type;   
    
    -- triler words registers
    signal trailer_word_0_reg: std_logic_vector(31 downto 0);
    signal trailer_word_1_reg: std_logic_vector(31 downto 0);
    signal trailer_word_2_reg: std_logic_vector(31 downto 0);
    signal trailer_word_3_reg: std_logic_vector(31 downto 0);
    signal trailer_word_4_reg: std_logic_vector(31 downto 0);
    signal trailer_word_5_reg: std_logic_vector(31 downto 0);
    signal trailer_word_6_reg: std_logic_vector(31 downto 0);
    signal trailer_word_7_reg: std_logic_vector(31 downto 0);
    signal trailer_word_8_reg: std_logic_vector(31 downto 0);
    signal trailer_word_9_reg: std_logic_vector(31 downto 0);
    signal trailer_word_10_reg: std_logic_vector(31 downto 0);
    signal trailer_word_11_reg: std_logic_vector(31 downto 0);
    
begin

    -- update configuration parameters
----------------------------------------------------------------------------------------------------------------------------------------------------------
--    trig_prim_config_filt <= trig_prim_config(3 downto 0);
    trig_prim_config_peak <= trig_prim_config(1 downto 0); --(5 downto 4);

    -- components instantiation
----------------------------------------------------------------------------------------------------------------------------------------------------------
    
    -- modify the input data so that it is properly handled by the filter
    din_aux <= signed(resize(unsigned(din),16));
    
    -- filter
    trig_prim_filt_inst: k_low_pass_filter
    port map (        
        clk => clock,
        reset => reset,
	    enable => '1', 
	    x => din_aux,
        y => baseline_signed
    );
    
    -- transform the signed signal to a std_logic_vector
    baseline_aux <= std_logic_vector(baseline_signed);
    
    -- self-trigger core and peak finder
    trig_prim_peak_inst: trig_prim_peak
    port map (
        reset => reset,
        clock => clock,
        din => din, --dout_filt,
        din_delayed => b"00000000000000",
        threshold => threshold,
        sending_data => sending_data_aux,
        trig_prim_config => trig_prim_config_peak,
        interface_local_primitives_in => interface_local_primitives_in,
        interface_local_primitives_out => interface_local_primitives_out,
        self_trigger => peak_self_trigger,
        dout => dout_delayed,
        dout_mm => dout_delayed_mm
    );

    -- local primitives calculation
    trig_prim_calc_inst: trig_prim_calc
    port map (
        reset => reset,
        clock => clock,
        --din => dout_filt128,
        din_processed => dout_delayed64,
        din_processed_mm => dout_delayed64_mm,
        self_trigger => peak_self_trigger,
        interface_local_primitives_in => interface_local_primitives_out,
        interface_local_primitives_out => interface_local_primitives_in,
        data_available => data_available_aux,
        time_peak => time_peak_aux,
        time_pulse_ub => time_pulse_ub_aux,
        time_pulse_ob => time_pulse_ob_aux,
        max_peak => max_peak_aux,
        charge => charge_aux,
        number_peaks_ub => number_peaks_ub_aux,
        number_peaks_ob => number_peaks_ob_aux,
        --baseline => baseline_aux,
        amplitude => amplitude_aux
    );
    
    -- filtered data delay for matching trigger strategy
----------------------------------------------------------------------------------------------------------------------------------------------------------
    gendelay: for i in 13 downto 0 generate
    
        srlc32e_0_inst : srlc32e
        port map(
            clk => clock,
            ce => '1',
            a => "11111",
            d => dout_delayed(i), -- real time AFE filtered data
            q => open,
            q31 => dout_delayed32(i) -- AFE filtered data 32 clocks ago 
        );
        
        srlc32e_1_inst : srlc32e
        port map(
            clk => clock,
            ce => '1',
            a => "11111",
            d => dout_delayed32(i), -- AFE filtered data 32 clocks ago 
            q => dout_delayed64(i), -- AFE filtered data 64 clocks ago
            q31 => open
        );
        
        srlc32e_0_64_inst : srlc32e
        port map(
            clk => clock,
            ce => '1',
            a => "11111",
            d => dout_delayed_mm(i), -- real time 64 window AFE moving average
            q => open,
            q31 => dout_delayed32_mm(i) -- AFE moving average 32 clocks ago
        );
        
        srlc32e_1_64_inst : srlc32e
        port map(
            clk => clock,
            ce => '1',
            a => "11111",
            d => dout_delayed32_mm(i), -- AFE moving average 32 clocks ago
            q => dout_delayed64_mm(i), -- AFE moving average 64 clocks ago
            q31 => open
        );
        
    end generate gendelay;
    
    -- store the values of the local primitive calculation to fill the trailer words
----------------------------------------------------------------------------------------------------------------------------------------------------------
    local_prim_params_proc: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                time_peak_reg <= (others => '1');
                time_pulse_ub_reg <= (others => '1');
                time_pulse_ob_reg <= (others => '1');
                max_peak_reg <= (others => '1');
                charge_reg <= (others => '1');
                number_peaks_ub_reg <= (others => '1');
                number_peaks_ob_reg <= (others => '1');
            else
                if (data_available_aux='1') then
                    time_peak_reg <= time_peak_aux;
                    time_pulse_ub_reg <= time_pulse_ub_aux;
                    time_pulse_ob_reg <= time_pulse_ob_aux;
                    max_peak_reg <= max_peak_aux;
                    charge_reg <= charge_aux;
                    number_peaks_ub_reg <= number_peaks_ub_aux;
                    number_peaks_ob_reg <= number_peaks_ob_aux;
                end if;
            end if;
        end if;
    end process local_prim_params_proc;   
         
    -- previous info bit 
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- indicates that a waveform is between 2 self-trigger frames     
    previous_bit_proc: process(clock, reset, allow_previous_info, sending_data_aux, detection_aux)
    begin
        if rising_edge(clock) then
            if ( ( reset='1' ) or ( ( sending_data_aux='0' ) and ( info_previous_reg='1' ) )) then
                info_previous_reg <= '0';
            elsif ( ( allow_previous_info='1' ) and ( sending_data_aux='0' ) and ( detection_aux='1' ) 
                    and ( info_previous_reg='0' ) ) then
                info_previous_reg <= '1';
            end if;
        end if; 
    end process previous_bit_proc;
    
    -- variables with important info
    peak_current_aux <= interface_local_primitives_out(0);
    xcorr_current_aux <= interface_local_primitives_out(28 downto 1);
    detection_aux <= interface_local_primitives_in(0);
    allow_previous_info <= trig_prim_config_peak(1);  
    
    -- information output
    info_previous <= info_previous_reg;
    
    -- data sending control
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- FSM SENDING DATA CONTROL. 
    -- This Finite Sate controls when data is being sent 
    --      * Not_Sending Data --> Data is not being sent 
    --      * Sending_Data --> Remains in this state for Frame_Size tics when a self-trigger event has occured
    
    -- process to sync change the states of the FSM
    reg_states_data: process(clock, reset, next_state_data)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                current_state_data <= not_sending_data;
            else
                current_state_data <= next_state_data;
            end if;
        end if;
    end process reg_states_data;
    
    -- process to define why the states change
    mod_state_data: process(current_state_data, peak_self_trigger, data_sent_count)
    begin
        next_state_data <= current_state_data; -- declare default state for next_state_data to avoid latches
        case (current_state_data) is
            when not_sending_data =>
                if (peak_self_trigger='1') then
                    next_state_data <= sending_data;
                end if;
            when sending_data =>
                if (data_sent_count<=1) then
                    next_state_data <= not_sending_data;
                end if;
            when others =>
                -- do nothing
        end case;
    end process mod_state_data;
    
    -- finite state machine outputs
    do_states_data: process(current_state_data)
    begin
        case (current_state_data) is
            when not_sending_data =>
                sending_data_aux <= '0';
            when sending_data =>
                sending_data_aux <= '1';
            when others =>
                -- do nothing, hopefully
        end case;
    end process do_states_data;
    
    -- external process for the data sending finite state machine
    calc_ext_data_proc: process(clock, reset, current_state_data)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                data_sent_count <= frame_size;
            else
                if (current_state_data=not_sending_data) then               
                    data_sent_count <= frame_size;
                else
                    data_sent_count <= data_sent_count - 1;
                end if;
            end if;
        end if;
    end process calc_ext_data_proc;
    
    -- filling trailer words with metadata
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- FSM FRAME FORMAT: This Finite Sate Machine fills the trailer words from self-trigger frame format v1.5
    --      * IDLE          --> IDLE state, resets Trailer word registers 
    --      * ONE           --> One peak detected
    --      * TWO           --> Two peaks detected
    --      * THREE         --> Three peaks detected
    --      * FOUR          --> Four peaks detected 
    --      * FIVE          --> Five peaks detected
    --      * NO_MORE_PEAKS --> Self-Trigger Frame Format only allows info of FIVE different peaks
    --      * DATA          --> Trailer words are ready (only 1 clk)  
    
    -- process to sync change the states of the FSM
    reg_states_frame: process(clock, reset, next_state_frame)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                current_state_frame <= idle;
            else
                current_state_frame <= next_state_frame;
            end if;
        end if;
    end process reg_states_frame;
    
    -- process to define why the states change
    mod_state_frame: process(current_state_frame, sending_data_aux, data_available_aux)
    begin
        next_state_frame <= current_state_frame; -- declare default state for next_state_frame to avoid latches
        case (current_state_frame) is
            when idle => 
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= one;
                end if;
            when one =>
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= two;
                elsif (sending_data_aux='0') then
                    next_state_frame <= data;
                end if;
            when two =>
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= three;
                elsif (sending_data_aux='0') then
                    next_state_frame <= data;
                end if;
            when three =>
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= four;
                elsif (sending_data_aux='0') then
                    next_state_frame <= data;
                end if;
            when four =>
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= five;
                elsif (sending_data_aux='0') then
                    next_state_frame <= data;
                end if;
            when five => 
                if ( ( sending_data_aux='1' ) and ( data_available_aux='1' ) ) then
                    next_state_frame <= no_more_peaks;
                elsif (sending_data_aux='0') then
                    next_state_frame <= data;
                end if;
            when no_more_peaks =>
                if (sending_Data_aux='0') then
                    next_state_frame <= data;
                end if;
            when data =>       
                next_state_frame <= idle;
            when others =>
                -- do nothing
        end case;
    end process mod_state_frame;
    
    -- finite state machine outputs
    do_states_frame: process(current_state_frame, trailer_word_0_reg, trailer_word_1_reg, trailer_word_2_reg, trailer_word_3_reg, 
                             trailer_word_4_reg, trailer_word_5_reg, trailer_word_6_reg, trailer_word_7_reg, 
                             trailer_word_8_reg, trailer_word_9_reg, trailer_word_10_reg, trailer_word_11_reg)
    begin
        case (current_state_frame) is
            when data =>
                data_available_trailer <= '1';
                trailer_word_0 <= trailer_word_0_reg;
                trailer_word_1 <= trailer_word_1_reg;
                trailer_word_2 <= trailer_word_2_reg;
                trailer_word_3 <= trailer_word_3_reg;
                trailer_word_4 <= trailer_word_4_reg;
                trailer_word_5 <= trailer_word_5_reg;
                trailer_word_6 <= trailer_word_6_reg;
                trailer_word_7 <= trailer_word_7_reg;
                trailer_word_8 <= trailer_word_8_reg;
                trailer_word_9 <= trailer_word_9_reg;
                trailer_word_10 <= trailer_word_10_reg;
                trailer_word_11 <= trailer_word_11_reg; 
            when others =>
                -- this includes the states idle, one, two, three, four, five and no_more_peaks
                data_available_trailer <= '0';
                trailer_word_0 <= (others=>'0');
                trailer_word_1 <= (others=>'0');
                trailer_word_2 <= (others=>'0');
                trailer_word_3 <= (others=>'0');
                trailer_word_4 <= (others=>'0');
                trailer_word_5 <= (others=>'0');
                trailer_word_6 <= (others=>'0');
                trailer_word_7 <= (others=>'0');
                trailer_word_8 <= (others=>'0');
                trailer_word_9 <= (others=>'0');
                trailer_word_10 <= (others=>'0');
                trailer_word_11 <= (others=>'0'); 
        end case;
    end process do_states_frame;
    
    -- external process for the formation of te trailer words using the dataand the states of the frame finite state machine
    calc_trailer_frame_proc: process(clock, reset, current_state_frame)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                trailer_word_0_reg <= X"FFFFFFFF";
                trailer_word_1_reg <= X"FFFFFFFF";
                trailer_word_2_reg <= X"FFFFFFFF";
                trailer_word_3_reg <= X"FFFFFFFF";
                trailer_word_4_reg <= X"FFFFFFFF";
                trailer_word_5_reg <= X"FFFFFFFF";
                trailer_word_6_reg <= X"FFFFFFFF";
                trailer_word_7_reg <= X"FFFFFFFF";
                trailer_word_8_reg <= X"FFFFFFFF";
                trailer_word_9_reg <= X"FFFFFFFF";
                trailer_word_10_reg <= X"FFFFFFFF";
                trailer_word_11_reg <= X"FFFFFFFF";
            else
                if (current_state_frame=idle) then
                    trailer_word_0_reg <= X"FFFFFFFF";
                    trailer_word_1_reg <= X"FFFFFFFF";
                    trailer_word_2_reg <= X"FFFFFFFF";
                    trailer_word_3_reg <= X"FFFFFFFF";
                    trailer_word_4_reg <= X"FFFFFFFF";
                    trailer_word_5_reg <= X"FFFFFFFF";
                    trailer_word_6_reg <= X"FFFFFFFF";
                    trailer_word_7_reg <= X"FFFFFFFF";
                    trailer_word_8_reg <= X"FFFFFFFF";
                    trailer_word_9_reg <= X"FFFFFFFF";
                    trailer_word_10_reg <= X"FFFFFFFF";
                    trailer_word_11_reg <= X"FFFFFFFF";
                elsif (current_state_frame=one) then
                    trailer_word_0_reg <= ('1' & charge_reg & number_peaks_ob_reg & number_peaks_ub_reg); 
                    trailer_word_1_reg <= (time_pulse_ub_reg & time_peak_reg & max_peak_reg);
                    trailer_word_10_reg(31 downto 22) <= (time_pulse_ob_reg); 
                elsif (current_state_frame=two) then
                    trailer_word_2_reg <= ('1' & charge_reg & number_peaks_ob_reg & number_peaks_ub_reg); 
                    trailer_word_3_reg <= (time_pulse_ub_reg & time_peak_reg & max_peak_reg);
                    trailer_word_10_reg(21 downto 12) <= (time_pulse_ob_reg);  
                elsif (current_state_frame=three) then
                    trailer_word_4_reg <= ('1' & charge_reg & number_peaks_ob_reg & number_peaks_ub_reg); 
                    trailer_word_5_reg <= (time_pulse_ub_reg & time_peak_reg & max_peak_reg);
                    trailer_word_10_reg(11 downto 2) <= (time_pulse_ob_reg);  
                elsif (current_state_frame=four) then
                    trailer_word_6_reg <= ('1' & charge_reg & number_peaks_ob_reg & number_peaks_ub_reg); 
                    trailer_word_7_reg <= (time_pulse_ub_reg & time_peak_reg & max_peak_reg);
                    trailer_word_11_reg(31 downto 22) <= (time_pulse_ob_reg);    
                elsif (current_state_frame=five) then
                    trailer_word_8_reg <= ('1' & charge_reg & number_peaks_ob_reg & number_peaks_ub_reg); 
                    trailer_word_9_reg <= (time_pulse_ub_reg & time_peak_reg & max_peak_reg);
                    trailer_word_11_reg(21 downto 12) <= (time_pulse_ob_reg);    
                end if; 
            end if;
        end if;
    end process calc_trailer_frame_proc;
    
    -- trigger propagation (unknown use of this feature)
----------------------------------------------------------------------------------------------------------------------------------------------------------
--    Trigger_Propagation: process(clock, peak_self_trigger)
--    begin
--        if (clock'event and clock='1') then
--            if (peak_self_trigger = '1') then
--                Trigger_dly53 <= Trigger_dly53 sll 1;
--                Trigger_dly53(0) <= '1';
--            elsif ((Noise_aux='1') and (Config_Param_SELF_aux(0)='1')) then -- only main detections use the noise check 
--                Trigger_dly53 <= (others => '0');
--            else
--                Trigger_dly53 <= Trigger_dly53 sll 1;
--            end if;    
--        end if;
--    end process Trigger_Propagation;
--    --Noise_OR <= Noise_64(0) or Noise_64(1) or Noise_64(2) or Noise_64(3) or Noise_64(4) or Noise_64(5) or Noise_64(6) or Noise_64(7) or Noise_64(8) or Noise_64(9) or Noise_64(10) or Noise_64(11) or Noise_64(12) or Noise_64(13) or Noise_64(14) or Noise_64(15) or Noise_64(16) or Noise_64(17) or Noise_64(18) or Noise_64(19) or Noise_64(20) or Noise_64(21) or Noise_64(22) or Noise_64(23) or Noise_64(24) or Noise_64(25) or Noise_64(26) or Noise_64(27) or Noise_64(28) or Noise_64(29) or Noise_64(30) or Noise_64(31) or Noise_64(32) or Noise_64(33) or Noise_64(34) or Noise_64(35) or Noise_64(36) or Noise_64(37) or Noise_64(38) or Noise_64(39) or Noise_64(40) or Noise_64(41) or Noise_64(42) or Noise_64(43) or Noise_64(44) or Noise_64(45) or Noise_64(46) or Noise_64(47) or Noise_64(48) or Noise_64(49) or Noise_64(50) or Noise_64(51) or Noise_64(52) or Noise_64(53) or Noise_64(54) or Noise_64(55) or Noise_64(56) or Noise_64(57) or Noise_64(58) or Noise_64(59) or Noise_64(60) or Noise_64(61) or Noise_64(62) or Noise_64(63);  
--    Self_trigger_out_aux <= to_stdulogic(Trigger_dly53(53)); 
    
    -- outputs of the module
----------------------------------------------------------------------------------------------------------------------------------------------------------
    triggered <= peak_self_trigger; --Self_trigger_out_aux;                   
    data_Available <= data_available_aux;                 
    time_Peak <= time_peak_aux;                       
    time_Pulse_UB <= time_pulse_ub_aux;                   
    time_Pulse_OB <= time_pulse_ob_aux;                  
    max_Peak <= max_peak_aux;                        
    charge <= charge_aux;                          
    number_Peaks_UB <= number_peaks_ub_aux;                 
    number_Peaks_OB <= number_peaks_ob_aux; 
--    dout_filtered <= dout_filt;                  
    baseline <= baseline_aux(13 downto 0);                        
    amplitude <= amplitude_aux;                       
    peak_Current <= peak_current_aux;                             
    detection <= detection_aux; 
    xcorr_current <= xcorr_current_aux;
    sending <= sending_data_aux;   
    
--    dout_filt_delayed128 <= dout_filt128;
--    dout <= dout_delayed64;
--    dout_mm <= dout_delayed64_mm;
    
end trig_prim_arch;