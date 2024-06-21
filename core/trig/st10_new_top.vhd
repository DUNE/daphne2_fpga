-- st10_new_top.vhd
-- DAPHNE core logic, top level, self triggered mode sender
-- 10 AFE channels -> one output link to DAQ
-- 
-- Jamieson Olsen <jamieson@fnal.gov> & Daniel Avila Gomez <daniel.avila@eia.edu.co>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.daphne2_package.all;

entity st10_new_top is
generic( link_id: std_logic_vector(5 downto 0)  := "000000" ); -- this is the OUTPUT link ID that goes into the header
port(
    reset: in std_logic;

    adhoc: in std_logic_vector(7 downto 0); -- user defined command for adhoc trigger
    threshold: in std_logic_vector(13 downto 0); -- user defined threshold relative to avg baseline
    ti_trigger: in std_logic_vector(7 downto 0); -------------------------
    ti_trigger_stbr: in std_logic;  -------------------------
    slot_id: in std_logic_vector(3 downto 0);
    crate_id: in std_logic_vector(9 downto 0);
    detector_id: in std_logic_vector(5 downto 0);
    version_id: in std_logic_vector(5 downto 0);
    enable: in std_logic_vector(9 downto 0);

    aclk: in std_logic; -- AFE clock 62.500 MHz
    timestamp: in std_logic_vector(63 downto 0);
    afe_dat: in array_10x14_type; -- 10 AFE channels feed into this module
    ch_id: in array_10x6_type; -- channel identifier of each fo teh 10 AFE channels
    fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
    dout: out std_logic_vector(31 downto 0);
    kout: out std_logic_vector(3 downto 0)
);
end st10_new_top;

architecture st10_new_top_arch of st10_new_top is

    type state_type is (rst, scan, dump, idle);
    signal state: state_type;

    signal selc: integer range 0 to 9;
    signal fifo_ae: std_logic_vector(9 downto 0);
    signal fifo_rden: std_logic_vector(9 downto 0);
    signal fifo_ready: std_logic;
    signal fifo_do: array_10x32_type;
    signal fifo_ko: array_10x4_type;
    signal d, dout_reg: std_logic_vector(31 downto 0);
    signal k, kout_reg: std_logic_vector( 3 downto 0);

    component stc is
    generic( link_id: std_logic_vector(5 downto 0) := "000000" );
    port(
        reset: in std_logic;

        adhoc: in std_logic_vector(7 downto 0);
        threshold: std_logic_vector(13 downto 0);
        slot_id: std_logic_vector(3 downto 0);
        crate_id: std_logic_vector(9 downto 0);
        detector_id: std_logic_vector(5 downto 0);
        version_id: std_logic_vector(5 downto 0);
        enable: std_logic;

        aclk: in std_logic; -- AFE clock 62.500 MHz
        timestamp: in std_logic_vector(63 downto 0);
        ti_trigger: in std_logic_vector(7 downto 0); -------------------------
        ti_trigger_stbr: in std_logic;  -------------------------
        afe_dat: in std_logic_vector(13 downto 0);
        ch_id: in std_logic_vector(5 downto 0);
        fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
        fifo_rden: in std_logic;
        fifo_ae: out std_logic;
        fifo_do: out std_logic_vector(31 downto 0);
        fifo_ko: out std_logic_vector( 3 downto 0)
        );
    end component;

begin

    -- make 10 STC machines to monitor 10 AFE channels

    gen_stc_c: for c in 9 downto 0 generate

            stc_inst: stc 
            generic map( link_id => link_id ) 
            port map(
                reset => reset,
    
                adhoc => adhoc,
                threshold => threshold,
                ti_trigger => ti_trigger, -------------------------
                ti_trigger_stbr => ti_trigger_stbr,  -------------------------
                slot_id => slot_id,
                crate_id => crate_id,
                detector_id => detector_id,
                version_id => version_id,
                enable => enable(c),
    
                aclk => aclk,
                timestamp => timestamp,
            	afe_dat => afe_dat(c),
                ch_id => ch_id(c),
                fclk => fclk,
                fifo_rden => fifo_rden(c),
                fifo_ae => fifo_ae(c),
                fifo_do => fifo_do(c),
                fifo_ko => fifo_ko(c)
              );

    end generate gen_stc_c;

    -- sel_reg is a straight 6 bit register, but it is encoded with values 0-7, 10-17, 20-27, 30-37, 40-47
    -- there are gaps, so be careful when incrementing and looping...

    fifo_ready_proc: process(selc, fifo_ae)
    begin
        fifo_ready <= '0'; -- default
        loop_c: for c in 9 downto 0 loop
            if (selc=c and fifo_ae(c)='1') then
                fifo_ready <= '1';
            end if;
        end loop loop_c;
    end process fifo_ready_proc;

    gen_rden_c: for c in 9 downto 0 generate
        fifo_rden(c) <= '1' when (selc=c and state=dump) else '0';
    end generate gen_rden_c;

    -- FSM scans all STC machines in round robin manner, looking for a FIFO almost empty "fifo_ae" flag set. when it finds
    -- this, it reads one complete frame from that machine, then sends a few idles, then returns to scanning again.

    fsm_proc: process(fclk)
    begin
        if rising_edge(fclk) then
            if (reset='1') then
                state <= rst;
            else
                case(state) is

                    when rst =>
                        selc <= 0;
                        state <= scan;

                    when scan => 
                        if (fifo_ready='1') then
                            state <= dump;
                        else
                            if (selc=9) then
                                selc <= 0;
                            else
                                selc <= selc + 1;
                            end if;
                            state <= scan;
                        end if;

                    when dump =>
                        if (k="0001" and d(7 downto 0)=X"DC") then -- this the EOF word, done reading from this STC
                            state <= idle;
                        else
                            state <= dump;
                        end if;

                    when idle => -- send one idle word and resume scanning...
                        if (selc = 9) then
                            selc <= 0;
                        else
                            selc <= selc + 1;
                        end if;
                        state <= scan;

                    when others => 
                        state <= rst;
                end case;
            end if;
        end if;
    end process fsm_proc;

    outmux_proc: process(fifo_do, fifo_ko, selc, state)
    begin
        d <= X"000000BC"; -- default
        k <= "0001"; -- default
        loop_c: for c in 9 downto 0 loop
            if ( selc=c and state=dump ) then
                d <= fifo_do(c);
                k <= fifo_ko(c);
            end if;
        end loop loop_c;
    end process outmux_proc;

    -- register the outputs

    outreg_proc: process(fclk)
    begin
        if rising_edge(fclk) then
            dout_reg <= d;
            kout_reg <= k;
        end if;
    end process outreg_proc;

    dout <= dout_reg;
    kout <= kout_reg;

end st10_new_top_arch;