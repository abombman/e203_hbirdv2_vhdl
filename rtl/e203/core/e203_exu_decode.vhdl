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
--   The decode module to decode the instruction details. 
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_decode is 
  port ( -- The IR stage to Decoder
  	     i_instr:           in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
  	     i_pc:              in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     i_prdt_taken:      in std_logic;
  	     i_misalgn:         in std_logic;  -- The fetch misalign
  	     i_buserr:          in std_logic;  -- The fetch bus error
  	     i_muldiv_b2b:      in std_logic;  -- The back2back case for mul/div
         
         dbg_mode:          in std_logic;  
         
         -- The Decoded Info-Bus
  	     dec_rs1x0:        out std_logic;
  	     dec_rs2x0:        out std_logic;
  	     dec_rs1en:        out std_logic;
  	     dec_rs2en:        out std_logic;
  	     dec_rdwen:        out std_logic;
  	     dec_rs1idx:       out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec_rs2idx:       out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec_rdidx:        out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec_info:         out std_logic_vector(E203_DECINFO_WIDTH-1 downto 0);
         dec_imm:          out std_logic_vector(E203_XLEN-1 downto 0);
         dec_pc:           out std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     dec_misalgn:      out std_logic;
  	     dec_buserr:       out std_logic;
  	     dec_ilegl:        out std_logic;

  	     `if E203_HAS_NICE = "TRUE" then
  	     -- nice decode
         nice_xs_off:         in std_logic;
         dec_nice:            out std_logic;
  	     nice_cmt_off_ilgl_o: out std_logic;
         `end if

  	     dec_mulhsu:          out std_logic;
  	     dec_mul:             out std_logic;
  	     dec_div:             out std_logic;
  	     dec_rem:             out std_logic;
  	     dec_divu:            out std_logic;
         dec_remu:            out std_logic;

  	     dec_rv32:            out std_logic;
  	     dec_bjp:             out std_logic;
  	     dec_jal:             out std_logic;
  	     dec_jalr:            out std_logic;
  	     dec_bxx:             out std_logic;

  	     dec_jalr_rs1idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec_bjp_imm:         out std_logic_vector(E203_XLEN-1 downto 0)
  );
end e203_exu_decode;

