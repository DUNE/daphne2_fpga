-- trig_prim_filt.vhd
-- filter for the self trigger primitives calculation
--
-- This module filters the signal using low-pass filters to reduce high frequency noise
-- As a first stage, Least Significant Bits are truncated --> Configurable with Number of bits being truncated (1 or 2)
-- As a second stage, a simple Moving Average is used --> Configurable with the window size 2, 4, 8 or 16 samples
-- Filtering can be dsiabled by configuration
--
-- Ignacio Lopez de Rego Benedi <Ignacio.LopezdeRego@ciemat.es>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

entity trig_prim_filt is
port ( 
    reset: in std_logic; -- reset signal, active HIGH
    clock: in std_logic; -- AFE clock 62.500 MHz
    din: in std_logic_vector(13 downto 0); -- AFE data
    trig_prim_config: in std_logic_vector(3 downto 0); -- trig_prim_config[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
                                                       -- trig_prim_config[1] --> '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
                                                       -- trig_prim_config[3 downto 2] --> '00' = 2 Samples Window / '01' = 4 Samples Window / '10' = 8 Samples Window / '11' = 16 Samples Window
    dout: out std_logic_vector(13 downto 0) -- filtered or raw data based on configuration
);
end trig_prim_filt;

architecture trig_prim_filt_arch of trig_prim_filt is

    -- input delay signals 
    signal din_delay1, din_delay2, din_delay3: std_logic_vector(13 downto 0);

    -- configuration signals 
    signal trig_prim_config_reg: std_logic_vector(3 downto 0) := "1000";
    signal enable: std_logic :='1'; -- enable Signal. Active HIGH
    signal first_stage_LSB: std_logic :='0'; -- SECOND STAGE filter configuration. '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
    signal second_stage_window_size: std_logic_vector(1 downto 0) := (others=>'0'); -- SECOND STAGE Averaging Window Size. '00' = 4 Samples / '01' = 8 Samples / '10' = 16 / '11' = 32 Samples

    -- filter FIRST stage signals 
    signal first_filtered_out: std_logic_vector(13 downto 0); -- first stage filter output
    
    -- filter SECOND stage signals
    signal second_filtered_dif_aux, Second_Filtered_Dif_reg: std_logic_vector(13 downto 0);
    signal second_filtered_err_aux : std_logic_vector(12 downto 0);
    signal second_filtered_select: std_logic_vector(13 downto 0);    
    signal second_filtered_add_reg : std_logic_vector(13 downto 0);
    signal second_filtered_add, second_filtered_add_2: std_logic_vector(14 downto 0); -- SMA(n-1) + [ [x(n) - x(n-k)] / k ]

    signal second_filtered_delay1, second_filtered_delay2, second_filtered_delay3, second_filtered_delay4, second_filtered_delay5, second_filtered_delay6: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering
    signal second_filtered_delay7, second_filtered_delay8, second_filtered_delay9, second_filtered_delay10, second_filtered_delay11, second_filtered_delay12: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering 
    signal second_filtered_delay13, second_filtered_delay14, second_filtered_delay15, second_filtered_delay16: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering
    signal second_filtered_out, second_filtered_out_delay1 : std_logic_vector(13 downto 0); -- second stage filter output (real and delayed)

    signal second_filtered_2_dif_aux, second_filtered_2_dif_reg: std_logic_vector(13 downto 0);
    signal second_filtered_2_err_aux : std_logic_vector(12 downto 0);
    signal second_filtered_2_select: std_logic_vector(13 downto 0);
    signal second_filtered_2_add_reg : std_logic_vector(13 downto 0);
    signal second_filtered_2_add, second_filtered_2_add_2: std_logic_vector(14 downto 0); -- SMA(n-1) + [ [x(n) - x(n-k)] / k ]

    signal second_filtered_2_delay1, second_filtered_2_delay2, second_filtered_2_delay3, second_filtered_2_delay4, second_filtered_2_delay5, second_filtered_2_delay6: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering
    signal second_filtered_2_delay7, second_filtered_2_delay8, second_filtered_2_delay9, second_filtered_2_delay10, second_filtered_2_delay11, second_filtered_2_delay12: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering 
    signal second_filtered_2_delay13, second_filtered_2_delay14, second_filtered_2_delay15, second_filtered_2_delay16: std_logic_vector(13 downto 0); -- buffer for Simple moving average filtering
    signal second_filtered_2_out, second_filtered_2_out_delay1 : std_logic_vector(13 downto 0); -- second stage silter output (real and delayed)

    -- post reset stabilization signals --> 64 clk cycles so all the delays are properly filled
    signal reset_timer: integer := 64; -- 64 clk
    signal not_allow_filter: std_logic;
    constant reset_timer_cnt : integer := 64; -- 64 clk

begin

    -- synchronize and update configuration parameters
----------------------------------------------------------------------------------------------------------------------------------------------------------
    get_config_proc: process(clock)
    begin
        if rising_edge(clock) then
            trig_prim_config_reg <= trig_prim_config;
        end if;
    end process get_config_proc;
    
    -- Config_Param[0] --> 1 = ENABLE filtering / 0 = DISABLE filtering 
    -- Config_Param[1] --> '0' = 1 LSB truncated / '1' = 2 LSBs truncated 
    -- Config_Param[3 downto 2] --> '00' = 2 Samples Window / '01' = 4 Samples Window / '10' = 8 Samples Window / '11' = 16 Samples Window
    enable <= trig_prim_config_reg(0);
    first_stage_LSB <= trig_prim_config_reg(1);
    second_stage_window_size <= trig_prim_config_reg(3 downto 2);
    
    -- extra delays of input signal so the filter signal is in phase with the Raw data
----------------------------------------------------------------------------------------------------------------------------------------------------------
    din_delay_proc: process(clock, reset)
    begin
        if rising_edge(clock) then
            if(reset='1')then
                din_delay1 <= (others =>'0');
                din_delay2 <= (others =>'0');
                din_delay3 <= (others =>'0');
            else
                din_delay1 <= din;
                din_delay2 <= din_delay1;
                din_delay3 <= din_delay2;
            end if;
        end if;
    end process din_delay_proc;
    
    -- first stage of the filter 
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- truncating LSBs

    first_filter_stage: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                first_filtered_out <= din;
            else
                if (first_stage_LSB='0') then
                    first_filtered_out <= (din and "11111111111110");
                else
                    first_filtered_out <= (din and "11111111111100"); 
                end if;
            end if;
        end if;
    end process first_filter_stage;
    
    -- second stage of the filter
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- low pass filtering to reduce High Frequency noise 
    
    -- arithmetic operations for the filter
    second_filtered_dif_aux <= std_logic_vector(unsigned("000" & first_filtered_out(13 downto 3)) - unsigned("000" & second_filtered_select(13 downto 3)));
    second_filtered_err_aux <= std_logic_vector(unsigned('0' & first_filtered_out(13 downto 2)) - unsigned('0' & second_filtered_add_reg(13 downto 2)));
    second_filtered_add <= std_logic_vector(signed('0' & second_filtered_add_reg) + signed(resize(signed(second_filtered_err_aux ),15)));
    second_filtered_add_2 <= std_logic_vector(signed('0' & second_filtered_add_reg) + signed(resize(signed(second_filtered_dif_reg ),15)));

    ---- select which element from the buffer to pick, and then shift (division)
    second_filter_Stage_arithmetic: process(second_stage_window_size, second_filtered_delay2, second_filtered_delay4, second_filtered_delay8, second_filtered_delay16)
    begin
        if (second_stage_window_size="00") then
            second_filtered_select <= second_filtered_delay2;
        elsif (second_stage_window_size="01") then
            second_filtered_select <= second_filtered_delay4;               
        elsif (second_stage_window_size="10") then 
            second_filtered_select <= second_filtered_delay8;         
        else
            second_filtered_select <= second_filtered_delay16;    
        end if;
    end process second_filter_stage_arithmetic;
    
    -- synchronous buffering data and filter output
    second_filter_stage: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                second_filtered_delay1  <= (others =>'0');
                second_filtered_delay2  <= (others =>'0'); 
                second_filtered_delay3  <= (others =>'0'); 
                second_filtered_delay4  <= (others =>'0'); 
                second_filtered_delay5  <= (others =>'0'); 
                second_filtered_delay6  <= (others =>'0'); 
                second_filtered_delay7  <= (others =>'0'); 
                second_filtered_delay8  <= (others =>'0'); 
                second_filtered_delay9  <= (others =>'0');
                second_filtered_delay10 <= (others =>'0'); 
                second_filtered_delay11 <= (others =>'0');
                second_filtered_delay12 <= (others =>'0'); 
                second_filtered_delay13 <= (others =>'0'); 
                second_filtered_delay14 <= (others =>'0'); 
                second_filtered_delay15 <= (others =>'0');
                second_filtered_delay16 <= (others =>'0');
                second_filtered_add_reg <= (others =>'0');
                second_filtered_dif_reg <= (others =>'0');
                second_filtered_out     <= (others =>'0');
            else
                second_filtered_delay1  <= first_filtered_out;
                second_filtered_delay2  <= Second_filtered_delay1; 
                second_filtered_delay3  <= Second_filtered_delay2; 
                second_filtered_delay4  <= Second_filtered_delay3; 
                second_filtered_delay5  <= Second_filtered_delay4; 
                second_filtered_delay6  <= Second_filtered_delay5; 
                second_filtered_delay7  <= Second_filtered_delay6; 
                second_filtered_delay8  <= Second_filtered_delay7; 
                second_filtered_delay9  <= Second_filtered_delay8; 
                second_filtered_delay10 <= Second_filtered_delay9; 
                second_filtered_delay11 <= Second_filtered_delay10; 
                second_filtered_delay12 <= Second_filtered_delay11; 
                second_filtered_delay13 <= Second_filtered_delay12; 
                second_filtered_delay14 <= Second_filtered_delay13; 
                second_filtered_delay15 <= Second_filtered_delay14;
                second_filtered_delay16 <= Second_filtered_delay15; 
                second_filtered_add_reg <= Second_filtered_add(13 downto 0);
                second_filtered_Dif_reg <= Second_filtered_Dif_aux;
                second_filtered_out     <= Second_filtered_add_2(13 downto 0);   
            end if;
        end if;
    end process second_filter_stage;
    
    -- arithmetic operations for the filter
    second_filtered_2_dif_aux <= std_logic_vector(unsigned("000" & second_filtered_out(13 downto 3)) - unsigned("000" & second_filtered_2_select(13 downto 3)));
    second_filtered_2_err_aux <= std_logic_vector(unsigned('0' & second_filtered_out(13 downto 2)) - unsigned('0' & second_filtered_2_add_reg(13 downto 2)));
    second_filtered_2_add <= std_logic_vector(signed('0' & second_filtered_2_add_reg) + signed(resize(signed(second_filtered_2_err_aux),15)));
    second_filtered_2_add_2 <= std_logic_vector(signed('0' & second_filtered_2_add_reg) + signed(resize(signed(second_filtered_2_dif_reg),15)));

    ---- Selects which element from the buffer to pick, and the shift (division)
    second_filter_2_stage_arithmetic: process(second_stage_window_size, second_filtered_2_delay2, second_filtered_2_delay4, second_filtered_2_delay8, second_filtered_2_delay16)
    begin
        if (second_stage_window_size="00") then
            second_filtered_2_select <= second_filtered_2_delay2;
        elsif (second_stage_window_size="01") then
            second_filtered_2_select <= second_filtered_2_delay4;               
        elsif (second_stage_window_size="10") then 
            second_filtered_2_select <= second_filtered_2_delay8;         
        else
            second_filtered_2_select <= second_filtered_2_delay16;    
        end if;
    end process second_filter_2_stage_arithmetic;
    
    -- synchronous buffering data and filter output
    Second_Filter_2_Stage: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                second_filtered_2_delay1    <= (others =>'0');
                second_filtered_2_delay2    <= (others =>'0'); 
                second_filtered_2_delay3    <= (others =>'0'); 
                second_filtered_2_delay4    <= (others =>'0'); 
                second_filtered_2_delay5    <= (others =>'0'); 
                second_filtered_2_delay6    <= (others =>'0'); 
                second_filtered_2_delay7    <= (others =>'0'); 
                second_filtered_2_delay8    <= (others =>'0'); 
                second_filtered_2_delay9    <= (others =>'0');
                second_filtered_2_delay10   <= (others =>'0'); 
                second_filtered_2_delay11   <= (others =>'0');
                second_filtered_2_delay12   <= (others =>'0'); 
                second_filtered_2_delay13   <= (others =>'0'); 
                second_filtered_2_delay14   <= (others =>'0'); 
                second_filtered_2_delay15   <= (others =>'0');
                second_filtered_2_delay16   <= (others =>'0');
                second_filtered_2_add_reg   <= (others =>'0');
                second_filtered_2_dif_reg   <= (others =>'0');
                second_filtered_2_out       <= (others =>'0');
            else
                second_filtered_2_delay1    <= second_filtered_out;
                second_filtered_2_delay2    <= second_filtered_2_delay1; 
                second_filtered_2_delay3    <= second_filtered_2_delay2; 
                second_filtered_2_delay4    <= second_filtered_2_delay3; 
                second_filtered_2_delay5    <= second_filtered_2_delay4; 
                second_filtered_2_delay6    <= second_filtered_2_delay5; 
                second_filtered_2_delay7    <= second_filtered_2_delay6; 
                second_filtered_2_delay8    <= second_filtered_2_delay7; 
                second_filtered_2_delay9    <= second_filtered_2_delay8; 
                second_filtered_2_delay10   <= second_filtered_2_delay9; 
                second_filtered_2_delay11   <= second_filtered_2_delay10; 
                second_filtered_2_delay12   <= second_filtered_2_delay11; 
                second_filtered_2_delay13   <= second_filtered_2_delay12; 
                second_filtered_2_delay14   <= second_filtered_2_delay13; 
                second_filtered_2_delay15   <= second_filtered_2_delay14;
                second_filtered_2_delay16   <= second_filtered_2_delay15; 
                second_filtered_2_add_reg   <= second_filtered_2_add(13 downto 0);
                second_filtered_2_dif_reg   <= second_filtered_2_dif_aux;
                second_filtered_2_out       <= second_filtered_2_add_2(13 downto 0);   
            end if;
        end if;
    end process Second_Filter_2_Stage;
    
    -- timer after reset
----------------------------------------------------------------------------------------------------------------------------------------------------------
    timer_reset_stage: process(clock, reset)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                reset_timer <= reset_timer_cnt;
                not_allow_filter <= '1';
            else
                if (reset_timer>0) then
                    reset_timer <= reset_timer - 1;
                    not_allow_filter <= '1';
                else
                    reset_timer <= reset_timer;
                    not_allow_filter <= '0';
                end if;
            end if;
        end if;
    end process timer_reset_stage;
    
    -- output selection 
----------------------------------------------------------------------------------------------------------------------------------------------------------
    -- filtered / not filtered  
     
    output_proc: process(enable, second_filtered_2_out, din_delay3, not_allow_filter)
    begin
        if( (enable='1') and (not_allow_filter='0') )then
            dout <= second_filtered_2_out;
        else
            dout <= din_delay3; 
        end if;
    end process output_proc;

end trig_prim_filt_arch;