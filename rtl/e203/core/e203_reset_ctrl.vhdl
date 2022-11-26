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
--  The Reset Ctrl module to implement reset control
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_reset_ctrl is 
  generic( MASTER: integer:= 1);
  port(
        clk:       in std_logic;  -- clock
        rst_n:     in std_logic;  -- async reset
        test_mode: in std_logic;  -- test mode
        
        -- The core's clk and rst
        rst_core: out std_logic;

        -- The ITCM/DTCM clk and rst
        `if E203_HAS_ITCM = "TRUE" then 
        rst_itcm: out std_logic;
        `end if
        `if E203_HAS_DTCM = "TRUE" then 
        rst_dtcm: out std_logic;
        `end if

        -- The Top always on clk and rst
        rst_aon:  out std_logic
  );
end e203_reset_ctrl;
  
architecture impl of e203_reset_ctrl is 
  signal rst_sync_n: std_logic;
  
  `if E203_HAS_LOCKSTEP = "FALSE" then 
    constant RST_SYNC_LEVEL: integer:= E203_ASYNC_FF_LEVELS;    
  `end if
  
  signal rst_sync_r: std_logic_vector(RST_SYNC_LEVEL-1 downto 0);

begin
  master_gen: if MASTER = 1 generate
    rst_sync_PROC: process(clk, rst_n)
    begin
      if rst_n = '0' then
        rst_sync_r(RST_SYNC_LEVEL-1 downto 0) <= (RST_SYNC_LEVEL-1 downto 0 => '0');
      elsif rising_edge(clk) then
        rst_sync_r(RST_SYNC_LEVEL-1 downto 0) <= (RST_SYNC_LEVEL-2 downto 0 => '0') & '1';
      end if;
    end process;

    rst_sync_n <= rst_n when test_mode = '1' else rst_sync_r(E203_ASYNC_FF_LEVELS-1);
  end generate;
  
  -- Just pass through for slave in lockstep mode
  slave_gen: if MASTER /= 1 generate
    rst_sync_PROC_SLV: process(all)
    begin
      rst_sync_r <= (others => '0'); 
    end process;
    rst_sync_n <= rst_n;
  end generate;
  
  -- The core's clk and rst
  rst_core <= rst_sync_n;
  
  -- The ITCM/DTCM clk and rst
  `if E203_HAS_ITCM = "TRUE" then 
    rst_itcm <= rst_sync_n;
  `end if

  `if E203_HAS_DTCM = "TRUE" then 
    rst_dtcm <= rst_sync_n;
  `end if
  
  -- The Top always on clk and rst
 rst_aon <= rst_sync_n;

end impl;