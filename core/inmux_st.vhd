-- inmux_st.vhd
--
-- channel input mux connects the input channel buses (9x5x14) to the four self trigger streaming sender inputs.
-- each input bus is connected to an input bus and this selection is controlled by a 6 bit register
-- these control registers are R/W. Self trigger senders have 10 channel inputs. This new module is implemented as
-- a different version fo the one created for the straming senders because of this difference.
--
-- jamieson olsen <jamieson@fnal.gov> & daniel avila gomez <daniel.avila@eia.edu.co>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne2_package.all;

entity inmux_st is
port(
    clock: in std_logic;
    reset: in std_logic;
    we: in std_logic;
    addr: in std_logic_vector(5 downto 0);
    din: in std_logic_vector(5 downto 0);
    enable: in std_logic_vector(39 downto 0);
    dout: out std_logic_vector(5 downto 0);

    afe_dat: in array_5x9x14_type; -- AFE data synced to mclk
    enable_out: out array_4x10_type; -- enable for selected respective AFE channels
    data_out: out array_4x10x14_type; -- AFE data out to the four self trigger senders
    chid_out: out array_4x10x6_type -- channel id outputs to the self trigger sender
);
end inmux_st;

architecture inmux_st_arch of inmux_st is

    -- 40 6-bit select registers in 3D array with worlds nastiest initial conditions

    signal select_reg: array_4x10x6_type := (
        0 => (0=>"000000", 1=>"000001", 2=>"000010", 3=>"000011", 4=>"000100",
              5=>"000101", 6=>"000110", 7=>"000111", 8=>"001010", 9=>"001011"),
        1 => (0=>"001100", 1=>"001101", 2=>"001110", 3=>"001111", 4=>"010000",
              5=>"010001", 6=>"010100", 7=>"010101", 8=>"010110", 9=>"010111"),
        2 => (0=>"011000", 1=>"011001", 2=>"011010", 3=>"011011", 4=>"011110",
              5=>"011111", 6=>"100000", 7=>"100001", 8=>"100010", 9=>"100011"),  
        3 => (0=>"100100", 1=>"100101", 2=>"101000", 3=>"101001", 4=>"101010",
              5=>"101011", 6=>"101100", 7=>"101101", 8=>"101110", 9=>"101111"));

