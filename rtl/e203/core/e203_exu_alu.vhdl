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
--  The ALU module to implement the compute function unit
--    and the AGU (address generate unit) for LSU is also handled by ALU
--    additionaly, the shared-impelmentation of MUL and DIV instruction 
--    is also shared by ALU in E200
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_alu is 
port (  
  	   -- The operands and decode info from dispatch
       i_valid:      in std_logic;  -- Handshake valid
       i_ready:     out std_logic;  -- Handshake ready 
       i_longpipe:  out std_logic;  -- Indicate this instruction is issued as a long pipe instruction
       
      `if E203_HAS_CSR_NICE = "TRUE" then 
       nice_csr_valid: out std_logic;
       nice_csr_ready:  in std_logic;
       nice_csr_addr:  out std_logic_vector(31 downto 0);
       nice_csr_wr:    out std_logic;
       nice_csr_wdata: out std_logic_vector(31 downto 0);
       nice_csr_rdata:  in std_logic_vector(31 downto 0);
  	  `end if

      `if E203_HAS_NICE = "TRUE" then 
       nice_xs_off:    out std_logic;
  	  `end if
       
       amo_wait:       out std_logic;
  	   oitf_empty:      in std_logic;
  	   
  	   i_itag:          in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
  	   i_rs1:           in std_logic_vector(E203_XLEN-1 downto 0);
       i_rs2:           in std_logic_vector(E203_XLEN-1 downto 0);
       i_imm:           in std_logic_vector(E203_XLEN-1 downto 0);
       i_info:          in std_logic_vector(E203_DECINFO_WIDTH-1 downto 0);
       i_pc:            in std_logic_vector(E203_PC_SIZE-1 downto 0);
       i_instr:         in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
       i_pc_vld:        in std_logic;
       i_rdidx:         in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
       i_rdwen:         in std_logic;
       i_ilegl:         in std_logic;
       i_buserr:        in std_logic;
       i_misalgn:       in std_logic;
       
       flush_req:       in std_logic;  
       flush_pulse:     in std_logic;

       -- The Commit Interface
       cmt_o_valid:    out std_logic; -- Handshake valid
       cmt_o_ready:     in std_logic; -- Handshake ready 
       cmt_o_pc_vld:   out std_logic;
       cmt_o_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
       cmt_o_instr:    out std_logic_vector(E203_INSTR_SIZE-1 downto 0);
       cmt_o_imm:      out std_logic_vector(E203_XLEN-1 downto 0); -- The resolved ture/false

       --   The Branch and Jump Commit
       cmt_o_rv32:     out std_logic; -- The predicted ture/false
       cmt_o_bjp:      out std_logic;
       cmt_o_mret:     out std_logic;
       cmt_o_dret:     out std_logic;     
       cmt_o_ecall:    out std_logic;
       cmt_o_ebreak:   out std_logic;
       cmt_o_fencei:   out std_logic;
       cmt_o_wfi:      out std_logic;
       cmt_o_ifu_misalgn: out std_logic;
       cmt_o_ifu_buserr:  out std_logic;
       cmt_o_ifu_ilegl:   out std_logic;
       cmt_o_bjp_prdt:    out std_logic; -- The predicted ture/false    
       cmt_o_bjp_rslv:    out std_logic; -- The resolved ture/false

       -- The AGU Exception 
       cmt_o_misalgn:     out std_logic; -- The misalign exception generated
       cmt_o_ld:          out std_logic;
       cmt_o_stamo:       out std_logic;
       cmt_o_buserr:      out std_logic; -- The bus-error exception generated
       cmt_o_badaddr:     out std_logic_vector(E203_ADDR_SIZE-1 downto 0);

       -- The ALU Write-Back Interface
       wbck_o_valid:      out std_logic; -- Handshake valid
       wbck_o_ready:       in std_logic; -- Handshake ready 
       wbck_o_wdat:       out std_logic_vector(E203_XLEN-1 downto 0);
       wbck_o_rdidx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
       
       mdv_nob2b:          in std_logic; 
       
       -- The CSR Interface
       csr_ena:           out std_logic;
       csr_wr_en:         out std_logic;
       csr_rd_en:         out std_logic;        
       csr_idx:           out std_logic_vector(12-1 downto 0);    
        
       nonflush_cmt_ena:   in std_logic;
       csr_access_ilgl:    in std_logic;
       read_csr_dat:       in std_logic_vector(E203_XLEN-1 downto 0);
       wbck_csr_dat:      out std_logic_vector(E203_XLEN-1 downto 0);
     
       -- The AGU ICB Interface to LSU-ctrl
       --    * Bus cmd channel
       agu_icb_cmd_valid:    out std_logic; -- Handshake valid
       agu_icb_cmd_ready:     in std_logic; -- Handshake ready
       agu_icb_cmd_addr:     out std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr 
       agu_icb_cmd_read:     out std_logic; -- Read or write
       agu_icb_cmd_wdata:    out std_logic_vector(E203_XLEN-1 downto 0);
       agu_icb_cmd_wmask:    out std_logic_vector(E203_XLEN/8-1 downto 0);
       agu_icb_cmd_lock:     out std_logic;
       agu_icb_cmd_excl:     out std_logic;
       agu_icb_cmd_size:     out std_logic_vector(1 downto 0);
       agu_icb_cmd_back2agu: out std_logic;
       agu_icb_cmd_usign:    out std_logic;
       agu_icb_cmd_itag:     out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
       
       -- * Bus RSP channel
       agu_icb_rsp_valid:     in std_logic; -- Response valid
       agu_icb_rsp_ready:    out std_logic; -- Response ready
       agu_icb_rsp_err:       in std_logic; -- Response error
       agu_icb_rsp_excl_ok:   in std_logic;
       agu_icb_rsp_rdata:     in std_logic_vector(E203_XLEN-1 downto 0);

      `if E203_HAS_NICE = "TRUE" then
       -- The nice interface
       --    * cmd channel 
       nice_req_valid:       out std_logic; -- Response valid 
       nice_req_ready:        in std_logic; -- Response ready
       nice_req_instr:       out std_logic_vector(E203_XLEN-1 downto 0);
       nice_req_rs1:         out std_logic_vector(E203_XLEN-1 downto 0);
       nice_req_rs2:         out std_logic_vector(E203_XLEN-1 downto 0);
       
       -- * RSP channel will be directly pass to longp-wback module
       nice_rsp_multicyc_valid:  in std_logic; -- I: current insn is multi-cycle.
       nice_rsp_multicyc_ready: out std_logic; -- O:

       nice_longp_wbck_valid:   out std_logic; -- Handshake valid
       nice_longp_wbck_ready:    in std_logic; -- Handshake ready
       nice_o_itag:             out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
       i_nice_cmt_off_ilgl:      in std_logic; 
  	  `end if

       clk:                      in std_logic;  
       rst_n:                    in std_logic  
  );
end e203_exu_alu;

