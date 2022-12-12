---------------------------------------------------------------                                                                      
-- Copyright 2018-2020 Nuclei System Technology, Inc.                
--                                                                         
-- Licensed under the Apache License, Version 2.0 (the "License");         
-- you may not use this file except in compliance with the License.        
-- You may obtain a copy of the License at                                 
--                                                                         
--     http://www.apache.org/licenses/LICENSE-2.0                          
--                                                                         
-- Unless required by applicable law or agreed to in writing, software    
-- distributed under the License is distributed on an "AS IS" BASIS,       
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and     
-- limitations under the License.                                          
 
-- e203_hbirdv2 config constant package 
-- analysis/compiler tool is configured for VHDL-2019
-- text is coded by UTF-8
-------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package config_pkg is

-------------------------------------------------------------   
`if E203_CFG_ADDR_SIZE_IS_16 = "TRUE" then
  constant E203_CFG_ADDR_SIZE: integer:= 16;
`end if

`if E203_CFG_ADDR_SIZE_IS_24 = "TRUE" then
  constant E203_CFG_ADDR_SIZE: integer:= 24;
`end if
      
`if E203_CFG_ADDR_SIZE_IS_32 = "TRUE" then
  constant E203_CFG_ADDR_SIZE: integer:= 32;
`end if
-------------------------------------------------------------

    
-------------------------------------------------------------
  constant E203_CFG_ITCM_ADDR_WIDTH: integer:= 16;
  -- 64KB have address 16bits wide
  -- The depth is 64*1024*8/E203_CFG_ADDR_SIZE
  
  --constant E203_CFG_ITCM_ADDR_WIDTH: integer:= 20;
  -- 1024KB have address 20bits wide
  -- The depth is 1024*1024*8/E203_CFG_ADDR_SIZE
  
  --constant E203_CFG_ITCM_ADDR_WIDTH: integer:= 21;
  -- 2048KB have address 21bits wide
  -- The depth is 2048*1024*8/E203_CFG_ADDR_SIZE
  
  constant E203_CFG_ITCM_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"8000_0000";
-------------------------------------------------------------

-------------------------------------------------------------
  constant E203_CFG_DTCM_ADDR_WIDTH: integer:= 16;
  
  constant E203_CFG_DTCM_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"9000_0000";
-------------------------------------------------------------

-------------------------------------------------------------
  -- PPI: 0x1000 0000 -- 0x1FFF FFFF
  constant E203_CFG_PPI_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"1000_0000";
  --constant E203_CFG_PPI_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4):= x"1";
  subtype E203_CFG_PPI_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4);
  
  -- CLINT: 0x0200 0000 -- 0x0200 FFFF
  constant E203_CFG_CLINT_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"0200_0000";
  --constant E203_CFG_CLINT_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-16):= x"0200";
  subtype E203_CFG_CLINT_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-16);
  
  -- PLIC: 0x0C00 0000 -- 0x0CFF FFFF
  constant E203_CFG_PLIC_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"0C00_0000";
  --constant E203_CFG_PLIC_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-8):= x"0C";
  subtype E203_CFG_PLIC_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-8);
  
  -- FIO: 0xF000 0000 -- 0xFFFF FFFF
  constant E203_CFG_FIO_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0):= x"F000_0000";
  --constant E203_CFG_FIO_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4):= x"F";
  subtype E203_CFG_FIO_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4);
-------------------------------------------------------------

end package;

