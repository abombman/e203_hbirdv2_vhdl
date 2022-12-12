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
--  This module to implement the 17cycles MUL and 33 cycles DIV unit, which is mostly 
--  share the datapath with ALU_DPATH module to save gatecount to mininum
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_SUPPORT_MULDIV = "TRUE" then
entity e203_exu_alu_muldiv is 
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
end e203_exu_alu_muldiv;

architecture impl of e203_exu_alu_muldiv is 
  signal muldiv_i_hsked: std_ulogic;
  signal muldiv_o_hsked: std_ulogic;
  signal flushed_r:      std_ulogic;
  signal flushed_set:    std_ulogic;
  signal flushed_clr:    std_ulogic;
  signal flushed_ena:    std_ulogic;
  signal flushed_nxt:    std_ulogic;

  signal i_mul:          std_ulogic;
  signal i_mulh:         std_ulogic;
  signal i_mulhsu:       std_ulogic;
  signal i_mulhu:        std_ulogic;
  signal i_div:          std_ulogic;
  signal i_divu:         std_ulogic;
  signal i_rem:          std_ulogic;
  signal i_remu:         std_ulogic;

  signal i_b2b:          std_ulogic;
  signal back2back_seq:  std_ulogic;

  signal mul_rs1_sign:   std_ulogic;
  signal mul_rs2_sign:   std_ulogic;

  signal mul_op1:        std_ulogic_vector(32 downto 0);
  signal mul_op2:        std_ulogic_vector(32 downto 0);

  signal i_op_mul:       std_ulogic;
  signal i_op_div:       std_ulogic;

  constant MULDIV_STATE_WIDTH: integer:= 3;

  signal muldiv_state_nxt: std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal muldiv_state_r:   std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal muldiv_state_ena: std_ulogic;

  -- State 0: The 0th state, means this is the 1 cycle see the operand inputs
  constant MULDIV_STATE_0TH:       std_ulogic_vector(2 downto 0):= "000";
  -- State 1: Executing the instructions
  constant MULDIV_STATE_EXEC:      std_ulogic_vector(2 downto 0):= "001";
  -- State 2: Div check if need correction
  constant MULDIV_STATE_REMD_CHCK: std_ulogic_vector(2 downto 0):= "010";
  -- State 3: Quotient correction
  constant MULDIV_STATE_QUOT_CORR: std_ulogic_vector(2 downto 0):= "011";
  -- State 4: Reminder correction
  constant MULDIV_STATE_REMD_CORR: std_ulogic_vector(2 downto 0):= "100";

  signal state_0th_nxt:            std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal state_exec_nxt:           std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal state_remd_chck_nxt:      std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal state_quot_corr_nxt:      std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);
  signal state_remd_corr_nxt:      std_ulogic_vector(MULDIV_STATE_WIDTH-1 downto 0);  
  signal state_0th_exit_ena:       std_ulogic;
  signal state_exec_exit_ena:      std_ulogic;
  signal state_remd_chck_exit_ena: std_ulogic;
  signal state_quot_corr_exit_ena: std_ulogic;
  signal state_remd_corr_exit_ena: std_ulogic;

  signal special_cases:            std_ulogic;
  signal muldiv_i_valid_nb2b:      std_ulogic;

  signal muldiv_sta_is_0th:        std_ulogic;
  signal muldiv_sta_is_exec:       std_ulogic;
  signal muldiv_sta_is_remd_chck:  std_ulogic;
  signal muldiv_sta_is_quot_corr:  std_ulogic;
  signal muldiv_sta_is_remd_corr:  std_ulogic;

  signal div_need_corrct:          std_ulogic;
  signal mul_exec_last_cycle:      std_ulogic;
  signal div_exec_last_cycle:      std_ulogic;
  signal exec_last_cycle:          std_ulogic;

  signal state_exec_enter_ena:     std_ulogic;

  constant EXEC_CNT_W:             integer:= 6;
  constant EXEC_CNT_1:             std_ulogic_vector(5 downto 0):= 6d"1";
  constant EXEC_CNT_16:            std_ulogic_vector(5 downto 0):= 6d"16";
  constant EXEC_CNT_32:            std_ulogic_vector(5 downto 0):= 6d"32";
  
  signal exec_cnt_r:               std_ulogic_vector(EXEC_CNT_W-1 downto 0);
  signal exec_cnt_set:             std_ulogic;
  signal exec_cnt_inc:             std_ulogic;
  signal exec_cnt_ena:             std_ulogic;
  signal exec_cnt_nxt:             std_ulogic_vector(EXEC_CNT_W-1 downto 0);

  signal cycle_0th:                std_ulogic;
  signal cycle_16th:               std_ulogic;
  signal cycle_32nd:               std_ulogic;

  signal part_prdt_hi_r:           std_ulogic_vector(32 downto 0);
  signal part_prdt_lo_r:           std_ulogic_vector(32 downto 0);
  signal part_prdt_hi_nxt:         std_ulogic_vector(32 downto 0);
  signal part_prdt_lo_nxt:         std_ulogic_vector(32 downto 0);

  signal part_prdt_sft1_r:         std_ulogic;
  signal booth_code:               std_ulogic_vector(2 downto 0);
  signal booth_sel_zero:           std_ulogic;
  signal booth_sel_two:            std_ulogic;
  signal booth_sel_one:            std_ulogic;
  signal booth_sel_sub:            std_ulogic;

  signal mul_exe_alu_res:          std_ulogic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0);
  signal mul_exe_alu_op2:          std_ulogic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0); 
  signal mul_exe_alu_op1:          std_ulogic_vector(E203_MULDIV_ADDER_WIDTH-1 downto 0);
  signal mul_exe_alu_add:          std_ulogic;
  signal mul_exe_alu_sub:          std_ulogic;

  signal part_prdt_sft1_nxt:       std_ulogic;
  signal mul_exe_cnt_set:          std_ulogic;
  signal mul_exe_cnt_inc:          std_ulogic;
  signal part_prdt_hi_ena:         std_ulogic;
  signal part_prdt_lo_ena:         std_ulogic;

  signal mul_res:                  std_ulogic_vector(E203_XLEN-1 downto 0);

  signal part_remd_r:              std_ulogic_vector(32 downto 0);
  signal part_quot_r:              std_ulogic_vector(32 downto 0);

  signal div_rs1_sign:             std_ulogic;
  signal div_rs2_sign:             std_ulogic;

  signal dividend:                 std_ulogic_vector(65 downto 0);
  signal divisor:                  std_ulogic_vector(33 downto 0);

  signal quot_0cycl:               std_ulogic;

  signal dividend_lsft1:           std_ulogic_vector(66 downto 0);

  signal prev_quot:                std_ulogic;

  signal part_remd_sft1_r:         std_ulogic;

  signal div_exe_alu_res:          std_ulogic_vector(33 downto 0);
  signal div_exe_alu_op1:          std_ulogic_vector(33 downto 0);
  signal div_exe_alu_op2:          std_ulogic_vector(33 downto 0);
  signal div_exe_alu_add:          std_ulogic;
  signal div_exe_alu_sub:          std_ulogic;

  signal current_quot:             std_ulogic;

  signal div_exe_part_remd:        std_ulogic_vector(66 downto 0);

  signal div_exe_part_remd_lsft1:  std_ulogic_vector(67 downto 0);

  signal part_remd_ena:            std_ulogic;

  signal div_exe_cnt_set:          std_ulogic;
  signal div_exe_cnt_inc:          std_ulogic;
  signal corrct_phase:             std_ulogic;
  signal check_phase:              std_ulogic;

  signal div_quot_corr_alu_res:    std_ulogic_vector(33 downto 0);
  signal div_remd_corr_alu_res:    std_ulogic_vector(33 downto 0);

  signal div_remd:                 std_ulogic_vector(32 downto 0);
  signal div_quot:                 std_ulogic_vector(32 downto 0);
  signal part_remd_nxt:            std_ulogic_vector(32 downto 0);
  signal part_quot_nxt:            std_ulogic_vector(32 downto 0);

  signal div_remd_chck_alu_res:    std_ulogic_vector(33 downto 0);
  signal div_remd_chck_alu_op1:    std_ulogic_vector(33 downto 0);
  signal div_remd_chck_alu_op2:    std_ulogic_vector(33 downto 0);

  signal div_remd_chck_alu_add:    std_ulogic;
  signal div_remd_chck_alu_sub:    std_ulogic;
  signal remd_is_0:                std_ulogic;
  signal remd_is_neg_divs:         std_ulogic;
  signal remd_is_divs:             std_ulogic;

  signal remd_inc_quot_dec:        std_ulogic;

  signal div_quot_corr_alu_op1:    std_ulogic_vector(33 downto 0);
  signal div_quot_corr_alu_op2:    std_ulogic_vector(33 downto 0);

  signal div_quot_corr_alu_add:    std_ulogic;
  signal div_quot_corr_alu_sub:    std_ulogic;

  signal div_remd_corr_alu_op1:    std_ulogic_vector(33 downto 0);
  signal div_remd_corr_alu_op2:    std_ulogic_vector(33 downto 0);

  signal div_remd_corr_alu_add:    std_ulogic;
  signal div_remd_corr_alu_sub:    std_ulogic;

  signal part_quot_ena:            std_ulogic;

  signal div_res:                  std_ulogic_vector(E203_XLEN-1 downto 0);

  signal div_by_0:                 std_ulogic;
  signal div_ovf:                  std_ulogic;

  signal div_by_0_res_quot:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal div_by_0_res_remd:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal div_by_0_res:             std_ulogic_vector(E203_XLEN-1 downto 0);

  signal div_ovf_res_quot:         std_ulogic_vector(E203_XLEN-1 downto 0);
  signal div_ovf_res_remd:         std_ulogic_vector(E203_XLEN-1 downto 0);
  signal div_ovf_res:              std_ulogic_vector(E203_XLEN-1 downto 0);

  signal div_special_cases:        std_ulogic;

  signal div_special_res:          std_ulogic_vector(E203_XLEN-1 downto 0);

  signal special_res:              std_ulogic_vector(E203_XLEN-1 downto 0);

  signal back2back_mul_res:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal back2back_mul_rem:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal back2back_mul_div:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal back2back_res:            std_ulogic_vector(E203_XLEN-1 downto 0);

  signal wbck_condi:               std_ulogic;

  signal res_sel_spl:              std_ulogic;
  signal res_sel_b2b:              std_ulogic;
  signal res_sel_div:              std_ulogic;
  signal res_sel_mul:              std_ulogic;

  signal req_alu_sel1:             std_ulogic;
  signal req_alu_sel2:             std_ulogic;
  signal req_alu_sel3:             std_ulogic;
  signal req_alu_sel4:             std_ulogic;
  signal req_alu_sel5:             std_ulogic;

  -------------------------------------------------------------------------------------
  -- System verilog assertion parameters,the function will be translated in the future. 
  -- signal golden0_mul_op1:          std_ulogic_vector(31 downto 0);
  -- signal golden0_mul_op2:          std_ulogic_vector(31 downto 0);
  -- signal golden0_mul_res_pre:      std_ulogic_vector(63 downto 0);
  -- signal golden0_mul_res:          std_ulogic_vector(63 downto 0);
  -- signal golden1_mul_res:          std_ulogic_vector(63 downto 0);
 
  -- signal golden1_res_mul:          std_ulogic_vector(31 downto 0);
  -- signal golden1_res_mulh:         std_ulogic_vector(31 downto 0);
  -- signal golden1_res_mulhsu:       std_ulogic_vector(31 downto 0);
  -- signal golden1_res_mulhu:        std_ulogic_vector(31 downto 0);
 
  -- signal golden2_res_mul_SxS:      std_ulogic_vector(63 downto 0);
  -- signal golden2_res_mul_SxU:      std_ulogic_vector(63 downto 0);
  -- signal golden2_res_mul_UxS:      std_ulogic_vector(63 downto 0);
  -- signal golden2_res_mul_UxU:      std_ulogic_vector(63 downto 0);
 
  -- signal golden2_res_mul:          std_ulogic_vector(31 downto 0);
  -- signal golden2_res_mulh:         std_ulogic_vector(31 downto 0);
  -- signal golden2_res_mulhsu:       std_ulogic_vector(31 downto 0);
  -- signal golden2_res_mulhu:        std_ulogic_vector(31 downto 0);
 
  -- signal golden_res_div:           std_ulogic_vector(32 downto 0);
  -- signal golden_res_divu:          std_ulogic_vector(32 downto 0);
  -- signal golden_res_rem:           std_ulogic_vector(32 downto 0);
  -- signal golden_res_remu:          std_ulogic_vector(32 downto 0);
 
  -- signal golden_res:               std_ulogic_vector(E203_XLEN-1 downto 0);
  -------------------------------------------------------------------------------------
  
  signal is_op_div:                std_ulogic;
  signal is_div_need_correct:      std_ulogic;
  signal part_rs1:                 std_ulogic_vector(30 downto 0);

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
  muldiv_i_hsked <= muldiv_i_valid and muldiv_i_ready;
  muldiv_o_hsked <= muldiv_o_valid and muldiv_o_ready;

  flushed_set <= flush_pulse;
  flushed_clr <= muldiv_o_hsked and (not flush_pulse);
  flushed_ena <= flushed_set or flushed_clr;
  flushed_nxt <= flushed_set or (not flushed_clr);
  flushed_dfflr: component sirv_gnrl_dfflr generic map (1)
                                              port map (lden    => flushed_ena, 
                                                        dnxt(0) => flushed_nxt, 
                                                        qout(0) => flushed_r, 
                                                        clk     => clk,
                                                        rst_n   => rst_n
                                                     );
  
  i_mul    <= muldiv_i_info(E203_DECINFO_MULDIV_MUL   'right); -- We treat this as signed X signed
  i_mulh   <= muldiv_i_info(E203_DECINFO_MULDIV_MULH  'right);
  i_mulhsu <= muldiv_i_info(E203_DECINFO_MULDIV_MULHSU'right);
  i_mulhu  <= muldiv_i_info(E203_DECINFO_MULDIV_MULHU 'right);
  i_div    <= muldiv_i_info(E203_DECINFO_MULDIV_DIV   'right);
  i_divu   <= muldiv_i_info(E203_DECINFO_MULDIV_DIVU  'right);
  i_rem    <= muldiv_i_info(E203_DECINFO_MULDIV_REM   'right);
  i_remu   <= muldiv_i_info(E203_DECINFO_MULDIV_REMU  'right);
  -- If it is flushed then it is not back2back real case
  i_b2b    <= muldiv_i_info(E203_DECINFO_MULDIV_B2B   'right) and (not flushed_r) and (not mdv_nob2b);

  back2back_seq <= i_b2b;

  mul_rs1_sign <= '0' when (i_mulhu)             = '1' else muldiv_i_rs1(E203_XLEN-1);
  mul_rs2_sign <= '0' when (i_mulhsu or i_mulhu) = '1' else muldiv_i_rs2(E203_XLEN-1);

  mul_op1 <= mul_rs1_sign & muldiv_i_rs1;
  mul_op2 <= mul_rs2_sign & muldiv_i_rs2;

  i_op_mul <= i_mul or i_mulh or i_mulhsu or i_mulhu;
  i_op_div <= i_div or i_divu or i_rem    or i_remu;


  --///////////////////////////////////////////////////////////////////////////////
  -- Implement the state machine for 
  --    (1) The MUL instructions
  --    (2) The DIV instructions
  muldiv_i_valid_nb2b <= muldiv_i_valid and (not back2back_seq) and (not special_cases);

  -- Define some common signals and reused later to save gatecounts
  muldiv_sta_is_0th       <= (muldiv_state_r ?= MULDIV_STATE_0TH      );
  muldiv_sta_is_exec      <= (muldiv_state_r ?= MULDIV_STATE_EXEC     );
  muldiv_sta_is_remd_chck <= (muldiv_state_r ?= MULDIV_STATE_REMD_CHCK);
  muldiv_sta_is_quot_corr <= (muldiv_state_r ?= MULDIV_STATE_QUOT_CORR);
  muldiv_sta_is_remd_corr <= (muldiv_state_r ?= MULDIV_STATE_REMD_CORR);

  -- **** If the current state is 0th,
  -- If a new instruction come (non back2back), next state is MULDIV_STATE_EXEC
  state_0th_exit_ena <= muldiv_sta_is_0th and muldiv_i_valid_nb2b and (not flush_pulse);
  state_0th_nxt      <= MULDIV_STATE_EXEC;

  -- **** If the current state is exec,
                      -- If it is div op, then jump to DIV_CHECK state
  is_op_div           <= '1' when i_op_div = '1' else
                      -- If it is not div-need-correction, then jump to 0th
                         muldiv_o_hsked;
  state_exec_exit_ena <=  muldiv_sta_is_exec and (
                      -- If it is the last cycle (16th or 32rd cycles), 
                          (exec_last_cycle and is_op_div)
                          or flush_pulse);
  state_exec_nxt      <= 
                         MULDIV_STATE_0TH when flush_pulse = '1' else
                      -- If it is div op, then jump to DIV_CHECK state
                         MULDIV_STATE_REMD_CHCK when i_op_div = '1' else
                      -- If it is not div-need-correction, then jump to 0th 
                         MULDIV_STATE_0TH
                        ;

  -- **** If the current state is REMD_CHCK,
  -- If it is div-need-correction, then jump to QUOT_CORR state
  --   otherwise jump to the 0th
                           -- If it is div op, then jump to DIV_CHECK state
  is_div_need_correct      <= '1' when div_need_corrct = '1' else
                           -- If it is not div-need-correction, then jump to 0th
                              muldiv_o_hsked;
  state_remd_chck_exit_ena <= muldiv_sta_is_remd_chck and (is_div_need_correct or flush_pulse );
  state_remd_chck_nxt      <= MULDIV_STATE_0TH when flush_pulse = '1' else
                           -- If it is div-need-correction, then jump to QUOT_CORR state
                              MULDIV_STATE_QUOT_CORR when div_need_corrct = '1' else
                           -- If it is not div-need-correction, then jump to 0th 
                              MULDIV_STATE_0TH;

  -- **** If the current state is QUOT_CORR,
  -- Always jump to REMD_CORR state
  state_quot_corr_exit_ena <= (muldiv_sta_is_quot_corr and (flush_pulse or '1'));
  state_quot_corr_nxt      <= MULDIV_STATE_0TH when flush_pulse = '1' else MULDIV_STATE_REMD_CORR;

                
  -- **** If the current state is REMD_CORR,
  -- Then jump to 0th 
  state_remd_corr_exit_ena <= (muldiv_sta_is_remd_corr and (flush_pulse or muldiv_o_hsked));
  state_remd_corr_nxt      <= MULDIV_STATE_0TH when flush_pulse = '1' else MULDIV_STATE_0TH;

  -- The state will only toggle when each state is meeting the condition to exit 
  muldiv_state_ena <= state_0th_exit_ena 
                   or state_exec_exit_ena  
                   or state_remd_chck_exit_ena  
                   or state_quot_corr_exit_ena  
                   or state_remd_corr_exit_ena;  

  -- The next-state is onehot mux to select different entries
  muldiv_state_nxt <= 
                      ((MULDIV_STATE_WIDTH-1 downto 0 => state_0th_exit_ena      ) and state_0th_nxt      )
                   or ((MULDIV_STATE_WIDTH-1 downto 0 => state_exec_exit_ena     ) and state_exec_nxt     )
                   or ((MULDIV_STATE_WIDTH-1 downto 0 => state_remd_chck_exit_ena) and state_remd_chck_nxt)
                   or ((MULDIV_STATE_WIDTH-1 downto 0 => state_quot_corr_exit_ena) and state_quot_corr_nxt)
                   or ((MULDIV_STATE_WIDTH-1 downto 0 => state_remd_corr_exit_ena) and state_remd_corr_nxt)
                      ;

  muldiv_state_dfflr: component sirv_gnrl_dfflr generic map (MULDIV_STATE_WIDTH) 
                                                   port map (muldiv_state_ena, muldiv_state_nxt, muldiv_state_r, clk, rst_n);

  state_exec_enter_ena <= muldiv_state_ena and (muldiv_state_nxt ?= MULDIV_STATE_EXEC);

  exec_cnt_set <= state_exec_enter_ena;
  exec_cnt_inc <= muldiv_sta_is_exec and (not exec_last_cycle); 
  exec_cnt_ena <= exec_cnt_inc or exec_cnt_set; 
  -- When set, the counter is set to 1, because the 0th state also counted as 0th cycle
  exec_cnt_nxt <= EXEC_CNT_1 when exec_cnt_set = '1' else std_ulogic_vector(u_unsigned(exec_cnt_r) + 1); -- There is another technique in "Digital Design Using VHDL" on page 257.
  exec_cnt_dfflr: component sirv_gnrl_dfflr generic map (EXEC_CNT_W) 
                                              port map (exec_cnt_ena, exec_cnt_nxt, exec_cnt_r, clk, rst_n);
  -- The exec state is the last cycle when the exec_cnt_r is reaching the last cycle (16 or 32cycles)

  cycle_0th  <= muldiv_sta_is_0th;
  cycle_16th <= (exec_cnt_r ?= EXEC_CNT_16);
  cycle_32nd <= (exec_cnt_r ?= EXEC_CNT_32);
  mul_exec_last_cycle <= cycle_16th;
  div_exec_last_cycle <= cycle_32nd;
  exec_last_cycle <= mul_exec_last_cycle when i_op_mul = '1' else div_exec_last_cycle;

  -- Use booth-4 algorithm to conduct the multiplication
  booth_code <= (muldiv_i_rs1(1 downto 0) & '0') when cycle_0th = '1' else
                (mul_rs1_sign & part_prdt_lo_r(0) & part_prdt_sft1_r) when cycle_16th = '1' else
                (part_prdt_lo_r(1 downto 0) & part_prdt_sft1_r);
  -- booth_code == 3'b000 =  0
  -- booth_code == 3'b001 =  1
  -- booth_code == 3'b010 =  1
  -- booth_code == 3'b011 =  2
  -- booth_code == 3'b100 = -2
  -- booth_code == 3'b101 = -1
  -- booth_code == 3'b110 = -1
  -- booth_code == 3'b111 = -0
  booth_sel_zero <= (booth_code ?= 3b"000") or (booth_code ?= 3b"111");
  booth_sel_two  <= (booth_code ?= 3b"011") or (booth_code ?= 3b"100");
  booth_sel_one  <= (not booth_sel_zero) and (not booth_sel_two);
  booth_sel_sub  <= booth_code(2);  

  -- 35 bits adder needed
  mul_exe_alu_res <= muldiv_req_alu_res;
  mul_exe_alu_op2 <= 
                     ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => booth_sel_zero) and (E203_MULDIV_ADDER_WIDTH-1 downto 0 => '0')) 
                  or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => booth_sel_one ) and (mul_rs2_sign & mul_rs2_sign & mul_rs2_sign & muldiv_i_rs2)) 
                  or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => booth_sel_two ) and (mul_rs2_sign & mul_rs2_sign & muldiv_i_rs2 & '0')) 
                    ;
  mul_exe_alu_op1 <= (E203_MULDIV_ADDER_WIDTH-1 downto 0 => '0') when cycle_0th = '1' else
                     (part_prdt_hi_r(32) & part_prdt_hi_r(32) & part_prdt_hi_r);  
  mul_exe_alu_add <= (not booth_sel_sub);
  mul_exe_alu_sub <= booth_sel_sub;

  part_prdt_hi_nxt <= mul_exe_alu_res(34 downto 2);
  part_rs1         <= (mul_rs1_sign & muldiv_i_rs1(31 downto 2)) when cycle_0th = '1' else part_prdt_lo_r(32 downto 2);
  part_prdt_lo_nxt <= (mul_exe_alu_res(1 downto 0) & part_rs1);

  part_prdt_sft1_nxt <= muldiv_i_rs1(1) when cycle_0th = '1' else part_prdt_lo_r(1);

  mul_exe_cnt_set <= exec_cnt_set and i_op_mul;
  mul_exe_cnt_inc <= exec_cnt_inc and i_op_mul; 

  part_prdt_hi_ena <= mul_exe_cnt_set or mul_exe_cnt_inc or state_exec_exit_ena;
  part_prdt_lo_ena <= part_prdt_hi_ena;
  part_prdt_sft1_dfflr: component sirv_gnrl_dfflr generic map (1)
                                              port map (lden    => part_prdt_lo_ena, 
                                                        dnxt(0) => part_prdt_sft1_nxt, 
                                                        qout(0) => part_prdt_sft1_r, 
                                                        clk     => clk,
                                                        rst_n   => rst_n
                                                     );

  -- This mul_res is not back2back case, so directly from the adder result
  mul_res <= part_prdt_lo_r(32 downto 1) when i_mul = '1' else mul_exe_alu_res(31 downto 0);

  -- The Divider Implementation, using the non-restoring signed division 
  div_rs1_sign <= '0' when (i_divu or i_remu) = '1' else muldiv_i_rs1(E203_XLEN-1);
  div_rs2_sign <= '0' when (i_divu or i_remu) = '1' else muldiv_i_rs2(E203_XLEN-1);

  dividend <= ((33-1 downto 0 => div_rs1_sign) & div_rs1_sign & muldiv_i_rs1);
  divisor  <= (div_rs2_sign & div_rs2_sign & muldiv_i_rs2);

  quot_0cycl <= '0' when (dividend(65) xor divisor(33)) = '1' else '1'; -- If the sign(s0)!=sign(d), then set q_1st = -1

  dividend_lsft1 <= (dividend(65 downto 0) & quot_0cycl);

  prev_quot <= quot_0cycl when cycle_0th = '1' else part_quot_r(0);

  -- 34 bits adder needed
  div_exe_alu_res <= muldiv_req_alu_res(33 downto 0);
  div_exe_alu_op1 <= dividend_lsft1(66 downto 33) when cycle_0th = '1' else (part_remd_sft1_r & part_remd_r(32 downto 0));
  div_exe_alu_op2 <= divisor;
  div_exe_alu_add <= (not prev_quot);
  div_exe_alu_sub <=      prev_quot ;

  current_quot <= '0' when (div_exe_alu_res(33) xor divisor(33)) = '1' else '1';

  div_exe_part_remd(66 downto 33) <= div_exe_alu_res;
  div_exe_part_remd(32 downto  0) <= dividend_lsft1(32 downto 0) when cycle_0th = '1' else part_quot_r(32 downto 0);

  div_exe_part_remd_lsft1 <= (div_exe_part_remd(66 downto 0) & current_quot);

  -- Since the part_remd_r is only save 33bits (after left shifted), so the adder result MSB bit we need to save
  --   it here, which will be used at next round
  part_remd_sft1_dfflr: component sirv_gnrl_dfflr generic map (1)
                                              port map (lden    => part_remd_ena, 
                                                        dnxt(0) => div_exe_alu_res(32), 
                                                        qout(0) => part_remd_sft1_r, 
                                                        clk     => clk,
                                                        rst_n   => rst_n
                                                     );
  
  div_exe_cnt_set <= exec_cnt_set and i_op_div;
  div_exe_cnt_inc <= exec_cnt_inc and i_op_div; 

  corrct_phase <= muldiv_sta_is_remd_corr or muldiv_sta_is_quot_corr;
  check_phase  <= muldiv_sta_is_remd_chck;

  -- Note: in last cycle, the reminder value is the non-shifted value
  --   but the quotient value is the shifted value, and last bit of quotient value is shifted always by 1 
  -- If need corrective, the correct quot first, and then reminder, so reminder output as comb logic directly to 
  -- save a cycle
  div_remd <= part_remd_r(32 downto 0) when check_phase = '1' else
              div_remd_corr_alu_res(32 downto 0) when corrct_phase = '1' else
              div_exe_part_remd(65 downto 33);
  div_quot <= part_quot_r(32 downto 0) when check_phase = '1' else
              part_quot_r(32 downto 0) when corrct_phase = '1' else
              (div_exe_part_remd(31 downto 0) & '1');

  -- The partial reminder and quotient   
  part_remd_nxt <= div_remd_corr_alu_res(32 downto 0) when corrct_phase = '1' else
                   div_remd when (muldiv_sta_is_exec and div_exec_last_cycle) = '1' else
                   div_exe_part_remd_lsft1(65 downto 33);
  part_quot_nxt <= div_quot_corr_alu_res(32 downto 0) when corrct_phase = '1' else
                   div_quot when (muldiv_sta_is_exec and div_exec_last_cycle) = '1' else
                   div_exe_part_remd_lsft1(32 downto 0);

  div_remd_chck_alu_res <= muldiv_req_alu_res(33 downto 0);
  div_remd_chck_alu_op1 <= (part_remd_r(32) & part_remd_r);
  div_remd_chck_alu_op2 <= divisor;
  div_remd_chck_alu_add <= '1';
  div_remd_chck_alu_sub <= '0';

  remd_is_0 <= not(or(part_remd_r));
  remd_is_neg_divs <= not(or(div_remd_chck_alu_res)); 
  remd_is_divs <= (part_remd_r ?= divisor(32 downto 0));
  div_need_corrct <= i_op_div and (
                         ((part_remd_r(32) xor dividend(65)) and (not remd_is_0))
                       or remd_is_neg_divs
                       or remd_is_divs
                     );

  remd_inc_quot_dec <= (part_remd_r(32) xor divisor(33));

  div_quot_corr_alu_res <= muldiv_req_alu_res(33 downto 0);
  div_quot_corr_alu_op1 <= (part_quot_r(32) & part_quot_r);
  div_quot_corr_alu_op2 <= 34b"1";
  div_quot_corr_alu_add <= (not remd_inc_quot_dec);
  div_quot_corr_alu_sub <= remd_inc_quot_dec;

  div_remd_corr_alu_res <= muldiv_req_alu_res(33 downto 0);
  div_remd_corr_alu_op1 <= (part_remd_r(32) & part_remd_r);
  div_remd_corr_alu_op2 <= divisor;
  div_remd_corr_alu_add <= remd_inc_quot_dec;
  div_remd_corr_alu_sub <= not remd_inc_quot_dec;

  -- The partial reminder register will be loaded in the exe state, and in reminder correction cycle
  part_remd_ena <= div_exe_cnt_set or div_exe_cnt_inc or state_exec_exit_ena or state_remd_corr_exit_ena;
  -- The partial quotient register will be loaded in the exe state, and in quotient correction cycle
  part_quot_ena <= div_exe_cnt_set or div_exe_cnt_inc or state_exec_exit_ena or state_quot_corr_exit_ena;

  div_res <= div_quot(E203_XLEN-1 downto 0) when (i_div or i_divu) = '1' else div_remd(E203_XLEN-1 downto 0);

  div_by_0 <= not (or(muldiv_i_rs2)); -- Divisor is all zeros
  div_ovf  <= (i_div or i_rem) and (and(muldiv_i_rs2))  -- Divisor is all ones, means -1
           -- Dividend is 10000...000, means -(2^xlen -1)
              and muldiv_i_rs1(E203_XLEN-1) and (not(or(muldiv_i_rs1(E203_XLEN-2 downto 0))));

  div_by_0_res_quot <= not (E203_XLEN-1 downto 0 => '0');
  div_by_0_res_remd <= dividend(E203_XLEN-1 downto 0);
  div_by_0_res <= div_by_0_res_quot when (i_div or i_divu) = '1' else div_by_0_res_remd;

  div_ovf_res_quot  <= ('1' & (E203_XLEN-1-1 downto 0 => '0'));
  div_ovf_res_remd  <= (E203_XLEN-1 downto 0 => '0');
  div_ovf_res <= div_ovf_res_quot when (i_div or i_divu) = '1' else div_ovf_res_remd;

  div_special_cases <= i_op_div and (div_by_0 or div_ovf);
  div_special_res <= div_by_0_res when div_by_0 = '1' else div_ovf_res;

  -- Output generateion
  special_cases <= div_special_cases; -- Only divider have special cases
  special_res <= div_special_res; -- Only divider have special cases

  -- To detect the sequence of MULH[[S]U] rdh, rs1, rs2;    MUL rdl, rs1, rs2
  -- To detect the sequence of     DIV[U] rdq, rs1, rs2; REM[U] rdr, rs1, rs2  
  back2back_mul_res <= (part_prdt_lo_r(E203_XLEN-2 downto 0) & part_prdt_sft1_r); -- Only the MUL will be treated as back2back
  back2back_mul_rem <= part_remd_r(E203_XLEN-1 downto 0);
  back2back_mul_div <= part_quot_r(E203_XLEN-1 downto 0);
  back2back_res <= (
                       ((E203_XLEN-1 downto 0 => (i_mul          )) and back2back_mul_res)
                    or ((E203_XLEN-1 downto 0 => (i_rem or i_remu)) and back2back_mul_rem)
                    or ((E203_XLEN-1 downto 0 => (i_div or i_divu)) and back2back_mul_div)
                   );

  -- The output will be valid:
  --   * If it is back2back and sepcial cases, just directly pass out from input
  --   * If it is not back2back sequence when it is the last cycle of exec state 
  --     (not div need correction) or last correct state;
  wbck_condi <= '1' when (back2back_seq or special_cases) = '1' else 
                (
                     (muldiv_sta_is_exec and exec_last_cycle and (not i_op_div))
                  or (muldiv_sta_is_remd_chck and (not div_need_corrct)) 
                  or muldiv_sta_is_remd_corr 
                );
  muldiv_o_valid <= wbck_condi and muldiv_i_valid;
  muldiv_i_ready <= wbck_condi and muldiv_o_ready;
  res_sel_spl  <= special_cases;
  res_sel_b2b  <= back2back_seq and (not special_cases);
  res_sel_div  <= (not back2back_seq) and (not special_cases) and i_op_div;
  res_sel_mul  <= (not back2back_seq) and (not special_cases) and i_op_mul;
  muldiv_o_wbck_wdat <= 
                        ((E203_XLEN-1 downto 0 => res_sel_b2b) and back2back_res)
                     or ((E203_XLEN-1 downto 0 => res_sel_spl) and special_res)
                     or ((E203_XLEN-1 downto 0 => res_sel_div) and div_res)
                     or ((E203_XLEN-1 downto 0 => res_sel_mul) and mul_res);

  -- There is no exception cases for MULDIV, so no addtional cmt signals
  muldiv_o_wbck_err <= '0';

  -- The operands and info to ALU
  req_alu_sel1 <= i_op_mul;
  req_alu_sel2 <= i_op_div and (muldiv_sta_is_0th or muldiv_sta_is_exec);
  req_alu_sel3 <= i_op_div and muldiv_sta_is_quot_corr;
  req_alu_sel4 <= i_op_div and muldiv_sta_is_remd_corr;
  req_alu_sel5 <= i_op_div and muldiv_sta_is_remd_chck;

  muldiv_req_alu_op1 <= 
                        ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel1) and mul_exe_alu_op1)
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel2) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_exe_alu_op1      ))
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel3) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_quot_corr_alu_op1))
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel4) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_remd_corr_alu_op1)) 
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel5) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_remd_chck_alu_op1));

  muldiv_req_alu_op2 <= 
                        ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel1) and mul_exe_alu_op2)
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel2) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_exe_alu_op2      ))
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel3) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_quot_corr_alu_op2))
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel4) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_remd_corr_alu_op2)) 
                     or ((E203_MULDIV_ADDER_WIDTH-1 downto 0 => req_alu_sel5) and ((E203_MULDIV_ADDER_WIDTH-34-1 downto 0 => '0') & div_remd_chck_alu_op2));

  muldiv_req_alu_add <= 
                        (req_alu_sel1 and mul_exe_alu_add      )
                     or (req_alu_sel2 and div_exe_alu_add      )
                     or (req_alu_sel3 and div_quot_corr_alu_add)
                     or (req_alu_sel4 and div_remd_corr_alu_add) 
                     or (req_alu_sel5 and div_remd_chck_alu_add);

  muldiv_req_alu_sub <= 
                        (req_alu_sel1 and mul_exe_alu_sub      )
                     or (req_alu_sel2 and div_exe_alu_sub      )
                     or (req_alu_sel3 and div_quot_corr_alu_sub)
                     or (req_alu_sel4 and div_remd_corr_alu_sub) 
                     or (req_alu_sel5 and div_remd_chck_alu_sub);

  muldiv_sbf_0_ena <= part_remd_ena or part_prdt_hi_ena;
  muldiv_sbf_0_nxt <= part_prdt_hi_nxt when i_op_mul = '1' else part_remd_nxt;

  muldiv_sbf_1_ena <= part_quot_ena or part_prdt_lo_ena;
  muldiv_sbf_1_nxt <= part_prdt_lo_nxt when i_op_mul = '1' else part_quot_nxt;

  part_remd_r <= muldiv_sbf_0_r;
  part_quot_r <= muldiv_sbf_1_r;
  part_prdt_hi_r <= muldiv_sbf_0_r;
  part_prdt_lo_r <= muldiv_sbf_1_r;

  muldiv_i_longpipe <= '0';