architecture impl of e203_exu_alu is 
  signal ifu_excp_op: std_ulogic;
  signal alu_op:      std_ulogic;
  signal agu_op:      std_ulogic;
  signal bjp_op:      std_ulogic;
  signal csr_op:      std_ulogic;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal mdv_op:      std_ulogic;
 `end if 
 `if E203_HAS_NICE = "TRUE" then
  signal nice_op:     std_ulogic;
 `end if
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal mdv_i_valid: std_ulogic;
 `end if
  signal agu_i_valid: std_ulogic;
  signal alu_i_valid: std_ulogic;
  signal bjp_i_valid: std_ulogic;
  signal csr_i_valid: std_ulogic;
  signal ifu_excp_i_valid:  std_ulogic;
 `if E203_HAS_NICE = "TRUE" then
  signal nice_i_valid: std_ulogic;
  signal nice_i_ready: std_ulogic;
 `end if
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal mdv_i_ready:  std_ulogic;
 `end if
  signal agu_i_ready:  std_ulogic;
  signal alu_i_ready:  std_ulogic;
  signal bjp_i_ready:  std_ulogic;
  signal csr_i_ready:  std_ulogic;
  signal ifu_excp_i_ready: std_ulogic;

  signal agu_i_longpipe:   std_ulogic;

 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal mdv_i_longpipe:   std_ulogic;
 `end if
 `if E203_HAS_NICE = "TRUE" then
  signal nice_o_longpipe:  std_ulogic;
  signal nice_i_longpipe:  std_ulogic;
 `end if

  signal csr_o_valid:      std_ulogic;
  signal csr_o_ready:      std_ulogic;
  signal csr_o_wbck_wdat:  std_ulogic_vector(E203_XLEN-1 downto 0);
  signal csr_o_wbck_err:   std_ulogic;
  signal csr_i_rs1:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal csr_i_rs2:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal csr_i_imm:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal csr_i_info:       std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);
  signal csr_i_rdwen:      std_ulogic;
 `if E203_HAS_CSR_NICE = "TRUE" then
  signal csr_sel_nice:     std_ulogic;
 `end if
 
 `if E203_HAS_NICE = "TRUE" then
  signal nice_i_rs1:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal nice_i_rs2:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal nice_i_itag:      std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);
  signal nice_o_valid:     std_ulogic;
  signal nice_o_ready:     std_ulogic;
  signal nice_o_wbck_err:  std_ulogic;
 `end if

  signal bjp_o_valid:      std_ulogic;
  signal bjp_o_ready:      std_ulogic;
  signal bjp_o_wbck_wdat:  std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_o_wbck_err:   std_ulogic;
  signal bjp_o_cmt_bjp:    std_ulogic;
  signal bjp_o_cmt_mret:   std_ulogic;
  signal bjp_o_cmt_dret:   std_ulogic;
  signal bjp_o_cmt_fencei: std_ulogic;
  signal bjp_o_cmt_prdt:   std_ulogic;
  signal bjp_o_cmt_rslv:   std_ulogic;
  signal bjp_req_alu_op1:  std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_req_alu_op2:  std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_req_alu_cmp_eq:  std_ulogic;
  signal bjp_req_alu_cmp_ne:  std_ulogic;
  signal bjp_req_alu_cmp_lt:  std_ulogic;
  signal bjp_req_alu_cmp_gt:  std_ulogic;
  signal bjp_req_alu_cmp_ltu: std_ulogic;
  signal bjp_req_alu_cmp_gtu: std_ulogic;
  signal bjp_req_alu_add:     std_ulogic;
  signal bjp_req_alu_cmp_res: std_ulogic;
  signal bjp_req_alu_add_res: std_ulogic_vector(E203_XLEN-1 downto 0);
  
  signal bjp_i_rs1:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_i_rs2:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_i_imm:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal bjp_i_info:          std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);
  signal bjp_i_pc:            std_ulogic_vector(E203_PC_SIZE-1 downto 0);

  signal agu_o_valid:         std_ulogic;
  signal agu_o_ready:         std_ulogic;

  signal agu_o_wbck_wdat:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_o_wbck_err:      std_ulogic;

  signal agu_o_cmt_misalgn:   std_ulogic;
  signal agu_o_cmt_ld:        std_ulogic;
  signal agu_o_cmt_stamo:     std_ulogic;
  signal agu_o_cmt_buserr:    std_ulogic;
  signal agu_o_cmt_badaddr:   std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);

  signal agu_req_alu_op1:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_req_alu_op2:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_req_alu_swap:    std_ulogic;
  signal agu_req_alu_add:     std_ulogic;
  signal agu_req_alu_and:     std_ulogic;
  signal agu_req_alu_or:      std_ulogic;
  signal agu_req_alu_xor:     std_ulogic;
  signal agu_req_alu_max:     std_ulogic;
  signal agu_req_alu_min:     std_ulogic;
  signal agu_req_alu_maxu:    std_ulogic;
  signal agu_req_alu_minu:    std_ulogic;
  signal agu_req_alu_res:     std_ulogic_vector(E203_XLEN-1 downto 0);

  signal agu_sbf_0_ena:       std_ulogic;
  signal agu_sbf_0_nxt:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_sbf_0_r:         std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_sbf_1_ena:       std_ulogic;
  signal agu_sbf_1_nxt:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_sbf_1_r:         std_ulogic_vector(E203_XLEN-1 downto 0);

  signal agu_i_rs1:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_i_rs2:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_i_imm:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal agu_i_info:          std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);
  signal agu_i_itag:          std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);

  signal alu_o_valid:         std_ulogic;
  signal alu_o_ready:         std_ulogic;
  signal alu_o_wbck_wdat:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_o_wbck_err:      std_ulogic;
  signal alu_o_cmt_ecall:     std_ulogic;
  signal alu_o_cmt_ebreak:    std_ulogic;
  signal alu_o_cmt_wfi:       std_ulogic;

  signal alu_req_alu_add:     std_ulogic;
  signal alu_req_alu_sub:     std_ulogic;
  signal alu_req_alu_xor:     std_ulogic;
  signal alu_req_alu_sll:     std_ulogic;
  signal alu_req_alu_srl:     std_ulogic;
  signal alu_req_alu_sra:     std_ulogic;
  signal alu_req_alu_or:      std_ulogic;
  signal alu_req_alu_and:     std_ulogic;
  signal alu_req_alu_slt:     std_ulogic;
  signal alu_req_alu_sltu:    std_ulogic;
  signal alu_req_alu_lui:     std_ulogic;
  signal alu_req_alu_op1:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_req_alu_op2:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_req_alu_res:     std_ulogic_vector(E203_XLEN-1 downto 0);

  signal alu_i_rs1:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_i_rs2:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_i_imm:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_i_info:          std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);
  signal alu_i_pc:            std_ulogic_vector(E203_PC_SIZE-1 downto 0);

 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal mdv_i_rs1:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal mdv_i_rs2:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal mdv_i_imm:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal mdv_i_info:          std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);
  signal mdv_i_itag:          std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);

  signal mdv_o_valid:         std_ulogic;
  signal mdv_o_ready:         std_ulogic;
  signal mdv_o_wbck_wdat:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal mdv_o_wbck_err:      std_ulogic;

  signal muldiv_req_alu_op1:  std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal muldiv_req_alu_op2:  std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal muldiv_req_alu_add:  std_ulogic;
  signal muldiv_req_alu_sub:  std_ulogic;
  signal muldiv_req_alu_res:  std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);

  signal muldiv_sbf_0_ena:    std_ulogic;
  signal muldiv_sbf_0_nxt:    std_ulogic_vector(33-1 downto 0);
  signal muldiv_sbf_0_r:      std_ulogic_vector(33-1 downto 0);

  signal muldiv_sbf_1_ena:    std_ulogic;
  signal muldiv_sbf_1_nxt:    std_ulogic_vector(33-1 downto 0);
  signal muldiv_sbf_1_r:      std_ulogic_vector(33-1 downto 0);
 `end if

  signal alu_req_alu:         std_ulogic;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal muldiv_req_alu:      std_ulogic;
 `end if
  signal bjp_req_alu:         std_ulogic;
  signal agu_req_alu:         std_ulogic;

  signal ifu_excp_o_valid:    std_ulogic;
  signal ifu_excp_o_ready:    std_ulogic;
  signal ifu_excp_o_wbck_wdat: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal ifu_excp_o_wbck_err:  std_ulogic;
  
  signal o_valid:              std_ulogic;
  signal o_ready:              std_ulogic;
  signal o_sel_ifu_excp:       std_ulogic;
  signal o_sel_alu:            std_ulogic;
  signal o_sel_bjp:            std_ulogic;
  signal o_sel_csr:            std_ulogic;
  signal o_sel_agu:            std_ulogic;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  signal o_sel_mdv:            std_ulogic;
 `end if
 `if E203_HAS_NICE = "TRUE" then
  signal o_sel_nice:           std_ulogic;
 `end if

  signal wbck_o_rdwen:         std_ulogic;
  signal wbck_o_err:           std_ulogic;
      
  signal o_need_wbck:          std_ulogic;
  signal o_need_cmt:           std_ulogic;
  
  signal is_cmt_oready:        std_ulogic;
  signal is_wbck_oready:       std_ulogic;

  component e203_exu_alu_rglr is 
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
  end component;
  component e203_exu_alu_csrctrl is 
    port ( -- The Handshake Interface 
           csr_i_valid:  in std_logic; -- Handshake valid
           csr_i_ready: out std_logic; -- Handshake ready
  
           csr_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
           csr_i_info:   in std_logic_vector(E203_DECINFO_CSR_WIDTH-1 downto 0);
           csr_i_rdwen:  in std_logic;
  
           csr_ena:     out std_logic;
           csr_wr_en:   out std_logic;
           csr_rd_en:   out std_logic;
           csr_idx:     out std_logic_vector(12-1 downto 0);
  
           csr_access_ilgl: in std_logic;
           read_csr_dat:    in std_logic_vector(E203_XLEN-1 downto 0);
           wbck_csr_dat:   out std_logic_vector(E203_XLEN-1 downto 0);
  
          `if E203_HAS_CSR_NICE = "TRUE" then 
           nice_xs_off:     in std_logic;
           csr_sel_nice:   out std_logic;
           nice_csr_valid: out std_logic;
           nice_csr_ready:  in std_logic;
           nice_csr_addr:  out std_logic_vector(32-1 downto 0);
           nice_csr_wr:    out std_logic;
           nice_csr_wdata: out std_logic_vector(32-1 downto 0);
           nice_csr_rdata:  in std_logic_vector(32-1 downto 0);
          `end if
           
           -- The CSR Write-back/Commit Interface
           csr_o_valid: out std_logic; -- Handshake valid
           csr_o_ready:  in std_logic; -- Handshake ready
           -- The Write-Back Interface for Special (unaligned ldst and AMO instructions) 
           csr_o_wbck_wdat: out std_logic_vector(E203_XLEN-1 downto 0);
           csr_o_wbck_err:  out std_logic;
  
           clk:              in std_logic;  
           rst_n:            in std_logic 
    );
  end component;
  component e203_exu_alu_bjp is 
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
  end component;
  component e203_exu_alu_lsuagu is 
    port ( -- The Handshake Interface 
           agu_i_valid:  in std_logic; -- Handshake valid
           agu_i_ready: out std_logic; -- Handshake ready
  
           agu_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
           agu_i_rs2:    in std_logic_vector(E203_XLEN-1 downto 0);
           agu_i_imm:    in std_logic_vector(E203_XLEN-1 downto 0);
           agu_i_info:   in std_logic_vector(E203_DECINFO_AGU_WIDTH-1 downto 0);
           agu_i_itag:   in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
  
           agu_i_longpipe: out std_logic;
           flush_req:       in std_logic;  
           flush_pulse:     in std_logic;
           amo_wait:       out std_logic;  
           oitf_empty:      in std_logic;
  
           -- The AGU Write-Back/Commit Interface
           agu_o_valid:      out std_logic; -- Handshake valid
           agu_o_ready:       in std_logic; -- Handshake ready  
           agu_o_wbck_wdat:  out std_logic_vector(E203_XLEN-1 downto 0); 
           agu_o_wbck_err:   out std_logic;
           -- The Commit Interface for all ldst and amo instructions
           agu_o_cmt_misalgn: out std_logic;
           agu_o_cmt_ld:      out std_logic;
           agu_o_cmt_stamo:   out std_logic;
           agu_o_cmt_buserr:  out std_logic;
           agu_o_cmt_badaddr: out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  
           -- The ICB Interface to LSU-ctrl
           --    * Bus cmd channel
           agu_icb_cmd_valid:  out  std_logic; -- Handshake valid
           agu_icb_cmd_ready:   in  std_logic; -- Handshake ready
           -- Note: The data on rdata or wdata channel must be naturally
           --       aligned, this is in line with the AXI definition
           agu_icb_cmd_addr:     out std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr
           agu_icb_cmd_read:     out std_logic;                                -- Read or write
           agu_icb_cmd_wdata:    out std_logic_vector(E203_XLEN-1 downto 0);
           agu_icb_cmd_wmask:    out std_logic_vector(E203_XLEN/8-1 downto 0);
           agu_icb_cmd_back2agu: out std_logic;
           agu_icb_cmd_lock:     out std_logic;
           agu_icb_cmd_excl:     out std_logic;
           agu_icb_cmd_size:     out std_logic_vector(1 downto 0);
           agu_icb_cmd_itag:     out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
           agu_icb_cmd_usign:    out std_logic;
  
           --    * Bus RSP channel
           agu_icb_rsp_valid:     in  std_logic; -- Response valid
           agu_icb_rsp_ready:    out  std_logic; -- Response ready
           agu_icb_rsp_err:       in  std_logic; -- Response error
           agu_icb_rsp_excl_ok:   in  std_logic;
           -- Note: the RSP rdata is inline with AXI definition
           agu_icb_rsp_rdata:     in std_logic_vector(E203_XLEN-1 downto 0);
  
           -- To share the ALU datapath, generate interface to ALU
           --   for single-issue machine, seems the AGU must be shared with ALU, otherwise
           --   it wasted the area for no points 
           -- 
           -- The operands and info to ALU
           agu_req_alu_op1:  out std_logic_vector(E203_XLEN-1 downto 0);
           agu_req_alu_op2:  out std_logic_vector(E203_XLEN-1 downto 0);
           agu_req_alu_swap: out std_logic;
           agu_req_alu_add:  out std_logic;
           agu_req_alu_and:  out std_logic;
           agu_req_alu_or:   out std_logic;
           agu_req_alu_xor:  out std_logic;
           agu_req_alu_max:  out std_logic;
           agu_req_alu_min:  out std_logic;
           agu_req_alu_maxu: out std_logic;
           agu_req_alu_minu: out std_logic;
           agu_req_alu_res:   in std_logic_vector(E203_XLEN-1 downto 0);
           
           -- The Shared-Buffer interface to ALU-Shared-Buffer
           agu_sbf_0_ena:    out std_logic;
           agu_sbf_0_nxt:    out std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_0_r:       in std_logic_vector(E203_XLEN-1 downto 0);
           
           agu_sbf_1_ena:    out std_logic;
           agu_sbf_1_nxt:    out std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_1_r:       in std_logic_vector(E203_XLEN-1 downto 0);
  
           clk:               in std_logic;  
           rst_n:             in std_logic  
         );
  end component;
  component e203_exu_alu_muldiv is 
    port ( mdv_nob2b:    in std_logic;
  
           -- The Issue Handshake Interface to MULDIV 
           muldiv_i_valid:  in std_logic; -- Handshake valid
           muldiv_i_ready: out std_logic; -- Handshake ready
  
           muldiv_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
           muldiv_i_rs2:    in std_logic_vector(E203_XLEN-1 downto 0);
           muldiv_i_imm:    in std_logic_vector(E203_XLEN-1 downto 0);
           muldiv_i_info:   in std_logic_vector(E203_DECINFO_MULDIV_WIDTH-1 downto 0);
           muldiv_i_itag:   in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
  
           muldiv_i_longpipe: out std_logic;
  
           flush_pulse:        in std_logic;  
  
           -- The MULDIV Write-Back/Commit Interface
           muldiv_o_valid:     out std_logic; -- Handshake valid
           muldiv_o_ready:      in std_logic; -- Handshake ready  
           muldiv_o_wbck_wdat: out std_logic_vector(E203_XLEN-1 downto 0); 
           muldiv_o_wbck_err:  out std_logic;
           
           -- There is no exception cases for MULDIV, so no addtional cmt signals
           -- To share the ALU datapath, generate interface to ALU
           -- The operands and info to ALU
           muldiv_req_alu_op1: out std_logic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0);
           muldiv_req_alu_op2: out std_logic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0);
           muldiv_req_alu_add: out std_logic;
           muldiv_req_alu_sub: out std_logic;
           muldiv_req_alu_res:  in std_logic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0);
           
           -- The Shared-Buffer interface to ALU-Shared-Buffer
           muldiv_sbf_0_ena:   out std_logic;
           muldiv_sbf_0_nxt:   out std_logic_vector(33-1 downto 0);
           muldiv_sbf_0_r:      in std_logic_vector(33-1 downto 0);
           
           muldiv_sbf_1_ena:   out std_logic;
           muldiv_sbf_1_nxt:   out std_logic_vector(33-1 downto 0);
           muldiv_sbf_1_r:      in std_logic_vector(33-1 downto 0);
  
           clk:                 in std_logic;  
           rst_n:               in std_logic  
         );
  end component;
  component e203_exu_alu_dpath is 
    port ( -- ALU request the datapath 
           alu_req_alu:      in std_logic;  
           alu_req_alu_add:  in std_logic;  
           alu_req_alu_sub:  in std_logic;
           alu_req_alu_xor:  in std_logic;  
           alu_req_alu_sll:  in std_logic;
           alu_req_alu_srl:  in std_logic;  
           alu_req_alu_sra:  in std_logic;
           alu_req_alu_or:   in std_logic;  
           alu_req_alu_and:  in std_logic;
           alu_req_alu_slt:  in std_logic;  
           alu_req_alu_sltu: in std_logic;
           alu_req_alu_lui:  in std_logic;     
           alu_req_alu_op1:  in std_logic_vector(E203_XLEN-1 downto 0);
           alu_req_alu_op2:  in std_logic_vector(E203_XLEN-1 downto 0);
           alu_req_alu_res: out std_logic_vector(E203_XLEN-1 downto 0);
            
           -- BJP request the datapath
           bjp_req_alu:          in std_logic;
           bjp_req_alu_op1:      in std_logic_vector(E203_XLEN-1 downto 0);
           bjp_req_alu_op2:      in std_logic_vector(E203_XLEN-1 downto 0);
           bjp_req_alu_cmp_eq:   in std_logic;  
           bjp_req_alu_cmp_ne:   in std_logic;
           bjp_req_alu_cmp_lt:   in std_logic;  
           bjp_req_alu_cmp_gt:   in std_logic;
           bjp_req_alu_cmp_ltu:  in std_logic;  
           bjp_req_alu_cmp_gtu:  in std_logic;
           bjp_req_alu_add:      in std_logic;  
           bjp_req_alu_cmp_res: out std_logic; 
           bjp_req_alu_add_res: out std_logic_vector(E203_XLEN-1 downto 0);
  
           -- AGU request the datapath
           agu_req_alu:          in std_logic;
           agu_req_alu_op1:      in std_logic_vector(E203_XLEN-1 downto 0);
           agu_req_alu_op2:      in std_logic_vector(E203_XLEN-1 downto 0);
           agu_req_alu_swap:     in std_logic;  
           agu_req_alu_add:      in std_logic;
           agu_req_alu_and:      in std_logic;  
           agu_req_alu_or:       in std_logic;
           agu_req_alu_xor:      in std_logic;  
           agu_req_alu_max:      in std_logic;
           agu_req_alu_min:      in std_logic;  
           agu_req_alu_maxu:     in std_logic; 
           agu_req_alu_minu:     in std_logic;
           agu_req_alu_res:     out std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_0_ena:        in std_logic;
           agu_sbf_0_nxt:        in std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_0_r:         out std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_1_ena:        in std_logic;
           agu_sbf_1_nxt:        in std_logic_vector(E203_XLEN-1 downto 0);
           agu_sbf_1_r:         out std_logic_vector(E203_XLEN-1 downto 0);
  
          `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
           -- MULDIV request the datapath
           muldiv_req_alu:       in std_logic;
           muldiv_req_alu_op1:   in std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
           muldiv_req_alu_op2:   in std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);  
           muldiv_req_alu_add:   in std_logic;
           muldiv_req_alu_sub:   in std_logic;
           muldiv_req_alu_res:  out std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);  
           muldiv_sbf_0_ena:     in std_logic;
           muldiv_sbf_0_nxt:     in std_logic_vector(33-1 downto 0);
           muldiv_sbf_0_r:      out std_logic_vector(33-1 downto 0);
           muldiv_sbf_1_ena:     in std_logic;
           muldiv_sbf_1_nxt:     in std_logic_vector(33-1 downto 0);
           muldiv_sbf_1_r:      out std_logic_vector(33-1 downto 0);
          `end if
  
           clk:               in std_logic;  
           rst_n:             in std_logic  
         );
  end component;
  component e203_exu_nice is 
    port ( -- The Handshake Interface 
           nice_i_xs_off: in std_logic;
           nice_i_valid:  in std_logic; -- Handshake valid
           nice_i_ready: out std_logic; -- Handshake ready
  
           nice_i_instr:     in std_logic_vector(E203_XLEN-1 downto 0);
           nice_i_rs1:       in std_logic_vector(E203_XLEN-1 downto 0);
           nice_i_rs2:       in std_logic_vector(E203_XLEN-1 downto 0);
           nice_i_itag:      in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
           nice_o_longpipe: out std_logic;
  
           -- The nice Commit Interface
           nice_o_valid:    out std_logic; -- Handshake valid
           nice_o_ready:     in std_logic; -- Handshake ready
  
           -- The nice write-back Interface
           nice_o_itag_valid: out std_logic; -- Handshake valid
           nice_o_itag_ready:  in std_logic; -- Handshake ready
           nice_o_itag:       out std_logic_vector(E203_ITAG_WIDTH-1 downto 0); 
           
           -- The nice Request Interface
           nice_rsp_multicyc_valid:   in std_logic; -- I: current insn is multi-cycle.
           nice_rsp_multicyc_ready:  out std_logic; -- O:  
           
           nice_req_valid:           out std_logic; -- Handshake valid
           nice_req_ready:            in std_logic; -- Handshake ready
           nice_req_instr:           out std_logic_vector(E203_XLEN-1 downto 0);
           nice_req_rs1:             out std_logic_vector(E203_XLEN-1 downto 0);
           nice_req_rs2:             out std_logic_vector(E203_XLEN-1 downto 0);
           
           clk:                       in std_logic;  
           rst_n:                     in std_logic 
    );
  end component;
begin
  -- Dispatch to different sub-modules according to their types
  ifu_excp_op <= i_ilegl or i_buserr or i_misalgn;
  alu_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_ALU); 
  agu_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_AGU); 
  bjp_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_BJP); 
  csr_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_CSR); 
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  mdv_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_MULDIV); 
 `end if
 `if E203_HAS_NICE = "TRUE" then
  nice_op <= (not ifu_excp_op) and (i_info(E203_DECINFO_GRP'range) ?= E203_DECINFO_GRP_NICE);
 `end if

  -- The ALU incoming instruction may go to several different targets:
  --   * The ALUDATAPATH if it is a regular ALU instructions
  --   * The Branch-cmp if it is a BJP instructions
  --   * The AGU if it is a load/store relevant instructions
  --   * The MULDIV if it is a MUL/DIV relevant instructions and MULDIV
  --       is reusing the ALU adder
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  mdv_i_valid <= i_valid and mdv_op;
 `end if
  agu_i_valid <= i_valid and agu_op;
  alu_i_valid <= i_valid and alu_op;
  bjp_i_valid <= i_valid and bjp_op;
  csr_i_valid <= i_valid and csr_op;
  ifu_excp_i_valid <= i_valid and ifu_excp_op;
`if E203_HAS_NICE = "TRUE" then
  nice_i_valid <= i_valid and nice_op;
