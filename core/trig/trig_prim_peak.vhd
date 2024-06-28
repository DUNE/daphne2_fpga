-- trig_prim_peak.vhd
-- peak detection logic and control for self trigger generation and trigger primitives calculation
--
-- This module is a modified version of the CIEMAT's peak detector module. This version intends
-- to implement logic that matches the matching trigger implemented by the EIA University in Colombia
-- by adjusting the output as required by the trigger primitives modules designed by CIEMAT.
-- All credit of the base of the design goes to Ignacio Lopez from CIEMAT.
-- This module detects peaks of a light pulse and activates a self-trigger signal when required
-- The detection is done with a configurable threshold over a cross correlation algorithm calculation
-- Activate the self trigger: each detected peak / Only main (first) peaks (not those present in the undershoot)
-- Posibility to activate self-trigger to capture a waveform that is not fully recorded in a data acquisition frame
-- This module tends to be independent, so there is interface with Primitive Calculation module
--
-- Ignacio Lopez de Rego Benedi <Ignacio.LopezdeRego@ciemat.es> & Daniel Avila Gomez <daniel.avila@eia.edu.co> 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity trig_prim_peak is
port ( 
    reset: in  std_logic; -- reset signal. Active HIGH 
    clock: in  std_logic; -- AFE clock 62.500 MHz
    din: in  std_logic_vector(13 downto 0);  -- AFE raw data
    din_delayed: in std_logic_vector(13 downto 0); -- delayed n clk tics AFE raw data
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    sending_data: in  std_logic; -- data is being sent. Active HIGH
    trig_prim_config: in  std_logic_vector(1 downto 0); -- trig_prim_config[0] --> '0' = Peak detector as self-trigger  / '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
                                                        -- trig_prim_config[1] --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames   
                                                        --                     --> '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames
    interface_local_primitives_in: in  std_logic_vector(28 downto 0); -- interface with Local Primitives calculation block --> set for matching trigger self trigger algorithm 
    interface_local_primitives_out: out std_logic_vector(28 downto 0); -- interface with Local Primitives calculation block --> set for matching trigger self trigger algorithm
    self_trigger: out std_logic; -- active HIGH when a Self-trigger event occurs
    dout: out std_logic_vector(13 downto 0);
    dout_mm: out std_logic_vector(13 downto 0)
);
end trig_prim_peak;

architecture trig_prim_peak_arch of trig_prim_peak is

    -- configuration signals  
    signal main_peak_self_trigger: std_logic ; -- '0' = All detected peaks ACTIVATE self-trigger  / '1' = ONLY MAIN peaks ACTIVATE self-trigger(Undershoot peaks will not trigger)
    signal allow_partialWavefrom_self_trigger: std_logic ; -- '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames / '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames    

    -- interface with local trigger primitives calculation module signals 
    signal interface_local_primitives_in_reg: std_logic_vector(28 downto 0);
    signal detection: std_logic; -- active HIGH during detection and local primitives calculation 

    -- peak detection signals
    signal xcorr_current: std_logic_vector(27 downto 0) := (others => '0'); -- matching filter calculation output
    signal peak_detection: std_logic :='0'; -- active HIGH when a local peak is detected

    -- EIA's implementation
    component trig_xc is -- self trigger and peak detector based on matching filter component
    port(
        reset: in std_logic;
        clock: in std_logic;
        din: in std_logic_vector(13 downto 0);
        din_delayed: in std_logic_vector(13 downto 0);
        threshold: in std_logic_vector(41 downto 0); 
        xcorr_calc: out std_logic_vector(27 downto 0);
        triggered: out std_logic;
        trigsample: out std_logic_vector(13 downto 0);
        dout: out std_logic_vector(13 downto 0);
        dout_mm: out std_logic_vector(13 downto 0));
    end component;

begin

    -- update configuration parameters
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- trig_prim_config[0] --> '0' = Peak detector as self-trigger  / '1' = Main detection as Self-Trigger (Undershoot peaks will not trigger)
    -- trig_prim_config[1] --> '0' = NOT ALLOWED  Self-Trigger with light pulse between 2 data adquisition frames   
    --                     --> '1' = ALLOWED Self-Trigger with light pulse between 2 data adquisition frames
    main_peak_self_trigger              <= trig_prim_config(0);
    allow_partialWavefrom_self_trigger  <= trig_prim_config(1);

    -- self trigger logic
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- build the component that generates the self trigger signal or detects local peaks
        
    trig_xc_inst: trig_xc
    port map(
        reset => reset,
        clock => clock,
        din => din,
        din_delayed => din_delayed,
        threshold => threshold,
        xcorr_calc => xcorr_current,
        triggered => peak_detection,
        trigsample => open,
        dout => dout,
        dout_mm => dout_mm
    );

    self_trigger <= (peak_detection and not(main_peak_self_trigger)) or (main_peak_self_trigger and peak_detection and not(detection)) or ((allow_partialWavefrom_self_trigger and detection and not(sending_data)));

    -- interface with local primitives calculation block
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- data coming from local primitive calculation module
    
    get_interface_params_proc: process(clock)
    begin
        if rising_edge(clock) then
            interface_local_primitives_in_reg <= interface_local_primitives_in;
        end if;
    end process get_interface_params_proc;
    
    detection <= interface_local_primitives_in_reg(0);
    
    -- data sent to local primitive calculation module
    interface_local_primitives_out(0) <= peak_detection;
    interface_local_primitives_out(28 downto 1) <= xcorr_current;

end trig_prim_peak_arch;