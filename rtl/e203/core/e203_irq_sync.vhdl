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

--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------                                                            
                                                                         
-- ====================================================================
-- 
-- Description:
--  The IRQ and Event Sync module
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_irq_sync is 
  generic( MASTER: integer:= 1);
  port(
        clk:       in std_logic;  -- clock
        rst_n:     in std_logic;  -- async reset
        
        ext_irq_a: in std_logic;  
        sft_irq_a: in std_logic;
        tmr_irq_a: in std_logic;
        dbg_irq_a: in std_logic;
        
        ext_irq_r: out std_logic;
        sft_irq_r: out std_logic;
        tmr_irq_r: out std_logic;
        dbg_irq_r: out std_logic
  );
end e203_irq_sync;

architecture impl of e203_irq_sync is 
 `if (E203_HAS_LOCKSTEP = "FALSE") and (E203_IRQ_NEED_SYNC = "TRUE") then 
  component sirv_gnrl_sync is
    generic(
            DP:        integer:= 2;
            DW:        integer:= 32
    );
    port(                         
          din_a:  in std_logic_vector( DW-1 downto 0 );
          dout:  out std_logic_vector( DW-1 downto 0 );
          rst_n:  in std_logic;
          clk:    in std_logic 
    );
  end component;
 `end if
begin
  master_gen: if MASTER = 1 generate
  `if E203_HAS_LOCKSTEP = "FALSE" then 
    `if E203_IRQ_NEED_SYNC = "TRUE" then
    u_dbg_irq_sync: component sirv_gnrl_sync generic map ( DP => E203_ASYNC_FF_LEVELS,
    	                                                     DW => 1
    	                                                   )
                                                port map ( din_a(0)=> dbg_irq_a,
                                                           dout(0) => dbg_irq_r,
                                                           clk     => clk  ,
                                                           rst_n   => rst_n 
                                                	       );
    u_ext_irq_sync: component sirv_gnrl_sync generic map ( DP => E203_ASYNC_FF_LEVELS,
    	                                                     DW => 1
    	                                                   )
                                                port map ( din_a(0)=> ext_irq_a,
                                                           dout(0) => ext_irq_r,
                                                           clk     => clk  ,
                                                           rst_n   => rst_n 
                                                	       );
    u_sft_irq_sync: component sirv_gnrl_sync generic map ( DP => E203_ASYNC_FF_LEVELS,
    	                                                     DW => 1
    	                                                   )
                                                port map ( din_a(0)=> sft_irq_a,
                                                           dout(0) => sft_irq_r,
                                                           clk     => clk  ,
                                                           rst_n   => rst_n 
                                                	       );
    u_tmr_irq_sync: component sirv_gnrl_sync generic map ( DP => E203_ASYNC_FF_LEVELS,
    	                                                     DW => 1
    	                                                   )
                                                port map ( din_a(0)=> tmr_irq_a,
                                                           dout(0) => tmr_irq_r,
                                                           clk     => clk  ,
                                                           rst_n   => rst_n 
                                                	       );
    `else
    ext_irq_r <= ext_irq_a;
    sft_irq_r <= sft_irq_a;
    tmr_irq_r <= tmr_irq_a;
    dbg_irq_r <= dbg_irq_a;
    `end if
  `end if  
  end generate;
  
  -- Just pass through for slave in lockstep mode
  slave_gen: if MASTER /= 1 generate
    ext_irq_r <= ext_irq_a;
    sft_irq_r <= sft_irq_a;
    tmr_irq_r <= tmr_irq_a;
    dbg_irq_r <= dbg_irq_a;
  end generate;
end impl;