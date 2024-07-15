-- stc.vhd
-- self triggered channel machine for ONE DAPHNE channel
-- 
-- This module watches one channel data bus and computes the average signal level 
-- (baseline.vhd) based on the last 256 samples. When it detects a trigger condition
-- (defined in trig.vhd) it then begins assemblying the output frame in a FIFO. 
-- It stores 64 pre trigger samples plus + post trigger samples, densely packed. 
-- a single 32x1024 FIFO can store nearly 9 output records.
-- 
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity stc is
generic( link_id: std_logic_vector(5 downto 0) := "000000"; ch_id: std_logic_vector(5 downto 0) := "000000" );
port(
    reset: in std_logic;    

    slot_id: std_logic_vector(3 downto 0);
    crate_id: std_logic_vector(9 downto 0);
    detector_id: std_logic_vector(5 downto 0);
    version_id: std_logic_vector(5 downto 0);
    adhoc: std_logic_vector(7 downto 0); -- command for adhoc trigger
    threshold_xc: std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    st_prim_config: std_logic_vector(1 downto 0); -- 5 downto-- local primitives calculation configuration
    ti_trigger: in std_logic_vector(7 downto 0); -------------------------
    ti_trigger_stbr: in std_logic;  -------------------------
    trig_rst_count: in std_logic;
    aclk: in std_logic; -- AFE clock 62.500 MHz
    timestamp: in std_logic_vector(63 downto 0);
	afe_dat: in std_logic_vector(13 downto 0); -- aligned AFE data
    enable: in std_logic;
    
    fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
    fifo_rden: in std_logic;
    fifo_ae: out std_logic;
    fifo_do: out std_logic_vector(31 downto 0);
    fifo_ko: out std_logic_vector( 3 downto 0);
    TCount: out std_logic_vector(63 downto 0);
    Pcount: out std_logic_vector(63 downto 0)
  );
end stc;