---------------------------------------------------------------------------------------
`if FPGA_SOURCE = "FALSE" then
`if DISABLE_SV_ASSERTION = "FALSE" then
//synopsys translate_off
  -- These below code are used for reference check with assertion
  wire [31:0] golden0_mul_op1 = mul_op1[32] ? (~mul_op1[31:0]+1) : mul_op1[31:0];
  wire [31:0] golden0_mul_op2 = mul_op2[32] ? (~mul_op2[31:0]+1) : mul_op2[31:0];
  wire [63:0] golden0_mul_res_pre = golden0_mul_op1 * golden0_mul_op2;
  wire [63:0] golden0_mul_res = (mul_op1[32]^mul_op2[32]) ? (~golden0_mul_res_pre + 1) : golden0_mul_res_pre;
  wire [63:0] golden1_mul_res = $signed(mul_op1) * $signed(mul_op2); 
  
  // To check the signed * operation is really get what we wanted
    CHECK_SIGNED_OP_CORRECT:
      assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))  ((golden0_mul_res == golden1_mul_res)))
      else $fatal ("\n Error: Oops, This should never happen. \n");

  wire [31:0] golden1_res_mul    = golden1_mul_res[31:0];
  wire [31:0] golden1_res_mulh   = golden1_mul_res[63:32];                       
  wire [31:0] golden1_res_mulhsu = golden1_mul_res[63:32];                                              
  wire [31:0] golden1_res_mulhu  = golden1_mul_res[63:32];                                                

  wire [63:0] golden2_res_mul_SxS = $signed(muldiv_i_rs1)   * $signed(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_SxU = $signed(muldiv_i_rs1)   * $unsigned(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_UxS = $unsigned(muldiv_i_rs1) * $signed(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_UxU = $unsigned(muldiv_i_rs1) * $unsigned(muldiv_i_rs2);
  
  wire [31:0] golden2_res_mul    = golden2_res_mul_SxS[31:0];
  wire [31:0] golden2_res_mulh   = golden2_res_mul_SxS[63:32];                       
  wire [31:0] golden2_res_mulhsu = golden2_res_mul_SxU[63:32];                                              
  wire [31:0] golden2_res_mulhu  = golden2_res_mul_UxU[63:32];                                                

  // To check four different combination will all generate same lower 32bits result
    CHECK_FOUR_COMB_SAME_RES:
      assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))
          (golden2_res_mul_SxS[31:0] == golden2_res_mul_SxU[31:0])
        & (golden2_res_mul_UxS[31:0] == golden2_res_mul_UxU[31:0])
        & (golden2_res_mul_SxU[31:0] == golden2_res_mul_UxS[31:0])
       )
      else $fatal ("\n Error: Oops, This should never happen. \n");

  // Seems the golden2 result is not correct in case of mulhsu, so have to comment it out
  // // To check golden1 and golden2 result are same
  // // CHECK_GOLD1_AND_GOLD2_SAME:
  // // assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))
  // //      (i_mul    ? (golden1_res_mul    == golden2_res_mul   ) : 1'b1)
  // //     &(i_mulh   ? (golden1_res_mulh   == golden2_res_mulh  ) : 1'b1)
  // //     &(i_mulhsu ? (golden1_res_mulhsu == golden2_res_mulhsu) : 1'b1)
  // //     &(i_mulhu  ? (golden1_res_mulhu  == golden2_res_mulhu ) : 1'b1)
  // //   )
  // // else $fatal ("\n Error: Oops, This should never happen. \n");
      
  -- The special case will need to be handled specially
  wire [32:0] golden_res_div  = div_special_cases ? div_special_res : 
     (  $signed({div_rs1_sign,muldiv_i_rs1})   / ((div_by_0 | div_ovf) ? 1 :   $signed({div_rs2_sign,muldiv_i_rs2})));
  wire [32:0] golden_res_divu  = div_special_cases ? div_special_res : 
     ($unsigned({div_rs1_sign,muldiv_i_rs1})   / ((div_by_0 | div_ovf) ? 1 : $unsigned({div_rs2_sign,muldiv_i_rs2})));
  wire [32:0] golden_res_rem  = div_special_cases ? div_special_res : 
     (  $signed({div_rs1_sign,muldiv_i_rs1})   % ((div_by_0 | div_ovf) ? 1 :   $signed({div_rs2_sign,muldiv_i_rs2})));
  wire [32:0] golden_res_remu  = div_special_cases ? div_special_res : 
     ($unsigned({div_rs1_sign,muldiv_i_rs1})   % ((div_by_0 | div_ovf) ? 1 : $unsigned({div_rs2_sign,muldiv_i_rs2})));
 
  // To check golden and actual result are same
  wire [`E203_XLEN-1:0] golden_res = 
         i_mul    ? golden1_res_mul    :
         i_mulh   ? golden1_res_mulh   :
         i_mulhsu ? golden1_res_mulhsu :
         i_mulhu  ? golden1_res_mulhu  :
         i_div    ? golden_res_div [31:0]    :
         i_divu   ? golden_res_divu[31:0]    :
         i_rem    ? golden_res_rem [31:0]    :
         i_remu   ? golden_res_remu[31:0]    :
                    `E203_XLEN'b0;

  CHECK_GOLD_AND_ACTUAL_SAME:
    // Since the printed value is not aligned with posedge clock, so change it to negetive
    assert property (@(negedge clk) disable iff ((~rst_n) | flush_pulse)
        (muldiv_o_valid ? (golden_res == muldiv_o_wbck_wdat   ) : 1'b1)
     )
    else begin
        $display("??????????????????????????????????????????");
        $display("??????????????????????????????????????????");
        $display("{i_mul,i_mulh,i_mulhsu,i_mulhu,i_div,i_divu,i_rem,i_remu}=%d%d%d%d%d%d%d%d",i_mul,i_mulh,i_mulhsu,i_mulhu,i_div,i_divu,i_rem,i_remu);
        $display("muldiv_i_rs1=%h\nmuldiv_i_rs2=%h\n",muldiv_i_rs1,muldiv_i_rs2);     
        $display("golden_res=%h\nmuldiv_o_wbck_wdat=%h",golden_res,muldiv_o_wbck_wdat);     
        $display("??????????????????????????????????????????");
        $fatal ("\n Error: Oops, This should never happen. \n");
      end

//synopsys translate_on
`end if
`end if
end impl;
`end if