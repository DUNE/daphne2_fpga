-- resets.vhd
--
-- make a few different types of soft reset and align to different clock domains
-- all soft resets come from GbE logic in the OEICLK domain. this assumes that the OEICLOCK
--
-- DAPHNE2
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.daphne2_package.all;

entity resets is
port(
     
    oeiclk: in std_logic;
    rx_wren: in std_logic;
    rx_addr: in std_logic_vector(31 downto 0);

    sclk100: in std_logic;
    sclk200: in std_logic;
    mclk: in std_logic;

    reset_fe_mclk: out std_logic;  -- reset the iserdes and fsm in the front end
    reset_fe_sclk200: out std_logic; -- reset the idelay
    reset_ep: out std_logic; -- sync to sclk100
    reset_mmcm1: out std_logic -- ok to sync to sclk100
  );
end resets;

architecture resets_arch of resets is

signal fe_rst_decode, fe_rst_decode_reg: std_logic;
signal fe_rst_count: std_logic_vector(5 downto 0);
signal fe_rst1_reg, fe_rst2_reg: std_logic;
signal reset_fe_mclk_reg, reset_fe_sclk200_reg: std_logic;

signal mmcm1_rst_decode, mmcm1_rst_decode_reg: std_logic;
signal mmcm1_rst_count: std_logic_vector(3 downto 0);
signal mmcm1_rst_reg: std_logic;
signal mmcm1_rst_sclk100_reg: std_logic;

signal ep_rst_decode, ep_rst_decode_reg: std_logic;
signal ep_rst_count: std_logic_vector(3 downto 0);
signal ep_rst_reg: std_logic;
signal ep_rst_sclk100_reg: std_logic;

begin

-- when the user wants to soft reset the front end logic, they write to this GBE address

fe_rst_decode <= '1' when (std_match(rx_addr,FE_RST_ADDR) and rx_wren='1') else '0';

-- triggers an up counter and produces two wide pulses one after another, still in oeiclk domain

fe_rst_proc: process(oeiclk)
begin
    if rising_edge(oeiclk) then
        fe_rst_decode_reg <= fe_rst_decode;  -- register and pulse stretch in the oeiclk domain

        if (fe_rst_decode_reg='1') then
            fe_rst_count <= "000000";
        elsif (fe_rst_count /= "111111") then
            fe_rst_count <= std_logic_vector(unsigned(fe_rst_count)+1);
        end if;

        if (fe_rst_count(5 downto 4)="00") then -- each pulse is ~128ns
            fe_rst1_reg <= '1';
        else
            fe_rst1_reg <= '0';
        end if;

        if (fe_rst_count(5 downto 4)="10") then
            fe_rst2_reg <= '1';
        else
            fe_rst2_reg <= '0';
        end if;

    end if;
end process fe_rst_proc;

-- resync these FE reset pulses in the correct clock domains

fe_rst_sclk200_proc: process(sclk200) -- first front end reset pulse, to reset the idelay, sync to sclk200
begin
    if rising_edge(sclk200) then
        reset_fe_sclk200_reg <= fe_rst1_reg;
    end if;
end process fe_rst_sclk200_proc;

reset_fe_sclk200 <= reset_fe_sclk200_reg; 

fe_rst_mclk_proc: process(mclk) -- then the other front end reset pulse, for the fsm and iserdes
begin
    if rising_edge(mclk) then
        reset_fe_mclk_reg <= fe_rst2_reg;
    end if;
end process fe_rst_mclk_proc;

reset_fe_mclk <= reset_fe_mclk_reg;

-- mmcm1 reset
-- mmcm1 makes mclk and fclk, the main clocks for the FPGA
-- reset mmcm1 any time the clock input changes (local vs endpoint)

mmcm1_rst_decode <= '1' when (std_match(rx_addr,MMCM1_RST_ADDR) and rx_wren='1') else '0';

mmcm1_rst_proc: process(oeiclk)
begin
    if rising_edge(oeiclk) then
        mmcm1_rst_decode_reg <= mmcm1_rst_decode;
        if (mmcm1_rst_decode_reg='1') then
            mmcm1_rst_count <= "0000";
            mmcm1_rst_reg <= '1';
        elsif (mmcm1_rst_count /= "1111") then
            mmcm1_rst_count <= std_logic_vector(unsigned(mmcm1_rst_count)+1);
            mmcm1_rst_reg <= '1';
        else
            mmcm1_rst_reg <= '0';
        end if;
    end if;
end process mmcm1_rst_proc;

-- endpoint reset

ep_rst_decode <= '1' when (std_match(rx_addr,EP_RST_ADDR) and rx_wren='1') else '0';

ep_rst_proc: process(oeiclk)
begin
    if rising_edge(oeiclk) then
        ep_rst_decode_reg <= ep_rst_decode;
        if (ep_rst_decode_reg='1') then
            ep_rst_count <= "0000";
            ep_rst_reg <= '1';
        elsif (ep_rst_count /= "1111") then
            ep_rst_count <= std_logic_vector(unsigned(ep_rst_count)+1);
            ep_rst_reg <= '1';
        else
            ep_rst_reg <= '0';
        end if;
    end if;
end process ep_rst_proc;

-- ep and mmcm1 resets should be resynced into sclk100 domain

sclk100_rst_proc: process(sclk100)
begin
    if rising_edge(sclk100) then
        ep_rst_sclk100_reg <= ep_rst_reg;
        mmcm1_rst_sclk100_reg <= mmcm1_rst_reg;
    end if;
end process sclk100_rst_proc;

reset_ep <= ep_rst_sclk100_reg;

reset_mmcm1 <= mmcm1_rst_sclk100_reg;

end resets_arch;
