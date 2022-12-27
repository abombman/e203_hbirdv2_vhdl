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
--    The CPU module to implement Core and other top level glue logics
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_NICE = "TRUE" then
entity e203_subsys_nice_core is 
  port( -- System
  	    nice_clk:         in std_logic;  
        nice_rst_n:       in std_logic;
        nice_active:     out std_logic; 
        nice_mem_holdup: out std_logic;

        -- Control cmd_req
        nice_req_valid:   in std_logic; 
  	    nice_req_ready:  out std_logic; 
  	    nice_req_inst:    in std_logic_vector(E203_XLEN-1 downto 0);
        nice_req_rs1:     in std_logic_vector(E203_XLEN-1 downto 0);
        nice_req_rs2:     in std_logic_vector(E203_XLEN-1 downto 0);

        -- Control cmd_rsp
        nice_rsp_valid:  out std_logic; 
        nice_rsp_ready:   in std_logic;  
        nice_rsp_rdat:   out std_logic_vector(E203_XLEN-1 downto 0);
        nice_rsp_err:    out std_logic;

        -- Memory lsu_req
        nice_icb_cmd_valid: out std_logic; 
        nice_icb_cmd_ready:  in std_logic;  
        nice_icb_cmd_addr:  out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
        nice_icb_cmd_read:  out std_logic;
        nice_icb_cmd_wdata: out std_logic_vector(E203_XLEN-1 downto 0);
        nice_icb_cmd_size:  out std_logic_vector(1 downto 0);

        -- Memory lsu_rsp
        nice_icb_rsp_valid:  in std_logic; 
  	    nice_icb_rsp_ready: out std_logic; 
  	    nice_icb_rsp_rdata:  in std_logic_vector(E203_XLEN-1 downto 0);
        nice_icb_rsp_err:    in std_logic
  	);
end e203_subsys_nice_core;

