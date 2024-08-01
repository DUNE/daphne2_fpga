-- trig_xc.vhd
-- matching filter cross correlation self trigger full module 
--
-- This module connects the high pass first order IIR filter used to subtract the baseline
-- from the AFE data with the matching filter core module, so that the last one receives 
-- the proper data and triggers in the right conditions
-- The baseline output generated by this module is delayed by 4 clock ticks, this is
-- related to the pipeline stages created inside the filter
--
-- Daniel Avila Gomez <daniel.avila@eia.edu.co>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

library unisim;
use unisim.vcomponents.all;

entity trig_xc is
port(
    reset: in std_logic;
    clock: in std_logic;
    din: in std_logic_vector(13 downto 0);
--    din_delayed: in std_logic_vector(13 downto 0);
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    xcorr_calc: out std_logic_vector(27 downto 0); -- matching filter cross correlation calculated value
    dout_movmean_32: out std_logic_vector(13 downto 0);
    triggered: out std_logic
--    trigsample: out std_logic_vector(13 downto 0)
);
end trig_xc;

architecture trig_xc_arch of trig_xc is

    signal st_xc_filt_dout, st_xc_filt_dout_reg36, st_xc_mov_mean: std_logic_vector(13 downto 0);
    signal st_xc_filt_dout_reg36_reg0: std_logic_vector(13 downto 0) := (others => '0');
    -- signal trigsample_reg: std_logic_vector(13 downto 0) := (others => '0');
    signal triggered_core: std_logic;
    
    -- component st_xc_filt is -- high pass first order iir filter for the algorithm (subtracts the baseline)
    -- port(
    --     reset: in std_logic;
    --     clock: in std_logic;
    --     din: in std_logic_vector(13 downto 0);
    --     dout: out std_logic_vector(13 downto 0));
    -- end component;

    component st_xc is -- cross correlation matching filter component
    port(
        reset: in std_logic;
        clock: in std_logic;
        din: in std_logic_vector(13 downto 0);
        din_mm: in std_logic_vector(13 downto 0);
        threshold: in std_logic_vector(41 downto 0); 
        xcorr_calc: out std_logic_vector(27 downto 0);
        triggered: out std_logic);
    end component;
    
    component st_xc_mm is -- moving mean calculator and subtractor
    port(
        reset: in std_logic;
        clock: in std_logic;
        din: in std_logic_vector(13 downto 0);
        din_delayed: out std_logic_vector(13 downto 0);
        dout_movmean_32: out std_logic_vector(13 downto 0);
        dout: out std_logic_vector(13 downto 0));
    end component;

begin
    
    -- core modules of the trigger
------------------------------------------------------------------------------------------------------------------------------
    
    -- generate the filtered output that does not have a baseline
    
    -- st_xc_filt_inst: st_xc_filt
    -- port map(
    --     reset => reset,
    --     clock => clock,
    --     din => din,
    --     dout => st_xc_filt_dout
    -- );
    
    -- calculate with a moving mean the "always-zero" signal
    
    st_mm_inst: st_xc_mm
    port map (
        reset => reset,
        clock => clock,
        din => din, --st_xc_filt_dout,
        din_delayed => st_xc_filt_dout_reg36,
        dout_movmean_32 => dout_movmean_32,
        dout => st_xc_mov_mean
    );

    -- use the filtered output to watch over the data and generate self triggers
    
    st_xc_inst: st_xc
    port map(
        reset => reset,
        clock => clock,
        din => st_xc_filt_dout_reg36_reg0,
        din_mm => st_xc_mov_mean,
        xcorr_calc => xcorr_calc,
        threshold => threshold,
        triggered => triggered_core
    );
    
    -- module data delays
------------------------------------------------------------------------------------------------------------------------------
    -- add extra delay to match the internal delay given by the moving average calculator (1 extra)
    
    gendelay_mm_int: process(clock, reset, st_xc_filt_dout_reg36) 
    begin
        if rising_edge(clock) then
            if (reset='1') then
                st_xc_filt_dout_reg36_reg0 <= (others => '0');
            else
                st_xc_filt_dout_reg36_reg0 <= st_xc_filt_dout_reg36;
            end if;
        end if;
    end process gendelay_mm_int;   

    -- determine the sample that asserted the trigger 
    
    -- xc_trigsample_proc: process(clock, reset, triggered_core, din_delayed)
    -- begin
    --     if rising_edge(clock) then
    --         if (reset='1') then
    --             trigsample_reg <= (others => '0');
    --         else
    --             if (triggered_core='1') then
    --                 trigsample_reg <= din_delayed; --afe_del_reg2;
    --             end if;
    --         end if;
    --     end if;
    -- end process xc_trigsample_proc;

    -- trigsample <= trigsample_reg;
    triggered <= triggered_core;

end trig_xc_arch;