begin

    -- handle writing and reading back the control registers

    gen_sender: for s in 3 downto 0 generate
        gen_chan: for c in 9 downto 0 generate
        
        process(clock)
        begin
            if rising_edge(clock) then
                if ( we='1' and addr=std_logic_vector(to_unsigned(10*s+c,6)) ) then
                    select_reg(s)(c) <= din;
                end if;
            end if;
        end process;

        dout <= select_reg(s)(c) when ( addr=std_logic_vector(to_unsigned(s,6)) ) else "ZZZZZZ";
        
        end generate gen_chan;
    end generate gen_sender;    

    -- 40 output muxes, each one is controlled by a sel_reg register and selects any one of input buses.
    -- note that the "9th" input bus afe_dat(x)(8) is the frame marker, which is not useful for any of the
    -- sender modules, so it is NOT selectable here. To force an output bus to all zeros, set select_reg to
    -- an unused/illegal value (for example, 8 or 9).
    -- each select register controls its respective enabler too, so that is the reason why the enabler
    -- has the exact same configuration.

    gen_outsender: for s in 3 downto 0 generate
        gen_outchan: for c in 9 downto 0 generate

        enable_out(s)(c) <= enable(0)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(0,6)) ) else 
                            enable(1)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(1,6)) ) else 
                            enable(2)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(2,6)) ) else
                            enable(3)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(3,6)) ) else
                            enable(4)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(4,6)) ) else
                            enable(5)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(5,6)) ) else
                            enable(6)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(6,6)) ) else
                            enable(7)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(7,6)) ) else

                            enable(8)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(10,6)) ) else
                            enable(9)  when ( select_reg(s)(c)=std_logic_vector(to_unsigned(11,6)) ) else
                            enable(10) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(12,6)) ) else
                            enable(11) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(13,6)) ) else
                            enable(12) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(14,6)) ) else
                            enable(13) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(15,6)) ) else
                            enable(14) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(16,6)) ) else
                            enable(15) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(17,6)) ) else

                            enable(16) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(20,6)) ) else
                            enable(17) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(21,6)) ) else
                            enable(18) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(22,6)) ) else
                            enable(19) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(23,6)) ) else
                            enable(20) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(24,6)) ) else
                            enable(21) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(25,6)) ) else
                            enable(22) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(26,6)) ) else
                            enable(23) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(27,6)) ) else

                            enable(24) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(30,6)) ) else
                            enable(25) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(31,6)) ) else
                            enable(26) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(32,6)) ) else
                            enable(27) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(33,6)) ) else
                            enable(28) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(34,6)) ) else
                            enable(29) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(35,6)) ) else
                            enable(30) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(36,6)) ) else
                            enable(31) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(37,6)) ) else

                            enable(32) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(40,6)) ) else
                            enable(33) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(41,6)) ) else
                            enable(34) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(42,6)) ) else
                            enable(35) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(43,6)) ) else
                            enable(36) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(44,6)) ) else
                            enable(37) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(45,6)) ) else
                            enable(38) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(46,6)) ) else
                            enable(39) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(47,6)) ) else

                            enable(10*s+c);
        
        data_out(s)(c) <= afe_dat(0)(0) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(0,6)) ) else
                          afe_dat(0)(1) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(1,6)) ) else 
                          afe_dat(0)(2) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(2,6)) ) else
                          afe_dat(0)(3) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(3,6)) ) else
                          afe_dat(0)(4) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(4,6)) ) else
                          afe_dat(0)(5) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(5,6)) ) else
                          afe_dat(0)(6) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(6,6)) ) else
                          afe_dat(0)(7) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(7,6)) ) else

                          afe_dat(1)(0) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(10,6)) ) else
                          afe_dat(1)(1) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(11,6)) ) else
                          afe_dat(1)(2) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(12,6)) ) else
                          afe_dat(1)(3) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(13,6)) ) else
                          afe_dat(1)(4) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(14,6)) ) else
                          afe_dat(1)(5) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(15,6)) ) else
                          afe_dat(1)(6) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(16,6)) ) else
                          afe_dat(1)(7) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(17,6)) ) else

                          afe_dat(2)(0) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(20,6)) ) else
                          afe_dat(2)(1) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(21,6)) ) else
                          afe_dat(2)(2) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(22,6)) ) else
                          afe_dat(2)(3) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(23,6)) ) else
                          afe_dat(2)(4) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(24,6)) ) else
                          afe_dat(2)(5) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(25,6)) ) else
                          afe_dat(2)(6) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(26,6)) ) else
                          afe_dat(2)(7) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(27,6)) ) else

                          afe_dat(3)(0) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(30,6)) ) else
                          afe_dat(3)(1) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(31,6)) ) else
                          afe_dat(3)(2) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(32,6)) ) else
                          afe_dat(3)(3) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(33,6)) ) else
                          afe_dat(3)(4) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(34,6)) ) else
                          afe_dat(3)(5) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(35,6)) ) else
                          afe_dat(3)(6) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(36,6)) ) else
                          afe_dat(3)(7) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(37,6)) ) else

                          afe_dat(4)(0) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(40,6)) ) else
                          afe_dat(4)(1) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(41,6)) ) else
                          afe_dat(4)(2) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(42,6)) ) else
                          afe_dat(4)(3) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(43,6)) ) else
                          afe_dat(4)(4) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(44,6)) ) else
                          afe_dat(4)(5) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(45,6)) ) else
                          afe_dat(4)(6) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(46,6)) ) else
                          afe_dat(4)(7) when ( select_reg(s)(c)=std_logic_vector(to_unsigned(47,6)) ) else

                          (others => '0');
        
        end generate gen_outchan;
    end generate gen_outsender;

    -- the senders, which are connected to the outputs of this module, need to know the channel id
    -- values for each data self trigger channel they are receiving. the channel id values are stored in the
    -- select_reg registers. so output these values here...

    chid_out <= select_reg;

end inmux_st_arch;