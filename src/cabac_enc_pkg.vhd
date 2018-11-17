library ieee;
library std;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;
use     std.textio.all;

package cabac_enc_pkg is

    constant ctxIdxRange : integer := 120;

    constant InputW : integer := 34; 
    constant InputWLen : integer := integer(floor(log2(real(InputW))+real(1)));
    constant OutputW : integer := 40; 
    constant OutputWLen : integer := integer(floor(log2(real(OutputW))+real(1))); -- Number of bits required to represent OutputW.


    constant PutBitLoopLen : integer := 5; -- TODO: reduce

    -- Table types
    type transIdx_t    is array(0 to 63)                         of std_logic_vector(5 downto 0);
    type qRange_t      is array(0 to 3)                          of std_logic_vector(7 downto 0);
    type rangeTabLps_t is array(0 to  63)                        of qRange_t;
    type ctxTblInit_t  is array(0 to (52*3*ctxIdxRange)-1) of std_logic_vector(6 downto 0); 
    type ctxTbl_t      is array(0 to ctxIdxRange-1)        of std_logic_vector(6 downto 0); 


    -- ---------------------------------------------------------------------------
    -- Functions
    -- ---------------------------------------------------------------------------
    function string_to_binary(inp: string) 
    return std_logic_vector;

    impure function InitctxTbl (RomFileName : in string) 
    return ctxTblInit_t;

    impure function InittransIdx (RomFileName : in string) 
    return transIdx_t;

    impure function InitrangeTabLps (RomFileName : in string)
    return rangeTabLps_t;

end package cabac_enc_pkg;

package body cabac_enc_pkg is
    -- ---------------------------------------------------------------------------
    -- Functions
    -- ---------------------------------------------------------------------------
    function string_to_binary(inp: string) return std_logic_vector is 
        variable temp: std_logic_vector(inp'length-1 downto 0) := (others => 'X'); 
    begin 
        for i in inp'range loop 
            case inp(i) is 
                when '0'    => temp(i-1) := '0'; 
                when '1'    => temp(i-1) := '1'; 
                when others => temp(i-1) := 'X'; 
            end case; 
        end loop;
        return temp; 
    end function string_to_binary;

    impure function InitctxTbl (RomFileName : in string) return ctxTblInit_t is
        FILE romfile : text is in RomFileName;
        variable RomFileLine : line;
        variable rom : ctxTblInit_t;
        variable TestString : string(7 downto 1);
    begin
        for i in ctxTblInit_t'range loop
            readline(romfile, RomFileLine);
            read(RomFileLine, TestString);
            rom(i) := string_to_binary(TestString)(6 downto 0);
        end loop;
        return rom;
    end function;

    impure function InittransIdx (RomFileName : in string) return transIdx_t is
        FILE romfile : text is in RomFileName;
        variable RomFileLine : line;
        variable rom : transIdx_t;
        variable TestString : string(8 downto 1);
    begin
        for i in 0 to 63 loop
            readline(romfile, RomFileLine);
            read(RomFileLine, TestString);
            rom(i) := string_to_binary(TestString)(5 downto 0);
        end loop;
        return rom;
    end function;

    impure function InitrangeTabLps (RomFileName : in string) return rangeTabLps_t is
        FILE romfile : text is in RomFileName;
        variable RomFileLine : line;
        variable rom : rangeTabLps_t;
        variable TestString : string(8 downto 1);
    begin
        for i in 0 to 3 loop
            for j in 0 to 63 loop
                readline(romfile, RomFileLine);
                read(RomFileLine, TestString);
                rom(j)(i) := string_to_binary(TestString)(7 downto 0);
            end loop;
        end loop;
        return rom;
    end function;

end package body cabac_enc_pkg;