`end if 

  i_ready <=  (agu_i_ready and agu_op)
         `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
           or (mdv_i_ready and mdv_op)
         `end if
           or (alu_i_ready and alu_op)
           or (ifu_excp_i_ready and ifu_excp_op)
           or (bjp_i_ready and bjp_op)
           or (csr_i_ready and csr_op)
         `if E203_HAS_NICE = "TRUE" then
           or (nice_i_ready and nice_op)
         `end if
             ;

`if E203_HAS_NICE = "TRUE" then
  nice_i_longpipe <= nice_o_longpipe;
`end if

 i_longpipe <= (agu_i_longpipe and agu_op) 
           `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
            or (mdv_i_longpipe and mdv_op) 
           `end if
           `if E203_HAS_NICE = "TRUE" then
            or (nice_i_longpipe and nice_op)
           `end if
               ;
 
  -- Instantiate the CSR module
  csr_i_rs1   <= (E203_XLEN         -1 downto 0 => csr_op) and i_rs1;
  csr_i_rs2   <= (E203_XLEN         -1 downto 0 => csr_op) and i_rs2;
  csr_i_imm   <= (E203_XLEN         -1 downto 0 => csr_op) and i_imm;
  csr_i_info  <= (E203_DECINFO_WIDTH-1 downto 0 => csr_op) and i_info;  
  csr_i_rdwen <=                                   csr_op  and i_rdwen;

 `if E203_HAS_NICE = "TRUE" then
  nice_i_rs1  <= (E203_XLEN      -1 downto 0 => nice_op) and i_rs1;
  nice_i_rs2  <= (E203_XLEN      -1 downto 0 => nice_op) and i_rs2;
  nice_i_itag <= (E203_ITAG_WIDTH-1 downto 0 => nice_op) and i_itag;  
  
  nice_o_wbck_err <= i_nice_cmt_off_ilgl;
  
  u_e203_exu_nice: component e203_exu_nice port map(

  nice_i_xs_off           => nice_xs_off,
  nice_i_valid            => nice_i_valid, -- Handshake valid
  nice_i_ready            => nice_i_ready, -- Handshake ready
  nice_i_instr            => i_instr,
  nice_i_rs1              => nice_i_rs1, -- Handshake valid
  nice_i_rs2              => nice_i_rs2, -- Handshake ready
      
  nice_i_itag             => nice_i_itag,
  nice_o_longpipe         => nice_o_longpipe,
      
  nice_o_valid            => nice_o_valid, -- Handshake valid
  nice_o_ready            => nice_o_ready, -- Handshake ready
    
  nice_o_itag_valid       => nice_longp_wbck_valid, -- Handshake valid
  nice_o_itag_ready       => nice_longp_wbck_ready, -- Handshake ready
  nice_o_itag             => nice_o_itag,   
  
  nice_rsp_multicyc_valid => nice_rsp_multicyc_valid, -- I: current insn is multi-cycle.
  nice_rsp_multicyc_ready => nice_rsp_multicyc_ready, -- O:                             
  
  nice_req_valid          => nice_req_valid, -- Handshake valid
  nice_req_ready          => nice_req_ready, -- Handshake ready
  nice_req_instr          => nice_req_instr, -- Handshake ready
  nice_req_rs1            => nice_req_rs1, -- Handshake valid
  nice_req_rs2            => nice_req_rs2, -- Handshake ready
      
  clk                     => clk,
  rst_n                   => rst_n       
  );
 `end if
  
  u_e203_exu_alu_csrctrl: component e203_exu_alu_csrctrl port map(

 `if E203_HAS_CSR_NICE = "TRUE" then
  nice_xs_off      => nice_xs_off,
  csr_sel_nice     => csr_sel_nice,
  nice_csr_valid   => nice_csr_valid,
  nice_csr_ready   => nice_csr_ready,
  nice_csr_addr    => nice_csr_addr,
  nice_csr_wr      => nice_csr_wr,
  nice_csr_wdata   => nice_csr_wdata,
  nice_csr_rdata   => nice_csr_rdata,
 `end if
  csr_access_ilgl  => csr_access_ilgl,

  csr_i_valid      => csr_i_valid,
  csr_i_ready      => csr_i_ready,

  csr_i_rs1        => csr_i_rs1,
  csr_i_info       => csr_i_info(E203_DECINFO_CSR_WIDTH-1 downto 0),
  csr_i_rdwen      => csr_i_rdwen,

  csr_ena          => csr_ena,
  csr_idx          => csr_idx,
  csr_rd_en        => csr_rd_en,
  csr_wr_en        => csr_wr_en,
  read_csr_dat     => read_csr_dat,
  wbck_csr_dat     => wbck_csr_dat,

  csr_o_valid      => csr_o_valid    ,   
  csr_o_ready      => csr_o_ready    ,   
  csr_o_wbck_wdat  => csr_o_wbck_wdat,
  csr_o_wbck_err   => csr_o_wbck_err ,

  clk              => clk,
  rst_n            => rst_n
  );

  -- Instantiate the BJP module
  bjp_i_rs1  <= (E203_XLEN         -1 downto 0 => bjp_op) and i_rs1;
  bjp_i_rs2  <= (E203_XLEN         -1 downto 0 => bjp_op) and i_rs2;
  bjp_i_imm  <= (E203_XLEN         -1 downto 0 => bjp_op) and i_imm;
  bjp_i_info <= (E203_DECINFO_WIDTH-1 downto 0 => bjp_op) and i_info;  
  bjp_i_pc   <= (E203_PC_SIZE      -1 downto 0 => bjp_op) and i_pc;  

  u_e203_exu_alu_bjp: component e203_exu_alu_bjp port map(
  bjp_i_valid         => bjp_i_valid        ,
  bjp_i_ready         => bjp_i_ready        ,
  bjp_i_rs1           => bjp_i_rs1          ,
  bjp_i_rs2           => bjp_i_rs2          ,
  bjp_i_info          => bjp_i_info(E203_DECINFO_BJP_WIDTH-1 downto 0),
  bjp_i_imm           => bjp_i_imm          ,
  bjp_i_pc            => bjp_i_pc           ,

  bjp_o_valid         => bjp_o_valid        ,
  bjp_o_ready         => bjp_o_ready        ,
  bjp_o_wbck_wdat     => bjp_o_wbck_wdat    ,
  bjp_o_wbck_err      => bjp_o_wbck_err     ,

  bjp_o_cmt_bjp       => bjp_o_cmt_bjp      ,
  bjp_o_cmt_mret      => bjp_o_cmt_mret     ,
  bjp_o_cmt_dret      => bjp_o_cmt_dret     ,
  bjp_o_cmt_fencei    => bjp_o_cmt_fencei   ,
  bjp_o_cmt_prdt      => bjp_o_cmt_prdt     ,
  bjp_o_cmt_rslv      => bjp_o_cmt_rslv     ,

  bjp_req_alu_op1     => bjp_req_alu_op1    ,
  bjp_req_alu_op2     => bjp_req_alu_op2    ,
  bjp_req_alu_cmp_eq  => bjp_req_alu_cmp_eq ,
  bjp_req_alu_cmp_ne  => bjp_req_alu_cmp_ne ,
  bjp_req_alu_cmp_lt  => bjp_req_alu_cmp_lt ,
  bjp_req_alu_cmp_gt  => bjp_req_alu_cmp_gt ,
  bjp_req_alu_cmp_ltu => bjp_req_alu_cmp_ltu,
  bjp_req_alu_cmp_gtu => bjp_req_alu_cmp_gtu,
  bjp_req_alu_add     => bjp_req_alu_add    ,
  bjp_req_alu_cmp_res => bjp_req_alu_cmp_res,
  bjp_req_alu_add_res => bjp_req_alu_add_res,

  clk                 => clk,
  rst_n               => rst_n
  );

  -- Instantiate the AGU module 
  agu_i_rs1  <= (E203_XLEN         -1 downto 0 => agu_op) and i_rs1;
  agu_i_rs2  <= (E203_XLEN         -1 downto 0 => agu_op) and i_rs2;
  agu_i_imm  <= (E203_XLEN         -1 downto 0 => agu_op) and i_imm;
  agu_i_info <= (E203_DECINFO_WIDTH-1 downto 0 => agu_op) and i_info;  
  agu_i_itag <= (E203_ITAG_WIDTH   -1 downto 0 => agu_op) and i_itag;  

  u_e203_exu_alu_lsuagu: component e203_exu_alu_lsuagu port map(
  agu_i_valid          => agu_i_valid   ,
  agu_i_ready          => agu_i_ready   ,
  agu_i_rs1            => agu_i_rs1     ,
  agu_i_rs2            => agu_i_rs2     ,
  agu_i_imm            => agu_i_imm     ,
  agu_i_info           => agu_i_info(E203_DECINFO_AGU_WIDTH-1 downto 0),
  agu_i_longpipe       => agu_i_longpipe,
  agu_i_itag           => agu_i_itag    ,

  flush_pulse          => flush_pulse   ,
  flush_req            => flush_req     ,
  amo_wait             => amo_wait      ,
  oitf_empty           => oitf_empty    ,

  agu_o_valid          => agu_o_valid         ,
  agu_o_ready          => agu_o_ready         ,
  agu_o_wbck_wdat      => agu_o_wbck_wdat     ,
  agu_o_wbck_err       => agu_o_wbck_err      ,
  agu_o_cmt_misalgn    => agu_o_cmt_misalgn   ,
  agu_o_cmt_ld         => agu_o_cmt_ld        ,
  agu_o_cmt_stamo      => agu_o_cmt_stamo     ,
  agu_o_cmt_buserr     => agu_o_cmt_buserr    ,
  agu_o_cmt_badaddr    => agu_o_cmt_badaddr   ,
                                        
  agu_icb_cmd_valid    => agu_icb_cmd_valid   ,
  agu_icb_cmd_ready    => agu_icb_cmd_ready   ,
  agu_icb_cmd_addr     => agu_icb_cmd_addr    ,
  agu_icb_cmd_read     => agu_icb_cmd_read    ,
  agu_icb_cmd_wdata    => agu_icb_cmd_wdata   ,
  agu_icb_cmd_wmask    => agu_icb_cmd_wmask   ,
  agu_icb_cmd_lock     => agu_icb_cmd_lock    ,
  agu_icb_cmd_excl     => agu_icb_cmd_excl    ,
  agu_icb_cmd_size     => agu_icb_cmd_size    ,
  agu_icb_cmd_back2agu => agu_icb_cmd_back2agu,
  agu_icb_cmd_usign    => agu_icb_cmd_usign   ,
  agu_icb_cmd_itag     => agu_icb_cmd_itag    ,
  agu_icb_rsp_valid    => agu_icb_rsp_valid   ,
  agu_icb_rsp_ready    => agu_icb_rsp_ready   ,
  agu_icb_rsp_err      => agu_icb_rsp_err     ,
  agu_icb_rsp_excl_ok  => agu_icb_rsp_excl_ok ,
  agu_icb_rsp_rdata    => agu_icb_rsp_rdata   ,
                                           
  agu_req_alu_op1      => agu_req_alu_op1     ,
  agu_req_alu_op2      => agu_req_alu_op2     ,
  agu_req_alu_swap     => agu_req_alu_swap    ,
  agu_req_alu_add      => agu_req_alu_add     ,
  agu_req_alu_and      => agu_req_alu_and     ,
  agu_req_alu_or       => agu_req_alu_or      ,
  agu_req_alu_xor      => agu_req_alu_xor     ,
  agu_req_alu_max      => agu_req_alu_max     ,
  agu_req_alu_min      => agu_req_alu_min     ,
  agu_req_alu_maxu     => agu_req_alu_maxu    ,
  agu_req_alu_minu     => agu_req_alu_minu    ,
  agu_req_alu_res      => agu_req_alu_res     ,
                                  
  agu_sbf_0_ena        => agu_sbf_0_ena       ,
  agu_sbf_0_nxt        => agu_sbf_0_nxt       ,
  agu_sbf_0_r          => agu_sbf_0_r         ,
 
  agu_sbf_1_ena        => agu_sbf_1_ena       ,
  agu_sbf_1_nxt        => agu_sbf_1_nxt       ,
  agu_sbf_1_r          => agu_sbf_1_r         ,
     
  clk                  => clk,
  rst_n                => rst_n
  );

  -- Instantiate the regular ALU module
  alu_i_rs1  <= (E203_XLEN         -1 downto 0 => alu_op) and i_rs1;
  alu_i_rs2  <= (E203_XLEN         -1 downto 0 => alu_op) and i_rs2;
  alu_i_imm  <= (E203_XLEN         -1 downto 0 => alu_op) and i_imm;
  alu_i_info <= (E203_DECINFO_WIDTH-1 downto 0 => alu_op) and i_info;  
  alu_i_pc   <= (E203_PC_SIZE      -1 downto 0 => alu_op) and i_pc;  

  u_e203_exu_alu_rglr: component e203_exu_alu_rglr port map(
  alu_i_valid      => alu_i_valid     ,
  alu_i_ready      => alu_i_ready     ,
  alu_i_rs1        => alu_i_rs1       ,
  alu_i_rs2        => alu_i_rs2       ,
  alu_i_info       => alu_i_info(E203_DECINFO_ALU_WIDTH-1 downto 0),
  alu_i_imm        => alu_i_imm       ,
  alu_i_pc         => alu_i_pc        ,

  alu_o_valid      => alu_o_valid     ,
  alu_o_ready      => alu_o_ready     ,
  alu_o_wbck_wdat  => alu_o_wbck_wdat ,
  alu_o_wbck_err   => alu_o_wbck_err  ,
  alu_o_cmt_ecall  => alu_o_cmt_ecall ,
  alu_o_cmt_ebreak => alu_o_cmt_ebreak,
  alu_o_cmt_wfi    => alu_o_cmt_wfi   ,

  alu_req_alu_add  => alu_req_alu_add ,
  alu_req_alu_sub  => alu_req_alu_sub ,
  alu_req_alu_xor  => alu_req_alu_xor ,
  alu_req_alu_sll  => alu_req_alu_sll ,
  alu_req_alu_srl  => alu_req_alu_srl ,
  alu_req_alu_sra  => alu_req_alu_sra ,
  alu_req_alu_or   => alu_req_alu_or  ,
  alu_req_alu_and  => alu_req_alu_and ,
  alu_req_alu_slt  => alu_req_alu_slt ,
  alu_req_alu_sltu => alu_req_alu_sltu,
  alu_req_alu_lui  => alu_req_alu_lui ,
  alu_req_alu_op1  => alu_req_alu_op1 ,
  alu_req_alu_op2  => alu_req_alu_op2 ,
  alu_req_alu_res  => alu_req_alu_res ,

  clk              => clk,
  rst_n            => rst_n 
  );

 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  -- Instantiate the MULDIV module
  mdv_i_rs1  <= (E203_XLEN         -1 downto 0 => mdv_op) and i_rs1;
  mdv_i_rs2  <= (E203_XLEN         -1 downto 0 => mdv_op) and i_rs2;
  mdv_i_imm  <= (E203_XLEN         -1 downto 0 => mdv_op) and i_imm;
  mdv_i_info <= (E203_DECINFO_WIDTH-1 downto 0 => mdv_op) and i_info;  
  mdv_i_itag <= (E203_ITAG_WIDTH   -1 downto 0 => mdv_op) and i_itag;  

  u_e203_exu_alu_muldiv: component e203_exu_alu_muldiv port map(
  mdv_nob2b          => mdv_nob2b      ,

  muldiv_i_valid     => mdv_i_valid    ,
  muldiv_i_ready     => mdv_i_ready    ,
                    
  muldiv_i_rs1       => mdv_i_rs1      ,
  muldiv_i_rs2       => mdv_i_rs2      ,
  muldiv_i_imm       => mdv_i_imm      ,
  muldiv_i_info      => mdv_i_info(E203_DECINFO_MULDIV_WIDTH-1 downto 0),
  muldiv_i_longpipe  => mdv_i_longpipe ,
  muldiv_i_itag      => mdv_i_itag     ,
                     
  flush_pulse        => flush_pulse    ,

  muldiv_o_valid     => mdv_o_valid    ,
  muldiv_o_ready     => mdv_o_ready    ,
  muldiv_o_wbck_wdat => mdv_o_wbck_wdat,
  muldiv_o_wbck_err  => mdv_o_wbck_err ,

  muldiv_req_alu_op1 => muldiv_req_alu_op1,
  muldiv_req_alu_op2 => muldiv_req_alu_op2,
  muldiv_req_alu_add => muldiv_req_alu_add,
  muldiv_req_alu_sub => muldiv_req_alu_sub,
  muldiv_req_alu_res => muldiv_req_alu_res,
      
  muldiv_sbf_0_ena   => muldiv_sbf_0_ena  ,
  muldiv_sbf_0_nxt   => muldiv_sbf_0_nxt  ,
  muldiv_sbf_0_r     => muldiv_sbf_0_r    ,
     
  muldiv_sbf_1_ena   => muldiv_sbf_1_ena  ,
  muldiv_sbf_1_nxt   => muldiv_sbf_1_nxt  ,
  muldiv_sbf_1_r     => muldiv_sbf_1_r    ,

  clk                => clk               ,
  rst_n              => rst_n              
  );
`end if

  -- Instantiate the Shared Datapath module
  alu_req_alu <= alu_op and i_rdwen; -- Regular ALU only req datapath when it need to write-back
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_req_alu <= mdv_op; -- Since MULDIV have no point to let rd=0, so always need ALU datapath
 `end if
  bjp_req_alu <= bjp_op; -- Since BJP may not write-back, but still need ALU datapath
  agu_req_alu <= agu_op; -- Since AGU may have some other features, so always need ALU datapath

  u_e203_exu_alu_dpath: component e203_exu_alu_dpath port map(
  alu_req_alu         => alu_req_alu        ,    
  alu_req_alu_add     => alu_req_alu_add    ,
  alu_req_alu_sub     => alu_req_alu_sub    ,
  alu_req_alu_xor     => alu_req_alu_xor    ,
  alu_req_alu_sll     => alu_req_alu_sll    ,
  alu_req_alu_srl     => alu_req_alu_srl    ,
  alu_req_alu_sra     => alu_req_alu_sra    ,
  alu_req_alu_or      => alu_req_alu_or     ,
  alu_req_alu_and     => alu_req_alu_and    ,
  alu_req_alu_slt     => alu_req_alu_slt    ,
  alu_req_alu_sltu    => alu_req_alu_sltu   ,
  alu_req_alu_lui     => alu_req_alu_lui    ,
  alu_req_alu_op1     => alu_req_alu_op1    ,
  alu_req_alu_op2     => alu_req_alu_op2    ,
  alu_req_alu_res     => alu_req_alu_res    ,
      
  bjp_req_alu         => bjp_req_alu        ,
  bjp_req_alu_op1     => bjp_req_alu_op1    ,
  bjp_req_alu_op2     => bjp_req_alu_op2    ,
  bjp_req_alu_cmp_eq  => bjp_req_alu_cmp_eq ,
  bjp_req_alu_cmp_ne  => bjp_req_alu_cmp_ne ,
  bjp_req_alu_cmp_lt  => bjp_req_alu_cmp_lt ,
  bjp_req_alu_cmp_gt  => bjp_req_alu_cmp_gt ,
  bjp_req_alu_cmp_ltu => bjp_req_alu_cmp_ltu,
  bjp_req_alu_cmp_gtu => bjp_req_alu_cmp_gtu,
  bjp_req_alu_add     => bjp_req_alu_add    ,
  bjp_req_alu_cmp_res => bjp_req_alu_cmp_res,
  bjp_req_alu_add_res => bjp_req_alu_add_res,
        
  agu_req_alu         => agu_req_alu        ,
  agu_req_alu_op1     => agu_req_alu_op1    ,
  agu_req_alu_op2     => agu_req_alu_op2    ,
  agu_req_alu_swap    => agu_req_alu_swap   ,
  agu_req_alu_add     => agu_req_alu_add    ,
  agu_req_alu_and     => agu_req_alu_and    ,
  agu_req_alu_or      => agu_req_alu_or     ,
  agu_req_alu_xor     => agu_req_alu_xor    ,
  agu_req_alu_max     => agu_req_alu_max    ,
  agu_req_alu_min     => agu_req_alu_min    ,
  agu_req_alu_maxu    => agu_req_alu_maxu   ,
  agu_req_alu_minu    => agu_req_alu_minu   ,
  agu_req_alu_res     => agu_req_alu_res    ,
        
  agu_sbf_0_ena       => agu_sbf_0_ena      ,
  agu_sbf_0_nxt       => agu_sbf_0_nxt      ,
  agu_sbf_0_r         => agu_sbf_0_r        ,
       
  agu_sbf_1_ena       => agu_sbf_1_ena      ,
  agu_sbf_1_nxt       => agu_sbf_1_nxt      ,
  agu_sbf_1_r         => agu_sbf_1_r        ,      

 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_req_alu      => muldiv_req_alu     ,

  muldiv_req_alu_op1  => muldiv_req_alu_op1 ,
  muldiv_req_alu_op2  => muldiv_req_alu_op2 ,
  muldiv_req_alu_add  => muldiv_req_alu_add ,
  muldiv_req_alu_sub  => muldiv_req_alu_sub ,
  muldiv_req_alu_res  => muldiv_req_alu_res ,
      
  muldiv_sbf_0_ena    => muldiv_sbf_0_ena   ,
  muldiv_sbf_0_nxt    => muldiv_sbf_0_nxt   ,
  muldiv_sbf_0_r      => muldiv_sbf_0_r     ,
     
  muldiv_sbf_1_ena    => muldiv_sbf_1_ena   ,
  muldiv_sbf_1_nxt    => muldiv_sbf_1_nxt   ,
  muldiv_sbf_1_r      => muldiv_sbf_1_r     ,
 `end if

  clk                 => clk                ,
  rst_n               => rst_n          
  );

  ifu_excp_i_ready <= ifu_excp_o_ready;
  ifu_excp_o_valid <= ifu_excp_i_valid;
  ifu_excp_o_wbck_wdat <= (E203_XLEN-1 downto 0 => '0');
  ifu_excp_o_wbck_err  <= '1'; -- IFU illegal instruction always treat as error

  
  -- Aribtrate the Result and generate output interfaces
  o_sel_ifu_excp <= ifu_excp_op;
  o_sel_alu      <= alu_op;
  o_sel_bjp      <= bjp_op;
  o_sel_csr      <= csr_op;
  o_sel_agu      <= agu_op;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  o_sel_mdv <= mdv_op;
 `end if
 `if E203_HAS_NICE = "TRUE" then
  o_sel_nice <= nice_op;
 `end if

  o_valid <= (o_sel_alu      and alu_o_valid     )
          or (o_sel_bjp      and bjp_o_valid     )
          or (o_sel_csr      and csr_o_valid     )
          or (o_sel_agu      and agu_o_valid     )
          or (o_sel_ifu_excp and ifu_excp_o_valid)
         `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
          or (o_sel_mdv      and mdv_o_valid     )
         `end if
         `if E203_HAS_NICE = "TRUE" then
          or (o_sel_nice     and nice_o_valid    )
         `end if
                 ;

  ifu_excp_o_ready <= o_sel_ifu_excp and o_ready;
  alu_o_ready      <= o_sel_alu      and o_ready;
  agu_o_ready      <= o_sel_agu      and o_ready;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  mdv_o_ready      <= o_sel_mdv and o_ready;
 `end if
  bjp_o_ready      <= o_sel_bjp and o_ready;
  csr_o_ready      <= o_sel_csr and o_ready;
 `if E203_HAS_NICE = "TRUE" then
  nice_o_ready     <= o_sel_nice and o_ready;
 `end if

  wbck_o_wdat <= 
                 ((E203_XLEN-1 downto 0 => o_sel_alu) and alu_o_wbck_wdat)
              or ((E203_XLEN-1 downto 0 => o_sel_bjp) and bjp_o_wbck_wdat)
              or ((E203_XLEN-1 downto 0 => o_sel_csr) and csr_o_wbck_wdat)
              or ((E203_XLEN-1 downto 0 => o_sel_agu) and agu_o_wbck_wdat)
             `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
              or ((E203_XLEN-1 downto 0 => o_sel_mdv) and mdv_o_wbck_wdat)
             `end if
              or ((E203_XLEN-1 downto 0 => o_sel_ifu_excp) and ifu_excp_o_wbck_wdat)
                 ;

  wbck_o_rdidx <= i_rdidx; 

  wbck_o_rdwen <= i_rdwen;
                  
  wbck_o_err <= 
                (o_sel_alu and alu_o_wbck_err)
             or (o_sel_bjp and bjp_o_wbck_err)
             or (o_sel_csr and csr_o_wbck_err)
             or (o_sel_agu and agu_o_wbck_err)
            `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
             or (o_sel_mdv and mdv_o_wbck_err)
            `end if
             or (o_sel_ifu_excp and ifu_excp_o_wbck_err)
            `if E203_HAS_NICE = "TRUE" then
             or (o_sel_nice and nice_o_wbck_err)
            `end if
                ;

  --  Each Instruction need to commit or write-back
  --   * The write-back only needed when the unit need to write-back
  --     the result (need to write RD), and it is not a long-pipe uop
  --     (need to be write back by its long-pipe write-back, not here)
  --   * Each instruction need to be commited 
  o_need_wbck <= wbck_o_rdwen and (not i_longpipe) and (not wbck_o_err);
  o_need_cmt  <= '1';
  
  is_cmt_oready  <= cmt_o_ready when o_need_cmt = '1' else '1';
  is_wbck_oready <= wbck_o_ready when o_need_wbck = '1' else '1';  
  o_ready <= is_cmt_oready and wbck_o_ready; 

  wbck_o_valid <= o_need_wbck and o_valid and is_cmt_oready;
  cmt_o_valid  <= o_need_cmt  and o_valid and is_wbck_oready;
  
  --  The commint interface have some special signals
  cmt_o_instr   <= i_instr;  
  cmt_o_pc      <= i_pc;  
  cmt_o_imm     <= i_imm;
  cmt_o_rv32    <= i_info(E203_DECINFO_RV32'right); 

  -- The cmt_o_pc_vld is used by the commit stage to check
  -- if current instruction is outputing a valid current PC
  --   to guarante the commit to flush pipeline safely, this
  --   vld only be asserted when:
  --     * There is a valid instruction here
  --       otherwise, the commit stage may use wrong PC
  --       value to stored in DPC or EPC
  cmt_o_pc_vld <=
  -- Otherwise, just use the i_pc_vld
                  i_pc_vld;

  cmt_o_misalgn     <= (o_sel_agu and agu_o_cmt_misalgn) ;
  cmt_o_ld          <= (o_sel_agu and agu_o_cmt_ld)      ;
  cmt_o_badaddr     <= ((E203_ADDR_SIZE-1 downto 0 => o_sel_agu) and agu_o_cmt_badaddr);
  cmt_o_buserr      <= o_sel_agu and agu_o_cmt_buserr;
  cmt_o_stamo       <= o_sel_agu and agu_o_cmt_stamo ;

  cmt_o_bjp         <= o_sel_bjp and bjp_o_cmt_bjp;
  cmt_o_mret        <= o_sel_bjp and bjp_o_cmt_mret;
  cmt_o_dret        <= o_sel_bjp and bjp_o_cmt_dret;
  cmt_o_bjp_prdt    <= o_sel_bjp and bjp_o_cmt_prdt;
  cmt_o_bjp_rslv    <= o_sel_bjp and bjp_o_cmt_rslv;
  cmt_o_fencei      <= o_sel_bjp and bjp_o_cmt_fencei;

  cmt_o_ecall       <= o_sel_alu and alu_o_cmt_ecall;
  cmt_o_ebreak      <= o_sel_alu and alu_o_cmt_ebreak;
  cmt_o_wfi         <= o_sel_alu and alu_o_cmt_wfi;
  cmt_o_ifu_misalgn <= i_misalgn;
  cmt_o_ifu_buserr  <= i_buserr;
  cmt_o_ifu_ilegl   <= i_ilegl or (o_sel_csr and csr_access_ilgl);

end impl;