-- st_mm.vhd
-- moving average calculator and subtractor
--
-- This module implements a 64 window moving mean/average calculator
-- used to obtain a local average of the data in order to subtract this
-- value from the same data and generate a new dataset that fine allows
-- the self trigger module based in the cross correlation to find local 
-- peaks apart from the main peak
--
-- Daniel Avila Gomez <daniel.avila@eia.edu.co> 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;
library unisim;
use unisim.vcomponents.all;

entity st_xc_mm is
port( 
    reset: in std_logic;
    clock: in std_logic;
    din: in std_logic_vector(13 downto 0);
    din_delayed: out std_logic_vector(13 downto 0);
    dout: out std_logic_vector(13 downto 0);
    mov_mean_32: out std_logic_vector(13 downto 0)
);
end st_xc_mm;

architecture st_xc_mm_arch of st_xc_mm is

    signal din_delayed32, din_delayed32_aux, din_delayed64: std_logic_vector(13 downto 0) := (others => '0'); -- register signals for the moving average window    
    signal din_delayed32_aux0, din_delayed32_aux1, din_delayed32_aux2, din_delayed32_aux3: std_logic_vector(13 downto 0) := (others => '0'); -- input data registers after 32 clock delays
    signal reg_adder_32, reg_adder_reg_32, reg_adder_sub_32, reg_adder_64, reg_adder_reg_64, reg_adder_sub_64: signed(19 downto 0) := to_signed(0,20); -- addition register signal  
    signal mean_val_32, mean_val_64: std_logic_vector(19 downto 0) := (others => '0'); -- auxiliar signal for the mean value
    signal sub: std_logic_vector(13 downto 0) := (others => '0'); -- subtraction signal
    
begin

    -- create  a 64 clock delay for the data in order to know the AFE value 64 clock cycles ago
    
    gendelay: for i in 13 downto 0 generate
        srlc32e_0_inst: srlc32e
        port map(
            clk => clock,
            ce => '1',
            a => "11111",
            d => din(i), -- real time AFE filtered data
            q => din_delayed32_aux(i),
            q31 => din_delayed32(i) -- AFE filtered data 32 clocks ago
        );
        
        srlc32e_1_inst: srlc32e
        port map(           
            clk => clock,
            ce => '1',
            a => "11111",
            d => din_delayed32(i), -- AFE filtered data 32 clocks ago
            q => din_delayed64(i), -- AFE filtered data 64 clocks ago
            q31 => open
        );
    end generate gendelay;

    -- acumulate the data and subtract the oldest value
    
    add_sub_proc: process(clock, reset, din, din_delayed32_aux, reg_adder_sub_32, reg_adder_32, din_delayed64, reg_adder_sub_64, reg_adder_64)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                reg_adder_32 <= (others => '0');
                reg_adder_sub_32 <= (others => '0');
                reg_adder_64 <= (others => '0');
                reg_adder_sub_64 <= (others => '0');
            else
                -- 32 samples window size
                reg_adder_sub_32 <= resize(signed(din),20) - resize(signed(din_delayed32_aux),20);
                reg_adder_32 <= reg_adder_sub_32 + reg_adder_32;

                -- 64 samples window size              
                reg_adder_sub_64 <= resize(signed(din),20) - resize(signed(din_delayed64),20);
                reg_adder_64 <= reg_adder_sub_64 + reg_adder_64;
            end if;
        end if;
    end process add_sub_proc;    
       
    -- register the output to keep it synchronized to the clock
    
    mean_val_proc: process(clock, reset, reg_adder_32, reg_adder_64)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                mean_val_32 <= (others => '0');
                mean_val_64 <= (others => '0');
            else
                mean_val_32 <= std_logic_vector(shift_right(signed(reg_adder_32),5));
                mean_val_64 <= std_logic_vector(shift_right(signed(reg_adder_64),6));
            end if;
        end if;
    end process mean_val_proc;    
    
    -- create extra clock delays for the input data so that the mean can be subtracted from it 
    
    gendelay_extra_proc: process(clock, reset, din_delayed32_aux, din_delayed32_aux0)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                din_delayed32_aux0 <= (others => '0');
                din_delayed32_aux1 <= (others => '0');
            else
                din_delayed32_aux0 <= din_delayed32_aux;                
                din_delayed32_aux1 <= din_delayed32_aux0;
            end if;
        end if;
    end process gendelay_extra_proc;
    
    -- subtract the mean from the data
    
    subtractor_proc: process(clock, reset, din_delayed32_aux1, mean_val_64)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                sub <= (others => '0');
            else
                sub <= std_logic_vector(resize((resize(signed(din_delayed32_aux1),20) - signed(mean_val_64)),14));
            end if;
        end if;
    end process subtractor_proc;
    
    mov_mean_32 <= mean_val_32(13 downto 0);
    din_delayed <= din_delayed32_aux1;
    dout <= sub;
    
end st_xc_mm_arch;