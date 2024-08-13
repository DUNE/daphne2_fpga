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
    signal reg_adder_32, reg_adder_64: signed(19 downto 0) := (others => '0'); -- addition register signal  
    signal reg_adder_32_sub, reg_adder_64_sub: signed(19 downto 0) := (others => '0'); -- addition register signal  
    signal reg_adder_32_reg, reg_adder_64_reg: signed(19 downto 0) := (others => '0'); -- addition register signal  
    -- signal in_A_32, in_A_64: std_logic_vector(29 downto 0) := (others => '0'); -- DSPs module interconnect signals
    -- signal in_D: std_logic_vector(24 downto 0) := (others => '0'); -- DSPs module interconnect signals
    -- signal add_counter_32: integer := 32; -- window size counter  
    -- signal add_counter_64: integer := 64; -- window size counter    
    signal mean_val_32, mean_val_64: std_logic_vector(19 downto 0) := (others => '0'); -- auxiliar signal for the mean value 47474747
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

    add_acummulator: process(clock, reset, din, din_delayed32_aux, reg_adder_32, reg_adder_32_sub, reg_adder_32_reg, din_delayed64, reg_adder_64, reg_adder_64_sub, reg_adder_64_reg)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                reg_adder_32_sub <= (others => '0');
                reg_adder_32_reg <= (others => '0');
                reg_adder_32 <= (others => '0');
                reg_adder_64_sub <= (others => '0');
                reg_adder_64_reg <= (others => '0');
                reg_adder_64 <= (others => '0');
            else
                -- 32 sampels window size
                reg_adder_32_sub <= resize(signed(din),20) - resize(signed(din_delayed32_aux),20);
                reg_adder_32_reg <= reg_adder_32;
                reg_adder_32 <= reg_adder_32_sub + reg_adder_32_reg;

                -- 64 samples window size
                reg_adder_64_sub <= resize(signed(din),20) - resize(signed(din_delayed64),20);
                reg_adder_64_reg <= reg_adder_64;
                reg_adder_64 <= reg_adder_64_sub + reg_adder_64_reg;
            end if;
        end if;
    end process add_acummulator;

    -- -- generate a counter to know how many samples have filled the window, once it reaches 64 start subtracting
    
    -- samples_count_proc: process(clock, reset, add_counter_32, add_counter_64)
    -- begin
    --     if rising_edge(clock) then
    --         if (reset='1') then
    --             add_counter_32 <= 0;
    --             add_counter_64 <= 0;
    --         else
    --             -- counter for 32 samples window size
    --             if (add_counter_32>32) then
    --                 add_counter_32 <= add_counter_32;
    --             else
    --                 add_counter_32 <= add_counter_32 + 1;
    --             end if;

    --             -- counter for 64 samples window size
    --             if (add_counter_64>64) then
    --                 add_counter_64 <= add_counter_64;
    --             else
    --                 add_counter_64 <= add_counter_64 + 1;
    --             end if;
    --         end if;
    --     end if;
    -- end process samples_count_proc;
    
    -- -- change the size of the input data so that it fits the DSP's ports size
    -- -- also, transform the inputs to signed signals
    
    -- in_A_64 <= std_logic_vector(resize(signed(din_delayed64),30)) when (add_counter_64>64) else (others => '0');
    -- in_A_32 <= std_logic_vector(resize(signed(din_delayed64),30)) when (add_counter_32>32) else (others => '0');
    -- in_D <= std_logic_vector(resize(signed(din),25));
    
    -- -- create the accumulator for the 32 samples window moving average 
    
    -- add_accumulator_32: DSP48E1
    --    generic map (
    --       A_INPUT            => "DIRECT",               
    --       B_INPUT            => "DIRECT",               
    --       USE_DPORT          => TRUE, -- use the D port so that the pre subtraction can be performed
    --       USE_MULT           => "MULTIPLY",            
    --       USE_SIMD           => "ONE48",               
    --       AUTORESET_PATDET   => "NO_RESET",    
    --       MASK               => X"3fffffffffff",           
    --       PATTERN            => X"000000000000",        
    --       SEL_MASK           => "MASK",            
    --       SEL_PATTERN        => "PATTERN",     
    --       USE_PATTERN_DETECT => "NO_PATDET",
    --       ACASCREG           => 1, 
    --       ADREG              => 1, -- one pipeline stage after the input data and the last element of the window have been subtracted
    --       ALUMODEREG         => 0,
    --       AREG               => 1, -- one pipeline stage for the input data
    --       BCASCREG           => 2, 
    --       BREG               => 2,
    --       CARRYINREG         => 0,
    --       CARRYINSELREG      => 0, 
    --       CREG               => 0,
    --       DREG               => 1, -- one pipeline stage for the oldest element of the window, to match the delay of the input data
    --       INMODEREG          => 0, 
    --       MREG               => 1, -- one pipeline stage after the unused muliplicator for performance
    --       OPMODEREG          => 0, 
    --       PREG               => 1 -- one pipeline stage to add the old value of the accumulator of the window
    --    )
    --    port map (
    --       ACOUT             => open,       
    --       BCOUT             => open,           
    --       CARRYCASCOUT      => open,
    --       MULTSIGNOUT       => open,  
    --       PCOUT             => open,  
    --       OVERFLOW          => open,             
    --       PATTERNBDETECT    => open,
    --       PATTERNDETECT     => open,   
    --       UNDERFLOW         => open,           
    --       CARRYOUT          => open,    
    --       P                 => reg_adder_32,   
    --       ACIN              => b"000000000000000000000000000000",     
    --       BCIN              => b"000000000000000000",              
    --       CARRYCASCIN       => '0',       
    --       MULTSIGNIN        => '0', 
    --       PCIN              => X"000000000000",                    
    --       ALUMODE           => X"0",               
    --       CARRYINSEL        => b"000",         
    --       CLK               => clock,     
    --       INMODE            => b"01100",                
    --       OPMODE            => b"0100101", -- PREG is used in order to add to the current value the old value (accumulator function)
    --       A                 => in_A_32, -- 32 clock old sample
    --       B                 => b"000000000000000001",        
    --       C                 => X"ffffffffffff",                           
    --       CARRYIN           => '0', 
    --       D                 => in_D, -- current sample
    --       CEA1              => '0',             
    --       CEA2              => '1',                    
    --       CEAD              => '1',                
    --       CEALUMODE         => '0',         
    --       CEB1              => '1',             
    --       CEB2              => '1',                     
    --       CEC               => '0',                    
    --       CECARRYIN         => '0',          
    --       CECTRL            => '0',                
    --       CED               => '1',                       
    --       CEINMODE          => '0',            
    --       CEM               => '1',                  
    --       CEP               => '1',                       
    --       RSTA              => reset,                  
    --       RSTALLCARRYIN     => '0',   
    --       RSTALUMODE        => '0',        
    --       RSTB              => reset,                 
    --       RSTC              => '0',                     
    --       RSTCTRL           => '0',               
    --       RSTD              => reset,                     
    --       RSTINMODE         => '0',          
    --       RSTM              => reset,                     
    --       RSTP              => reset                     
    --    );
    
    -- -- create the accumulator for the 64 samples window moving average 
    
    -- add_accumulator_64: DSP48E1
    --    generic map (
    --       A_INPUT            => "DIRECT",               
    --       B_INPUT            => "DIRECT",               
    --       USE_DPORT          => TRUE, -- use the D port so that the pre subtraction can be performed
    --       USE_MULT           => "MULTIPLY",            
    --       USE_SIMD           => "ONE48",               
    --       AUTORESET_PATDET   => "NO_RESET",    
    --       MASK               => X"3fffffffffff",           
    --       PATTERN            => X"000000000000",        
    --       SEL_MASK           => "MASK",            
    --       SEL_PATTERN        => "PATTERN",     
    --       USE_PATTERN_DETECT => "NO_PATDET",
    --       ACASCREG           => 1, 
    --       ADREG              => 1, -- one pipeline stage after the input data and the last element of the window have been subtracted
    --       ALUMODEREG         => 0,
    --       AREG               => 1, -- one pipeline stage for the input data
    --       BCASCREG           => 2, 
    --       BREG               => 2,
    --       CARRYINREG         => 0,
    --       CARRYINSELREG      => 0, 
    --       CREG               => 0,
    --       DREG               => 1, -- one pipeline stage for the oldest element of the window, to match the delay of the input data
    --       INMODEREG          => 0, 
    --       MREG               => 1, -- one pipeline stage after the unused muliplicator for performance
    --       OPMODEREG          => 0, 
    --       PREG               => 1 -- one pipeline stage to add the old value of the accumulator of the window
    --    )
    --    port map (
    --       ACOUT             => open,       
    --       BCOUT             => open,           
    --       CARRYCASCOUT      => open,
    --       MULTSIGNOUT       => open,  
    --       PCOUT             => open,  
    --       OVERFLOW          => open,             
    --       PATTERNBDETECT    => open,
    --       PATTERNDETECT     => open,   
    --       UNDERFLOW         => open,           
    --       CARRYOUT          => open,    
    --       P                 => reg_adder_64,   
    --       ACIN              => b"000000000000000000000000000000",     
    --       BCIN              => b"000000000000000000",              
    --       CARRYCASCIN       => '0',       
    --       MULTSIGNIN        => '0', 
    --       PCIN              => X"000000000000",                    
    --       ALUMODE           => X"0",               
    --       CARRYINSEL        => b"000",         
    --       CLK               => clock,     
    --       INMODE            => b"01100",                
    --       OPMODE            => b"0100101", -- PREG is used in order to add to the current value the old value (accumulator function)
    --       A                 => in_A_64, -- 64 clock old sample
    --       B                 => b"000000000000000001",        
    --       C                 => X"ffffffffffff",                           
    --       CARRYIN           => '0', 
    --       D                 => in_D, -- current sample
    --       CEA1              => '0',             
    --       CEA2              => '1',                    
    --       CEAD              => '1',                
    --       CEALUMODE         => '0',         
    --       CEB1              => '1',             
    --       CEB2              => '1',                     
    --       CEC               => '0',                    
    --       CECARRYIN         => '0',          
    --       CECTRL            => '0',                
    --       CED               => '1',                       
    --       CEINMODE          => '0',            
    --       CEM               => '1',                  
    --       CEP               => '1',                       
    --       RSTA              => reset,                  
    --       RSTALLCARRYIN     => '0',   
    --       RSTALUMODE        => '0',        
    --       RSTB              => reset,                 
    --       RSTC              => '0',                     
    --       RSTCTRL           => '0',               
    --       RSTD              => reset,                     
    --       RSTINMODE         => '0',          
    --       RSTM              => reset,                     
    --       RSTP              => reset                     
    --    );
       
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
    
    gendelay_extra_proc: process(clock, reset, din_delayed32_aux, din_delayed32_aux0, din_delayed32_aux1, din_delayed32_aux2)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                din_delayed32_aux0 <= (others => '0');
                din_delayed32_aux1 <= (others => '0');
                din_delayed32_aux2 <= (others => '0');
                din_delayed32_aux3 <= (others => '0');
            else
                din_delayed32_aux0 <= din_delayed32_aux;
                din_delayed32_aux1 <= din_delayed32_aux0;
                din_delayed32_aux2 <= din_delayed32_aux1;
                din_delayed32_aux3 <= din_delayed32_aux2;
            end if;
        end if;
    end process gendelay_extra_proc;
    
    -- subtract the mean from the data
    
    subtractor_proc: process(clock, reset, din_delayed32_aux3, mean_val_64)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                sub <= (others => '0');
            else
                sub <= std_logic_vector(resize((signed(resize(signed(din_delayed32_aux3),48)) - signed(mean_val_64)),14));
            end if;
        end if;
    end process subtractor_proc;
    
    mov_mean_32 <= mean_val_32(13 downto 0);
    din_delayed <= din_delayed32_aux3;
    dout <= sub;
    
end st_xc_mm_arch;