architecture impl of e203_subsys_nice_core is 
  constant ROWBUF_DP:    integer:= 4;
  constant ROWBUF_IDX_W: integer:= 2;
  constant ROW_IDX_W:    integer:= 2;
  constant COL_IDX_W:    integer:= 4;
  constant PIPE_NUM:     integer:= 3;

  signal opcode    :     std_ulogic_vector(6 downto 0);
  signal rv32_func3:     std_ulogic_vector(2 downto 0);
  signal rv32_func7:     std_ulogic_vector(6 downto 0);

  signal opcode_custom3: std_ulogic; 

  signal rv32_func3_000: std_ulogic; 
  signal rv32_func3_001: std_ulogic; 
  signal rv32_func3_010: std_ulogic; 
  signal rv32_func3_011: std_ulogic; 
  signal rv32_func3_100: std_ulogic; 
  signal rv32_func3_101: std_ulogic; 
  signal rv32_func3_110: std_ulogic; 
  signal rv32_func3_111: std_ulogic; 

  signal rv32_func7_0000000: std_ulogic; 
  signal rv32_func7_0000001: std_ulogic; 
  signal rv32_func7_0000010: std_ulogic; 
  signal rv32_func7_0000011: std_ulogic; 
  signal rv32_func7_0000100: std_ulogic; 
  signal rv32_func7_0000101: std_ulogic; 
  signal rv32_func7_0000110: std_ulogic; 
  signal rv32_func7_0000111: std_ulogic; 
  
  signal custom3_lbuf  :     std_ulogic; 
  signal custom3_sbuf  :     std_ulogic; 
  signal custom3_rowsum:     std_ulogic; 

  signal custom_multi_cyc_op: std_ulogic;
  
  signal custom_mem_op:       std_ulogic;
 
  constant NICE_FSM_WIDTH:    integer:= 2; 
  constant IDLE          :    std_ulogic_vector(1 downto 0):= 2d"0"; 
  constant LBUF          :    std_ulogic_vector(1 downto 0):= 2d"1"; 
  constant SBUF          :    std_ulogic_vector(1 downto 0):= 2d"2"; 
  constant ROWSUM        :    std_ulogic_vector(1 downto 0):= 2d"3"; 

  signal state_r:             std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 
  signal nxt_state:           std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 
  signal state_idle_nxt:      std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 
  signal state_lbuf_nxt:      std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 
  signal state_sbuf_nxt:      std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 
  signal state_rowsum_nxt:    std_ulogic_vector(NICE_FSM_WIDTH-1 downto 0); 

  signal nice_req_hsked:      std_ulogic;
  signal nice_rsp_hsked:      std_ulogic;
  signal nice_icb_rsp_hsked:  std_ulogic;
  signal illgel_instr:        std_ulogic;

  signal state_idle_exit_ena: std_ulogic; 
  signal state_lbuf_exit_ena: std_ulogic; 
  signal state_sbuf_exit_ena: std_ulogic; 
  signal state_rowsum_exit_ena: std_ulogic; 
  signal state_ena:             std_ulogic; 

  signal state_is_idle  :       std_ulogic; 
  signal state_is_lbuf  :       std_ulogic; 
  signal state_is_sbuf  :       std_ulogic; 
  signal state_is_rowsum:       std_ulogic; 

  signal lbuf_icb_rsp_hsked_last: std_ulogic; 
  
  signal sbuf_icb_rsp_hsked_last: std_ulogic; 
 
  signal rowsum_done:             std_ulogic; 
 
  constant clonum:                std_ulogic_vector(ROW_IDX_W-1 downto 0):= "10";  -- fixed clonum
  
  signal lbuf_cnt_r:              std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal lbuf_cnt_nxt:            std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal lbuf_cnt_clr:            std_ulogic;
  signal lbuf_cnt_incr:           std_ulogic;
  signal lbuf_cnt_ena:            std_ulogic;
  signal lbuf_cnt_last:           std_ulogic;
  signal lbuf_icb_rsp_hsked:      std_ulogic;
  signal nice_rsp_valid_lbuf:     std_ulogic;
  signal nice_icb_cmd_valid_lbuf: std_ulogic;

  signal sbuf_cnt_r:              std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal sbuf_cnt_nxt:            std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal sbuf_cnt_clr:            std_ulogic;
  signal sbuf_cnt_incr:           std_ulogic;
  signal sbuf_cnt_ena:            std_ulogic;
  signal sbuf_cnt_last:           std_ulogic;
  signal sbuf_icb_cmd_hsked:      std_ulogic;
  signal sbuf_icb_rsp_hsked:      std_ulogic;
  signal nice_rsp_valid_sbuf:     std_ulogic;
  signal nice_icb_cmd_valid_sbuf: std_ulogic;
  signal nice_icb_cmd_hsked:      std_ulogic;

  signal sbuf_cmd_cnt_r:          std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal sbuf_cmd_cnt_nxt:        std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal sbuf_cmd_cnt_clr:        std_ulogic;
  signal sbuf_cmd_cnt_incr:       std_ulogic;
  signal sbuf_cmd_cnt_ena:        std_ulogic;
  signal sbuf_cmd_cnt_last:       std_ulogic;

  signal rowbuf_cnt_r:            std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal rowbuf_cnt_nxt:          std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal rowbuf_cnt_clr:          std_ulogic;
  signal rowbuf_cnt_incr:         std_ulogic;
  signal rowbuf_cnt_ena:          std_ulogic;
  signal rowbuf_cnt_last:         std_ulogic;
  signal rowbuf_icb_rsp_hsked:    std_ulogic;
  signal rowbuf_rsp_hsked:        std_ulogic;
  signal nice_rsp_valid_rowsum:   std_ulogic;

  signal rcv_data_buf_ena:        std_ulogic;
  signal rcv_data_buf_set:        std_ulogic;
  signal rcv_data_buf_clr:        std_ulogic;
  signal rcv_data_buf_valid:      std_ulogic;
  signal rcv_data_buf:            std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal rcv_data_buf_idx:        std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal rcv_data_buf_idx_nxt:    std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 

  signal rowsum_acc_r:            std_ulogic_vector(E203_XLEN-1 downto 0);
  signal rowsum_acc_nxt:          std_ulogic_vector(E203_XLEN-1 downto 0);
  signal rowsum_acc_adder:        std_ulogic_vector(E203_XLEN-1 downto 0);
  signal rowsum_acc_ena:          std_ulogic;
  signal rowsum_acc_set:          std_ulogic;
  signal rowsum_acc_flg:          std_ulogic;
  signal nice_icb_cmd_valid_rowsum: std_ulogic;
  signal rowsum_res:                std_ulogic_vector(E203_XLEN-1 downto 0);

  type rowbuf_type is array(ROWBUF_DP-1 downto 0) of std_ulogic_vector(E203_XLEN-1 downto 0);
  signal rowbuf_r:        rowbuf_type;
  signal rowbuf_wdat:     rowbuf_type;
  signal rowbuf_we:       std_ulogic_vector(ROWBUF_DP-1 downto 0);
  signal rowbuf_idx_mux:  std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal rowbuf_wdat_mux: std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal rowbuf_wr_mux:   std_ulogic; 
 
  signal lbuf_idx:        std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal lbuf_wr:         std_ulogic; 
  signal lbuf_wdata:      std_ulogic_vector(E203_XLEN-1 downto 0);

  signal rowsum_idx:      std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  signal rowsum_wr:       std_ulogic; 
  signal rowsum_wdata:    std_ulogic_vector(E203_XLEN-1 downto 0);

  signal maddr_acc_r:     std_ulogic_vector(E203_XLEN-1 downto 0); 
 
  signal lbuf_maddr_ena:  std_ulogic;

  signal sbuf_maddr_ena:  std_ulogic;

  signal rowsum_maddr_ena: std_ulogic;

  signal maddr_ena:        std_ulogic;
  signal maddr_ena_idle:   std_ulogic;

  signal maddr_acc_op1:    std_ulogic_vector(E203_XLEN-1 downto 0); -- not reused
  signal maddr_acc_op2:    std_ulogic_vector(E203_XLEN-1 downto 0); 

  signal maddr_acc_next:   std_ulogic_vector(E203_XLEN-1 downto 0);
  signal maddr_acc_ena:    std_ulogic;

  signal sbuf_idx:         std_ulogic_vector(ROWBUF_IDX_W-1 downto 0); 
  
  signal is_custum_memop:  std_ulogic;
  signal lbuf_not_full:    std_ulogic;
  signal sbuf_not_full:    std_ulogic;
  signal rcvbuf_not_full:  std_ulogic;