architecture stc_arch of stc is

    signal afe_dly32_i, afe_dly64_i, afe_dly96_i, afe_dly128_i, afe_dly160_i, afe_dly: std_logic_vector(13 downto 0); 
    signal afe_dly0, afe_dly1, afe_dly2: std_logic_vector(13 downto 0);
    signal block_count: std_logic_vector(5 downto 0);

    type state_type is (rst, wait4trig, 
                        sof, hdr0, hdr1, hdr2, hdr3, hdr4, 
                        dat0, dat1, dat2, dat3, dat4, dat5, dat6, dat7, dat8, dat9, dat10, dat11, dat12, dat13, dat14, dat15, 
                        trailer1, trailer2, trailer3, trailer4, trailer5, trailer6, 
                        trailer7, trailer8, trailer9, trailer10, trailer11, trailer12, trailer13, eof);
    signal state: state_type;

    signal d: std_logic_vector(31 downto 0);
    signal ts_reg: std_logic_vector(63 downto 0);
    signal k: std_logic_vector(3 downto 0);
    signal fifo_wren: std_logic;
    signal almostempty: std_logic_vector(3 downto 0);
    signal almostfull: std_logic_vector(3 downto 0);
    signal fifo_af: std_logic;
    signal trigCount: unsigned(63 downto 0) := (others => '0');
    signal packCount: unsigned(63 downto 0) := (others => '0');


    type array_4x64_type is array(3 downto 0) of std_logic_vector(63 downto 0);
    signal DI, DO: array_4x64_type;

    type array_4x8_type is array(3 downto 0) of std_logic_vector(7 downto 0);
    signal DIP, DOP: array_4x8_type;

    -- self trigger core signals
    signal baseline: std_logic_vector(13 downto 0); --trigsample
    signal info_previous, data_available_trailer: std_logic;
    signal trailer_word_0, trailer_word_0_reg, trailer_word_1, trailer_word_1_reg: std_logic_vector(31 downto 0);
    signal trailer_word_2, trailer_word_2_reg, trailer_word_3, trailer_word_3_reg: std_logic_vector(31 downto 0);
    signal trailer_word_4, trailer_word_4_reg, trailer_word_5, trailer_word_5_reg: std_logic_vector(31 downto 0);
    signal trailer_word_6, trailer_word_6_reg, trailer_word_7, trailer_word_7_reg: std_logic_vector(31 downto 0);
    signal trailer_word_8, trailer_word_8_reg, trailer_word_9, trailer_word_9_reg: std_logic_vector(31 downto 0);
    signal trailer_word_10, trailer_word_10_reg, trailer_word_11, trailer_word_11_reg: std_logic_vector(31 downto 0);

    -- EIA & CIEMAT & MILANO integration of the self trigger (core and local primitives calculator)

    component trig_prim is
    port(
        clock: in std_logic;
        reset: in std_logic;
        din: in stD_logic_vector(13 downto 0);
        threshold: in std_logic_vector(41 downto 0);
        trig_prim_config: in std_logic_vector(1 downto 0); --5 downto
        triggered: out std_logic;
        data_available: out std_logic;
        time_peak: out std_logic_vector(8 downto 0);
        time_pulse_ub: out std_logic_vector(8 downto 0);
        time_pulse_ob: out std_logic_vector(9 downto 0);
        max_peak: out stD_logic_vector(13 downto 0);
        charge: out std_logic_vector(22 downto 0);
        number_peaks_ub: out std_logic_vector(3 downto 0);
        number_peaks_ob: out std_logic_vector(3 downto 0);
        -- dout_filtered: out std_logic_vector(13 downto 0);
        baseline: out std_logic_vector(13 downto 0);
        amplitude: out std_logic_vector(13 downto 0);
        peak_current: out std_logic;
        xcorr_current: out std_logic_vector(27 downto 0);
        detection: out std_logic;
        sending: out std_logic;
        info_previous: out std_logic;
        data_available_trailer: out std_logic;
        trailer_word_0: out std_logic_vector(31 downto 0);
        trailer_word_1: out std_logic_vector(31 downto 0);
        trailer_word_2: out std_logic_vector(31 downto 0);
        trailer_word_3: out std_logic_vector(31 downto 0);
        trailer_word_4: out std_logic_vector(31 downto 0);
        trailer_word_5: out std_logic_vector(31 downto 0);
        trailer_word_6: out std_logic_vector(31 downto 0);
        trailer_word_7: out std_logic_vector(31 downto 0);
        trailer_word_8: out std_logic_vector(31 downto 0);
        trailer_word_9: out std_logic_vector(31 downto 0);
        trailer_word_10: out std_logic_vector(31 downto 0);
        trailer_word_11: out std_logic_vector(31 downto 0)
    );
    end component;

    component CRC_OL is
    generic( Nbits: positive := 32; CRC_Width: positive := 20;
             G_Poly: std_logic_vector := X"8359f"; G_InitVal: std_logic_vector := X"fffff" );
    port(
        CRC: out std_logic_vector(CRC_Width-1 downto 0);
        Calc: in std_logic;
        Clk: in std_logic;
        DIn: in std_logic_vector(Nbits-1 downto 0);
        Reset: in std_logic);
    end component;

    signal crc_calc, crc_reset, triggered, triggered_ad, triggered_xc: std_logic;
    signal crc20: std_logic_vector(19 downto 0);