architecture impl of e203_exu_decode is 
  signal rv32_instr:    std_ulogic_vector(32-1 downto 0);
  signal rv16_instr:    std_ulogic_vector(16-1 downto 0);
  signal opcode:        std_ulogic_vector(6 downto 0);

  signal opcode_1_0_00: std_ulogic;
  signal opcode_1_0_01: std_ulogic;
  signal opcode_1_0_10: std_ulogic;
  signal opcode_1_0_11: std_ulogic;

  signal rv32:          std_ulogic;

  signal rv32_rd:       std_ulogic_vector(4 downto 0);
  signal rv32_func3:    std_ulogic_vector(2 downto 0);
  signal rv32_rs1:      std_ulogic_vector(4 downto 0);
  signal rv32_rs2:      std_ulogic_vector(4 downto 0);
  signal rv32_func7:    std_ulogic_vector(6 downto 0);

  signal rv16_rd:       std_ulogic_vector(4 downto 0);
  signal rv16_rs1:      std_ulogic_vector(4 downto 0);
  signal rv16_rs2:      std_ulogic_vector(4 downto 0);

  signal rv16_rdd:      std_ulogic_vector(4 downto 0);
  signal rv16_rss1:     std_ulogic_vector(4 downto 0);
  signal rv16_rss2:     std_ulogic_vector(4 downto 0);
  signal rv16_func3:    std_ulogic_vector(2 downto 0);

  signal opcode_4_2_000     :std_ulogic;
  signal opcode_4_2_001     :std_ulogic;
  signal opcode_4_2_010     :std_ulogic;
  signal opcode_4_2_011     :std_ulogic;
  signal opcode_4_2_100     :std_ulogic;
  signal opcode_4_2_101     :std_ulogic;
  signal opcode_4_2_110     :std_ulogic;
  signal opcode_4_2_111     :std_ulogic;
  signal opcode_6_5_00      :std_ulogic;
  signal opcode_6_5_01      :std_ulogic;
  signal opcode_6_5_10      :std_ulogic;
  signal opcode_6_5_11      :std_ulogic;

  signal rv32_func3_000     :std_ulogic;
  signal rv32_func3_001     :std_ulogic;
  signal rv32_func3_010     :std_ulogic;
  signal rv32_func3_011     :std_ulogic;
  signal rv32_func3_100     :std_ulogic;
  signal rv32_func3_101     :std_ulogic;
  signal rv32_func3_110     :std_ulogic;
  signal rv32_func3_111     :std_ulogic;

  signal rv16_func3_000     :std_ulogic;
  signal rv16_func3_001     :std_ulogic;
  signal rv16_func3_010     :std_ulogic;
  signal rv16_func3_011     :std_ulogic;
  signal rv16_func3_100     :std_ulogic;
  signal rv16_func3_101     :std_ulogic;
  signal rv16_func3_110     :std_ulogic;
  signal rv16_func3_111     :std_ulogic;

  signal rv32_func7_0000000 :std_ulogic;
  signal rv32_func7_0100000 :std_ulogic;
  signal rv32_func7_0000001 :std_ulogic;
  signal rv32_func7_0000101 :std_ulogic;
  signal rv32_func7_0001001 :std_ulogic;
  signal rv32_func7_0001101 :std_ulogic;
  signal rv32_func7_0010101 :std_ulogic;
  signal rv32_func7_0100001 :std_ulogic;
  signal rv32_func7_0010001 :std_ulogic;
  signal rv32_func7_0101101 :std_ulogic;
  signal rv32_func7_1111111 :std_ulogic;
  signal rv32_func7_0000100 :std_ulogic;
  signal rv32_func7_0001000 :std_ulogic;
  signal rv32_func7_0001100 :std_ulogic;
  signal rv32_func7_0101100 :std_ulogic;
  signal rv32_func7_0010000 :std_ulogic;
  signal rv32_func7_0010100 :std_ulogic;
  signal rv32_func7_1100000 :std_ulogic;
  signal rv32_func7_1110000 :std_ulogic;
  signal rv32_func7_1010000 :std_ulogic;
  signal rv32_func7_1101000 :std_ulogic;
  signal rv32_func7_1111000 :std_ulogic;
  signal rv32_func7_1010001 :std_ulogic;
  signal rv32_func7_1110001 :std_ulogic;
  signal rv32_func7_1100001 :std_ulogic;
  signal rv32_func7_1101001 :std_ulogic;

  signal rv32_rs1_x0        :std_ulogic;
  signal rv32_rs2_x0        :std_ulogic;
  signal rv32_rs2_x1        :std_ulogic;
  signal rv32_rd_x0         :std_ulogic;
  signal rv32_rd_x2         :std_ulogic;

  signal rv16_rs1_x0        :std_ulogic;
  signal rv16_rs2_x0        :std_ulogic;
  signal rv16_rd_x0         :std_ulogic;
  signal rv16_rd_x2         :std_ulogic;

  signal rv32_rs1_x31       :std_ulogic;
  signal rv32_rs2_x31       :std_ulogic;
  signal rv32_rd_x31        :std_ulogic;

  signal rv32_load          :std_ulogic;
  signal rv32_store         :std_ulogic;
  signal rv32_madd          :std_ulogic;
  signal rv32_branch        :std_ulogic;

  signal rv32_load_fp       :std_ulogic;
  signal rv32_store_fp      :std_ulogic;
  signal rv32_msub          :std_ulogic;
  signal rv32_jalr          :std_ulogic;

  signal rv32_custom0       :std_ulogic;
  signal rv32_custom1       :std_ulogic;
  signal rv32_nmsub         :std_ulogic;
  signal rv32_resved0       :std_ulogic;
  signal rv32_miscmem       :std_ulogic;

  signal rv32_amo           :std_ulogic;

  signal rv32_nmadd         :std_ulogic; 
  signal rv32_jal           :std_ulogic; 

  signal rv32_op_imm        :std_ulogic; 
  signal rv32_op            :std_ulogic; 
  signal rv32_op_fp         :std_ulogic; 
  signal rv32_system        :std_ulogic; 

  signal rv32_auipc         :std_ulogic; 
  signal rv32_lui           :std_ulogic; 
  signal rv32_resved1       :std_ulogic; 
  signal rv32_resved2       :std_ulogic; 

  signal rv32_op_imm_32     :std_ulogic; 
  signal rv32_op_32         :std_ulogic; 
  signal rv32_custom2       :std_ulogic; 
  signal rv32_custom3       :std_ulogic; 

  signal rv16_addi4spn      :std_ulogic;
  signal rv16_lw            :std_ulogic;
  signal rv16_sw            :std_ulogic;

  signal rv16_addi          :std_ulogic;
  signal rv16_jal           :std_ulogic;
  signal rv16_li            :std_ulogic;
  signal rv16_lui_addi16sp  :std_ulogic;
  signal rv16_miscalu       :std_ulogic;
  signal rv16_j             :std_ulogic;
  signal rv16_beqz          :std_ulogic;
  signal rv16_bnez          :std_ulogic;

  signal rv16_slli          :std_ulogic;
  signal rv16_lwsp          :std_ulogic;
  signal rv16_jalr_mv_add   :std_ulogic;
  signal rv16_swsp          :std_ulogic;

  `if E203_HAS_FPU = "FALSE" then
  constant rv16_flw         :std_ulogic:= '0';
  constant rv16_fld         :std_ulogic:= '0';
  constant rv16_fsw         :std_ulogic:= '0';
  constant rv16_fsd         :std_ulogic:= '0';
  constant rv16_fldsp       :std_ulogic:= '0';
  constant rv16_flwsp       :std_ulogic:= '0';
  constant rv16_fsdsp       :std_ulogic:= '0';
  constant rv16_fswsp       :std_ulogic:= '0';
  `end if

  signal rv16_lwsp_ilgl      :std_ulogic;

  signal rv16_nop            :std_ulogic;

  signal rv16_srli           :std_ulogic;
  signal rv16_srai           :std_ulogic;
  signal rv16_andi           :std_ulogic;

  signal rv16_instr_12_is0   :std_ulogic;
  signal rv16_instr_6_2_is0s :std_ulogic;

  signal rv16_sxxi_shamt_legl:std_ulogic;
  signal rv16_sxxi_shamt_ilgl:std_ulogic;

  signal rv16_addi16sp       :std_ulogic;
  signal rv16_lui            :std_ulogic;

  signal rv16_li_ilgl        :std_ulogic;

  signal rv16_lui_ilgl       :std_ulogic;

  signal rv16_li_lui_ilgl    :std_ulogic;

  signal rv16_addi4spn_ilgl  :std_ulogic;
  signal rv16_addi16sp_ilgl  :std_ulogic;

  signal rv16_subxororand    :std_ulogic;
  signal rv16_sub            :std_ulogic;
  signal rv16_xor            :std_ulogic;
  signal rv16_or             :std_ulogic;
  signal rv16_and            :std_ulogic;
  signal rv16_jr             :std_ulogic;              
  signal rv16_mv             :std_ulogic;    
  signal rv16_ebreak         :std_ulogic;
  signal rv16_jalr           :std_ulogic;
  signal rv16_add            :std_ulogic;

  `if  E203_HAS_NICE = "TRUE" then
  signal nice_need_rs1:       std_ulogic;
  signal nice_need_rs2:       std_ulogic;
  signal nice_need_rd :       std_ulogic;
  signal nice_instr   :       std_ulogic_vector(31 downto 5);
  signal nice_op:             std_ulogic;
  signal nice_info_bus:       std_ulogic_vector(E203_DECINFO_NICE_WIDTH-1 downto 0);
  `end if
  signal is_nice_need_rs1:    std_ulogic;
  signal is_nice_need_rs2:    std_ulogic;
  signal is_nice_need_rd :    std_ulogic;

  -- Branch Instructions
  signal rv32_beq :           std_ulogic;
  signal rv32_bne :           std_ulogic;
  signal rv32_blt :           std_ulogic;
  signal rv32_bgt :           std_ulogic;
  signal rv32_bltu:           std_ulogic;
  signal rv32_bgtu:           std_ulogic;

  -- System Instructions
  signal rv32_ecall :         std_ulogic;
  signal rv32_ebreak:         std_ulogic;
  signal rv32_mret  :         std_ulogic;
  signal rv32_dret  :         std_ulogic;
  signal rv32_wfi   :         std_ulogic;
  
  signal rv32_csrrw :         std_ulogic; 
  signal rv32_csrrs :         std_ulogic; 
  signal rv32_csrrc :         std_ulogic; 
  signal rv32_csrrwi:         std_ulogic; 
  signal rv32_csrrsi:         std_ulogic; 
  signal rv32_csrrci:         std_ulogic; 
  signal rv32_dret_ilgl:      std_ulogic;
  signal rv32_ecall_ebreak_ret_wfi: std_ulogic;
  signal rv32_csr:            std_ulogic; 

  signal rv32_fence:          std_ulogic;
  signal rv32_fence_i:        std_ulogic;
  signal rv32_fence_fencei:   std_ulogic;
  signal bjp_op:              std_ulogic;
  signal bjp_info_bus:        std_ulogic_vector(E203_DECINFO_BJP_WIDTH-1 downto 0);

  -- ALU Instructions
  signal rv32_addi :          std_ulogic;
  signal rv32_slti :          std_ulogic;
  signal rv32_sltiu:          std_ulogic;
  signal rv32_xori :          std_ulogic;
  signal rv32_ori  :          std_ulogic;
  signal rv32_andi :          std_ulogic;

  signal rv32_slli:           std_ulogic;
  signal rv32_srli:           std_ulogic;
  signal rv32_srai:           std_ulogic;

  signal rv32_sxxi_shamt_legl:std_ulogic;
  signal rv32_sxxi_shamt_ilgl:std_ulogic;

  signal rv32_add :           std_ulogic;
  signal rv32_sub :           std_ulogic;
  signal rv32_sll :           std_ulogic;
  signal rv32_slt :           std_ulogic;
  signal rv32_sltu:           std_ulogic;
  signal rv32_xor :           std_ulogic;
  signal rv32_srl :           std_ulogic;
  signal rv32_sra :           std_ulogic;
  signal rv32_or  :           std_ulogic;
  signal rv32_and :           std_ulogic;

  signal rv32_nop    :        std_ulogic;
  signal ecall_ebreak:        std_ulogic;

  signal alu_op:              std_ulogic;
  signal need_imm:            std_ulogic;
  signal alu_info_bus:        std_ulogic_vector(E203_DECINFO_ALU_WIDTH-1 downto 0);

  signal csr_op:              std_ulogic;
  signal csr_info_bus:        std_ulogic_vector(E203_DECINFO_CSR_WIDTH-1 downto 0);

  signal rv32_mul   :         std_ulogic;
  signal rv32_mulh  :         std_ulogic;
  signal rv32_mulhsu:         std_ulogic;
  signal rv32_mulhu :         std_ulogic;
  signal rv32_div   :         std_ulogic;
  signal rv32_divu  :         std_ulogic;
  signal rv32_rem   :         std_ulogic;
  signal rv32_remu  :         std_ulogic;

  `if E203_SUPPORT_MULDIV = "TRUE" then
  signal muldiv_op:           std_ulogic;
  `end if
  `if E203_SUPPORT_MULDIV = "FALSE" then
  signal muldiv_op:           std_ulogic;
  `end if

  signal muldiv_info_bus:        std_ulogic_vector(E203_DECINFO_CSR_WIDTH-1 downto 0);

  -- Load/Store Instructions
  signal rv32_lb :             std_ulogic;
  signal rv32_lh :             std_ulogic;
  signal rv32_lw :             std_ulogic;
  signal rv32_lbu:             std_ulogic;
  signal rv32_lhu:             std_ulogic;

  signal rv32_sb :             std_ulogic;
  signal rv32_sh :             std_ulogic;
  signal rv32_sw :             std_ulogic;

  -- Atomic Instructions
  `if E203_SUPPORT_AMO = "TRUE" then
  signal rv32_lr_w     :       std_ulogic;
  signal rv32_sc_w     :       std_ulogic;
  signal rv32_amoswap_w:       std_ulogic;
  signal rv32_amoadd_w :       std_ulogic;
  signal rv32_amoxor_w :       std_ulogic;
  signal rv32_amoand_w :       std_ulogic;
  signal rv32_amoor_w  :       std_ulogic;
  signal rv32_amomin_w :       std_ulogic;
  signal rv32_amomax_w :       std_ulogic;
  signal rv32_amominu_w:       std_ulogic;
  signal rv32_amomaxu_w:       std_ulogic;
  `end if
  `if E203_SUPPORT_AMO = "FALSE" then
  constant rv32_lr_w     :     std_ulogic:= '0';
  constant rv32_sc_w     :     std_ulogic:= '0';
  constant rv32_amoswap_w:     std_ulogic:= '0';
  constant rv32_amoadd_w :     std_ulogic:= '0';
  constant rv32_amoxor_w :     std_ulogic:= '0';
  constant rv32_amoand_w :     std_ulogic:= '0';
  constant rv32_amoor_w  :     std_ulogic:= '0';
  constant rv32_amomin_w :     std_ulogic:= '0';
  constant rv32_amomax_w :     std_ulogic:= '0';
  constant rv32_amominu_w:     std_ulogic:= '0';
  constant rv32_amomaxu_w:     std_ulogic:= '0';
  `end if
  signal amoldst_op:           std_ulogic;
  signal lsu_info_size:        std_ulogic_vector(1 downto 0);
  signal lsu_info_usign:       std_ulogic;
  signal agu_info_bus:         std_ulogic_vector(E203_DECINFO_AGU_WIDTH-1 downto 0);
  
  signal rv32_all0s_ilgl:      std_ulogic;
  signal rv32_all1s_ilgl:      std_ulogic;
  signal rv16_all0s_ilgl:      std_ulogic;
  signal rv16_all1s_ilgl:      std_ulogic;
  signal rv_all0s1s_ilgl:      std_ulogic;

  signal rv32_need_rd:         std_ulogic;
  signal rv32_need_rs1:        std_ulogic;
  signal rv32_need_rs2:        std_ulogic;

  signal rv32_i_imm:           std_ulogic_vector(32-1 downto 0);
  signal rv32_s_imm:           std_ulogic_vector(32-1 downto 0);
  signal rv32_b_imm:           std_ulogic_vector(32-1 downto 0);
  signal rv32_u_imm:           std_ulogic_vector(32-1 downto 0);
  signal rv32_j_imm:           std_ulogic_vector(32-1 downto 0);
  signal rv32_jalr_imm:        std_ulogic_vector(32-1 downto 0);
  signal rv32_jal_imm:         std_ulogic_vector(32-1 downto 0);
  signal rv32_bxx_imm:         std_ulogic_vector(32-1 downto 0);

  signal rv32_imm_sel_i:       std_ulogic;
  signal rv32_imm_sel_jalr:    std_ulogic;
  signal rv32_imm_sel_u:       std_ulogic;
  signal rv32_imm_sel_j:       std_ulogic;
  signal rv32_imm_sel_jal:     std_ulogic;
  signal rv32_imm_sel_b:       std_ulogic;
  signal rv32_imm_sel_bxx:     std_ulogic;
  signal rv32_imm_sel_s:       std_ulogic;

  signal rv16_imm_sel_cis:     std_ulogic;
  signal rv16_imm_sel_cili:    std_ulogic;
  signal rv16_imm_sel_cilui:   std_ulogic;
  signal rv16_imm_sel_ci16sp:  std_ulogic;
  signal rv16_imm_sel_css:     std_ulogic;
  signal rv16_imm_sel_ciw:     std_ulogic;
  signal rv16_imm_sel_cl:      std_ulogic;
  signal rv16_imm_sel_cs:      std_ulogic;
  signal rv16_imm_sel_cb:      std_ulogic;
  signal rv16_imm_sel_cj:      std_ulogic;
  signal rv32_need_imm:        std_ulogic;
  signal rv16_need_imm:        std_ulogic;

  signal rv16_cis_imm:         std_ulogic_vector(32-1 downto 0);
  signal rv16_cis_d_imm:       std_ulogic_vector(32-1 downto 0);
  signal rv16_cili_imm:        std_ulogic_vector(32-1 downto 0);
  signal rv16_cilui_imm:       std_ulogic_vector(32-1 downto 0);
  signal rv16_ci16sp_imm:      std_ulogic_vector(32-1 downto 0);
  signal rv16_css_imm:         std_ulogic_vector(32-1 downto 0);
  signal rv16_css_d_imm:       std_ulogic_vector(32-1 downto 0);
  signal rv16_ciw_imm:         std_ulogic_vector(32-1 downto 0);
  signal rv16_cl_imm:          std_ulogic_vector(32-1 downto 0);
  signal rv16_cl_d_imm:        std_ulogic_vector(32-1 downto 0);
  signal rv16_cs_imm:          std_ulogic_vector(32-1 downto 0);
  signal rv16_cs_d_imm:        std_ulogic_vector(32-1 downto 0);
  signal rv16_cb_imm:          std_ulogic_vector(32-1 downto 0);
  signal rv16_bxx_imm:         std_ulogic_vector(32-1 downto 0);
  signal rv16_cj_imm:          std_ulogic_vector(32-1 downto 0);
  signal rv16_jjal_imm:        std_ulogic_vector(32-1 downto 0);
  signal rv16_jrjalr_imm:      std_ulogic_vector(32-1 downto 0);
  signal rv32_load_fp_imm:     std_ulogic_vector(32-1 downto 0);
  signal rv32_store_fp_imm:    std_ulogic_vector(32-1 downto 0);
  signal rv32_imm:             std_ulogic_vector(32-1 downto 0);
  signal rv16_imm:             std_ulogic_vector(32-1 downto 0);
  
  signal legl_ops:             std_ulogic;
  signal rv16_format_cr:       std_ulogic;
  signal rv16_format_ci:       std_ulogic;
  signal rv16_format_css:      std_ulogic;
  signal rv16_format_ciw:      std_ulogic;
  signal rv16_format_cl:       std_ulogic;
  signal rv16_format_cs:       std_ulogic;
  signal rv16_format_cb:       std_ulogic;
  signal rv16_format_cj:       std_ulogic;
  signal rv16_need_cr_rs1:     std_ulogic;
  signal rv16_need_cr_rs2:     std_ulogic;
  signal rv16_need_cr_rd:      std_ulogic;
  signal rv16_need_ci_rs1:     std_ulogic;
  signal rv16_need_ci_rs2:     std_ulogic;
  signal rv16_need_ci_rd:      std_ulogic;

  signal rv16_cr_rs1:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cr_rs2:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cr_rd:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ci_rs1:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ci_rs2:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ci_rd:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);

  signal rv16_need_css_rs1:    std_ulogic;
  signal rv16_need_css_rs2:    std_ulogic;
  signal rv16_need_css_rd:     std_ulogic;
  signal rv16_need_ciw_rss1:   std_ulogic;
  signal rv16_need_ciw_rss2:   std_ulogic;
  signal rv16_need_ciw_rdd:    std_ulogic;
  signal rv16_need_cl_rss1:    std_ulogic;
  signal rv16_need_cl_rss2:    std_ulogic;
  signal rv16_need_cl_rdd:     std_ulogic;
  signal rv16_need_cs_rss1:    std_ulogic;
  signal rv16_need_cs_rss2:    std_ulogic;
  signal rv16_need_cs_rdd:     std_ulogic;
  signal rv16_need_cb_rss1:    std_ulogic;
  signal rv16_need_cb_rss2:    std_ulogic;
  signal rv16_need_cb_rdd:     std_ulogic;
  signal rv16_need_cj_rss1:    std_ulogic;
  signal rv16_need_cj_rss2:    std_ulogic;
  signal rv16_need_cj_rdd:     std_ulogic;

  signal rv16_css_rs1:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_css_rs2:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_css_rd:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ciw_rss1:        std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ciw_rss2:        std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_ciw_rdd:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cl_rss1:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cl_rss2:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cl_rdd:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cs_rss1:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cs_rss2:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cs_rdd:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cb_rss1:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cb_rss2:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cb_rdd:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cj_rss1:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cj_rss2:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_cj_rdd:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);

  signal rv16_need_rs1:        std_ulogic;
  signal rv16_need_rs2:        std_ulogic;
  signal rv16_need_rd:         std_ulogic;
  signal rv16_need_rss1:       std_ulogic;
  signal rv16_need_rss2:       std_ulogic;
  signal rv16_need_rdd:        std_ulogic;
  signal rv16_rs1en:           std_ulogic;
  signal rv16_rs2en:           std_ulogic;
  signal rv16_rden:            std_ulogic;
  signal rv16_rs1idx:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_rs2idx:          std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv16_rdidx:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rv_index_ilgl:        std_ulogic;
