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
--  The module for debug RAM program
--
-- ====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_debug_ram is 
  port(  clk:       in std_logic;
         rst_n:     in std_logic;
         ram_cs:    in std_logic;
         ram_rd:    in std_logic;
         ram_addr:  in std_logic_vector( 3-1 downto 0); 
         ram_wdat:  in std_logic_vector(32-1 downto 0);  
         ram_dout: out std_logic_vector(32-1 downto 0)  
  );
end sirv_debug_ram;

architecture impl of sirv_debug_ram is
  type debug_ram_type is array(0 to 6) of std_ulogic_vector(31 downto 0);
  signal debug_ram_r: debug_ram_type;
  signal ram_wen: std_ulogic_vector(6 downto 0);

  component sirv_gnrl_dfflr is
    generic( DW: integer );
    port( 
    	    lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
begin
  ram_dout <= debug_ram_r(to_integer(u_unsigned(ram_addr)));
  
  debug_ram_gen: for i in 0 to 6 generate
    signal is_addr_i: std_ulogic;
  begin
    is_addr_i <= '1' when to_integer(u_unsigned(ram_addr)) = i else
    	         '0';
    ram_wen(i) <= ram_cs and (not ram_rd) and is_addr_i;
    ram_dfflr: component sirv_gnrl_dfflr generic map(32)
                                            port map(ram_wen(i), ram_wdat, debug_ram_r(i), clk, rst_n);  
  end generate;
end impl;