------------------------------------------------------------------------------
-- Copyright 2018-2020 Nuclei System Technology, Inc.                
--                                                                         
--   Licensed under the Apache License, Version 2.0 (the "License");         
-- you may not use this file except in compliance with the License.        
-- You may obtain a copy of the License at                                 
--                                                                         
--     http://www.apache.org/licenses/LICENSE-2.0                          
--                                                                         
--   Unless required by applicable law or agreed to in writing, software    
-- distributed under the License is distributed on an "AS IS" BASIS,       
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and     
-- limitations under the License.                                          
------------------------------------------------------------------------------
-- Description:
--  module sirv_jtag_dtm
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------

--=====================================================================
--
-- Description:
--  The module for debug ROM program
--
-- ====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_debug_rom is 
  port(  
         rom_addr:  in std_logic_vector( 7-1 downto 2);   
         rom_dout: out std_logic_vector(32-1 downto 0)  
  );
end sirv_debug_rom;

 -- These ROM contents support only RV32 
 -- See $RISCV/riscv-tools/riscv-isa-sim/debug_rom/debug_rom.h/S
 -- The code assumes only 28 bytes of Debug RAM.

 -- def xlen32OnlyRomContents : Array[Byte] = Array(
 -- 0x6f, 0x00, 0xc0, 0x03, 0x6f, 0x00, 0xc0, 0x00, 0x13, 0x04, 0xf0, 0xff,
 -- 0x6f, 0x00, 0x80, 0x00, 0x13, 0x04, 0x00, 0x00, 0x0f, 0x00, 0xf0, 0x0f,
 -- 0x83, 0x24, 0x80, 0x41, 0x23, 0x2c, 0x80, 0x40, 0x73, 0x24, 0x40, 0xf1,
 -- 0x23, 0x20, 0x80, 0x10, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x84, 0x00,
 -- 0x63, 0x1a, 0x04, 0x02, 0x73, 0x24, 0x20, 0x7b, 0x73, 0x00, 0x20, 0x7b,
 -- 0x73, 0x10, 0x24, 0x7b, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x04, 0x1c,
 -- 0x13, 0x04, 0x04, 0xf4, 0x63, 0x16, 0x04, 0x00, 0x23, 0x2c, 0x90, 0x40,
 -- 0x67, 0x00, 0x00, 0x40, 0x73, 0x24, 0x40, 0xf1, 0x23, 0x26, 0x80, 0x10,
 -- 0x73, 0x60, 0x04, 0x7b, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x04, 0x02,
 -- 0xe3, 0x0c, 0x04, 0xfe, 0x6f, 0xf0, 0x1f, 0xfe).map(_.toByte)

 architecture impl of sirv_debug_rom is 
   type rom_addr_type is array(0 to 28) of std_logic_vector(31 downto 0); -- 29 words in total
   signal debug_rom: rom_addr_type;  
 begin
   rom_dout<= debug_rom(to_integer(unsigned(rom_addr)));
   
   -- 0x6f, 0x00, 0xc0, 0x03, 0x6f, 0x00, 0xc0, 0x00, 0x13, 0x04, 0xf0, 0xff,
   debug_rom( 0)(7  downto  0) <= x"6f";
   debug_rom( 0)(15 downto  8) <= x"00";
   debug_rom( 0)(23 downto 16) <= x"c0";
   debug_rom( 0)(31 downto 24) <= x"03";
   
   debug_rom( 1)(7  downto  0) <= x"6f";
   debug_rom( 1)(15 downto  8) <= x"00";
   debug_rom( 1)(23 downto 16) <= x"c0";
   debug_rom( 1)(31 downto 24) <= x"00";
  
   debug_rom( 2)(7  downto  0) <= x"13";
   debug_rom( 2)(15 downto  8) <= x"04";
   debug_rom( 2)(23 downto 16) <= x"f0";
   debug_rom( 2)(31 downto 24) <= x"ff";
 
   -- 0x6f, 0x00, 0x80, 0x00, 0x13, 0x04, 0x00, 0x00, 0x0f, 0x00, 0xf0, 0x0f,
   debug_rom( 3)(7  downto  0) <= x"6f";
   debug_rom( 3)(15 downto  8) <= x"00";
   debug_rom( 3)(23 downto 16) <= x"80";
   debug_rom( 3)(31 downto 24) <= x"00";
 
   debug_rom( 4)(7  downto  0) <= x"13";
   debug_rom( 4)(15 downto  8) <= x"04";
   debug_rom( 4)(23 downto 16) <= x"00";
   debug_rom( 4)(31 downto 24) <= x"00";
 
   debug_rom( 5)(7  downto  0) <= x"0f";
   debug_rom( 5)(15 downto  8) <= x"00";
   debug_rom( 5)(23 downto 16) <= x"f0";
   debug_rom( 5)(31 downto 24) <= x"0f";
 
   -- 0x83, 0x24, 0x80, 0x41, 0x23, 0x2c, 0x80, 0x40, 0x73, 0x24, 0x40, 0xf1,
   debug_rom( 6)(7  downto  0) <= x"83";
   debug_rom( 6)(15 downto  8) <= x"24";
   debug_rom( 6)(23 downto 16) <= x"80";
   debug_rom( 6)(31 downto 24) <= x"41";
  
   debug_rom( 7)(7  downto  0) <= x"23";
   debug_rom( 7)(15 downto  8) <= x"2c";
   debug_rom( 7)(23 downto 16) <= x"80";
   debug_rom( 7)(31 downto 24) <= x"40";
 
   debug_rom( 8)(7  downto  0) <= x"73";
   debug_rom( 8)(15 downto  8) <= x"24";
   debug_rom( 8)(23 downto 16) <= x"40";
   debug_rom( 8)(31 downto 24) <= x"f1";
 
   -- 0x23, 0x20, 0x80, 0x10, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x84, 0x00,
   debug_rom( 9)(7  downto  0) <= x"23";
   debug_rom( 9)(15 downto  8) <= x"20";
   debug_rom( 9)(23 downto 16) <= x"80";
   debug_rom( 9)(31 downto 24) <= x"10";
 
   debug_rom(10)(7  downto  0) <= x"73";
   debug_rom(10)(15 downto  8) <= x"24";
   debug_rom(10)(23 downto 16) <= x"00";
   debug_rom(10)(31 downto 24) <= x"7b";
 
   debug_rom(11)(7  downto  0) <= x"13";
   debug_rom(11)(15 downto  8) <= x"74";
   debug_rom(11)(23 downto 16) <= x"84";
   debug_rom(11)(31 downto 24) <= x"00";
                   
   -- 0x63, 0x1a, 0x04, 0x02, 0x73, 0x24, 0x20, 0x7b, 0x73, 0x00, 0x20, 0x7b,
   debug_rom(12)(7  downto  0) <= x"63";
   debug_rom(12)(15 downto  8) <= x"1a";
   debug_rom(12)(23 downto 16) <= x"04";
   debug_rom(12)(31 downto 24) <= x"02";
   
   debug_rom(13)(7  downto  0) <= x"73";
   debug_rom(13)(15 downto  8) <= x"24";
   debug_rom(13)(23 downto 16) <= x"20";
   debug_rom(13)(31 downto 24) <= x"7b";
   
   debug_rom(14)(7  downto  0) <= x"73";
   debug_rom(14)(15 downto  8) <= x"00";
   debug_rom(14)(23 downto 16) <= x"20";
   debug_rom(14)(31 downto 24) <= x"7b";
                
   -- 0x73, 0x10, 0x24, 0x7b, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x04, 0x1c,
   debug_rom(15)(7  downto  0) <= x"73";
   debug_rom(15)(15 downto  8) <= x"10";
   debug_rom(15)(23 downto 16) <= x"24";
   debug_rom(15)(31 downto 24) <= x"7b";
   
   debug_rom(16)(7  downto  0) <= x"73";
   debug_rom(16)(15 downto  8) <= x"24";
   debug_rom(16)(23 downto 16) <= x"00";
   debug_rom(16)(31 downto 24) <= x"7b";
   
   debug_rom(17)(7  downto  0) <= x"13";
   debug_rom(17)(15 downto  8) <= x"74";
   debug_rom(17)(23 downto 16) <= x"04";
   debug_rom(17)(31 downto 24) <= x"1c";
             
   -- 0x13, 0x04, 0x04, 0xf4, 0x63, 0x16, 0x04, 0x00, 0x23, 0x2c, 0x90, 0x40,
   debug_rom(18)(7  downto  0) <= x"13";
   debug_rom(18)(15 downto  8) <= x"04";
   debug_rom(18)(23 downto 16) <= x"04";
   debug_rom(18)(31 downto 24) <= x"f4";
   
   debug_rom(19)(7  downto  0) <= x"63";
   debug_rom(19)(15 downto  8) <= x"16";
   debug_rom(19)(23 downto 16) <= x"04";
   debug_rom(19)(31 downto 24) <= x"00";
 
   debug_rom(20)(7  downto  0) <= x"23";
   debug_rom(20)(15 downto  8) <= x"2c";
   debug_rom(20)(23 downto 16) <= x"90";
   debug_rom(20)(31 downto 24) <= x"40";
 
   -- 0x67, 0x00, 0x00, 0x40, 0x73, 0x24, 0x40, 0xf1, 0x23, 0x26, 0x80, 0x10,
   debug_rom(21)(7  downto  0) <= x"67";
   debug_rom(21)(15 downto  8) <= x"00";
   debug_rom(21)(23 downto 16) <= x"00";
   debug_rom(21)(31 downto 24) <= x"40";
 
   debug_rom(22)(7  downto  0) <= x"73";
   debug_rom(22)(15 downto  8) <= x"24";
   debug_rom(22)(23 downto 16) <= x"40";
   debug_rom(22)(31 downto 24) <= x"f1";
 
   debug_rom(23)(7  downto  0) <= x"23";
   debug_rom(23)(15 downto  8) <= x"26";
   debug_rom(23)(23 downto 16) <= x"80";
   debug_rom(23)(31 downto 24) <= x"10";
   
   -- 0x73, 0x60, 0x04, 0x7b, 0x73, 0x24, 0x00, 0x7b, 0x13, 0x74, 0x04, 0x02,
   debug_rom(24)(7  downto  0) <= x"73";
   debug_rom(24)(15 downto  8) <= x"60";
   debug_rom(24)(23 downto 16) <= x"04";
   debug_rom(24)(31 downto 24) <= x"7b";
 
   debug_rom(25)(7  downto  0) <= x"73";
   debug_rom(25)(15 downto  8) <= x"24";
   debug_rom(25)(23 downto 16) <= x"00";
   debug_rom(25)(31 downto 24) <= x"7b";
 
   debug_rom(26)(7  downto  0) <= x"13";
   debug_rom(26)(15 downto  8) <= x"74";
   debug_rom(26)(23 downto 16) <= x"04";
   debug_rom(26)(31 downto 24) <= x"02";
 
   -- 0xe3, 0x0c, 0x04, 0xfe, 0x6f, 0xf0, 0x1f, 0xfe).map(_.toByte)
   debug_rom(27)(7  downto  0) <= x"e3";
   debug_rom(27)(15 downto  8) <= x"0c";
   debug_rom(27)(23 downto 16) <= x"04";
   debug_rom(27)(31 downto 24) <= x"fe";
 
   debug_rom(28)(7  downto  0) <= x"6f";
   debug_rom(28)(15 downto  8) <= x"f0";
   debug_rom(28)(23 downto 16) <= x"1f";
   debug_rom(28)(31 downto 24) <= x"fe";
 end impl;