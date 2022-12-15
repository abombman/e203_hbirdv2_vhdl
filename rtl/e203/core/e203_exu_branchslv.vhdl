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
--   The Branch Resolve module to resolve the branch instructions
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_branchslv is 
  port ( -- The BJP condition final result need to be resolved at ALU
  	     cmt_i_valid:    in std_logic; -- Handshake valid
  	     cmt_i_ready:   out std_logic; -- Handshake ready
         cmt_i_rv32:     in std_logic;
  	     cmt_i_dret:     in std_logic; -- The dret instruction
  	     cmt_i_mret:     in std_logic; -- The ret instruction
  	     cmt_i_fencei:   in std_logic; -- The fencei instruction
  	     cmt_i_bjp:      in std_logic;  
  	     cmt_i_bjp_prdt: in std_logic; -- The predicted ture/false  
  	     cmt_i_bjp_rslv: in std_logic; -- The resolved ture/false
  	     cmt_i_pc:       in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     cmt_i_imm:      in std_logic_vector(E203_XLEN-1 downto 0); -- The resolved ture/false

  	     csr_epc_r:      in std_logic_vector(E203_PC_SIZE-1 downto 0);
         csr_dpc_r:      in std_logic_vector(E203_PC_SIZE-1 downto 0);
         
         nonalu_excpirq_flush_req_raw: in std_logic; 
         brchmis_flush_ack:            in std_logic; 
         brchmis_flush_req:           out std_logic;
         brchmis_flush_add_op1:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
         brchmis_flush_add_op2:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
        `if E203_TIMING_BOOST = "TRUE" then
         brchmis_flush_pc:            out std_logic_vector(E203_PC_SIZE-1 downto 0);
        `end if

         cmt_mret_ena:                out std_logic;
         cmt_dret_ena:                out std_logic;
         cmt_fencei_ena:              out std_logic;
         
         clk:                          in std_logic;  
         rst_n:                        in std_logic  
  	   );
end e203_exu_branchslv;

architecture impl of e203_exu_branchslv is 
  signal brchmis_flush_ack_pre: std_ulogic;
  signal brchmis_flush_req_pre: std_ulogic;
  signal brchmis_need_flush:    std_ulogic;
  signal cmt_i_is_branch:       std_ulogic;
  signal brchmis_flush_hsked:   std_ulogic;
  signal is_rv32:               std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal brchmis_flush:         std_ulogic;
begin
  brchmis_flush_req <= brchmis_flush_req_pre and (not nonalu_excpirq_flush_req_raw);
  brchmis_flush_ack_pre <= brchmis_flush_ack and (not nonalu_excpirq_flush_req_raw);
  -- In Two stage impelmentation, several branch instructions are handled as below:
  --   * It is predicted at IFU, and target is handled in IFU. But 
  --             we need to check if it is predicted correctly or not. If not,
  --             we need to flush the pipeline
  --             Note: the JUMP instrution will always jump, hence they will be
  --                   both predicted and resolved as true
  brchmis_need_flush <= (
                          (cmt_i_bjp and (cmt_i_bjp_prdt xor cmt_i_bjp_rslv)) 
                         -- If it is a FenceI instruction, it is always Flush 
                         or cmt_i_fencei 
                         -- If it is a RET instruction, it is always jump 
                         or cmt_i_mret 
                         -- If it is a DRET instruction, it is always jump 
                         or cmt_i_dret 
                        );

  cmt_i_is_branch <= (   cmt_i_bjp 
                      or cmt_i_fencei 
                      or cmt_i_mret 
                      or cmt_i_dret 
                     );

  brchmis_flush_req_pre <= cmt_i_valid and brchmis_need_flush;

  -- * If it is a DRET instruction, the new target PC is DPC register
  -- * If it is a RET instruction, the new target PC is EPC register
  -- * If predicted as taken, but actually it is not taken, then 
  --     The new target PC should caculated by PC+2/4
  -- * If predicted as not taken, but actually it is taken, then 
  --     The new target PC should caculated by PC+offset
  brchmis_flush_add_op1 <= csr_dpc_r when cmt_i_dret = '1' else
                           csr_epc_r when cmt_i_mret = '1' else 
                           cmt_i_pc;
  is_rv32               <= std_ulogic_vector(to_unsigned(4, E203_PC_SIZE)) when cmt_i_rv32 = '1' else std_ulogic_vector(to_signed(2, E203_PC_SIZE));                 
  brchmis_flush_add_op2 <= (E203_PC_SIZE-1 downto 0 => '0') when cmt_i_dret = '1' else
                           (E203_PC_SIZE-1 downto 0 => '0') when cmt_i_mret = '1' else
                           is_rv32 when (cmt_i_fencei or cmt_i_bjp_prdt)    = '1' else 
                           cmt_i_imm(E203_PC_SIZE-1 downto 0);
 `if E203_TIMING_BOOST = "TRUE" then
  -- Replicated two adders here to trade area with timing
  brchmis_flush_pc <= 
                     -- The fenceI is also need to trigger the flush to its next instructions
                     std_logic_vector((u_unsigned(cmt_i_pc) + u_unsigned(is_rv32)))                            when (cmt_i_fencei or (cmt_i_bjp and cmt_i_bjp_prdt)) = '1' else
                     std_logic_vector((u_unsigned(cmt_i_pc) + u_unsigned(cmt_i_imm(E203_PC_SIZE-1 downto 0)))) when (cmt_i_bjp and (not cmt_i_bjp_prdt)) = '1' else
                     csr_dpc_r when cmt_i_dret = '1' else
                     csr_epc_r ;-- Last condition cmt_i_mret commented
                                -- to save gatecount and timing
  `end if

  brchmis_flush_hsked <= brchmis_flush_req and brchmis_flush_ack;
  cmt_mret_ena <= cmt_i_mret and brchmis_flush_hsked;
  cmt_dret_ena <= cmt_i_dret and brchmis_flush_hsked;
  cmt_fencei_ena <= cmt_i_fencei and brchmis_flush_hsked;
  brchmis_flush <= brchmis_flush_ack_pre when brchmis_need_flush = '1' else
                   '1';
  cmt_i_ready <= (not cmt_i_is_branch) or 
                 (
                   brchmis_flush
                   -- The Non-ALU flush will override the ALU flush
                   and (not nonalu_excpirq_flush_req_raw) 
                 );
end impl;