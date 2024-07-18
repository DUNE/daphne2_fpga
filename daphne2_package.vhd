-- daphne2_package.vhd
-- for the DAPHNE2 design
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package daphne2_package is

    -- Set lower byte of static IP for GbE Interface.
    -- MAC = 00:80:55:DE:00:XX and IP = 192.168.133.XX
    -- where XX is EFUSE_USER[15..8] NOTE this is one time programmable!

    -- Address Mapping using the std_match notation '-' is a "don't care" bit

    constant BRAM0_ADDR:    std_logic_vector(31 downto 0) := "0000000000000111000000----------";  -- 0x00070000-0x000703FF
    constant DEADBEEF_ADDR: std_logic_vector(31 downto 0) := X"0000aa55";
    constant STATVEC_ADDR:  std_logic_vector(31 downto 0) := X"00001974";
    constant SFPSTATVEC_ADDR:  std_logic_vector(31 downto 0) := X"00001975";
    constant GITVER_ADDR:   std_logic_vector(31 downto 0) := X"00009000";
    constant TESTREG_ADDR:  std_logic_vector(31 downto 0) := X"12345678";
    constant FIFO_ADDR:     std_logic_vector(31 downto 0) := X"80000000";

    type array_4x4_type is array (3 downto 0) of std_logic_vector(3 downto 0);
    type array_4x6_type is array (3 downto 0) of std_logic_vector(5 downto 0);
    type array_4x14_type is array (3 downto 0) of std_logic_vector(13 downto 0);
    type array_4x32_type is array (3 downto 0) of std_logic_vector(31 downto 0);
    type array_5x8_type is array (4 downto 0) of std_logic_vector(7 downto 0);
    type array_5x9_type is array (4 downto 0) of std_logic_vector(8 downto 0);
    type array_8x4_type is array (7 downto 0) of std_logic_vector(3 downto 0);
    type array_8x14_type is array (7 downto 0) of std_logic_vector(13 downto 0);
    type array_8x32_type is array (7 downto 0) of std_logic_vector(31 downto 0);
    type array_8x64_type is array (7 downto 0) of std_logic_vector(63 downto 0);
    type array_9x14_type is array (8 downto 0) of std_logic_vector(13 downto 0);
    type array_9x16_type is array (8 downto 0) of std_logic_vector(15 downto 0);
    type array_10x6_type is array (9 downto 0) of std_logic_vector(5 downto 0);
    type array_10x14_type is array (9 downto 0) of std_logic_vector(13 downto 0);

    type array_4x4x6_type is array (3 downto 0) of array_4x6_type;
    type array_4x4x14_type is array (3 downto 0) of array_4x14_type;
    type array_4x10x6_type is array (3 downto 0) of array_10x6_type;
    type array_4x10x14_type is array (3 downto 0) of array_10x14_type;
    type array_5x8x4_type is array (4 downto 0) of array_8x4_type;
    type array_5x8x14_type is array (4 downto 0) of array_8x14_type;
    type array_5x8x32_type is array (4 downto 0) of array_8x32_type;
    type array_5x8x64_type is array (4 downto 0) of array_8x64_type;
    type array_5x9x14_type is array (4 downto 0) of array_9x14_type;
    type array_5x9x16_type is array (4 downto 0) of array_9x16_type;

    -- write anything to this address to force trigger

    constant TRIGGER_ADDR: std_logic_vector(31 downto 0) := X"00002000";

    -- write anything to this address to force front end recalibration

    constant FE_RST_ADDR: std_logic_vector(31 downto 0) := X"00002001";

    -- read the status of the automatic front end logic (is it done?)

    constant FEDONE_ADDR: std_logic_vector(31 downto 0) := X"00002002";

    -- read the status of the automatic front end logic (warning of bit errors)

    constant FEWARN_ADDR: std_logic_vector(31 downto 0) := X"00002003";

    -- read the error count for each AFE front end module (range 0 to 255)

    constant AFE0_ERRCNT_ADDR: std_logic_vector(31 downto 0) := X"00002010";
    constant AFE1_ERRCNT_ADDR: std_logic_vector(31 downto 0) := X"00002011";
    constant AFE2_ERRCNT_ADDR: std_logic_vector(31 downto 0) := X"00002012";
    constant AFE3_ERRCNT_ADDR: std_logic_vector(31 downto 0) := X"00002013";
    constant AFE4_ERRCNT_ADDR: std_logic_vector(31 downto 0) := X"00002014";

    -- output link parameters

    constant DAQ_OUT_PARAM_ADDR: std_logic_vector(31 downto 0) := X"00003000";

    constant DEFAULT_DAQ_OUT_SLOT_ID:     std_logic_vector(3 downto 0) := "0010";
    constant DEFAULT_DAQ_OUT_CRATE_ID:    std_logic_vector(9 downto 0) := "0000000001";
    constant DEFAULT_DAQ_OUT_DETECTOR_ID: std_logic_vector(5 downto 0) := "000010";
    constant DEFAULT_DAQ_OUT_VERSION_ID:  std_logic_vector(5 downto 0) := "000010";

    -- DAQ output link mode selection register

    constant DAQ_OUTMODE_BASEADDR: std_logic_vector(31 downto 0) := X"00003001";

    constant DEFAULT_DAQ_OUTMODE: std_logic_vector(7 downto 0) := X"00";

    -- master clock and timing endpoint status register

    constant MCLK_STAT_ADDR: std_logic_vector(31 downto 0) := X"00004000";

    -- master clock and timing endpoint control register

    constant MCLK_CTRL_ADDR: std_logic_vector(31 downto 0) := X"00004001";
    
    -- write anything to this address to reset master clock MMCM1

    constant MMCM1_RST_ADDR: std_logic_vector(31 downto 0) := X"00004002";

    -- write anything to this address to reset timing endpoint logic

    constant EP_RST_ADDR: std_logic_vector(31 downto 0) := X"00004003";

    -- choose which inputs are connected to each streaming core sender.
    -- This is a block of 16 registers and is R/W 0x5000 - 0x500F  

    constant CORE_INMUX_ADDR: std_logic_vector(31 downto 0) := "0000000000000000010100000000----";

    -- address of the threshold register for the self trig senders

    constant THRESHOLD_BASEADDR: std_logic_vector(31 downto 0) := X"00006000";

    constant DEFAULT_THRESHOLD: std_logic_vector(13 downto 0) := "00000100000000";

    -- enable disable individual input channels for self triggered sender only

    constant ST_ENABLE_ADDR: std_logic_vector(31 downto 0) := X"00006001";

    constant DEFAULT_ST_ENABLE: std_logic_vector(39 downto 0) := X"0000000000"; -- all self triggered channels OFF 

    -- address of the ad hoc command for the self trig senders

    constant ST_ADHOC_BASEADDR: std_logic_vector(31 downto 0) := X"00006010";

    constant DEFAULT_ST_ADHOC_COMMAND: std_logic_vector(7 downto 0) := X"07";

    -- address of the cross correlation threshold register for the self trig sender

    constant THRESHOLD_XC_BASEADDR: std_logic_vector(31 downto 0) := X"00006100";
    
    constant DEFAULT_THRESHOLD_XC: std_logic_vector(41 downto 0) := "111111101100000000000000000000000011001000";

    -- spy buffers are 4k deep

    constant SPYBUF_AFE0_D0_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000000----------------";
    constant SPYBUF_AFE0_D1_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000001----------------";
    constant SPYBUF_AFE0_D2_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000010----------------";
    constant SPYBUF_AFE0_D3_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000011----------------";
    constant SPYBUF_AFE0_D4_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000100----------------";
    constant SPYBUF_AFE0_D5_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000101----------------";
    constant SPYBUF_AFE0_D6_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000110----------------";
    constant SPYBUF_AFE0_D7_BASEADDR: std_logic_vector(31 downto 0) := "0100000000000111----------------";
    constant SPYBUF_AFE0_FR_BASEADDR: std_logic_vector(31 downto 0) := "0100000000001000----------------";

    constant SPYBUF_AFE1_D0_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010000----------------";
    constant SPYBUF_AFE1_D1_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010001----------------";
    constant SPYBUF_AFE1_D2_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010010----------------";
    constant SPYBUF_AFE1_D3_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010011----------------";
    constant SPYBUF_AFE1_D4_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010100----------------";
    constant SPYBUF_AFE1_D5_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010101----------------";
    constant SPYBUF_AFE1_D6_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010110----------------";
    constant SPYBUF_AFE1_D7_BASEADDR: std_logic_vector(31 downto 0) := "0100000000010111----------------";
    constant SPYBUF_AFE1_FR_BASEADDR: std_logic_vector(31 downto 0) := "0100000000011000----------------";

    constant SPYBUF_AFE2_D0_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100000----------------";
    constant SPYBUF_AFE2_D1_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100001----------------";
    constant SPYBUF_AFE2_D2_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100010----------------";
    constant SPYBUF_AFE2_D3_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100011----------------";
    constant SPYBUF_AFE2_D4_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100100----------------";
    constant SPYBUF_AFE2_D5_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100101----------------";
    constant SPYBUF_AFE2_D6_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100110----------------";
    constant SPYBUF_AFE2_D7_BASEADDR: std_logic_vector(31 downto 0) := "0100000000100111----------------";
    constant SPYBUF_AFE2_FR_BASEADDR: std_logic_vector(31 downto 0) := "0100000000101000----------------";

    constant SPYBUF_AFE3_D0_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110000----------------";
    constant SPYBUF_AFE3_D1_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110001----------------";
    constant SPYBUF_AFE3_D2_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110010----------------";
    constant SPYBUF_AFE3_D3_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110011----------------";
    constant SPYBUF_AFE3_D4_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110100----------------";
    constant SPYBUF_AFE3_D5_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110101----------------";
    constant SPYBUF_AFE3_D6_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110110----------------";
    constant SPYBUF_AFE3_D7_BASEADDR: std_logic_vector(31 downto 0) := "0100000000110111----------------";
    constant SPYBUF_AFE3_FR_BASEADDR: std_logic_vector(31 downto 0) := "0100000000111000----------------";

    constant SPYBUF_AFE4_D0_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000000----------------";
    constant SPYBUF_AFE4_D1_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000001----------------";
    constant SPYBUF_AFE4_D2_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000010----------------";
    constant SPYBUF_AFE4_D3_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000011----------------";
    constant SPYBUF_AFE4_D4_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000100----------------";
    constant SPYBUF_AFE4_D5_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000101----------------";
    constant SPYBUF_AFE4_D6_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000110----------------";
    constant SPYBUF_AFE4_D7_BASEADDR: std_logic_vector(31 downto 0) := "0100000001000111----------------";
    constant SPYBUF_AFE4_FR_BASEADDR: std_logic_vector(31 downto 0) := "0100000001001000----------------";

    constant TRIG0_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800000";
    constant TRIG1_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800008";
    constant TRIG2_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800010";
    constant TRIG3_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800018";
    constant TRIG4_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800020";
    constant TRIG5_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800028";
    constant TRIG6_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800030";
    constant TRIG7_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800038";
    constant TRIG8_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800040";
    constant TRIG9_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800048";
    constant TRIG10_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800050";
    constant TRIG11_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800058";
    constant TRIG12_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800060";
    constant TRIG13_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800068";
    constant TRIG14_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800070";
    constant TRIG15_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800078";
    constant TRIG16_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800080";
    constant TRIG17_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800088";
    constant TRIG18_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800090";
    constant TRIG19_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800098";
    constant TRIG20_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000A0";
    constant TRIG21_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000A8";
    constant TRIG22_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000B0";
    constant TRIG23_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000B8";
    constant TRIG24_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000C0";
    constant TRIG25_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000C8";
    constant TRIG26_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000D0";
    constant TRIG27_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000D8";
    constant TRIG28_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000E0";
    constant TRIG29_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000E8";
    constant TRIG30_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000F0";
    constant TRIG31_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408000F8";
    constant TRIG32_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800100";
    constant TRIG33_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800108";
    constant TRIG34_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800110";
    constant TRIG35_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800118";
    constant TRIG36_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800120";
    constant TRIG37_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800128";
    constant TRIG38_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800130";
    constant TRIG39_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800138";

    constant PACK0_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800140";
    constant PACK1_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800148";
    constant PACK2_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800150";
    constant PACK3_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800158";
    constant PACK4_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800160";
    constant PACK5_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800168";
    constant PACK6_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800170";
    constant PACK7_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800178";
    constant PACK8_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800180";
    constant PACK9_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800188";
    constant PACK10_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800190";
    constant PACK11_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800198";
    constant PACK12_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001A0";
    constant PACK13_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001A8";
    constant PACK14_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001B0";
    constant PACK15_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001B8";
    constant PACK16_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001C0";
    constant PACK17_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001C8";
    constant PACK18_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001D0";
    constant PACK19_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001D8";
    constant PACK20_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001E0";
    constant PACK21_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001E8";
    constant PACK22_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001F0";
    constant PACK23_COUNT_ADDR: std_logic_vector(31 downto 0) := X"408001F8";
    constant PACK24_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800200";
    constant PACK25_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800208";
    constant PACK26_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800210";
    constant PACK27_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800218";
    constant PACK28_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800220";
    constant PACK29_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800228";
    constant PACK30_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800230";
    constant PACK31_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800238";
    constant PACK32_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800240";
    constant PACK33_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800248";
    constant PACK34_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800250";
    constant PACK35_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800258";
    constant PACK36_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800260";
    constant PACK37_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800268";
    constant PACK38_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800270";
    constant PACK39_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800278";
    constant SEND_COUNT_ADDR: std_logic_vector(31 downto 0) := X"40800280";

    -- spy buffer for the 64 bit timestamp value

    constant SPYBUFTS_BASEADDR: std_logic_vector(31 downto 0) := "0100000001010000----------------";

    -- spy buffer for the first output link 

    constant SPYBUFDOUT0_BASEADDR: std_logic_vector(31 downto 0) := "0100000001100000----------------";

    -- SPI slave has two FIFOs, each 2kx8. The command FIFO is write only. The response FIFO is read only.
    -- because of this they can and do share an address.

    constant SPI_FIFO_ADDR: std_logic_vector(31 downto 0) := X"90000000";

end package;


