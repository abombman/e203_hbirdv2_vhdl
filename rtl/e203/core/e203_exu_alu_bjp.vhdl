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
--   This module to implement the regular ALU instructions
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_alu_bjp is 
  port ( -- The Handshake Interface 
  	     bjp_i_valid:  in std_logic; -- Handshake valid
  	     bjp_i_ready: out std_logic; -- Handshake ready

  	     bjp_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
         bjp_i_rs2:    in std_logic_vector(E203_XLEN-1 downto 0);
         bjp_i_imm:    in std_logic_vector(E203_XLEN-1 downto 0);
         bjp_i_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0);
         bjp_i_info:   in std_logic_vector(E203_DECINFO_BJP_WIDTH-1 downto 0);

         -- The BJP Commit Interface
         bjp_o_valid: out std_logic; -- Handshake valid
  	     bjp_o_ready:  in std_logic; -- Handshake ready
  	     -- The Write-Back Result for JAL and JALR
  	     bjp_o_wbck_wdat:  out std_logic_vector(E203_XLEN-1 downto 0); 
         bjp_o_wbck_err:   out std_logic;
         -- The Commit Result for BJP
         bjp_o_cmt_bjp:    out std_logic;
         bjp_o_cmt_mret:   out std_logic;
         bjp_o_cmt_dret:   out std_logic;
         bjp_o_cmt_fencei: out std_logic;
         bjp_o_cmt_prdt:   out std_logic; -- The predicted ture/false 
         bjp_o_cmt_rslv:   out std_logic; -- The resolved ture/false

         -- To share the ALU datapath
         -- The operands and info to ALU
         bjp_req_alu_op1:     out std_logic_vector(E203_XLEN-1 downto 0);
         bjp_req_alu_op2:     out std_logic_vector(E203_XLEN-1 downto 0);
         bjp_req_alu_cmp_eq:  out std_logic;
         bjp_req_alu_cmp_ne:  out std_logic;
         bjp_req_alu_cmp_lt:  out std_logic;
         bjp_req_alu_cmp_gt:  out std_logic;
         bjp_req_alu_cmp_ltu: out std_logic;
         bjp_req_alu_cmp_gtu: out std_logic;
         bjp_req_alu_add:     out std_logic;
         
         bjp_req_alu_cmp_res:  in std_logic;
         bjp_req_alu_add_res:  in std_logic_vector(E203_XLEN-1 downto 0);
         
         clk:                  in std_logic;  
         rst_n:                in std_logic 
  );
end e203_exu_alu_bjp;

architecture impl of e203_exu_alu_bjp is 
  signal mret:        std_ulogic;
  signal dret:        std_ulogic;
  signal fencei:      std_ulogic;
  signal bxx:         std_ulogic;
  signal jump:        std_ulogic;  
  signal rv32:        std_ulogic;
  signal wbck_link:   std_ulogic;
  signal bjp_i_bprdt: std_ulogic;
  signal is_rv32:     std_ulogic_vector(E203_XLEN-1 downto 0);

begin
  mret   <= bjp_i_info(E203_DECINFO_BJP_MRET  'right); 
  dret   <= bjp_i_info(E203_DECINFO_BJP_DRET  'right); 
  fencei <= bjp_i_info(E203_DECINFO_BJP_FENCEI'right); 
  bxx    <= bjp_i_info(E203_DECINFO_BJP_BXX 'right); 
  jump   <= bjp_i_info(E203_DECINFO_BJP_JUMP'right); 
  rv32   <= bjp_i_info(E203_DECINFO_RV32    'right); 

  wbck_link <= jump;

  bjp_i_bprdt <= bjp_i_info(E203_DECINFO_BJP_BPRDT'right);

  bjp_req_alu_op1 <= bjp_i_pc when wbck_link = '1' else 
                     bjp_i_rs1;
  is_rv32         <= std_ulogic_vector(to_unsigned(4, E203_XLEN)) when rv32 = '1' else
                     std_ulogic_vector(to_unsigned(2, E203_XLEN));
  bjp_req_alu_op2 <= is_rv32 when wbck_link = '1' else
                     bjp_i_rs2;

  bjp_o_cmt_bjp <= bxx or jump;
  bjp_o_cmt_mret <= mret;
  bjp_o_cmt_dret <= dret;
  bjp_o_cmt_fencei <= fencei;

  bjp_req_alu_cmp_eq  <= bjp_i_info(E203_DECINFO_BJP_BEQ 'right); 
  bjp_req_alu_cmp_ne  <= bjp_i_info(E203_DECINFO_BJP_BNE 'right); 
  bjp_req_alu_cmp_lt  <= bjp_i_info(E203_DECINFO_BJP_BLT 'right); 
  bjp_req_alu_cmp_gt  <= bjp_i_info(E203_DECINFO_BJP_BGT 'right); 
  bjp_req_alu_cmp_ltu <= bjp_i_info(E203_DECINFO_BJP_BLTU'right); 
  bjp_req_alu_cmp_gtu <= bjp_i_info(E203_DECINFO_BJP_BGTU'right); 

  bjp_req_alu_add  <= wbck_link;

  bjp_o_valid     <= bjp_i_valid;
  bjp_i_ready     <= bjp_o_ready;
  bjp_o_cmt_prdt  <= bjp_i_bprdt;
  bjp_o_cmt_rslv  <= '1' when jump = '1' else bjp_req_alu_cmp_res;

  bjp_o_wbck_wdat  <= bjp_req_alu_add_res;
  bjp_o_wbck_err   <= '0';
end impl;