begin

    -- delay input data by 128 clocks to compensate for 64 clock trigger latency 
    -- and also for capturing 64 pre-trigger samples

    gendelay: for i in 13 downto 0 generate

        srlc32e_0_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "11111",
            d => afe_dat(i), -- real time AFE data
            q => open,
            q31 => afe_dly32_i(i) -- AFE data 32 clocks ago 
        );
    
        srlc32e_1_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "11111",
            d => afe_dly32_i(i),
            q => open,
            q31 => afe_dly64_i(i) -- AFE data 64 clocks ago
        );

        srlc32e_2_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "11111",
            d => afe_dly64_i(i),
            q => open,
            q31 => afe_dly96_i(i) -- AFE data 96 clocks ago
        );

        srlc32e_3_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "11111",
            d => afe_dly96_i(i),
            q => open,
            q31 => afe_dly128_i(i) -- AFE data 128 clocks ago
        );

        srlc32e_4_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "11111",
            d => afe_dly128_i(i),
            q => open,
            q31 => afe_dly160_i(i) -- AFE data 160 clocks ago
        );

        srlc32e_5_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => "01001",
            d => afe_dly160_i(i),
            q => afe_dly(i), -- AFE data 170 clocks ago
            q31 => open
        );

    end generate gendelay;

    -- now for dense data packing, we need to access up to last 4 samples at once...

    pack_proc: process(aclk)
    begin
        if rising_edge(aclk) then
            afe_dly0 <= afe_dly;
            afe_dly1 <= afe_dly0;
            afe_dly2 <= afe_dly1;
        end if;
    end process pack_proc;         
    
    -- trigger algorithm and local primitives calculator (EIA & CIEMAT's integration) 
    -- trigger latency in this module is assumed 106 clocks (?)

    trig_inst: trig_prim
    port map(
        clock => aclk,
        reset => reset,
        din => afe_dat,
        threshold => threshold_xc,
        trig_prim_config => st_prim_config,
        triggered => triggered_xc,        
        baseline => baseline,
        info_previous => info_previous,
        data_available_trailer => data_available_trailer,
        trailer_word_0 => trailer_word_0,
        trailer_word_1 => trailer_word_1,
        trailer_word_2 => trailer_word_2,
        trailer_word_3 => trailer_word_3,
        trailer_word_4 => trailer_word_4,
        trailer_word_5 => trailer_word_5,
        trailer_word_6 => trailer_word_6,
        trailer_word_7 => trailer_word_7,
        trailer_word_8 => trailer_word_8,
        trailer_word_9 => trailer_word_9,
        trailer_word_10 => trailer_word_10,
        trailer_word_11 => trailer_word_11
    );

    -- register/store the trailer data since it only lasts one clock cycle

    local_prim_frame_proc: process(aclk, data_available_trailer)
    begin
        if rising_edge(aclk) then
            if (data_available_trailer='1') then
                trailer_word_0_reg <= trailer_word_0;
                trailer_word_1_reg <= trailer_word_1;
                trailer_word_2_reg <= trailer_word_2;
                trailer_word_3_reg <= trailer_word_3;
                trailer_word_4_reg <= trailer_word_4;
                trailer_word_5_reg <= trailer_word_5;
                trailer_word_6_reg <= trailer_word_6;
                trailer_word_7_reg <= trailer_word_7;
                trailer_word_8_reg <= trailer_word_8;
                trailer_word_9_reg <= trailer_word_9;
                trailer_word_10_reg <= trailer_word_10;
                trailer_word_11_reg <= trailer_word_11;
            end if;
        end if;
    end process local_prim_frame_proc;

    -- ad hoc trigger condition
        
    triggered_ad <= '1' when ( ( ti_trigger=adhoc and ti_trigger_stbr='1' ) ) else '0';
    
    triggered <= ( triggered_ad or triggered_xc );

    -- FSM waits for trigger condition then assembles output frame and stores into FIFO

    count_proc: process(triggered, reset, trig_rst_count)
    begin
        if (reset = '1' or trig_rst_count = '1') then
        trigCount <= (others => '0'); 
        elsif rising_edge(triggered) then
            if enable = '1' then
                trigCount <= trigCount + 1; 
            end if;
        end if;
    end process;

    builder_fsm_proc: process(aclk)
    begin
        if rising_edge(aclk) then
            if (reset='1' or trig_rst_count='1') then ---------------////
                state <= rst;
                --trigCount <= (others => '0');
                packCount <= (others => '0');
            else
                case(state) is
                    when rst =>
                        state <= wait4trig;
                    when wait4trig => 
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        if (triggered='1' and enable='1' and fifo_af='1') then -- start assembling the output frame
                            block_count <= "000000";
                            packCount <= packCount+1;
                           -- trigCount <= trigCount+1;
                            ts_reg <= std_logic_vector( unsigned(timestamp) - 124 );
                            state <= sof; 
                        else
                            state <= wait4trig; --962 760 410 El de las naranjas
                        end if;
                    when sof =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= hdr0;
                    when hdr0 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= hdr1;
                    when hdr1 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= hdr2;
                    when hdr2 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= hdr3;
                    when hdr3 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= hdr4;
                    when hdr4 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat0;
                    when dat0 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat1;
                    when dat1 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat2;
                    when dat2 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat3;
                    when dat3 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat4;
                    when dat4 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat5;
                    when dat5 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat6;
                    when dat6 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat7;
                    when dat7 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat8;
                    when dat8 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat9;
                    when dat9 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat10;
                    when dat10 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat11;
                    when dat11 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat12;
                    when dat12 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');  
                        end if;
                        state <= dat13;
                    when dat13 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat14;
                    when dat14 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= dat15;
                    when dat15 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        if (block_count="111111") then -- we have cycled through the data block (16 samples per block) 64 times, done
                            state <= trailer1;
                        else
                            block_count <= std_logic_vector(unsigned(block_count) + 1);
                            state <= dat0;
                        end if;
                    when trailer1 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer2;
                    when trailer2 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer3;
                    when trailer3 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer4;
                    when trailer4 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer5;
                    when trailer5 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer6;
                    when trailer6 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer7;
                    when trailer7 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer8;
                    when trailer8 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer9;
                    when trailer9 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer10;
                    when trailer10 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer11;
                    when trailer11 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer12;
                    when trailer12 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= trailer13;
                    when trailer13 =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= eof;
                    when eof =>
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= wait4trig;
                    when others => 
                        if (trig_rst_count = '1') then
                            packCount <= (others => '0');
                        end if;
                        state <= rst;
                end case;
            end if;
        end if;
    end process builder_fsm_proc;

    -- now based on the FSM state, form the output stream
    -- 1024 samples densely packed into (1024/16*7) = 448 words
    -- total frame lenth = SOF + 5 header + 448 data + trailer + EOF = 456 words 

    d <= X"0000003C" when (state=sof) else -- sof of frame word = D0.0 & D0.0 & D0.0 & K28.1
         link_id & slot_id & crate_id & detector_id & version_id when (state=hdr0) else
         ts_reg(31 downto 0)  when (state=hdr1) else
         ts_reg(63 downto 32) when (state=hdr2) else
         (X"0000" & info_previous & "00000" & "0001" & ch_id(5 downto 0)) when (state=hdr3) else  -- trigger sample and channel ID "00" & trigsample & X"00" & "00" & ch_id(5 downto 0)
         ("00" & X"0000" & baseline(13 downto 0)) when (state=hdr4) else -- average baseline and user-threshold
         (afe_dly0( 3 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  0))                          when (state=dat0) else  -- sample2(3..0) & sample1(13..0) & sample0(13..0) 
         (afe_dly0( 7 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  4))                          when (state=dat2) else  -- sample4(7..0) & sample3(13..0) & sample2(13..4) 
         (afe_dly0(11 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  8))                          when (state=dat4) else  -- sample6(11..0) & sample5(13..0) & sample4(13..8) 
         ( afe_dly( 1 downto 0) & afe_dly0(13 downto 0) & afe_dly1(13 downto  0) & afe_dly2(13 downto 12)) when (state=dat6) else  -- sample9(1..0) & sample8(13..0) & sample7(13..0) & sample6(13..12) 
         (afe_dly0( 5 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  2))                          when (state=dat9) else  -- sample11(5..0) & sample10(13..0) & sample9(13..2)
         (afe_dly0( 9 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  6))                          when (state=dat11) else -- sample13(9..0) & sample12(13..0) & sample11(13..6)
         (afe_dly0(13 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto 10))                          when (state=dat13) else -- sample15(13..0) & sample14(13..0) & sample13(13..10)
         trailer_word_0_reg when (state=trailer1) else -- X"00000000"
         trailer_word_1_reg when (state=trailer2) else -- X"00000000"
         trailer_word_2_reg when (state=trailer3) else -- X"00000000"
         trailer_word_3_reg when (state=trailer4) else -- X"00000000"
         trailer_word_4_reg when (state=trailer5) else -- X"00000000"
         trailer_word_5_reg when (state=trailer6) else -- X"00000000"
         trailer_word_6_reg when (state=trailer7) else -- X"00000000"
         trailer_word_7_reg when (state=trailer8) else -- X"00000000"
         trailer_word_8_reg when (state=trailer9) else -- X"00000000"
         trailer_word_9_reg when (state=trailer10) else -- X"00000000"
         trailer_word_10_reg when (state=trailer11) else -- X"00000000"
         trailer_word_11_reg when (state=trailer12) else -- X"00000000"
         X"FFFFFFFF" when (state=trailer13) else
         "0000" & crc20 & X"DC" when (state=eof) else -- "0000" & CRC[19..0] & K28.6
         X"00000000"; 

    k <= "0001" when (state=sof) else
         "0001" when (state=eof) else 
         "0000";

    fifo_wren <= '1' when (state=sof) else
                 '1' when (state=hdr0) else
                 '1' when (state=hdr1) else
                 '1' when (state=hdr2) else
                 '1' when (state=hdr3) else
                 '1' when (state=hdr4) else
                 '1' when (state=dat0) else
                 '1' when (state=dat2) else
                 '1' when (state=dat4) else
                 '1' when (state=dat6) else
                 '1' when (state=dat9) else
                 '1' when (state=dat11) else
                 '1' when (state=dat13) else
                 '1' when (state=trailer1) else
                 '1' when (state=trailer2) else
                 '1' when (state=trailer3) else
                 '1' when (state=trailer4) else
                 '1' when (state=trailer5) else
                 '1' when (state=trailer6) else
                 '1' when (state=trailer7) else
                 '1' when (state=trailer8) else
                 '1' when (state=trailer9) else
                 '1' when (state=trailer10) else
                 '1' when (state=trailer11) else
                 '1' when (state=trailer12) else
                 '1' when (state=trailer13) else
                 '1' when (state=eof) else
                 '0';

    -- CRC generator is calculated over the DAPHNE frame, do not include the SOF and EOF words

    crc_calc <=  '1' when (state=hdr0) else
                 '1' when (state=hdr1) else
                 '1' when (state=hdr2) else
                 '1' when (state=hdr3) else
                 '1' when (state=hdr4) else
                 '1' when (state=dat0) else
                 '1' when (state=dat2) else
                 '1' when (state=dat4) else
                 '1' when (state=dat6) else
                 '1' when (state=dat9) else
                 '1' when (state=dat11) else
                 '1' when (state=dat13) else
                 '1' when (state=trailer1) else
                 '1' when (state=trailer2) else
                 '1' when (state=trailer3) else
                 '1' when (state=trailer4) else
                 '1' when (state=trailer5) else
                 '1' when (state=trailer6) else
                 '1' when (state=trailer7) else
                 '1' when (state=trailer8) else
                 '1' when (state=trailer9) else
                 '1' when (state=trailer10) else
                 '1' when (state=trailer11) else
                 '1' when (state=trailer12) else
                 '1' when (state=trailer13) else
                 '0';

    crc_reset <= '1' when (state=wait4trig) else '0'; -- change from SOF to idle/wait4trig to be consistant with streaming output (which works!)

    crc_inst: CRC_OL
       generic map (Nbits => 32, CRC_Width => 20, G_Poly => X"8359f", G_InitVal => X"FFFFF")
       port map(
         reset => crc_reset,
         clk => aclk,
         calc => crc_calc,
         din => d,
         crc => crc20);

     -- output FIFO is 4096 deep, so we can store up to ~8.78 output frames before overflow occurs
     -- now check the FIFO filling and draining rates so we avoid under-run...
     --
     -- BUT BE CAREFUL HERE... while it is true one complete frame is 466 words long, it takes LONGER
     -- than 466 ACLKs to write it into the FIFO because 7 data words written requires 16 clocks to receive
     -- That means that it takes: SOF + (5 Header) + (1024 data) + (13 trailer) + EOF = 1044 clocks. 
     -- At 62.5MHz this is ~16.5us. Once selected for readout, however, the event will be read from the FIFO
     -- in 466 FCLK cycles, or 3.88us. So once triggered this FIFO will fill relatively slowly, but once 

    genfifo: for i in 3 downto 0 generate

        DI(i)  <=  X"00000000000000" & d( ((8*i)+7) downto (8*i) );
        DIP(i) <=  "0000000" & k(i);

        fifo_inst: FIFO36E1 -- 9 bit wide x 4096 deep
        generic map(
            ALMOST_EMPTY_OFFSET => X"0180", -- this requires the careful tuning
            ALMOST_FULL_OFFSET => X"01D4", -- ORIGINAL X'0080' 
            DATA_WIDTH => 9,                 
            DO_REG => 1,
            EN_SYN => FALSE,                  
            EN_ECC_READ => FALSE,
            EN_ECC_WRITE => FALSE,
            FIFO_MODE => "FIFO36",         
            FIRST_WORD_FALL_THROUGH => TRUE, 
            INIT => X"000000000000000000",             
            SIM_DEVICE => "7SERIES",          
            SRVAL => X"000000000000000000"
        )
        port map(
            RST    => reset,
            RSTREG => '0',
            REGCE  => '1',
            INJECTDBITERR => '0',
            INJECTSBITERR => '0',
            WRCLK  => aclk, 
            WREN   => fifo_wren,
            DI     => DI(i), -- must be 64 bit vector, only lower byte is used
            DIP    => DIP(i), -- must be 8 bit vector, only lower bit is used
            RDCLK  => fclk,
            RDEN   => fifo_rden,
            DO     => DO(i), -- must be 64 bit vector, only lower byte is used
            DOP    => DOP(i), -- must be 8 bit vector, only lower bit is used
            ALMOSTEMPTY => almostempty(i),
            ALMOSTFULL => almostfull(i)
        );

    end generate genfifo;

    fifo_ae <= '1' when (almostempty="0000") else '0';
    fifo_af <= '1' when (almostfull="0000") else '0';
    fifo_do(31 downto 0) <= DO(3)(7 downto 0) & DO(2)(7 downto 0) & DO(1)(7 downto 0) & DO(0)(7 downto 0);
    fifo_ko( 3 downto 0) <= DOP(3)(0) & DOP(2)(0) & DOP(1)(0) & DOP(0)(0);
    TCount <= std_logic_vector(trigCount); 
    Pcount <= std_logic_vector(packCount); 


end stc_arch;