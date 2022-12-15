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
                                                                         
-- ====================================================================
-- 
-- Description:
--   The Write-Back module to arbitrate the write-back request to regfile
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_wbck is 
  port ( -- The ALU Write-Back Interface
  	     alu_wbck_i_valid:    in std_logic; -- Handshake valid
  	     alu_wbck_i_ready:   out std_logic; -- Handshake ready
         alu_wbck_i_wdat:     in std_logic_vector(E203_XLEN-1 downto 0);
         alu_wbck_i_rdidx:    in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         -- If ALU have error, it will not generate the wback_valid to wback module
         -- so we dont need the alu_wbck_i_err here

         -- The Longp Write-Back Interface
         longp_wbck_i_valid:  in std_logic; -- Handshake valid
  	     longp_wbck_i_ready: out std_logic; -- Handshake ready
  	     longp_wbck_i_wdat:   in std_logic_vector(E203_FLEN-1 downto 0);
  	     longp_wbck_i_flags:  in std_logic_vector(5-1 downto 0);
  	     longp_wbck_i_rdidx:  in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         longp_wbck_i_rdfpu:  in std_logic;
  	          
  	     -- The Final arbitrated Write-Back Interface to Regfile
         rf_wbck_o_ena:      out std_logic;
         rf_wbck_o_wdat:     out std_logic_vector(E203_XLEN-1 downto 0);
         rf_wbck_o_rdidx:    out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        
         clk:                          in std_logic;  
         rst_n:                        in std_logic  
  	   );
end e203_exu_wbck;

architecture impl of e203_exu_wbck is 
  signal wbck_ready4alu:   std_ulogic;
  signal wbck_sel_alu:     std_ulogic;
  signal wbck_ready4longp: std_ulogic;
  signal wbck_sel_longp:   std_ulogic;
  signal rf_wbck_o_ready:  std_ulogic;
  signal wbck_i_ready:     std_ulogic;
  signal wbck_i_valid:     std_ulogic;
  signal wbck_i_wdat:      std_ulogic_vector(E203_FLEN-1 downto 0);
  signal wbck_i_flags:     std_ulogic_vector(5-1 downto 0);
  signal wbck_i_rdidx:     std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal wbck_i_rdfpu:     std_ulogic;

  signal rf_wbck_o_valid:  std_ulogic;
  signal wbck_o_ena:       std_ulogic;
begin
  -- The ALU instruction can write-back only when there is no any 
  --  long pipeline instruction writing-back
  --    * Since ALU is the 1 cycle instructions, it have lowest 
  --      priority in arbitration
  wbck_ready4alu <= (not longp_wbck_i_valid);
  wbck_sel_alu <= alu_wbck_i_valid and wbck_ready4alu;
  -- The Long-pipe instruction can always write-back since it have high priority 
  wbck_ready4longp <= '1';
  wbck_sel_longp <= longp_wbck_i_valid and wbck_ready4longp;

  --////////////////////////////////////////////////////////////
  -- The Final arbitrated Write-Back Interface
  rf_wbck_o_ready <= '1'; -- Regfile is always ready to be write because it just has 1 w-port

  alu_wbck_i_ready   <= wbck_ready4alu   and wbck_i_ready;
  longp_wbck_i_ready <= wbck_ready4longp and wbck_i_ready;

  wbck_i_valid <= alu_wbck_i_valid when wbck_sel_alu = '1' else
                  longp_wbck_i_valid;
 `if E203_FLEN_IS_32 = "TRUE" then
  wbck_i_wdat <= alu_wbck_i_wdat when wbck_sel_alu = '1' else
                 longp_wbck_i_wdat;
 `else
  wbck_i_wdat <= ((E203_FLEN-E203_XLEN-1 downto 0=> '0') & alu_wbck_i_wdat) when wbck_sel_alu = '1' else
                 longp_wbck_i_wdat;
 `end if
  wbck_i_flags <= 5b"0" when wbck_sel_alu = '1' else
                  longp_wbck_i_flags;
  wbck_i_rdidx <= alu_wbck_i_rdidx when wbck_sel_alu = '1' else
                  longp_wbck_i_rdidx;
  wbck_i_rdfpu <= '0' when wbck_sel_alu = '1' else
                  longp_wbck_i_rdfpu;

  -- If it have error or non-rdwen it will not be send to this module
  --   instead have been killed at EU level, so it is always need to 
  --   write back into regfile at here
  wbck_i_ready <= rf_wbck_o_ready;
  rf_wbck_o_valid <= wbck_i_valid;

  wbck_o_ena <= rf_wbck_o_valid and rf_wbck_o_ready;

  rf_wbck_o_ena   <= wbck_o_ena and (not wbck_i_rdfpu);
  rf_wbck_o_wdat  <= wbck_i_wdat(E203_XLEN-1 downto 0);
  rf_wbck_o_rdidx <= wbck_i_rdidx;
end impl;