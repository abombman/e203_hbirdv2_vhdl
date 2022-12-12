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

entity e203_exu_alu_rglr is 
  port ( -- The Handshake Interface 
  	     alu_i_valid:  in std_logic; -- Handshake valid
  	     alu_i_ready: out std_logic; -- Handshake ready

  	     alu_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
         alu_i_rs2:    in std_logic_vector(E203_XLEN-1 downto 0);
         alu_i_imm:    in std_logic_vector(E203_XLEN-1 downto 0);
         alu_i_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0);
         alu_i_info:   in std_logic_vector(E203_DECINFO_ALU_WIDTH-1 downto 0);

         -- The ALU Write-back/Commit Interface
         alu_o_valid: out std_logic; -- Handshake valid
  	     alu_o_ready:  in std_logic; -- Handshake ready
  	     
  	     -- The Write-Back Interface for Special (unaligned ldst and AMO instructions)
  	     alu_o_wbck_wdat:  out std_logic_vector(E203_XLEN-1 downto 0); 
         alu_o_wbck_err:   out std_logic;
         alu_o_cmt_ecall:  out std_logic;
         alu_o_cmt_ebreak: out std_logic;
         alu_o_cmt_wfi:    out std_logic;

         -- To share the ALU datapath 
         -- The operands and info to ALU
         alu_req_alu_add:  out std_logic;
         alu_req_alu_sub:  out std_logic;
         alu_req_alu_xor:  out std_logic;
         alu_req_alu_sll:  out std_logic;
         alu_req_alu_srl:  out std_logic;
         alu_req_alu_sra:  out std_logic;
         alu_req_alu_or:   out std_logic;
         alu_req_alu_and:  out std_logic;
         alu_req_alu_slt:  out std_logic;
         alu_req_alu_sltu: out std_logic;
         alu_req_alu_lui:  out std_logic;
         alu_req_alu_op1:  out std_logic_vector(E203_XLEN-1 downto 0);
         alu_req_alu_op2:  out std_logic_vector(E203_XLEN-1 downto 0);

         alu_req_alu_res:   in std_logic_vector(E203_XLEN-1 downto 0);

         clk:               in std_logic;  
         rst_n:             in std_logic  
  	   );
end e203_exu_alu_rglr;

architecture impl of e203_exu_alu_rglr is 
  signal op2imm: std_ulogic;
  signal op1pc:  std_ulogic;
  signal nop:    std_ulogic;
  signal ecall:  std_ulogic;
  signal ebreak: std_ulogic;  
  signal wfi:    std_ulogic;
begin
  op2imm <= alu_i_info(E203_DECINFO_ALU_OP2IMM'right);
  op1pc  <= alu_i_info(E203_DECINFO_ALU_OP1PC 'right);

  alu_req_alu_op1 <= alu_i_pc  when op1pc  = '1' else alu_i_rs1;
  alu_req_alu_op2 <= alu_i_imm when op2imm = '1' else alu_i_rs2;

  nop    <= alu_i_info(E203_DECINFO_ALU_NOP 'right);
  ecall  <= alu_i_info(E203_DECINFO_ALU_ECAL'right);
  ebreak <= alu_i_info(E203_DECINFO_ALU_EBRK'right);
  wfi    <= alu_i_info(E203_DECINFO_ALU_WFI 'right);

  -- The NOP is encoded as ADDI, so need to uncheck it
  alu_req_alu_add  <= alu_i_info(E203_DECINFO_ALU_ADD 'right) and (not nop);
  alu_req_alu_sub  <= alu_i_info(E203_DECINFO_ALU_SUB 'right);
  alu_req_alu_xor  <= alu_i_info(E203_DECINFO_ALU_XOR 'right);
  alu_req_alu_sll  <= alu_i_info(E203_DECINFO_ALU_SLL 'right);
  alu_req_alu_srl  <= alu_i_info(E203_DECINFO_ALU_SRL 'right);
  alu_req_alu_sra  <= alu_i_info(E203_DECINFO_ALU_SRA 'right);
  alu_req_alu_or   <= alu_i_info(E203_DECINFO_ALU_OR  'right);
  alu_req_alu_and  <= alu_i_info(E203_DECINFO_ALU_AND 'right);
  alu_req_alu_slt  <= alu_i_info(E203_DECINFO_ALU_SLT 'right);
  alu_req_alu_sltu <= alu_i_info(E203_DECINFO_ALU_SLTU'right);
  alu_req_alu_lui  <= alu_i_info(E203_DECINFO_ALU_LUI 'right);

  alu_o_valid     <= alu_i_valid;
  alu_i_ready     <= alu_o_ready;
  alu_o_wbck_wdat <= alu_req_alu_res;

  alu_o_cmt_ecall  <= ecall;   
  alu_o_cmt_ebreak <= ebreak;   
  alu_o_cmt_wfi    <= wfi;   
  
  -- The exception or error result cannot write-back
  alu_o_wbck_err <= alu_o_cmt_ecall or alu_o_cmt_ebreak or alu_o_cmt_wfi;
end impl;