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
--  
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------

--=====================================================================
--
-- Description:
--  The module is to control the mask ROM
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_mrom_top is
  generic( AW: integer:= 12;
  	       DW: integer:= 32;
  	       DP: integer:= 1024
  );
  port( --    * Bus cmd channel
        rom_icb_cmd_valid:  in std_logic;  -- Handshake valid
  	    rom_icb_cmd_ready: out std_logic;  -- Handshake ready
  	    rom_icb_cmd_addr:   in std_logic_vector(AW-1 downto 0);  -- Bus transaction start addr
  	    rom_icb_cmd_read:   in std_logic;  -- Read or write

        --    * Bus RSP channel
  	    rom_icb_rsp_valid: out std_logic;  -- Response valid
  	    rom_icb_rsp_ready:  in std_logic;  -- Response ready
  	    rom_icb_rsp_err:   out std_logic;  -- Response error
  	    rom_icb_rsp_rdata: out std_logic_vector(DW-1 downto 0);
  	    
  	    clk:                in std_logic;
  	    rst_n:              in std_logic
  );
end sirv_mrom_top;
  
architecture impl of sirv_mrom_top is 
  signal rom_dout: std_logic_vector(DW-1 downto 0);
begin
  rom_icb_rsp_valid <= rom_icb_cmd_valid;
  rom_icb_cmd_ready <= rom_icb_rsp_ready;
  rom_icb_rsp_err   <= not rom_icb_cmd_read;
  rom_icb_rsp_rdata <= rom_dout;

  u_sirv_mrom: entity work.sirv_mrom generic map(AW, DW, DP)
                                        port map(rom_icb_cmd_addr, rom_dout); -- why? .rom_addr (rom_icb_cmd_addr[AW-1:2])
end impl;