begin 
  rv32_instr <= i_instr;
  rv16_instr <= i_instr(15 downto 0);

  opcode     <= rv32_instr(6 downto 0);

  opcode_1_0_00  <= (opcode(1 downto 0) ?= "00");
  opcode_1_0_01  <= (opcode(1 downto 0) ?= "01");
  opcode_1_0_10  <= (opcode(1 downto 0) ?= "10");
  opcode_1_0_11  <= (opcode(1 downto 0) ?= "11");

  rv32 <= (not (i_instr(4 downto 2) ?= "111")) and opcode_1_0_11;

  rv32_rd     <= rv32_instr(11 downto 7);
  rv32_func3  <= rv32_instr(14 downto 12);
  rv32_rs1    <= rv32_instr(19 downto 15);
  rv32_rs2    <= rv32_instr(24 downto 20);
  rv32_func7  <= rv32_instr(31 downto 25);

  rv16_rd     <= rv32_rd;
  rv16_rs1    <= rv16_rd; 
  rv16_rs2    <= rv32_instr(6 downto 2);

  rv16_rdd    <= "01" & rv32_instr(4 downto 2);
  rv16_rss1   <= "01" & rv32_instr(9 downto 7);
  rv16_rss2   <= rv16_rdd;

  rv16_func3  <= rv32_instr(15 downto 13);

  -- We generate the signals and reused them as much as possible to save gatecounts
  opcode_4_2_000 <= (opcode(4 downto 2) ?= "000");
  opcode_4_2_001 <= (opcode(4 downto 2) ?= "001");
  opcode_4_2_010 <= (opcode(4 downto 2) ?= "010");
  opcode_4_2_011 <= (opcode(4 downto 2) ?= "011");
  opcode_4_2_100 <= (opcode(4 downto 2) ?= "100");
  opcode_4_2_101 <= (opcode(4 downto 2) ?= "101");
  opcode_4_2_110 <= (opcode(4 downto 2) ?= "110");
  opcode_4_2_111 <= (opcode(4 downto 2) ?= "111");
  opcode_6_5_00  <= (opcode(6 downto 5) ?= "00");
  opcode_6_5_01  <= (opcode(6 downto 5) ?= "01");
  opcode_6_5_10  <= (opcode(6 downto 5) ?= "10");
  opcode_6_5_11  <= (opcode(6 downto 5) ?= "11");

  rv32_func3_000 <= (rv32_func3 ?= "000");
  rv32_func3_001 <= (rv32_func3 ?= "001");
  rv32_func3_010 <= (rv32_func3 ?= "010");
  rv32_func3_011 <= (rv32_func3 ?= "011");
  rv32_func3_100 <= (rv32_func3 ?= "100");
  rv32_func3_101 <= (rv32_func3 ?= "101");
  rv32_func3_110 <= (rv32_func3 ?= "110");
  rv32_func3_111 <= (rv32_func3 ?= "111");

  rv16_func3_000 <= (rv16_func3 ?= "000");
  rv16_func3_001 <= (rv16_func3 ?= "001");
  rv16_func3_010 <= (rv16_func3 ?= "010");
  rv16_func3_011 <= (rv16_func3 ?= "011");
  rv16_func3_100 <= (rv16_func3 ?= "100");
  rv16_func3_101 <= (rv16_func3 ?= "101");
  rv16_func3_110 <= (rv16_func3 ?= "110");
  rv16_func3_111 <= (rv16_func3 ?= "111");

  rv32_func7_0000000 <= (rv32_func7 ?= "0000000");
  rv32_func7_0100000 <= (rv32_func7 ?= "0100000");
  rv32_func7_0000001 <= (rv32_func7 ?= "0000001");
  rv32_func7_0000101 <= (rv32_func7 ?= "0000101");
  rv32_func7_0001001 <= (rv32_func7 ?= "0001001");
  rv32_func7_0001101 <= (rv32_func7 ?= "0001101");
  rv32_func7_0010101 <= (rv32_func7 ?= "0010101");
  rv32_func7_0100001 <= (rv32_func7 ?= "0100001");
  rv32_func7_0010001 <= (rv32_func7 ?= "0010001");
  rv32_func7_0101101 <= (rv32_func7 ?= "0101101");
  rv32_func7_1111111 <= (rv32_func7 ?= "1111111");
  rv32_func7_0000100 <= (rv32_func7 ?= "0000100"); 
  rv32_func7_0001000 <= (rv32_func7 ?= "0001000"); 
  rv32_func7_0001100 <= (rv32_func7 ?= "0001100"); 
  rv32_func7_0101100 <= (rv32_func7 ?= "0101100"); 
  rv32_func7_0010000 <= (rv32_func7 ?= "0010000"); 
  rv32_func7_0010100 <= (rv32_func7 ?= "0010100"); 
  rv32_func7_1100000 <= (rv32_func7 ?= "1100000"); 
  rv32_func7_1110000 <= (rv32_func7 ?= "1110000"); 
  rv32_func7_1010000 <= (rv32_func7 ?= "1010000"); 
  rv32_func7_1101000 <= (rv32_func7 ?= "1101000"); 
  rv32_func7_1111000 <= (rv32_func7 ?= "1111000"); 
  rv32_func7_1010001 <= (rv32_func7 ?= "1010001");  
  rv32_func7_1110001 <= (rv32_func7 ?= "1110001");  
  rv32_func7_1100001 <= (rv32_func7 ?= "1100001");  
  rv32_func7_1101001 <= (rv32_func7 ?= "1101001");  

  rv32_rs1_x0  <= (rv32_rs1 ?= "00000");
  rv32_rs2_x0  <= (rv32_rs2 ?= "00000");
  rv32_rs2_x1  <= (rv32_rs2 ?= "00001");
  rv32_rd_x0   <= (rv32_rd  ?= "00000");
  rv32_rd_x2   <= (rv32_rd  ?= "00010");

  rv16_rs1_x0  <= (rv16_rs1 ?= "00000");
  rv16_rs2_x0  <= (rv16_rs2 ?= "00000");
  rv16_rd_x0   <= (rv16_rd  ?= "00000");
  rv16_rd_x2   <= (rv16_rd  ?= "00010");

  rv32_rs1_x31 <= (rv32_rs1 ?= "11111");
  rv32_rs2_x31 <= (rv32_rs2 ?= "11111");
  rv32_rd_x31  <= (rv32_rd  ?= "11111");

  rv32_load     <= opcode_6_5_00 and opcode_4_2_000 and opcode_1_0_11; 
  rv32_store    <= opcode_6_5_01 and opcode_4_2_000 and opcode_1_0_11; 
  rv32_madd     <= opcode_6_5_10 and opcode_4_2_000 and opcode_1_0_11; 
  rv32_branch   <= opcode_6_5_11 and opcode_4_2_000 and opcode_1_0_11; 

  rv32_load_fp  <= opcode_6_5_00 and opcode_4_2_001 and opcode_1_0_11; 
  rv32_store_fp <= opcode_6_5_01 and opcode_4_2_001 and opcode_1_0_11; 
  rv32_msub     <= opcode_6_5_10 and opcode_4_2_001 and opcode_1_0_11; 
  rv32_jalr     <= opcode_6_5_11 and opcode_4_2_001 and opcode_1_0_11; 

  rv32_custom0  <= opcode_6_5_00 and opcode_4_2_010 and opcode_1_0_11; 
  rv32_custom1  <= opcode_6_5_01 and opcode_4_2_010 and opcode_1_0_11; 
  rv32_nmsub    <= opcode_6_5_10 and opcode_4_2_010 and opcode_1_0_11; 
  rv32_resved0  <= opcode_6_5_11 and opcode_4_2_010 and opcode_1_0_11;
  rv32_miscmem  <= opcode_6_5_00 and opcode_4_2_011 and opcode_1_0_11;

  `if E203_SUPPORT_AMO = "TURE" then
  rv32_amo      <= opcode_6_5_01 and opcode_4_2_011 and opcode_1_0_11; 
  `end if -- E203_SUPPORT_AMO
  `if E203_SUPPORT_AMO = "FALSE" then
  rv32_amo      <= '0'; 
  `end if 
  
  rv32_nmadd        <= opcode_6_5_10 and opcode_4_2_011 and opcode_1_0_11; 
  rv32_jal          <= opcode_6_5_11 and opcode_4_2_011 and opcode_1_0_11; 

  rv32_op_imm       <= opcode_6_5_00 and opcode_4_2_100 and opcode_1_0_11; 
  rv32_op           <= opcode_6_5_01 and opcode_4_2_100 and opcode_1_0_11; 
  rv32_op_fp        <= opcode_6_5_10 and opcode_4_2_100 and opcode_1_0_11; 
  rv32_system       <= opcode_6_5_11 and opcode_4_2_100 and opcode_1_0_11; 

  rv32_auipc        <= opcode_6_5_00 and opcode_4_2_101 and opcode_1_0_11; 
  rv32_lui          <= opcode_6_5_01 and opcode_4_2_101 and opcode_1_0_11; 
  rv32_resved1      <= opcode_6_5_10 and opcode_4_2_101 and opcode_1_0_11; 
  rv32_resved2      <= opcode_6_5_11 and opcode_4_2_101 and opcode_1_0_11; 

  rv32_op_imm_32    <= opcode_6_5_00 and opcode_4_2_110 and opcode_1_0_11; 
  rv32_op_32        <= opcode_6_5_01 and opcode_4_2_110 and opcode_1_0_11; 
  rv32_custom2      <= opcode_6_5_10 and opcode_4_2_110 and opcode_1_0_11; 
  rv32_custom3      <= opcode_6_5_11 and opcode_4_2_110 and opcode_1_0_11; 

  rv16_addi4spn     <= opcode_1_0_00 and rv16_func3_000;
  rv16_lw           <= opcode_1_0_00 and rv16_func3_010;
  rv16_sw           <= opcode_1_0_00 and rv16_func3_110;

  rv16_addi         <= opcode_1_0_01 and rv16_func3_000;
  rv16_jal          <= opcode_1_0_01 and rv16_func3_001;
  rv16_li           <= opcode_1_0_01 and rv16_func3_010;
  rv16_lui_addi16sp <= opcode_1_0_01 and rv16_func3_011;
  rv16_miscalu      <= opcode_1_0_01 and rv16_func3_100;
  rv16_j            <= opcode_1_0_01 and rv16_func3_101;
  rv16_beqz         <= opcode_1_0_01 and rv16_func3_110;
  rv16_bnez         <= opcode_1_0_01 and rv16_func3_111;

  rv16_slli         <= opcode_1_0_10 and rv16_func3_000;
  rv16_lwsp         <= opcode_1_0_10 and rv16_func3_010;
  rv16_jalr_mv_add  <= opcode_1_0_10 and rv16_func3_100;
  rv16_swsp         <= opcode_1_0_10 and rv16_func3_110;

  rv16_lwsp_ilgl    <= rv16_lwsp and rv16_rd_x0; -- (RES, rd=0)

  rv16_nop          <= rv16_addi  
                       and (not rv16_instr(12)) and (rv16_rd_x0) and (rv16_rs2_x0);

  rv16_srli         <= rv16_miscalu and (rv16_instr(11 downto 10) ?= "00");
  rv16_srai         <= rv16_miscalu and (rv16_instr(11 downto 10) ?= "01");
  rv16_andi         <= rv16_miscalu and (rv16_instr(11 downto 10) ?= "10");

  rv16_instr_12_is0   <= (rv16_instr(12)         ?= '0');
  rv16_instr_6_2_is0s <= (rv16_instr(6 downto 2) ?= 5b"0");

  rv16_sxxi_shamt_legl<=           rv16_instr_12_is0      -- shamt[5] must be zero for RV32C
                         and (not (rv16_instr_6_2_is0s)); -- shamt[4:0] must be non-zero for RV32C
            
  rv16_sxxi_shamt_ilgl<=  (rv16_slli or rv16_srli or rv16_srai) and (not rv16_sxxi_shamt_legl);

  rv16_addi16sp       <= rv16_lui_addi16sp and      rv32_rd_x2;
  rv16_lui            <= rv16_lui_addi16sp and (not rv32_rd_x0) and (not rv32_rd_x2);
  
  -- C.LI is only valid when rd!=x0.
  rv16_li_ilgl        <= rv16_li and (rv16_rd_x0);
  -- C.LUI is only valid when rd!=x0 or x2, and when the immediate is not equal to zero.
  rv16_lui_ilgl      <= rv16_lui and (rv16_rd_x0 or rv16_rd_x2 or (rv16_instr_6_2_is0s and rv16_instr_12_is0));

  rv16_li_lui_ilgl   <= rv16_li_ilgl or rv16_lui_ilgl;

  rv16_addi4spn_ilgl <= rv16_addi4spn and (rv16_instr_12_is0 and rv16_rd_x0 and opcode_6_5_00); -- (RES, nzimm=0, bits[12:5])
  rv16_addi16sp_ilgl <= rv16_addi16sp and  rv16_instr_12_is0 and rv16_instr_6_2_is0s;           -- (RES, nzimm=0, bits 12,6:2)

  rv16_subxororand  <= rv16_miscalu     and (rv16_instr(12 downto 10) ?= "011");
  rv16_sub          <= rv16_subxororand and (rv16_instr( 6 downto 5 ) ?= "00");
  rv16_xor          <= rv16_subxororand and (rv16_instr( 6 downto 5 ) ?= "01");
  rv16_or           <= rv16_subxororand and (rv16_instr( 6 downto 5 ) ?= "10");
  rv16_and          <= rv16_subxororand and (rv16_instr( 6 downto 5 ) ?= "11");

  rv16_jr           <= rv16_jalr_mv_add 
                    and (not rv16_instr(12)) and (not rv16_rs1_x0) and (rv16_rs2_x0); -- The RES rs1=0 illegal is already covered here
  rv16_mv           <= rv16_jalr_mv_add 
                    and (not rv16_instr(12)) and (not rv16_rd_x0) and (not rv16_rs2_x0);
  rv16_ebreak       <= rv16_jalr_mv_add 
                    and (rv16_instr(12)) and (rv16_rd_x0) and (rv16_rs2_x0);
  rv16_jalr         <= rv16_jalr_mv_add 
                    and (rv16_instr(12)) and (not rv16_rs1_x0) and (rv16_rs2_x0);
  rv16_add          <= rv16_jalr_mv_add  
                         and (rv16_instr(12)) and (not rv16_rd_x0) and (not rv16_rs2_x0);

  `if E203_HAS_NICE = "TRUE" then
  -- ==========================================================================
  -- add nice logic 

  nice_need_rs1 <= rv32_instr(13);
  nice_need_rs2 <= rv32_instr(12);
  nice_need_rd  <= rv32_instr(14);
  nice_instr    <= rv32_instr(31 downto 5);
  nice_op       <= rv32_custom0 or rv32_custom1 or rv32_custom2 or rv32_custom3;
  dec_nice      <= nice_op;
  
  nice_cmt_off_ilgl_o <= nice_xs_off and nice_op;

  nice_info_bus(E203_DECINFO_GRP'range)        <= E203_DECINFO_GRP_NICE;
  nice_info_bus(E203_DECINFO_RV32'right)       <= rv32;
  nice_info_bus(E203_DECINFO_NICE_INSTR'range) <= nice_instr;


  `end if

  -- Branch Instructions
  rv32_beq      <= rv32_branch and rv32_func3_000;
  rv32_bne      <= rv32_branch and rv32_func3_001;
  rv32_blt      <= rv32_branch and rv32_func3_100;
  rv32_bgt      <= rv32_branch and rv32_func3_101;
  rv32_bltu     <= rv32_branch and rv32_func3_110;
  rv32_bgtu     <= rv32_branch and rv32_func3_111;

  -- System Instructions
  rv32_ecall    <= rv32_system and rv32_func3_000 and (rv32_instr(31 downto 20) ?= 12b"0000_0000_0000");
  rv32_ebreak   <= rv32_system and rv32_func3_000 and (rv32_instr(31 downto 20) ?= 12b"0000_0000_0001");
  rv32_mret     <= rv32_system and rv32_func3_000 and (rv32_instr(31 downto 20) ?= 12b"0011_0000_0010");
  rv32_dret     <= rv32_system and rv32_func3_000 and (rv32_instr(31 downto 20) ?= 12b"0111_1011_0010");
  rv32_wfi      <= rv32_system and rv32_func3_000 and (rv32_instr(31 downto 20) ?= 12b"0001_0000_0101");
  -- We dont implement the WFI and MRET illegal exception when the rs and rd is not zeros

  rv32_csrrw   <= rv32_system and rv32_func3_001; 
  rv32_csrrs   <= rv32_system and rv32_func3_010; 
  rv32_csrrc   <= rv32_system and rv32_func3_011; 
  rv32_csrrwi  <= rv32_system and rv32_func3_101; 
  rv32_csrrsi  <= rv32_system and rv32_func3_110; 
  rv32_csrrci  <= rv32_system and rv32_func3_111; 

  rv32_dret_ilgl <= rv32_dret and (not dbg_mode);

  rv32_ecall_ebreak_ret_wfi <= rv32_system and rv32_func3_000;
  rv32_csr       <= rv32_system and (not rv32_func3_000);

  -- The Branch and system group of instructions will be handled by BJP
  dec_jal     <= rv32_jal    or rv16_jal  or rv16_j;
  dec_jalr    <= rv32_jalr   or rv16_jalr or rv16_jr;
  dec_bxx     <= rv32_branch or rv16_beqz or rv16_bnez;
  dec_bjp     <= dec_jal     or dec_jalr  or dec_bxx;

  bjp_op <= dec_bjp or rv32_mret or (rv32_dret and (not rv32_dret_ilgl)) or rv32_fence_fencei;
  bjp_info_bus(E203_DECINFO_GRP       'range)  <= E203_DECINFO_GRP_BJP;
  bjp_info_bus(E203_DECINFO_RV32      'right)  <= rv32;
  bjp_info_bus(E203_DECINFO_BJP_JUMP  'right)  <= dec_jal or dec_jalr;
  bjp_info_bus(E203_DECINFO_BJP_BPRDT 'right)  <= i_prdt_taken;
  bjp_info_bus(E203_DECINFO_BJP_BEQ   'right)  <= rv32_beq or rv16_beqz;
  bjp_info_bus(E203_DECINFO_BJP_BNE   'right)  <= rv32_bne or rv16_bnez;
  bjp_info_bus(E203_DECINFO_BJP_BLT   'right)  <= rv32_blt; 
  bjp_info_bus(E203_DECINFO_BJP_BGT   'right)  <= rv32_bgt;
  bjp_info_bus(E203_DECINFO_BJP_BLTU  'right)  <= rv32_bltu;
  bjp_info_bus(E203_DECINFO_BJP_BGTU  'right)  <= rv32_bgtu;
  bjp_info_bus(E203_DECINFO_BJP_BXX   'right)  <= dec_bxx;
  bjp_info_bus(E203_DECINFO_BJP_MRET  'right)  <= rv32_mret;
  bjp_info_bus(E203_DECINFO_BJP_DRET  'right)  <= rv32_dret;
  bjp_info_bus(E203_DECINFO_BJP_FENCE 'right)  <= rv32_fence;
  bjp_info_bus(E203_DECINFO_BJP_FENCEI'right)  <= rv32_fence_i;
  

  -- ALU Instructions
  rv32_addi     <= rv32_op_imm and rv32_func3_000;
  rv32_slti     <= rv32_op_imm and rv32_func3_010;
  rv32_sltiu    <= rv32_op_imm and rv32_func3_011;
  rv32_xori     <= rv32_op_imm and rv32_func3_100;
  rv32_ori      <= rv32_op_imm and rv32_func3_110;
  rv32_andi     <= rv32_op_imm and rv32_func3_111;

  rv32_slli     <= rv32_op_imm and rv32_func3_001 and (rv32_instr(31 downto 26) ?= 6b"000000");
  rv32_srli     <= rv32_op_imm and rv32_func3_101 and (rv32_instr(31 downto 26) ?= 6b"000000");
  rv32_srai     <= rv32_op_imm and rv32_func3_101 and (rv32_instr(31 downto 26) ?= 6b"010000");

  rv32_sxxi_shamt_legl <= (rv32_instr(25) ?= '0'); -- shamt[5] must be zero for RV32I
  rv32_sxxi_shamt_ilgl <= (rv32_slli or rv32_srli or rv32_srai) and (not rv32_sxxi_shamt_legl);

  rv32_add      <= rv32_op and rv32_func3_000 and rv32_func7_0000000;
  rv32_sub      <= rv32_op and rv32_func3_000 and rv32_func7_0100000;
  rv32_sll      <= rv32_op and rv32_func3_001 and rv32_func7_0000000;
  rv32_slt      <= rv32_op and rv32_func3_010 and rv32_func7_0000000;
  rv32_sltu     <= rv32_op and rv32_func3_011 and rv32_func7_0000000;
  rv32_xor      <= rv32_op and rv32_func3_100 and rv32_func7_0000000;
  rv32_srl      <= rv32_op and rv32_func3_101 and rv32_func7_0000000;
  rv32_sra      <= rv32_op and rv32_func3_101 and rv32_func7_0100000;
  rv32_or       <= rv32_op and rv32_func3_110 and rv32_func7_0000000;
  rv32_and      <= rv32_op and rv32_func3_111 and rv32_func7_0000000;

  rv32_nop      <= rv32_addi and rv32_rs1_x0 and rv32_rd_x0 and (not (or(rv32_instr(31 downto 20))));
  
  -- The ALU group of instructions will be handled by 1cycle ALU-datapath
  ecall_ebreak  <= rv32_ecall or rv32_ebreak or rv16_ebreak;

  alu_op     <= (not rv32_sxxi_shamt_ilgl) and (not rv16_sxxi_shamt_ilgl) 
                and (not rv16_li_lui_ilgl) and (not rv16_addi4spn_ilgl) and (not rv16_addi16sp_ilgl) and 
                ( rv32_op_imm 
                or (rv32_op and (not rv32_func7_0000001)) -- Exclude the MULDIV
                or rv32_auipc
                or rv32_lui
                or rv16_addi4spn
                or rv16_addi         
                or rv16_lui_addi16sp 
                or rv16_li or rv16_mv
                or rv16_slli         
                or rv16_miscalu  
                or rv16_add
                or rv16_nop or rv32_nop
                or rv32_wfi -- We just put WFI into ALU and do nothing in ALU
                or ecall_ebreak)
                ;
  
  alu_info_bus(E203_DECINFO_GRP       'range) <= E203_DECINFO_GRP_ALU;
  alu_info_bus(E203_DECINFO_RV32      'right) <= rv32;
  alu_info_bus(E203_DECINFO_ALU_ADD   'right) <= rv32_add      or rv32_addi or rv32_auipc    or
                                                 rv16_addi4spn or rv16_addi or rv16_addi16sp or rv16_add or
  -- We also decode LI and MV as the add instruction, becuase
  --   they all add x0 with a RS2 or Immeidate, and then write into RD
                                                 rv16_li   or rv16_mv;
  alu_info_bus(E203_DECINFO_ALU_SUB   'right) <= rv32_sub  or rv16_sub;      
  alu_info_bus(E203_DECINFO_ALU_SLT   'right) <= rv32_slt  or rv32_slti;     
  alu_info_bus(E203_DECINFO_ALU_SLTU  'right) <= rv32_sltu or rv32_sltiu;  
  alu_info_bus(E203_DECINFO_ALU_XOR   'right) <= rv32_xor  or rv32_xori or rv16_xor;    
  alu_info_bus(E203_DECINFO_ALU_SLL   'right) <= rv32_sll  or rv32_slli or rv16_slli;   
  alu_info_bus(E203_DECINFO_ALU_SRL   'right) <= rv32_srl  or rv32_srli or rv16_srli;
  alu_info_bus(E203_DECINFO_ALU_SRA   'right) <= rv32_sra  or rv32_srai or rv16_srai;   
  alu_info_bus(E203_DECINFO_ALU_OR    'right) <= rv32_or   or rv32_ori  or rv16_or;     
  alu_info_bus(E203_DECINFO_ALU_AND   'right) <= rv32_and  or rv32_andi or rv16_andi or rv16_and;
  alu_info_bus(E203_DECINFO_ALU_LUI   'right) <= rv32_lui  or rv16_lui; 
  alu_info_bus(E203_DECINFO_ALU_OP2IMM'right) <= need_imm; 
  alu_info_bus(E203_DECINFO_ALU_OP1PC 'right) <= rv32_auipc;
  alu_info_bus(E203_DECINFO_ALU_NOP   'right) <= rv16_nop  or rv32_nop;
  alu_info_bus(E203_DECINFO_ALU_ECAL  'right) <= rv32_ecall; 
  alu_info_bus(E203_DECINFO_ALU_EBRK  'right) <= rv32_ebreak or rv16_ebreak;
  alu_info_bus(E203_DECINFO_ALU_WFI   'right) <= rv32_wfi;

  csr_op                                      <= rv32_csr;
  csr_info_bus(E203_DECINFO_GRP       'range) <= E203_DECINFO_GRP_CSR;
  csr_info_bus(E203_DECINFO_RV32      'right) <= rv32;
  csr_info_bus(E203_DECINFO_CSR_CSRRW 'right) <= rv32_csrrw  or rv32_csrrwi; 
  csr_info_bus(E203_DECINFO_CSR_CSRRS 'right) <= rv32_csrrs  or rv32_csrrsi;
  csr_info_bus(E203_DECINFO_CSR_CSRRC 'right) <= rv32_csrrc  or rv32_csrrci;
  csr_info_bus(E203_DECINFO_CSR_RS1IMM'right) <= rv32_csrrwi or rv32_csrrsi or rv32_csrrci;
  csr_info_bus(E203_DECINFO_CSR_ZIMMM 'range) <= rv32_rs1;
  csr_info_bus(E203_DECINFO_CSR_RS1IS0'right) <= rv32_rs1_x0;
  csr_info_bus(E203_DECINFO_CSR_CSRIDX'range) <= rv32_instr(31 downto 20);
  
  -- Memory Order Instructions
  rv32_fence        <= rv32_miscmem or rv32_func3_000;
  rv32_fence_i      <= rv32_miscmem or rv32_func3_001;
  rv32_fence_fencei <= rv32_miscmem;

  -- MUL/DIV Instructions
  rv32_mul      <= rv32_op and rv32_func3_000 and rv32_func7_0000001;
  rv32_mulh     <= rv32_op and rv32_func3_001 and rv32_func7_0000001;
  rv32_mulhsu   <= rv32_op and rv32_func3_010 and rv32_func7_0000001;
  rv32_mulhu    <= rv32_op and rv32_func3_011 and rv32_func7_0000001;
  rv32_div      <= rv32_op and rv32_func3_100 and rv32_func7_0000001;
  rv32_divu     <= rv32_op and rv32_func3_101 and rv32_func7_0000001;
  rv32_rem      <= rv32_op and rv32_func3_110 and rv32_func7_0000001;
  rv32_remu     <= rv32_op and rv32_func3_111 and rv32_func7_0000001;

  -- The MULDIV group of instructions will be handled by MUL-DIV-datapath
  `if E203_SUPPORT_MULDIV = "TRUE" then
  muldiv_op <= rv32_op and rv32_func7_0000001;
  `end if
  `if E203_SUPPORT_MULDIV = "FALSE" then
  muldiv_op <= '0';
  `end if

  muldiv_info_bus(E203_DECINFO_GRP          'range) <= E203_DECINFO_GRP_MULDIV;
  muldiv_info_bus(E203_DECINFO_RV32         'right) <= rv32        ;
  muldiv_info_bus(E203_DECINFO_MULDIV_MUL   'right) <= rv32_mul    ;   
  muldiv_info_bus(E203_DECINFO_MULDIV_MULH  'right) <= rv32_mulh   ;
  muldiv_info_bus(E203_DECINFO_MULDIV_MULHSU'right) <= rv32_mulhsu ;
  muldiv_info_bus(E203_DECINFO_MULDIV_MULHU 'right) <= rv32_mulhu  ;
  muldiv_info_bus(E203_DECINFO_MULDIV_DIV   'right) <= rv32_div    ;
  muldiv_info_bus(E203_DECINFO_MULDIV_DIVU  'right) <= rv32_divu   ;
  muldiv_info_bus(E203_DECINFO_MULDIV_REM   'right) <= rv32_rem    ;
  muldiv_info_bus(E203_DECINFO_MULDIV_REMU  'right) <= rv32_remu   ;
  muldiv_info_bus(E203_DECINFO_MULDIV_B2B   'right) <= i_muldiv_b2b;

  dec_mulhsu <= rv32_mulh or rv32_mulhsu or rv32_mulhu;
  dec_mul    <= rv32_mul;
  dec_div    <= rv32_div;
  dec_divu   <= rv32_divu;
  dec_rem    <= rv32_rem;
  dec_remu   <= rv32_remu;

  -- Load/Store Instructions
  rv32_lb    <= rv32_load  and rv32_func3_000;
  rv32_lh    <= rv32_load  and rv32_func3_001;
  rv32_lw    <= rv32_load  and rv32_func3_010;
  rv32_lbu   <= rv32_load  and rv32_func3_100;
  rv32_lhu   <= rv32_load  and rv32_func3_101;

  rv32_sb    <= rv32_store and rv32_func3_000;
  rv32_sh    <= rv32_store and rv32_func3_001;
  rv32_sw    <= rv32_store and rv32_func3_010;

  -- Atomic Instructions
  `if E203_SUPPORT_AMO = "TRUE" then
  rv32_lr_w      <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"00010");
  rv32_sc_w      <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"00011");
  rv32_amoswap_w <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"00001");
  rv32_amoadd_w  <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"00000");
  rv32_amoxor_w  <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"00100");
  rv32_amoand_w  <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"01100");
  rv32_amoor_w   <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"01000");
  rv32_amomin_w  <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"10000");
  rv32_amomax_w  <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"10100");
  rv32_amominu_w <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"11000");
  rv32_amomaxu_w <= rv32_amo and rv32_func3_010 and (rv32_func7(6 downto 2) ?= 5b"11100");
  `end if
  amoldst_op <= rv32_amo or rv32_load or rv32_store or rv16_lw or rv16_sw or (rv16_lwsp and (not rv16_lwsp_ilgl)) or rv16_swsp;
  -- The RV16 always is word
  lsu_info_size  <= rv32_func3(1 downto 0) when rv32 = '1' else "10";
  -- The RV16 always is signed
  lsu_info_usign <= rv32_func3(2) when rv32 = '1' else '0';
  
  agu_info_bus(E203_DECINFO_GRP        'range) <= E203_DECINFO_GRP_AGU;
  agu_info_bus(E203_DECINFO_RV32       'right) <= rv32;
  agu_info_bus(E203_DECINFO_AGU_LOAD   'right) <= rv32_load  or rv32_lr_w or rv16_lw or rv16_lwsp;
  agu_info_bus(E203_DECINFO_AGU_STORE  'right) <= rv32_store or rv32_sc_w or rv16_sw or rv16_swsp;
  agu_info_bus(E203_DECINFO_AGU_SIZE   'range) <= lsu_info_size;
  agu_info_bus(E203_DECINFO_AGU_USIGN  'right) <= lsu_info_usign;
  agu_info_bus(E203_DECINFO_AGU_EXCL   'right) <= rv32_lr_w or rv32_sc_w;
  agu_info_bus(E203_DECINFO_AGU_AMO    'right) <= rv32_amo and (not(rv32_lr_w or rv32_sc_w)); -- We seperated the EXCL out of AMO in LSU handling
  agu_info_bus(E203_DECINFO_AGU_AMOSWAP'right) <= rv32_amoswap_w;
  agu_info_bus(E203_DECINFO_AGU_AMOADD 'right) <= rv32_amoadd_w ;
  agu_info_bus(E203_DECINFO_AGU_AMOAND 'right) <= rv32_amoand_w ;
  agu_info_bus(E203_DECINFO_AGU_AMOOR  'right) <= rv32_amoor_w  ;
  agu_info_bus(E203_DECINFO_AGU_AMOXOR 'right) <= rv32_amoxor_w ;
  agu_info_bus(E203_DECINFO_AGU_AMOMAX 'right) <= rv32_amomax_w ;
  agu_info_bus(E203_DECINFO_AGU_AMOMIN 'right) <= rv32_amomin_w ;
  agu_info_bus(E203_DECINFO_AGU_AMOMAXU'right) <= rv32_amomaxu_w;
  agu_info_bus(E203_DECINFO_AGU_AMOMINU'right) <= rv32_amominu_w;
  agu_info_bus(E203_DECINFO_AGU_OP2IMM 'right) <= need_imm; 

  -- Reuse the common signals as much as possible to save gatecounts
  rv32_all0s_ilgl  <= rv32_func7_0000000 
                   and rv32_rs2_x0 
                   and rv32_rs1_x0 
                   and rv32_func3_000 
                   and rv32_rd_x0 
                   and opcode_6_5_00 
                   and opcode_4_2_000 
                   and (opcode(1 downto 0) ?= 2b"00"); 

  rv32_all1s_ilgl  <= rv32_func7_1111111 
                   and rv32_rs2_x31 
                   and rv32_rs1_x31 
                   and rv32_func3_111 
                   and rv32_rd_x31 
                   and opcode_6_5_11 
                   and opcode_4_2_111 
                   and (opcode(1 downto 0) ?= 2b"11"); 

  rv16_all0s_ilgl  <= rv16_func3_000 -- rv16_func3  = rv32_instr[15:13];
                   and rv32_func3_000 -- rv32_func3  = rv32_instr[14:12];
                   and rv32_rd_x0     -- rv32_rd     = rv32_instr[11:7];
                   and opcode_6_5_00 
                   and opcode_4_2_000 
                   and (opcode(1 downto 0) ?= 2b"00"); 

  rv16_all1s_ilgl  <= rv16_func3_111
                   and rv32_func3_111 
                   and rv32_rd_x31 
                   and opcode_6_5_11 
                   and opcode_4_2_111 
                   and (opcode(1 downto 0) ?= 2b"11");
  
  rv_all0s1s_ilgl  <= (rv32_all0s_ilgl or rv32_all1s_ilgl) when rv32 = '1' else
                      (rv16_all0s_ilgl or rv16_all1s_ilgl);

  -- All the RV32IMA need RD register except the
  --   * Branch, Store,
  --   * fence, fence_i 
  --   * ecall, ebreak
  is_nice_need_rd <= 
                     `if E203_HAS_NICE = "TRUE" then
                       nice_need_rd when nice_op = '1' else
                     `end if
                       (
                           (not rv32_branch) 
                       and (not rv32_store)
                       and (not rv32_fence_fencei)
                       and (not rv32_ecall_ebreak_ret_wfi) 
                       );
  rv32_need_rd <= (not rv32_rd_x0) and is_nice_need_rd;

  -- All the RV32IMA need RS1 register except the
  --   * lui
  --   * auipc
  --   * jal
  --   * fence, fence_i 
  --   * ecall, ebreak  
  --   * csrrwi
  --   * csrrsi
  --   * csrrci
  is_nice_need_rs1 <= `if E203_HAS_NICE = "TRUE" then
                       nice_need_rs1 when nice_op = '1' else
                      `end if
                       (
                           (not rv32_lui)
                       and (not rv32_auipc)
                       and (not rv32_jal)
                       and (not rv32_fence_fencei)
                       and (not rv32_ecall_ebreak_ret_wfi)
                       and (not rv32_csrrwi)
                       and (not rv32_csrrsi)
                       and (not rv32_csrrci)
                       );
  rv32_need_rs1 <= (not rv32_rs1_x0) and is_nice_need_rs1;
                    
  -- Following RV32IMA instructions need RS2 register
  --   * branch
  --   * store
  --   * rv32_op
  --   * rv32_amo except the rv32_lr_w
  is_nice_need_rs2 <= `if E203_HAS_NICE = "TRUE" then
                       nice_need_rs2 when nice_op = '1' else
                      `end if
                       (
                          (rv32_branch)
                       or (rv32_store)
                       or (rv32_op)
                       or (rv32_amo and (not rv32_lr_w))
                       );
  rv32_need_rs2 <= (not rv32_rs2_x0) and is_nice_need_rs2;

  rv32_i_imm <= (20-1 downto 0 => rv32_instr(31))  
                 & rv32_instr(31 downto 20)
                ;

  rv32_s_imm <= (20-1 downto 0 => rv32_instr(31)) 
                 & rv32_instr(31 downto 25) 
                 & rv32_instr(11 downto 7)
                ;

  rv32_b_imm <= (19-1 downto 0 => rv32_instr(31)) 
                 & rv32_instr(31) 
                 & rv32_instr(7) 
                 & rv32_instr(30 downto 25) 
                 & rv32_instr(11 downto 8)
                 & '0'
                ;

  rv32_u_imm <= rv32_instr(31 downto 12) & 12b"0";

  rv32_j_imm <= (11-1 downto 0 => rv32_instr(31))
                 & rv32_instr(31) 
                 & rv32_instr(19 downto 12) 
                 & rv32_instr(20) 
                 & rv32_instr(30 downto 21)
                 & '0'
                ;

  -- It will select i-type immediate when
  --    * rv32_op_imm
  --    * rv32_jalr
  --    * rv32_load
  rv32_imm_sel_i    <= rv32_op_imm or rv32_jalr or rv32_load;
  rv32_imm_sel_jalr <= rv32_jalr;
  rv32_jalr_imm     <= rv32_i_imm;

  -- It will select u-type immediate when
  --    * rv32_lui, rv32_auipc 
  rv32_imm_sel_u <= rv32_lui or rv32_auipc;

  -- It will select j-type immediate when
  --    * rv32_jal
  rv32_imm_sel_j   <= rv32_jal;
  rv32_imm_sel_jal <= rv32_jal;
  rv32_jal_imm     <= rv32_j_imm;

  -- It will select b-type immediate when
  --    * rv32_branch
  rv32_imm_sel_b   <= rv32_branch;
  rv32_imm_sel_bxx <= rv32_branch;
  rv32_bxx_imm     <= rv32_b_imm;
                   
  -- It will select s-type immediate when
  --    * rv32_store
  rv32_imm_sel_s <= rv32_store;

  --   * Note: this CIS/CILI/CILUI/CI16SP-type is named by myself, because in 
  --           ISA doc, the CI format for LWSP is different
  --           with other CI formats in terms of immediate
  
  -- It will select CIS-type immediate when
  --    * rv16_lwsp
  rv16_imm_sel_cis <= rv16_lwsp;
  rv16_cis_imm <=    24b"0"
                   & rv16_instr(3 downto 2)
                   & rv16_instr(12)
                   & rv16_instr(6 downto 4)
                   & "00"
                  ;
              
  rv16_cis_d_imm <= 23b"0"
                   & rv16_instr(4 downto 2)
                   & rv16_instr(12)
                   & rv16_instr(6 downto 5)
                   & 3b"0"
                  ;
  -- It will select CILI-type immediate when
  --    * rv16_li
  --    * rv16_addi
  --    * rv16_slli
  --    * rv16_srai
  --    * rv16_srli
  --    * rv16_andi
  rv16_imm_sel_cili <= rv16_li or rv16_addi or rv16_slli
                  or rv16_srai or rv16_srli or rv16_andi;
  rv16_cili_imm <= (26-1 downto 0 => rv16_instr(12))
                   & rv16_instr(12)
                   & rv16_instr(6 downto 2)
                   ;
                   
  -- It will select CILUI-type immediate when
  --    * rv16_lui
  rv16_imm_sel_cilui <= rv16_lui;
  rv16_cilui_imm <= (14-1 downto 0 => rv16_instr(12))
                    & rv16_instr(12)
                    & rv16_instr(6 downto 2)
                    & 12b"0"
                    ;
                   
  -- It will select CI16SP-type immediate when
  --    * rv16_addi16sp
  rv16_imm_sel_ci16sp <= rv16_addi16sp;
  rv16_ci16sp_imm <= (22-1 downto 0 => rv16_instr(12))
                    & rv16_instr(12)
                    & rv16_instr(4)
                    & rv16_instr(3)
                    & rv16_instr(5)
                    & rv16_instr(2)
                    & rv16_instr(6)
                    & 4b"0"
                    ;
                   
  -- It will select CSS-type immediate when
  --    * rv16_swsp
  rv16_imm_sel_css <= rv16_swsp;
  rv16_css_imm <= 24b"0"
                  & rv16_instr(8 downto 7)
                  & rv16_instr(12 downto 9)
                  & "00"
                  ;
  rv16_css_d_imm <= 23b"0"
                   & rv16_instr(9 downto 7)
                   & rv16_instr(12 downto 10)
                   & 3b"0"
                   ;
  -- It will select CIW-type immediate when
  --    * rv16_addi4spn
  rv16_imm_sel_ciw <= rv16_addi4spn;
  rv16_ciw_imm <= 22b"0"
                  & rv16_instr(10 downto 7)
                  & rv16_instr(12)
                  & rv16_instr(11)
                  & rv16_instr(5)
                  & rv16_instr(6)
                  & "00"
                  ;

  -- It will select CL-type immediate when
  --    * rv16_lw
  rv16_imm_sel_cl <= rv16_lw;
  rv16_cl_imm <=  25b"0"
                  & rv16_instr(5)
                  & rv16_instr(12)
                  & rv16_instr(11)
                  & rv16_instr(10)
                  & rv16_instr(6)
                  & "00"
                  ;
                   
  rv16_cl_d_imm <= 24b"0"
                  & rv16_instr(6)
                  & rv16_instr(5)
                  & rv16_instr(12)
                  & rv16_instr(11)
                  & rv16_instr(10)
                  & 3b"0"
                  ;
  -- It will select CS-type immediate when
  --    * rv16_sw
  rv16_imm_sel_cs <= rv16_sw;
  rv16_cs_imm <= 25b"0"
                 & rv16_instr(5)
                 & rv16_instr(12)
                 & rv16_instr(11)
                 & rv16_instr(10)
                 & rv16_instr(6)
                 & "00"
                 ;
   rv16_cs_d_imm <= 24b"0"
                    & rv16_instr(6)
                    & rv16_instr(5)
                    & rv16_instr(12)
                    & rv16_instr(11)
                    & rv16_instr(10)
                    & 3b"0"
                    ;

  -- It will select CB-type immediate when
  --    * rv16_beqz
  --    * rv16_bnez
  rv16_imm_sel_cb <= rv16_beqz or rv16_bnez;
  rv16_cb_imm <= (23-1 downto 0 => rv16_instr(12))
                  & rv16_instr(12)
                  & rv16_instr(6 downto 5)
                  & rv16_instr(2)
                  & rv16_instr(11 downto 10)
                  & rv16_instr(4 downto 3)
                  & '0'
                 ;
  rv16_bxx_imm <= rv16_cb_imm;

  -- It will select CJ-type immediate when
  --    * rv16_j
  --    * rv16_jal
  rv16_imm_sel_cj <= rv16_j or rv16_jal;
  rv16_cj_imm <= (20-1 downto 0 => rv16_instr(12))
                  & rv16_instr(12)
                  & rv16_instr(8)
                  & rv16_instr(10 downto 9)
                  & rv16_instr(6)
                  & rv16_instr(7)
                  & rv16_instr(2)
                  & rv16_instr(11)
                  & rv16_instr(5 downto 3)
                  & '0'
                  ;
  rv16_jjal_imm <= rv16_cj_imm;

  -- It will select CR-type register (no-imm) when
  --    * rv16_jalr_mv_add
  rv16_jrjalr_imm <= 32b"0";
                   
  -- It will select CSR-type register (no-imm) when
  --    * rv16_subxororand

                   
  rv32_load_fp_imm  <= rv32_i_imm;
  rv32_store_fp_imm <= rv32_s_imm;
  rv32_imm <=    ((32-1 downto 0 => rv32_imm_sel_i) and rv32_i_imm)
              or ((32-1 downto 0 => rv32_imm_sel_s) and rv32_s_imm)
              or ((32-1 downto 0 => rv32_imm_sel_b) and rv32_b_imm)
              or ((32-1 downto 0 => rv32_imm_sel_u) and rv32_u_imm)
              or ((32-1 downto 0 => rv32_imm_sel_j) and rv32_j_imm)
              ;
                   
  rv32_need_imm <=    rv32_imm_sel_i
                   or rv32_imm_sel_s
                   or rv32_imm_sel_b
                   or rv32_imm_sel_u
                   or rv32_imm_sel_j
                   ;

  rv16_imm      <=    ((32-1 downto 0 => rv16_imm_sel_cis   ) and rv16_cis_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cili  ) and rv16_cili_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cilui ) and rv16_cilui_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_ci16sp) and rv16_ci16sp_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_css   ) and rv16_css_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_ciw   ) and rv16_ciw_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cl    ) and rv16_cl_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cs    ) and rv16_cs_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cb    ) and rv16_cb_imm)
                   or ((32-1 downto 0 => rv16_imm_sel_cj    ) and rv16_cj_imm)
                   ;

  rv16_need_imm <=    rv16_imm_sel_cis   
                   or rv16_imm_sel_cili  
                   or rv16_imm_sel_cilui 
                   or rv16_imm_sel_ci16sp
                   or rv16_imm_sel_css   
                   or rv16_imm_sel_ciw   
                   or rv16_imm_sel_cl    
                   or rv16_imm_sel_cs    
                   or rv16_imm_sel_cb    
                   or rv16_imm_sel_cj    
                   ;

  need_imm <= rv32_need_imm when rv32 = '1' else rv16_need_imm; 
  dec_imm  <= rv32_imm when rv32 = '1' else rv16_imm;
  dec_pc   <= i_pc;

  dec_info <= 
               ((E203_DECINFO_WIDTH-1 downto 0 => alu_op    ) and ((E203_DECINFO_WIDTH-E203_DECINFO_ALU_WIDTH-1 downto 0 => '0') & alu_info_bus))
            or ((E203_DECINFO_WIDTH-1 downto 0 => amoldst_op) and ((E203_DECINFO_WIDTH-E203_DECINFO_AGU_WIDTH-1 downto 0 => '0') & agu_info_bus))
            or ((E203_DECINFO_WIDTH-1 downto 0 => bjp_op    ) and ((E203_DECINFO_WIDTH-E203_DECINFO_BJP_WIDTH-1 downto 0 => '0') & bjp_info_bus))
            or ((E203_DECINFO_WIDTH-1 downto 0 => csr_op    ) and ((E203_DECINFO_WIDTH-E203_DECINFO_CSR_WIDTH-1 downto 0 => '0') & csr_info_bus))
            or ((E203_DECINFO_WIDTH-1 downto 0 => muldiv_op ) and ((E203_DECINFO_WIDTH-E203_DECINFO_CSR_WIDTH-1 downto 0 => '0') & muldiv_info_bus))
           `if E203_HAS_NICE = "TRUE" then
            or ((E203_DECINFO_WIDTH-1 downto 0 => nice_op   ) and ((E203_DECINFO_WIDTH-E203_DECINFO_NICE_WIDTH-1 downto 0=> '0') & nice_info_bus))
           `end if
            ;

  legl_ops <= 
               alu_op
            or amoldst_op
            or bjp_op
            or csr_op
            or muldiv_op
           `if E203_HAS_NICE = "TRUE" then
            or nice_op
           `end if
            ;

  -- To decode the registers for Rv16, divided into 8 groups
  rv16_format_cr  <= rv16_jalr_mv_add;
  rv16_format_ci  <= rv16_lwsp or rv16_flwsp or rv16_fldsp or rv16_li or rv16_lui_addi16sp or rv16_addi or rv16_slli; 
  rv16_format_css <= rv16_swsp or rv16_fswsp or rv16_fsdsp; 
  rv16_format_ciw <= rv16_addi4spn; 
  rv16_format_cl  <= rv16_lw or rv16_flw or rv16_fld; 
  rv16_format_cs  <= rv16_sw or rv16_fsw or rv16_fsd or rv16_subxororand; 
  rv16_format_cb  <= rv16_beqz or rv16_bnez or rv16_srli or rv16_srai or rv16_andi; 
  rv16_format_cj  <= rv16_j or rv16_jal; 


  -- In CR Cases:
  --   * JR:     rs1= rs1(coded),     rs2= x0 (coded),   rd = x0 (implicit)
  --   * JALR:   rs1= rs1(coded),     rs2= x0 (coded),   rd = x1 (implicit)
  --   * MV:     rs1= x0 (implicit),  rs2= rs2(coded),   rd = rd (coded)
  --   * ADD:    rs1= rs1(coded),     rs2= rs2(coded),   rd = rd (coded)
  --   * eBreak: rs1= rs1(coded),     rs2= x0 (coded),   rd = x0 (coded)
  rv16_need_cr_rs1   <= rv16_format_cr and '1';
  rv16_need_cr_rs2   <= rv16_format_cr and '1';
  rv16_need_cr_rd    <= rv16_format_cr and '1';
  rv16_cr_rs1 <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH)) when rv16_mv = '1' else rv16_rs1(E203_RFIDX_WIDTH-1 downto 0);
  rv16_cr_rs2 <= rv16_rs2(E203_RFIDX_WIDTH-1 downto 0);
  -- The JALR and JR difference in encoding is just the rv16_instr[12]
  rv16_cr_rd  <= ((E203_RFIDX_WIDTH-1-1 downto 0 => '0') & rv16_instr(12)) when ((rv16_jalr or rv16_jr) = '1') else 
                 rv16_rd(E203_RFIDX_WIDTH-1 downto 0);
                         
  -- In CI Cases:
  --   * LWSP:     rs1= x2 (implicit),  rd = rd 
  --   * LI/LUI:   rs1= x0 (implicit),  rd = rd
  --   * ADDI:     rs1= rs1(implicit),  rd = rd
  --   * ADDI16SP: rs1= rs1(implicit),  rd = rd
  --   * SLLI:     rs1= rs1(implicit),  rd = rd
  rv16_need_ci_rs1   <= rv16_format_ci and '1';
  rv16_need_ci_rs2   <= rv16_format_ci and '0';
  rv16_need_ci_rd    <= rv16_format_ci and '1';
  rv16_ci_rs1 <= std_logic_vector(to_unsigned(2, E203_RFIDX_WIDTH)) when ((rv16_lwsp or rv16_flwsp or rv16_fldsp) = '1') else
                 std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH)) when ((rv16_li or rv16_lui) = '1') else
                 rv16_rs1(E203_RFIDX_WIDTH-1 downto 0);
  rv16_ci_rs2 <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_ci_rd  <= rv16_rd(E203_RFIDX_WIDTH-1 downto 0);
  
  -- In CSS Cases:
  --   * SWSP:     rs1 = x2 (implicit), rs2= rs2 
  rv16_need_css_rs1  <= rv16_format_css and '1';
  rv16_need_css_rs2  <= rv16_format_css and '1';
  rv16_need_css_rd   <= rv16_format_css and '0';
  rv16_css_rs1       <= std_logic_vector(to_unsigned(2, E203_RFIDX_WIDTH));
  rv16_css_rs2       <= rv16_rs2(E203_RFIDX_WIDTH-1 downto 0);
  rv16_css_rd        <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
                       
  -- In CIW cases:
  --   * ADDI4SPN:   rdd = rdd, rss1= x2 (implicit)
  rv16_need_ciw_rss1 <= rv16_format_ciw and '1';
  rv16_need_ciw_rss2 <= rv16_format_ciw and '0';
  rv16_need_ciw_rdd  <= rv16_format_ciw and '1';
  rv16_ciw_rss1      <= std_logic_vector(to_unsigned(2, E203_RFIDX_WIDTH));
  rv16_ciw_rss2      <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_ciw_rdd       <= rv16_rdd(E203_RFIDX_WIDTH-1 downto 0);
                      
  -- In CL cases:
  --   * LW:   rss1 = rss1, rdd= rdd
  rv16_need_cl_rss1  <= rv16_format_cl and '1';
  rv16_need_cl_rss2  <= rv16_format_cl and '0';
  rv16_need_cl_rdd   <= rv16_format_cl and '1';
  rv16_cl_rss1       <= rv16_rss1(E203_RFIDX_WIDTH-1 downto 0);
  rv16_cl_rss2       <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_cl_rdd        <= rv16_rdd(E203_RFIDX_WIDTH-1 downto 0);
                     
  -- In CS cases:
  --   * SW:            rdd = none(implicit), rss1= rss1       , rss2=rss2
  --   * SUBXORORAND:   rdd = rss1,           rss1= rss1(coded), rss2=rss2
  rv16_need_cs_rss1  <= rv16_format_cs and '1';
  rv16_need_cs_rss2  <= rv16_format_cs and '1';
  rv16_need_cs_rdd   <= rv16_format_cs and rv16_subxororand;
  rv16_cs_rss1       <= rv16_rss1(E203_RFIDX_WIDTH-1 downto 0);
  rv16_cs_rss2       <= rv16_rss2(E203_RFIDX_WIDTH-1 downto 0);
  rv16_cs_rdd        <= rv16_rss1(E203_RFIDX_WIDTH-1 downto 0);
                    
  -- In CB cases:
  --   * BEQ/BNE:            rdd = none(implicit), rss1= rss1, rss2=x0(implicit)
  --   * SRLI/SRAI/ANDI:     rdd = rss1          , rss1= rss1, rss2=none(implicit)
  rv16_need_cb_rss1  <= rv16_format_cb and '1';
  rv16_need_cb_rss2  <= rv16_format_cb and (rv16_beqz or rv16_bnez);
  rv16_need_cb_rdd   <= rv16_format_cb and (not (rv16_beqz or rv16_bnez));
  rv16_cb_rss1       <= rv16_rss1(E203_RFIDX_WIDTH-1 downto 0);
  rv16_cb_rss2       <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_cb_rdd        <= rv16_rss1(E203_RFIDX_WIDTH-1 downto 0);
  
  -- In CJ cases:
  --   * J:            rdd = x0(implicit)
  --   * JAL:          rdd = x1(implicit)
  rv16_need_cj_rss1  <= rv16_format_cj and '0';
  rv16_need_cj_rss2  <= rv16_format_cj and '0';
  rv16_need_cj_rdd   <= rv16_format_cj and '1';
  rv16_cj_rss1       <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_cj_rss2       <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH));
  rv16_cj_rdd        <= std_logic_vector(to_unsigned(0, E203_RFIDX_WIDTH)) when rv16_j = '1' else 
                        std_logic_vector(to_unsigned(1, E203_RFIDX_WIDTH));

  -- rv16_format_cr  
  -- rv16_format_ci  
  -- rv16_format_css 
  -- rv16_format_ciw 
  -- rv16_format_cl  
  -- rv16_format_cs  
  -- rv16_format_cb  
  -- rv16_format_cj  
  rv16_need_rs1  <= rv16_need_cr_rs1 or rv16_need_ci_rs1 or rv16_need_css_rs1;
  rv16_need_rs2  <= rv16_need_cr_rs2 or rv16_need_ci_rs2 or rv16_need_css_rs2;
  rv16_need_rd   <= rv16_need_cr_rd  or rv16_need_ci_rd  or rv16_need_css_rd;

  rv16_need_rss1 <= rv16_need_ciw_rss1 or rv16_need_cl_rss1 or rv16_need_cs_rss1 or rv16_need_cb_rss1 or rv16_need_cj_rss1;
  rv16_need_rss2 <= rv16_need_ciw_rss2 or rv16_need_cl_rss2 or rv16_need_cs_rss2 or rv16_need_cb_rss2 or rv16_need_cj_rss2;
  rv16_need_rdd  <= rv16_need_ciw_rdd  or rv16_need_cl_rdd  or rv16_need_cs_rdd  or rv16_need_cb_rdd  or rv16_need_cj_rdd ;

  rv16_rs1en <= (rv16_need_rs1 or rv16_need_rss1);
  rv16_rs2en <= (rv16_need_rs2 or rv16_need_rss2);
  rv16_rden  <= (rv16_need_rd  or rv16_need_rdd );

  rv16_rs1idx <= 
          ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cr_rs1  ) and rv16_cr_rs1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ci_rs1  ) and rv16_ci_rs1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_css_rs1 ) and rv16_css_rs1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ciw_rss1) and rv16_ciw_rss1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cl_rss1 ) and rv16_cl_rss1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cs_rss1 ) and rv16_cs_rss1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cb_rss1 ) and rv16_cb_rss1)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cj_rss1 ) and rv16_cj_rss1)
       ;

  rv16_rs2idx <= 
          ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cr_rs2  ) and rv16_cr_rs2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ci_rs2  ) and rv16_ci_rs2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_css_rs2 ) and rv16_css_rs2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ciw_rss2) and rv16_ciw_rss2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cl_rss2 ) and rv16_cl_rss2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cs_rss2 ) and rv16_cs_rss2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cb_rss2 ) and rv16_cb_rss2)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cj_rss2 ) and rv16_cj_rss2)
       ;

  rv16_rdidx <= 
          ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cr_rd  ) and rv16_cr_rd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ci_rd  ) and rv16_ci_rd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_css_rd ) and rv16_css_rd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_ciw_rdd) and rv16_ciw_rdd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cl_rdd ) and rv16_cl_rdd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cs_rdd ) and rv16_cs_rdd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cb_rdd ) and rv16_cb_rdd)
       or ((E203_RFIDX_WIDTH-1 downto 0 => rv16_need_cj_rdd ) and rv16_cj_rdd)
       ;

  dec_rs1idx <= rv32_rs1(E203_RFIDX_WIDTH-1 downto 0) when rv32 = '1' else rv16_rs1idx;
  dec_rs2idx <= rv32_rs2(E203_RFIDX_WIDTH-1 downto 0) when rv32 = '1' else rv16_rs2idx;
  dec_rdidx  <= rv32_rd (E203_RFIDX_WIDTH-1 downto 0) when rv32 = '1' else rv16_rdidx ;


  dec_rs1en <= rv32_need_rs1 when rv32 = '1' else (rv16_rs1en and (not (rv16_rs1idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '0')))); 
  dec_rs2en <= rv32_need_rs2 when rv32 = '1' else (rv16_rs2en and (not (rv16_rs2idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '0'))));
  dec_rdwen <= rv32_need_rd  when rv32 = '1' else (rv16_rden  and (not (rv16_rdidx  ?= (E203_RFIDX_WIDTH-1 downto 0 => '0'))));

  dec_rs1x0 <= (dec_rs1idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '0'));
  dec_rs2x0 <= (dec_rs2idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '0'));
                     
  `if E203_RFREG_NUM_IS_4 = "TRUE" then 
  rv_index_ilgl <=
                   (or(dec_rs1idx(E203_RFIDX_WIDTH-1 downto 2)))
                or (or(dec_rs2idx(E203_RFIDX_WIDTH-1 downto 2)))
                or (or(dec_rdidx (E203_RFIDX_WIDTH-1 downto 2)))
                ;
  `end if
  `if E203_RFREG_NUM_IS_8 = "TRUE" then 
  rv_index_ilgl <=
                   (or(dec_rs1idx(E203_RFIDX_WIDTH-1 downto 3)))
                or (or(dec_rs2idx(E203_RFIDX_WIDTH-1 downto 3)))
                or (or(dec_rdidx (E203_RFIDX_WIDTH-1 downto 3)))
                ;
  `end if
  `if E203_RFREG_NUM_IS_16 = "TRUE" then 
  rv_index_ilgl <=
                   (or(dec_rs1idx(E203_RFIDX_WIDTH-1 downto 4)))
                or (or(dec_rs2idx(E203_RFIDX_WIDTH-1 downto 4)))
                or (or(dec_rdidx (E203_RFIDX_WIDTH-1 downto 4)))
                ;
  `end if
  `if E203_RFREG_NUM_IS_32 = "TRUE" then
  -- Never happen this illegal exception
  rv_index_ilgl <= '0';
  `end if

  dec_rv32 <= rv32;

  dec_bjp_imm <= 
                    ((32-1 downto 0 => (rv16_jal or rv16_j    )) and rv16_jjal_imm)
                 or ((32-1 downto 0 => (rv16_jalr_mv_add      )) and rv16_jrjalr_imm)
                 or ((32-1 downto 0 => (rv16_beqz or rv16_bnez)) and rv16_bxx_imm)
                 or ((32-1 downto 0 => (rv32_jal              )) and rv32_jal_imm)
                 or ((32-1 downto 0 => (rv32_jalr             )) and rv32_jalr_imm)
                 or ((32-1 downto 0 => (rv32_branch           )) and rv32_bxx_imm)
                 ;

  dec_jalr_rs1idx <= rv32_rs1(E203_RFIDX_WIDTH-1 downto 0) when rv32 = '1' else 
                     rv16_rs1(E203_RFIDX_WIDTH-1 downto 0); 

  dec_misalgn <= i_misalgn;
  dec_buserr  <= i_buserr ;

  dec_ilegl <= 
             (rv_all0s1s_ilgl) 
          or (rv_index_ilgl) 
          or (rv16_addi16sp_ilgl)
          or (rv16_addi4spn_ilgl)
          or (rv16_li_lui_ilgl)
          or (rv16_sxxi_shamt_ilgl)
          or (rv32_sxxi_shamt_ilgl)
          or (rv32_dret_ilgl)
          or (rv16_lwsp_ilgl)
          or (not legl_ops);
end impl;