begin
  -- here we only use custom3: 
  -- CUSTOM0 = 7'h0b, R type
  -- CUSTOM1 = 7'h2b, R tpye
  -- CUSTOM2 = 7'h5b, R type
  -- CUSTOM3 = 7'h7b, R type
  
  -- RISC-V format  
  --	.insn r  0x33,  0,  0, a0, a1, a2       0:  00c58533[ 	]+add [ 	]+a0,a1,a2
  --	.insn i  0x13,  0, a0, a1, 13           4:  00d58513[ 	]+addi[ 	]+a0,a1,13
  --	.insn i  0x67,  0, a0, 10(a1)           8:  00a58567[ 	]+jalr[ 	]+a0,10 (a1)
  --	.insn s   0x3,  0, a0, 4(a1)            c:  00458503[ 	]+lb  [ 	]+a0,4(a1)
  --	.insn sb 0x63,  0, a0, a1, target       10: feb508e3[ 	]+beq [ 	]+a0,a1,0 target
  --	.insn sb 0x23,  0, a0, 4(a1)            14: 00a58223[ 	]+sb  [ 	]+a0,4(a1)
  --	.insn u  0x37, a0, 0xfff                18: 00fff537[ 	]+lui [ 	]+a0,0xfff
  --	.insn uj 0x6f, a0, target               1c: fe5ff56f[ 	]+jal [ 	]+a0,0 target
  --	.insn ci 0x1, 0x0, a0, 4                20: 0511    [ 	]+addi[ 	]+a0,a0,4
  --	.insn cr 0x2, 0x8, a0, a1               22: 852e    [ 	]+mv  [ 	]+a0,a1
  --	.insn ciw 0x0, 0x0, a1, 1               24: 002c    [ 	]+addi[ 	]+a1,sp,8
  --	.insn cb 0x1, 0x6, a1, target           26: dde9    [ 	]+beqz[ 	]+a1,0 target
  --	.insn cj 0x1, 0x5, target               28: bfe1    [ 	]+j   [ 	]+0 targe
  
  --//////////////////////////////////////////////////////////
  -- decode
  --//////////////////////////////////////////////////////////
  opcode      <= (6 downto 0 => nice_req_valid) and nice_req_inst(6 downto 0);
  rv32_func3  <= (2 downto 0 => nice_req_valid) and nice_req_inst(14 downto 12);
  rv32_func7  <= (6 downto 0 => nice_req_valid) and nice_req_inst(31 downto 25);
  
  opcode_custom3 <= (opcode ?= 7b"1111011"); 

  rv32_func3_000 <= (rv32_func3 ?= 3b"000"); 
  rv32_func3_001 <= (rv32_func3 ?= 3b"001"); 
  rv32_func3_010 <= (rv32_func3 ?= 3b"010"); 
  rv32_func3_011 <= (rv32_func3 ?= 3b"011"); 
  rv32_func3_100 <= (rv32_func3 ?= 3b"100"); 
  rv32_func3_101 <= (rv32_func3 ?= 3b"101"); 
  rv32_func3_110 <= (rv32_func3 ?= 3b"110"); 
  rv32_func3_111 <= (rv32_func3 ?= 3b"111"); 

  rv32_func7_0000000 <= (rv32_func7 ?= 7b"0000000"); 
  rv32_func7_0000001 <= (rv32_func7 ?= 7b"0000001"); 
  rv32_func7_0000010 <= (rv32_func7 ?= 7b"0000010"); 
  rv32_func7_0000011 <= (rv32_func7 ?= 7b"0000011"); 
  rv32_func7_0000100 <= (rv32_func7 ?= 7b"0000100"); 
  rv32_func7_0000101 <= (rv32_func7 ?= 7b"0000101"); 
  rv32_func7_0000110 <= (rv32_func7 ?= 7b"0000110"); 
  rv32_func7_0000111 <= (rv32_func7 ?= 7b"0000111"); 

  --//////////////////////////////////////////////////////////
  -- custom3:
  -- Supported format: only R type here
  -- Supported instr:
  --  1. custom3 lbuf: load data(in memory) to row_buf
  --     lbuf (a1)
  --     .insn r opcode, func3, func7, rd, rs1, rs2    
  --  2. custom3 sbuf: store data(in row_buf) to memory
  --     sbuf (a1)
  --     .insn r opcode, func3, func7, rd, rs1, rs2    
  --  3. custom3 acc rowsum: load data from memory(@a1), accumulate row datas and write back 
  --     rowsum rd, a1, x0
  --     .insn r opcode, func3, func7, rd, rs1, rs2    
  --//////////////////////////////////////////////////////////
  custom3_lbuf     <= opcode_custom3 and rv32_func3_010 and rv32_func7_0000001; 
  custom3_sbuf     <= opcode_custom3 and rv32_func3_010 and rv32_func7_0000010; 
  custom3_rowsum   <= opcode_custom3 and rv32_func3_110 and rv32_func7_0000110; 

  --//////////////////////////////////////////////////////////
  --  multi-cyc op 
  --//////////////////////////////////////////////////////////
  custom_multi_cyc_op <= custom3_lbuf or custom3_sbuf or custom3_rowsum;
  -- need access memory
  custom_mem_op <= custom3_lbuf or custom3_sbuf or custom3_rowsum;
 
  --//////////////////////////////////////////////////////////
  -- NICE FSM 
  --//////////////////////////////////////////////////////////
  illgel_instr <= not (custom_multi_cyc_op);

  state_is_idle   <= (state_r ?= IDLE); 
  state_is_lbuf   <= (state_r ?= LBUF); 
  state_is_sbuf   <= (state_r ?= SBUF); 
  state_is_rowsum <= (state_r ?= ROWSUM); 

  state_idle_exit_ena <= state_is_idle and nice_req_hsked and (not illgel_instr); 
  state_idle_nxt <= LBUF   when custom3_lbuf   = '1' else 
                    SBUF   when custom3_sbuf   = '1' else
                    ROWSUM when custom3_rowsum = '1' else
		            IDLE;

  state_lbuf_exit_ena <= state_is_lbuf and lbuf_icb_rsp_hsked_last; 
  state_lbuf_nxt <= IDLE;
 
  state_sbuf_exit_ena <= state_is_sbuf and sbuf_icb_rsp_hsked_last; 
  state_sbuf_nxt <= IDLE;

  state_rowsum_exit_ena <= state_is_rowsum and rowsum_done; 
  state_rowsum_nxt <= IDLE;

  nxt_state <=  ((NICE_FSM_WIDTH-1 downto 0 => state_idle_exit_ena  ) and state_idle_nxt   )
              or((NICE_FSM_WIDTH-1 downto 0 => state_lbuf_exit_ena  ) and state_lbuf_nxt   ) 
              or((NICE_FSM_WIDTH-1 downto 0 => state_sbuf_exit_ena  ) and state_sbuf_nxt   ) 
              or((NICE_FSM_WIDTH-1 downto 0 => state_rowsum_exit_ena) and state_rowsum_nxt ) 
              ;

  state_ena <=   state_idle_exit_ena or state_lbuf_exit_ena 
              or state_sbuf_exit_ena or state_rowsum_exit_ena;

  state_dfflr: entity work.sirv_gnrl_dfflr generic map(NICE_FSM_WIDTH)
                                              port map(state_ena, nxt_state, state_r, nice_clk, nice_rst_n);

  --//////////////////////////////////////////////////////////
  -- instr EXU
  --//////////////////////////////////////////////////////////
  --////////// 1. custom3_lbuf
  lbuf_icb_rsp_hsked <= state_is_lbuf and nice_icb_rsp_hsked;
  lbuf_icb_rsp_hsked_last <= lbuf_icb_rsp_hsked and lbuf_cnt_last;
  lbuf_cnt_last <= (lbuf_cnt_r ?= clonum);
  lbuf_cnt_clr  <= custom3_lbuf and nice_req_hsked;
  lbuf_cnt_incr <= lbuf_icb_rsp_hsked and (not lbuf_cnt_last);
  lbuf_cnt_ena <= lbuf_cnt_clr or lbuf_cnt_incr;
  lbuf_cnt_nxt <=   ((ROWBUF_IDX_W-1 downto 0 => lbuf_cnt_clr ) and (ROWBUF_IDX_W-1 downto 0 => '0'))
                 or ((ROWBUF_IDX_W-1 downto 0 => lbuf_cnt_incr) and std_ulogic_vector(u_unsigned(lbuf_cnt_r) + '1'))
                         ;

  lbuf_cnt_dfflr: entity work.sirv_gnrl_dfflr generic map(ROWBUF_IDX_W)
                                                 port map(lbuf_cnt_ena, lbuf_cnt_nxt, lbuf_cnt_r, nice_clk, nice_rst_n);

  -- nice_rsp_valid wait for nice_icb_rsp_valid in LBUF
  nice_rsp_valid_lbuf <= state_is_lbuf and lbuf_cnt_last and nice_icb_rsp_valid;

  -- nice_icb_cmd_valid sets when lbuf_cnt_r is not full in LBUF
  lbuf_not_full <= '1' when (to_integer(u_unsigned(lbuf_cnt_r)) < to_integer(u_unsigned(clonum))) else
                   '0';
  nice_icb_cmd_valid_lbuf <= state_is_lbuf and lbuf_not_full;

  --////////// 2. custom3_sbuf
  sbuf_icb_cmd_hsked <= (state_is_sbuf or (state_is_idle and custom3_sbuf)) and nice_icb_cmd_hsked;
  sbuf_icb_rsp_hsked <= state_is_sbuf and nice_icb_rsp_hsked;
  sbuf_icb_rsp_hsked_last <= sbuf_icb_rsp_hsked and sbuf_cnt_last;
  sbuf_cnt_last <= (sbuf_cnt_r ?= clonum);
  --assign sbuf_cnt_clr = custom3_sbuf and nice_req_hsked;
  sbuf_cnt_clr  <= sbuf_icb_rsp_hsked_last;
  sbuf_cnt_incr <= sbuf_icb_rsp_hsked and (not sbuf_cnt_last);
  sbuf_cnt_ena  <= sbuf_cnt_clr or sbuf_cnt_incr;
  sbuf_cnt_nxt  <=   ((ROWBUF_IDX_W-1 downto 0 => sbuf_cnt_clr ) and (ROWBUF_IDX_W-1 downto 0 => '0'))
                  or ((ROWBUF_IDX_W-1 downto 0 => sbuf_cnt_incr) and std_ulogic_vector(u_unsigned(sbuf_cnt_r) + '1'))
                  ;

  sbuf_cnt_dfflr: entity work.sirv_gnrl_dfflr generic map(ROWBUF_IDX_W)
                                                 port map(sbuf_cnt_ena, sbuf_cnt_nxt, sbuf_cnt_r, nice_clk, nice_rst_n);

  -- nice_rsp_valid wait for nice_icb_rsp_valid in SBUF
  nice_rsp_valid_sbuf <= state_is_sbuf and sbuf_cnt_last and nice_icb_rsp_valid;

  sbuf_cmd_cnt_last <= (sbuf_cmd_cnt_r ?= clonum);
  sbuf_cmd_cnt_clr  <= sbuf_icb_rsp_hsked_last;
  sbuf_cmd_cnt_incr <= sbuf_icb_cmd_hsked and (not sbuf_cmd_cnt_last);
  sbuf_cmd_cnt_ena  <= sbuf_cmd_cnt_clr or sbuf_cmd_cnt_incr;
  sbuf_cmd_cnt_nxt  <=   ((ROWBUF_IDX_W-1 downto 0 => sbuf_cmd_cnt_clr ) and (ROWBUF_IDX_W-1 downto 0 => '0'))
                      or ((ROWBUF_IDX_W-1 downto 0 => sbuf_cmd_cnt_incr) and std_ulogic_vector(u_unsigned(sbuf_cmd_cnt_r) + '1'))
                             ;
  sbuf_cmd_cnt_dfflr: entity work.sirv_gnrl_dfflr generic map(ROWBUF_IDX_W)
                                                     port map(sbuf_cmd_cnt_ena, sbuf_cmd_cnt_nxt, sbuf_cmd_cnt_r, nice_clk, nice_rst_n);

  -- nice_icb_cmd_valid sets when sbuf_cmd_cnt_r is not full in SBUF
  sbuf_not_full <= '1' when (to_integer(u_unsigned(sbuf_cmd_cnt_r)) <= to_integer(u_unsigned(clonum))) else
                   '0';
  nice_icb_cmd_valid_sbuf <= (state_is_sbuf and sbuf_not_full and (sbuf_cnt_r ?/= clonum));


  --////////// 3. custom3_rowsum
  -- rowbuf counter 
  rowbuf_rsp_hsked <= nice_rsp_valid_rowsum and nice_rsp_ready;
  rowbuf_icb_rsp_hsked <= state_is_rowsum and nice_icb_rsp_hsked;
  rowbuf_cnt_last <= (rowbuf_cnt_r ?= clonum);
  rowbuf_cnt_clr  <= rowbuf_icb_rsp_hsked and rowbuf_cnt_last;
  rowbuf_cnt_incr <= rowbuf_icb_rsp_hsked and (not rowbuf_cnt_last);
  rowbuf_cnt_ena  <= rowbuf_cnt_clr or rowbuf_cnt_incr;
  rowbuf_cnt_nxt  <=   ((ROWBUF_IDX_W-1 downto 0 => rowbuf_cnt_clr ) and (ROWBUF_IDX_W-1 downto 0 => '0'))
                    or ((ROWBUF_IDX_W-1 downto 0 => rowbuf_cnt_incr) and std_ulogic_vector(u_unsigned(rowbuf_cnt_r) + '1'))
                    ;
  
  rowbuf_cnt_dfflr: entity work.sirv_gnrl_dfflr generic map(ROWBUF_IDX_W)
                                                   port map(rowbuf_cnt_ena, rowbuf_cnt_nxt, rowbuf_cnt_r, nice_clk, nice_rst_n);

  -- recieve data buffer, to make sure rowsum ops come from registers 
  rcv_data_buf_set <= rowbuf_icb_rsp_hsked;
  rcv_data_buf_clr <= rowbuf_rsp_hsked;
  rcv_data_buf_ena <= rcv_data_buf_clr or rcv_data_buf_set;
  rcv_data_buf_idx_nxt <=   ((ROWBUF_IDX_W-1 downto 0 => rcv_data_buf_clr) and (ROWBUF_IDX_W-1 downto 0 => '0'))
                         or ((ROWBUF_IDX_W-1 downto 0 => rcv_data_buf_set) and rowbuf_cnt_r        );

  rcv_data_buf_valid_dfflr: entity work.sirv_gnrl_dfflr generic map(1)
                                                           port map(lden    => '1',
                                                                    dnxt(0) => rcv_data_buf_ena,
                                                                    qout(0) => rcv_data_buf_valid,
                                                                    clk     => nice_clk,
                                                                    rst_n   => nice_rst_n
                                                                   );
  rcv_data_buf_dfflr: entity work.sirv_gnrl_dfflr generic map(E203_XLEN)
                                                     port map(rcv_data_buf_ena, nice_icb_rsp_rdata, rcv_data_buf, nice_clk, nice_rst_n);
  rowbuf_cnt_d_dfflr: entity work.sirv_gnrl_dfflr generic map(ROWBUF_IDX_W)
                                                     port map(rcv_data_buf_ena, rcv_data_buf_idx_nxt, rcv_data_buf_idx, nice_clk, nice_rst_n);

  -- rowsum accumulator 
  rowsum_acc_set <= rcv_data_buf_valid and (rcv_data_buf_idx ?= (ROWBUF_IDX_W-1 downto 0 => '0'));
  rowsum_acc_flg <= rcv_data_buf_valid and (rcv_data_buf_idx ?/= (ROWBUF_IDX_W-1 downto 0 => '0'));
  rowsum_acc_adder <= std_ulogic_vector(u_signed(rcv_data_buf) + u_signed(rowsum_acc_r));
  rowsum_acc_ena <= rowsum_acc_set or rowsum_acc_flg;
  rowsum_acc_nxt <=   ((E203_XLEN-1 downto 0 => rowsum_acc_set) and rcv_data_buf)
                   or ((E203_XLEN-1 downto 0 => rowsum_acc_flg) and rowsum_acc_adder)
                   ;
 
  rowsum_acc_dfflr: entity work.sirv_gnrl_dfflr generic map(E203_XLEN)
                                                   port map(rowsum_acc_ena, rowsum_acc_nxt, rowsum_acc_r, nice_clk, nice_rst_n);

  rowsum_done <= state_is_rowsum and nice_rsp_hsked;
  rowsum_res  <= rowsum_acc_r;

  -- rowsum finishes when the last acc data is added to rowsum_acc_r  
  nice_rsp_valid_rowsum <= state_is_rowsum and (rcv_data_buf_idx ?= clonum) and (not rowsum_acc_flg);

  -- nice_icb_cmd_valid sets when rcv_data_buf_idx is not full in LBUF
  rcvbuf_not_full <= '1' when (to_integer(u_unsigned(rcv_data_buf_idx)) < to_integer(u_unsigned(clonum))) else
                     '0';
  nice_icb_cmd_valid_rowsum <= state_is_rowsum and rcvbuf_not_full and (not rowsum_acc_flg);

  --////////// rowbuf
  -- rowbuf access list:
  --  1. lbuf will write to rowbuf, write data comes from memory, data length is defined by clonum 
  --  2. sbuf will read from rowbuf, and store it to memory, data length is defined by clonum 
  --  3. rowsum will accumulate data, and store to rowbuf, data length is defined by clonum 
   
  -- lbuf write to rowbuf
  lbuf_idx <= lbuf_cnt_r; 
  lbuf_wr <= lbuf_icb_rsp_hsked; 
  lbuf_wdata <= nice_icb_rsp_rdata;

  -- rowsum write to rowbuf(column accumulated data)
  rowsum_idx <= rcv_data_buf_idx; 
  rowsum_wr <= rcv_data_buf_valid; 
  rowsum_wdata <= std_ulogic_vector(u_signed(rowbuf_r(to_integer(u_unsigned(rowsum_idx)))) + u_signed(rcv_data_buf));

  -- rowbuf write mux
  rowbuf_wdat_mux <=   ((E203_XLEN-1 downto 0 => lbuf_wr  ) and lbuf_wdata  )
                    or ((E203_XLEN-1 downto 0 => rowsum_wr) and rowsum_wdata)
                    ;
  rowbuf_wr_mux   <=  lbuf_wr or rowsum_wr;
  rowbuf_idx_mux  <=   ((ROWBUF_IDX_W-1 downto 0 => lbuf_wr  ) and lbuf_idx  )
                    or ((ROWBUF_IDX_W-1 downto 0 => rowsum_wr) and rowsum_idx)
                    ;  

  -- rowbuf inst
  gen_rowbuf: for i in 0 to ROWBUF_DP-1 generate 
    signal eq_i: std_ulogic;
  begin
    eq_i <= '1' when to_integer(u_unsigned(rowbuf_idx_mux)) = i else '0';
    rowbuf_we(i) <= rowbuf_wr_mux and eq_i;
    rowbuf_wdat(i) <= ((E203_XLEN-1 downto 0 => rowbuf_we(i)) and rowbuf_wdat_mux);
    rowbuf_dfflr: entity work.sirv_gnrl_dfflr generic map(E203_XLEN)
                                                 port map(rowbuf_we(i), rowbuf_wdat(i), rowbuf_r(i), nice_clk, nice_rst_n);
  end generate;

  --////////// mem aacess addr management
  nice_icb_cmd_hsked <= nice_icb_cmd_valid and nice_icb_cmd_ready; 
  -- custom3_lbuf 
  -- wire [`E203_XLEN-1:0] lbuf_maddr    = state_is_idle ? nice_req_rs1 : maddr_acc_r ; 
  lbuf_maddr_ena <=   (state_is_idle and custom3_lbuf and nice_icb_cmd_hsked)
                   or (state_is_lbuf and nice_icb_cmd_hsked)
                   ;

  -- custom3_sbuf 
  -- wire [`E203_XLEN-1:0] sbuf_maddr    = state_is_idle ? nice_req_rs1 : maddr_acc_r ; 
  sbuf_maddr_ena <=   (state_is_idle and custom3_sbuf and nice_icb_cmd_hsked)
                   or (state_is_sbuf and nice_icb_cmd_hsked)
                   ;

  -- custom3_rowsum
  -- wire [`E203_XLEN-1:0] rowsum_maddr  = state_is_idle ? nice_req_rs1 : maddr_acc_r ; 
  rowsum_maddr_ena <=   (state_is_idle and custom3_rowsum and nice_icb_cmd_hsked)
                     or (state_is_rowsum and nice_icb_cmd_hsked)
                     ;

  -- maddr acc 
  --wire  maddr_incr = lbuf_maddr_ena or sbuf_maddr_ena or rowsum_maddr_ena or rbuf_maddr_ena;
  maddr_ena <= lbuf_maddr_ena or sbuf_maddr_ena or rowsum_maddr_ena;
  maddr_ena_idle <= maddr_ena and state_is_idle;

  maddr_acc_op1 <= nice_req_rs1 when maddr_ena_idle = '1' else maddr_acc_r; -- not reused
  maddr_acc_op2 <= (3 downto 0 => x"4", others => '0') when maddr_ena_idle = '1' else
                   (3 downto 0 => x"4", others => '0'); 

  maddr_acc_next <= std_ulogic_vector(u_signed(maddr_acc_op1) + u_signed(maddr_acc_op2));
  maddr_acc_ena <= maddr_ena;

  maddr_acc_dfflr: entity work.sirv_gnrl_dfflr generic map(E203_XLEN)
                                                  port map(maddr_acc_ena, maddr_acc_next, maddr_acc_r, nice_clk, nice_rst_n);

  --//////////////////////////////////////////////////////////
  -- Control cmd_req
  --//////////////////////////////////////////////////////////
  nice_req_hsked <= nice_req_valid and nice_req_ready;
  is_custum_memop <= nice_icb_cmd_ready when custom_mem_op = '1' else '1';
  nice_req_ready <= state_is_idle and is_custum_memop;

  --//////////////////////////////////////////////////////////
  -- Control cmd_rsp
  --//////////////////////////////////////////////////////////
  nice_rsp_hsked <= nice_rsp_valid and nice_rsp_ready; 
  nice_icb_rsp_hsked <= nice_icb_rsp_valid and nice_icb_rsp_ready;
  nice_rsp_valid <= nice_rsp_valid_rowsum or nice_rsp_valid_sbuf or nice_rsp_valid_lbuf;
  nice_rsp_rdat  <= (E203_XLEN-1 downto 0 => state_is_rowsum) and rowsum_res;

  -- memory access bus error
  --assign nice_rsp_err_irq  =   (nice_icb_rsp_hsked and nice_icb_rsp_err)
  --                          or (nice_req_hsked and illgel_instr)
  --                          ; 
  nice_rsp_err <= (nice_icb_rsp_hsked and nice_icb_rsp_err);

  --//////////////////////////////////////////////////////////
  -- Memory lsu
  --//////////////////////////////////////////////////////////
  -- memory access list:
  --  1. In IDLE, custom_mem_op will access memory(lbuf/sbuf/rowsum)
  --  2. In LBUF, it will read from memory as long as lbuf_cnt_r is not full
  --  3. In SBUF, it will write to memory as long as sbuf_cnt_r is not full
  --  3. In ROWSUM, it will read from memory as long as rowsum_cnt_r is not full
  --assign nice_icb_rsp_ready = state_is_ldst_rsp and nice_rsp_ready; 
  -- rsp always ready
  nice_icb_rsp_ready <= '1'; 
  sbuf_idx <= sbuf_cmd_cnt_r; 

  nice_icb_cmd_valid <=   (state_is_idle and nice_req_valid and custom_mem_op)
                      or nice_icb_cmd_valid_lbuf
                      or nice_icb_cmd_valid_sbuf
                      or nice_icb_cmd_valid_rowsum
                      ;
  nice_icb_cmd_addr  <= nice_req_rs1 when (state_is_idle and custom_mem_op) = '1' else
                        maddr_acc_r;
  nice_icb_cmd_read  <= (custom3_lbuf or custom3_rowsum) when (state_is_idle and custom_mem_op) = '1' else 
                        '0' when state_is_sbuf = '1' else 
                        '1';
  nice_icb_cmd_wdata <= rowbuf_r(to_integer(u_unsigned(sbuf_idx))) when (state_is_idle and custom3_sbuf) = '1' else
                        rowbuf_r(to_integer(u_unsigned(sbuf_idx))) when state_is_sbuf = '1' else
                        (E203_XLEN-1 downto 0 => '0'); 

  --assign nice_icb_cmd_wmask = {`sirv_XLEN_MW{custom3_sbuf}} and 4'b1111;
  nice_icb_cmd_size  <= 2b"10";
  nice_mem_holdup    <=  state_is_lbuf or state_is_sbuf or state_is_rowsum; 

  --//////////////////////////////////////////////////////////
  -- nice_active
  --//////////////////////////////////////////////////////////
  nice_active <= nice_req_valid when state_is_idle = '1' else '1';
end impl;
`end if