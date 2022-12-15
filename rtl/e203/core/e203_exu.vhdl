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
--   The EXU module to implement entire Execution Stage
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu is 
  port(
    commit_mret: out std_logic; 
    commit_trap: out std_logic; 
    exu_active:  out std_logic; 
    excp_active: out std_logic; 
  
    core_wfi:    out std_logic;
    tm_stop:     out std_logic;
    itcm_nohold: out std_logic;
    core_cgstop: out std_logic;
    tcm_cgstop:  out std_logic;
  
    core_mhartid: in std_logic_vector(E203_HART_ID_W-1 downto 0);
    dbg_irq_r:    in std_logic; 
    lcl_irq_r:    in std_logic_vector(E203_LIRQ_NUM-1 downto 0); 
    evt_r:        in std_logic_vector(E203_EVT_NUM-1 downto 0); 
    ext_irq_r:    in std_logic; 
    sft_irq_r:    in std_logic; 
    tmr_irq_r:    in std_logic; 
  
    -- From/To debug ctrl module
    cmt_dpc:        out std_logic_vector(E203_PC_SIZE-1 downto 0); 
    cmt_dpc_ena:    out std_logic; 
    cmt_dcause:     out std_logic_vector(3-1 downto 0); 
    cmt_dcause_ena: out std_logic; 
  
    wr_dcsr_ena    :out std_logic; 
    wr_dpc_ena     :out std_logic; 
    wr_dscratch_ena:out std_logic; 
  
    wr_csr_nxt:     out std_logic_vector(E203_XLEN-1 downto 0); 
  
    dcsr_r:          in std_logic_vector(E203_XLEN-1 downto 0);    
    dpc_r:           in std_logic_vector(E203_PC_SIZE-1 downto 0); 
    dscratch_r:      in std_logic_vector(E203_XLEN-1 downto 0);    
  
    dbg_mode:        in std_logic;  
    dbg_halt_r:      in std_logic;  
    dbg_step_r:      in std_logic;  
    dbg_ebreakm_r:   in std_logic;  
    dbg_stopcycle:   in std_logic;  
   
    -- The IFU IR stage to EXU interface
    i_valid:         in std_logic;                                    -- Handshake signals with EXU stage
    i_ready:        out std_logic; 
    i_ir:            in std_logic_vector(E203_INSTR_SIZE-1 downto 0); -- The instruction register
    i_pc:            in std_logic_vector(E203_PC_SIZE-1 downto 0);    -- The PC register along with
    i_pc_vld:        in std_logic;  
    i_misalgn:       in std_logic;                                    -- The fetch misalign
    i_buserr:        in std_logic;                                    -- The fetch bus error
    i_prdt_taken:    in std_logic;                 
    i_muldiv_b2b:    in std_logic;                 
    i_rs1idx:        in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);-- The RS1 index
    i_rs2idx:        in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);-- The RS2 index
  
    -- The Flush interface to IFU
    --
    --   To save the gatecount, when we need to flush pipeline with new PC, 
    --     we want to reuse the adder in IFU, so we will not pass flush-PC
    --     to IFU, instead, we pass the flush-pc-adder-op1/op2 to IFU
    --     and IFU will just use its adder to caculate the flush-pc-adder-result
    --
    pipe_flush_ack:  in std_logic;  
    pipe_flush_req: out std_logic;  
    pipe_flush_add_op1: out std_logic_vector(E203_PC_SIZE-1 downto 0);   
    pipe_flush_add_op2: out std_logic_vector(E203_PC_SIZE-1 downto 0);   
   `if E203_TIMING_BOOST = "TRUE" then
    pipe_flush_pc:      out std_logic_vector(E203_PC_SIZE-1 downto 0);   
   `end if
  
    -- The LSU Write-Back Interface
    lsu_o_valid:         in std_logic;  -- Handshake valid
    lsu_o_ready:        out std_logic;  -- Handshake ready
    lsu_o_wbck_wdat:     in std_logic_vector(E203_XLEN-1 downto 0); 
    lsu_o_wbck_itag:     in std_logic_vector(E203_ITAG_WIDTH -1 downto 0); 
    lsu_o_wbck_err:      in std_logic;   
    lsu_o_cmt_ld:        in std_logic;  
    lsu_o_cmt_st:        in std_logic;  
    lsu_o_cmt_badaddr:   in std_logic_vector(E203_ADDR_SIZE -1 downto 0); 
    lsu_o_cmt_buserr :   in std_logic;  -- The bus-error exception generated
  
    wfi_halt_ifu_req:   out std_logic; 
    wfi_halt_ifu_ack:    in std_logic; 
  
    oitf_empty:         out std_logic; 
    rf2ifu_x1:          out std_logic_vector(E203_XLEN-1 downto 0); 
    rf2ifu_rs1:         out std_logic_vector(E203_XLEN-1 downto 0); 
    dec2ifu_rden:       out std_logic;
    dec2ifu_rs1en:      out std_logic;
    dec2ifu_rdidx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
    dec2ifu_mulhsu:     out std_logic;
    dec2ifu_div   :     out std_logic;
    dec2ifu_rem   :     out std_logic;
    dec2ifu_divu  :     out std_logic;
    dec2ifu_remu  :     out std_logic;
  
    -- The AGU ICB Interface to LSU-ctrl
    --    * Bus cmd channel
    agu_icb_cmd_valid:  out std_logic;       -- Handshake valid
    agu_icb_cmd_ready:   in std_logic;       -- Handshake ready
    agu_icb_cmd_addr:   out std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr 
    agu_icb_cmd_read:   out std_logic;       -- Read or write
    agu_icb_cmd_wdata:  out std_logic_vector(E203_XLEN-1 downto 0);         
    agu_icb_cmd_wmask:  out std_logic_vector(E203_XLEN/8-1 downto 0);       
    agu_icb_cmd_lock:   out std_logic;                        
    agu_icb_cmd_excl:   out std_logic;                        
    agu_icb_cmd_size:   out std_logic_vector(1 downto 0);                   
    -- Several additional side channel signals
    --   Indicate LSU-ctrl module to
    --     return the ICB response channel back to AGU
    --     this is only used by AMO or unaligned load/store 1st uop
    --     to return the response
    agu_icb_cmd_back2agu: out std_logic;                         
    -- Sign extension or not
    agu_icb_cmd_usign:    out std_logic;                        
    agu_icb_cmd_itag:     out std_logic_vector(E203_ITAG_WIDTH -1 downto 0); 
  
    -- * Bus RSP channel
    agu_icb_rsp_valid:     in std_logic;     -- Response valid 
    agu_icb_rsp_ready:    out std_logic;     -- Response ready
    agu_icb_rsp_err  :     in std_logic;     -- Response error
    agu_icb_rsp_excl_ok:   in std_logic;    
    agu_icb_rsp_rdata:     in std_logic_vector(E203_XLEN-1 downto 0);        
  
   `if E203_HAS_CSR_NICE = "TRUE" then
    nice_csr_valid:       out std_logic;         
    nice_csr_ready:        in std_logic;         
    nice_csr_addr:        out std_logic_vector(31 downto 0); 
    nice_csr_wr:          out std_logic;        
    nice_csr_wdata:       out std_logic_vector(31 downto 0); 
    nice_csr_rdata:        in std_logic_vector(31 downto 0); 
   `end if
  
   `if E203_HAS_NICE = "TRUE" then
    -- The nice interface
    --
    -- * instruction cmd channel
    nice_req_valid:       out std_logic;  -- O: handshake flag, cmd is valid
    nice_req_ready:        in std_logic;  -- I: handshake flag, cmd is accepted.
    nice_req_inst:        out std_logic_vector(E203_XLEN-1 downto 0);    -- O: inst sent to nice. 
    nice_req_rs1 :        out std_logic_vector(E203_XLEN-1 downto 0);    -- O: rs op 1.
    nice_req_rs2 :        out std_logic_vector(E203_XLEN-1 downto 0);    -- O: rs op 2.
    nice_rsp_multicyc_valid:  in std_logic;                              -- I: current insn is multi-cycle.
    nice_rsp_multicyc_ready: out std_logic;                                                   
    nice_rsp_multicyc_dat  :  in std_logic_vector(E203_XLEN-1 downto 0); -- I: one cycle result write-back val.
    nice_rsp_multicyc_err  :  in std_logic;                      
   `end if

    test_mode:                in std_logic;  
    clk_aon:                  in std_logic;  
    clk:                      in std_logic;  
    rst_n:                    in std_logic  
  );
end e203_exu;
architecture impl of e203_exu is   
  -- Instantiate the Regfile
  signal rf_rs1: std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal rf_rs2: std_ulogic_vector(E203_XLEN-1 downto 0); 

  signal rf_wbck_ena:   std_ulogic;
  signal rf_wbck_wdat:  std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal rf_wbck_rdidx: std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal dec_rs1en:     std_ulogic;
  signal dec_rs2en:     std_ulogic;

  -- Instantiate the Decode
  signal dec_info:      std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);  
  signal dec_imm:       std_ulogic_vector(E203_XLEN-1 downto 0);           
  signal dec_pc:        std_ulogic_vector(E203_PC_SIZE-1 downto 0);        
  signal dec_rs1x0:     std_ulogic;
  signal dec_rs2x0:     std_ulogic;
  signal dec_rdwen:     std_ulogic;
  signal dec_rdidx:     std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal dec_misalgn:   std_ulogic;
  signal dec_buserr:    std_ulogic;
  signal dec_ilegl:     std_ulogic;

 `if E203_HAS_NICE = "TRUE" then
  signal nice_cmt_off_ilgl: std_ulogic;
  signal nice_xs_off:       std_ulogic;
 `end if

  -- The Decoded Info-Bus
  -- Instantiate the Dispatch
  signal disp_alu_valid:    std_ulogic; 
  signal disp_alu_ready:    std_ulogic; 
  signal disp_alu_longpipe: std_ulogic;
  signal disp_alu_itag:     std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0); 
  signal disp_alu_rs1:      std_ulogic_vector(E203_XLEN-1 downto 0);       
  signal disp_alu_rs2:      std_ulogic_vector(E203_XLEN-1 downto 0);       
  signal disp_alu_imm:      std_ulogic_vector(E203_XLEN-1 downto 0);       
  signal disp_alu_info:     std_ulogic_vector(E203_DECINFO_WIDTH-1 downto 0);  
  signal disp_alu_pc:       std_ulogic_vector(E203_PC_SIZE-1 downto 0);       
  signal disp_alu_rdidx:    std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);   
  signal disp_alu_rdwen:    std_ulogic;
  signal disp_alu_ilegl:    std_ulogic;
  signal disp_alu_misalgn:  std_ulogic;
  signal disp_alu_buserr:   std_ulogic;

  signal disp_oitf_ptr:     std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0); 
  signal disp_oitf_ready:   std_ulogic;

  signal disp_oitf_rs1fpu:  std_ulogic;
  signal disp_oitf_rs2fpu:  std_ulogic;
  signal disp_oitf_rs3fpu:  std_ulogic;
  signal disp_oitf_rdfpu:   std_ulogic;
  signal disp_oitf_rs1idx:  std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal disp_oitf_rs2idx:  std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal disp_oitf_rs3idx:  std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal disp_oitf_rdidx:   std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal disp_oitf_rs1en:   std_ulogic;
  signal disp_oitf_rs2en:   std_ulogic;
  signal disp_oitf_rs3en:   std_ulogic;
  signal disp_oitf_rdwen:   std_ulogic;
  signal disp_oitf_pc:      std_ulogic_vector(E203_PC_SIZE-1 downto 0); 

  signal oitfrd_match_disprs1: std_ulogic;
  signal oitfrd_match_disprs2: std_ulogic;
  signal oitfrd_match_disprs3: std_ulogic;
  signal oitfrd_match_disprd:  std_ulogic;

  signal disp_oitf_ena:        std_ulogic;

  signal wfi_halt_exu_req:     std_ulogic;
  signal wfi_halt_exu_ack:     std_ulogic;

  signal amo_wait:             std_ulogic;

  -- Instantiate the OITF
  signal oitf_ret_ena:         std_ulogic;
  signal oitf_ret_ptr:         std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0); 
  signal oitf_ret_rdidx:       std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal oitf_ret_pc:          std_ulogic_vector(E203_PC_SIZE-1 downto 0);    
  signal oitf_ret_rdwen:       std_ulogic;
  signal oitf_ret_rdfpu:       std_ulogic;

  -- Instantiate the ALU
  signal alu_wbck_o_valid:     std_ulogic;
  signal alu_wbck_o_ready:     std_ulogic;
  signal alu_wbck_o_wdat:      std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal alu_wbck_o_rdidx:     std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 

  signal alu_cmt_valid:        std_ulogic;
  signal alu_cmt_ready:        std_ulogic;
  signal alu_cmt_pc_vld:       std_ulogic;
  signal alu_cmt_pc:           std_ulogic_vector(E203_PC_SIZE-1 downto 0);    
  signal alu_cmt_instr:        std_ulogic_vector(E203_INSTR_SIZE-1 downto 0); 
  signal alu_cmt_imm:          std_ulogic_vector(E203_XLEN-1 downto 0);       
  signal alu_cmt_rv32:         std_ulogic;
  signal alu_cmt_bjp:          std_ulogic;
  signal alu_cmt_mret:         std_ulogic;
  signal alu_cmt_dret:         std_ulogic;
  signal alu_cmt_ecall:        std_ulogic;
  signal alu_cmt_ebreak:       std_ulogic;
  signal alu_cmt_wfi:          std_ulogic;
  signal alu_cmt_fencei:       std_ulogic;
  signal alu_cmt_ifu_misalgn:  std_ulogic;
  signal alu_cmt_ifu_buserr:   std_ulogic;
  signal alu_cmt_ifu_ilegl:    std_ulogic;
  signal alu_cmt_bjp_prdt:     std_ulogic;
  signal alu_cmt_bjp_rslv:     std_ulogic;
  signal alu_cmt_misalgn:      std_ulogic;
  signal alu_cmt_ld:           std_ulogic;
  signal alu_cmt_stamo:        std_ulogic;
  signal alu_cmt_buserr:       std_ulogic;
  signal alu_cmt_badaddr:      std_ulogic_vector(E203_ADDR_SIZE-1 downto 0); 

  signal csr_ena:              std_ulogic;
  signal csr_wr_en:            std_ulogic;
  signal csr_rd_en:            std_ulogic;
  signal csr_idx:              std_ulogic_vector(12-1 downto 0); 

  signal read_csr_dat:         std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal wbck_csr_dat:         std_ulogic_vector(E203_XLEN-1 downto 0); 

  signal flush_pulse:          std_ulogic;
  signal flush_req:            std_ulogic;

  signal nonflush_cmt_ena:     std_ulogic;

  signal csr_access_ilgl:      std_ulogic;

  signal mdv_nob2b:            std_ulogic;

 `if E203_HAS_NICE = "TRUE" then
  signal nice_longp_wbck_valid: std_ulogic;
  signal nice_longp_wbck_ready: std_ulogic;
  signal nice_o_itag:           std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0); 
 `end if

  -- Instantiate the Long-pipe Write-Back
  signal longp_wbck_o_valid:    std_ulogic;
  signal longp_wbck_o_ready:    std_ulogic;
  signal longp_wbck_o_wdat:     std_ulogic_vector(E203_FLEN-1 downto 0);        
  signal longp_wbck_o_rdidx:    std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal longp_wbck_o_rdfpu:    std_ulogic;
  signal longp_wbck_o_flags:    std_ulogic_vector(4 downto 0); 

  signal longp_excp_o_ready:    std_ulogic;
  signal longp_excp_o_valid:    std_ulogic;
  signal longp_excp_o_ld:       std_ulogic;
  signal longp_excp_o_st:       std_ulogic;
  signal longp_excp_o_buserr :  std_ulogic;
  signal longp_excp_o_badaddr:  std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
  signal longp_excp_o_insterr:  std_ulogic;
  signal longp_excp_o_pc:       std_ulogic_vector(E203_PC_SIZE-1 downto 0);  

  -- Instantiate the Commit
  signal cmt_badaddr:           std_ulogic_vector(E203_ADDR_SIZE-1 downto 0); 
  signal cmt_badaddr_ena:       std_ulogic;
  signal cmt_epc:               std_ulogic_vector(E203_PC_SIZE-1 downto 0); 
  signal cmt_epc_ena:           std_ulogic;
  signal cmt_cause:             std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal cmt_cause_ena:         std_ulogic;
  signal cmt_instret_ena:       std_ulogic;
  signal cmt_status_ena:        std_ulogic;

  signal cmt_mret_ena:          std_ulogic;

  signal csr_epc_r:             std_ulogic_vector(E203_PC_SIZE-1 downto 0);  
  signal csr_dpc_r:             std_ulogic_vector(E203_PC_SIZE-1 downto 0);  
  signal csr_mtvec_r:           std_ulogic_vector(E203_XLEN-1 downto 0);     

  signal u_mode:                std_ulogic;
  signal s_mode:                std_ulogic;
  signal h_mode:                std_ulogic;
  signal m_mode:                std_ulogic;

  signal status_mie_r:          std_ulogic;
  signal mtie_r:                std_ulogic;
  signal msie_r:                std_ulogic;
  signal meie_r:                std_ulogic;

  
begin
  -- Instantiate the Regfile
  u_e203_exu_regfile: entity work.e203_exu_regfile port map(
    read_src1_idx => i_rs1idx     ,
    read_src2_idx => i_rs2idx     ,
    read_src1_dat => rf_rs1       ,
    read_src2_dat => rf_rs2       ,

    x1_r          => rf2ifu_x1    ,

    wbck_dest_wen => rf_wbck_ena  ,
    wbck_dest_idx => rf_wbck_rdidx,
    wbck_dest_dat => rf_wbck_wdat ,
                             
    test_mode     => test_mode    ,
    clk           => clk          ,
    rst_n         => rst_n         
  );

  -- Instantiate the Decode
  -- The Decoded Info-Bus
  u_e203_exu_decode: entity work.e203_exu_decode port map(
    dbg_mode        => dbg_mode,

    i_instr         => i_ir,
    i_pc            => i_pc,
    i_misalgn       => i_misalgn,
    i_buserr        => i_buserr,
    i_prdt_taken    => i_prdt_taken, 
    i_muldiv_b2b    => i_muldiv_b2b, 
       
    dec_rv32        => OPEN,
    dec_bjp         => OPEN,
    dec_jal         => OPEN,
    dec_jalr        => OPEN,
    dec_bxx         => OPEN,
    dec_jalr_rs1idx => OPEN,
    dec_bjp_imm     => OPEN,

  `if E203_HAS_NICE = "TRUE" then
    dec_nice        => OPEN,
    nice_xs_off     => nice_xs_off,  
    nice_cmt_off_ilgl_o => nice_cmt_off_ilgl,      
  `end if

    dec_mulhsu      => dec2ifu_mulhsu,
    dec_mul         => OPEN,
    dec_div         => dec2ifu_div   ,
    dec_rem         => dec2ifu_rem   ,
    dec_divu        => dec2ifu_divu  ,
    dec_remu        => dec2ifu_remu  ,

    dec_info        => dec_info ,
    dec_rs1x0       => dec_rs1x0,
    dec_rs2x0       => dec_rs2x0,
    dec_rs1en       => dec_rs1en,
    dec_rs2en       => dec_rs2en,
    dec_rdwen       => dec_rdwen,
    dec_rs1idx      => OPEN,
    dec_rs2idx      => OPEN,
    dec_misalgn     => dec_misalgn,
    dec_buserr      => dec_buserr,
    dec_ilegl       => dec_ilegl,
    dec_rdidx       => dec_rdidx,
    dec_pc          => dec_pc,
    dec_imm         => dec_imm
  );

  -- Instantiate the Dispatch
  u_e203_exu_disp: entity work.e203_exu_disp port map(
    wfi_halt_exu_req     => wfi_halt_exu_req,
    wfi_halt_exu_ack     => wfi_halt_exu_ack,
    oitf_empty           => oitf_empty      ,

    amo_wait             => amo_wait        ,

    disp_i_valid         => i_valid         ,
    disp_i_ready         => i_ready         ,
                 
    disp_i_rs1x0         => dec_rs1x0       ,
    disp_i_rs2x0         => dec_rs2x0       ,
    disp_i_rs1en         => dec_rs1en       ,
    disp_i_rs2en         => dec_rs2en       ,
    disp_i_rs1idx        => i_rs1idx        ,
    disp_i_rs2idx        => i_rs2idx        ,
    disp_i_rdwen         => dec_rdwen       ,
    disp_i_rdidx         => dec_rdidx       ,
    disp_i_info          => dec_info        ,
    disp_i_rs1           => rf_rs1          ,
    disp_i_rs2           => rf_rs2          ,
    disp_i_imm           => dec_imm         ,
    disp_i_pc            => dec_pc          ,
    disp_i_misalgn       => dec_misalgn     ,
    disp_i_buserr        => dec_buserr      ,
    disp_i_ilegl         => dec_ilegl       ,

    disp_o_alu_valid     => disp_alu_valid   ,
    disp_o_alu_ready     => disp_alu_ready   ,
    disp_o_alu_longpipe  => disp_alu_longpipe,
    disp_o_alu_itag      => disp_alu_itag    ,
    disp_o_alu_rs1       => disp_alu_rs1     ,
    disp_o_alu_rs2       => disp_alu_rs2     ,
    disp_o_alu_rdwen     => disp_alu_rdwen   ,
    disp_o_alu_rdidx     => disp_alu_rdidx   ,
    disp_o_alu_info      => disp_alu_info    ,
    disp_o_alu_pc        => disp_alu_pc      ,
    disp_o_alu_imm       => disp_alu_imm     ,
    disp_o_alu_misalgn   => disp_alu_misalgn ,
    disp_o_alu_buserr    => disp_alu_buserr  ,
    disp_o_alu_ilegl     => disp_alu_ilegl   ,

    disp_oitf_ena        => disp_oitf_ena    ,
    disp_oitf_ptr        => disp_oitf_ptr    ,
    disp_oitf_ready      => disp_oitf_ready  ,

    disp_oitf_rs1en      => disp_oitf_rs1en ,
    disp_oitf_rs2en      => disp_oitf_rs2en ,
    disp_oitf_rs3en      => disp_oitf_rs3en ,
    disp_oitf_rdwen      => disp_oitf_rdwen ,
    disp_oitf_rs1idx     => disp_oitf_rs1idx,
    disp_oitf_rs2idx     => disp_oitf_rs2idx,
    disp_oitf_rs3idx     => disp_oitf_rs3idx,
    disp_oitf_rdidx      => disp_oitf_rdidx ,
    disp_oitf_rs1fpu     => disp_oitf_rs1fpu,
    disp_oitf_rs2fpu     => disp_oitf_rs2fpu,
    disp_oitf_rs3fpu     => disp_oitf_rs3fpu,
    disp_oitf_rdfpu      => disp_oitf_rdfpu ,
    disp_oitf_pc         => disp_oitf_pc    ,
 
    oitfrd_match_disprs1 => oitfrd_match_disprs1,
    oitfrd_match_disprs2 => oitfrd_match_disprs2,
    oitfrd_match_disprs3 => oitfrd_match_disprs3,
    oitfrd_match_disprd  => oitfrd_match_disprd ,
    
    clk                  => clk,
    rst_n                => rst_n 
  );

  -- Instantiate the OITF
  u_e203_exu_oitf: entity work.e203_exu_oitf port map(
    dis_ready            => disp_oitf_ready,
    dis_ena              => disp_oitf_ena  ,
    ret_ena              => oitf_ret_ena   ,

    dis_ptr              => disp_oitf_ptr  ,

    ret_ptr              => oitf_ret_ptr   ,
    ret_rdidx            => oitf_ret_rdidx ,
    ret_rdwen            => oitf_ret_rdwen ,
    ret_rdfpu            => oitf_ret_rdfpu ,
    ret_pc               => oitf_ret_pc    ,

    disp_i_rs1en         => disp_oitf_rs1en ,
    disp_i_rs2en         => disp_oitf_rs2en ,
    disp_i_rs3en         => disp_oitf_rs3en ,
    disp_i_rdwen         => disp_oitf_rdwen ,
    disp_i_rs1idx        => disp_oitf_rs1idx,
    disp_i_rs2idx        => disp_oitf_rs2idx,
    disp_i_rs3idx        => disp_oitf_rs3idx,
    disp_i_rdidx         => disp_oitf_rdidx ,
    disp_i_rs1fpu        => disp_oitf_rs1fpu,
    disp_i_rs2fpu        => disp_oitf_rs2fpu,
    disp_i_rs3fpu        => disp_oitf_rs3fpu,
    disp_i_rdfpu         => disp_oitf_rdfpu ,
    disp_i_pc            => disp_oitf_pc    ,

    oitfrd_match_disprs1 => oitfrd_match_disprs1,
    oitfrd_match_disprs2 => oitfrd_match_disprs2,
    oitfrd_match_disprs3 => oitfrd_match_disprs3,
    oitfrd_match_disprd  => oitfrd_match_disprd ,

    oitf_empty           => oitf_empty,

    clk                  => clk,
    rst_n                => rst_n      
  );

  -- Instantiate the ALU
  u_e203_exu_alu: entity work.e203_exu_alu port map(
 `if E203_HAS_CSR_NICE = "TRUE" then
    nice_csr_valid => nice_csr_valid,
    nice_csr_ready => nice_csr_ready,
    nice_csr_addr  => nice_csr_addr ,
    nice_csr_wr    => nice_csr_wr   ,
    nice_csr_wdata => nice_csr_wdata,
    nice_csr_rdata => nice_csr_rdata,
 `end if
    csr_access_ilgl  => csr_access_ilgl  ,
    nonflush_cmt_ena => nonflush_cmt_ena ,

    i_valid          => disp_alu_valid   ,
    i_ready          => disp_alu_ready   ,
    i_longpipe       => disp_alu_longpipe,
    i_itag           => disp_alu_itag    ,
    i_rs1            => disp_alu_rs1     ,
    i_rs2            => disp_alu_rs2     ,

  `if E203_HAS_NICE = "TRUE" then
    nice_xs_off      => nice_xs_off,
  `end if

    i_rdwen              => disp_alu_rdwen  ,
    i_rdidx              => disp_alu_rdidx  ,
    i_info               => disp_alu_info   ,
    i_pc                 => i_pc            ,
    i_pc_vld             => i_pc_vld        ,
    i_instr              => i_ir            ,
    i_imm                => disp_alu_imm    ,
    i_misalgn            => disp_alu_misalgn,
    i_buserr             => disp_alu_buserr ,
    i_ilegl              => disp_alu_ilegl  ,

    flush_pulse          => flush_pulse     ,
    flush_req            => flush_req       ,

    oitf_empty           => oitf_empty      ,
    amo_wait             => amo_wait        ,

    cmt_o_valid          => alu_cmt_valid      ,
    cmt_o_ready          => alu_cmt_ready      ,
    cmt_o_pc_vld         => alu_cmt_pc_vld     ,
    cmt_o_pc             => alu_cmt_pc         ,
    cmt_o_instr          => alu_cmt_instr      ,
    cmt_o_imm            => alu_cmt_imm        ,
    cmt_o_rv32           => alu_cmt_rv32       ,
    cmt_o_bjp            => alu_cmt_bjp        ,
    cmt_o_dret           => alu_cmt_dret       ,
    cmt_o_mret           => alu_cmt_mret       ,
    cmt_o_ecall          => alu_cmt_ecall      ,
    cmt_o_ebreak         => alu_cmt_ebreak     ,
    cmt_o_fencei         => alu_cmt_fencei     ,
    cmt_o_wfi            => alu_cmt_wfi        ,
    cmt_o_ifu_misalgn    => alu_cmt_ifu_misalgn,
    cmt_o_ifu_buserr     => alu_cmt_ifu_buserr ,
    cmt_o_ifu_ilegl      => alu_cmt_ifu_ilegl  ,
    cmt_o_bjp_prdt       => alu_cmt_bjp_prdt   ,
    cmt_o_bjp_rslv       => alu_cmt_bjp_rslv   ,
    cmt_o_misalgn        => alu_cmt_misalgn    ,
    cmt_o_ld             => alu_cmt_ld         ,
    cmt_o_stamo          => alu_cmt_stamo      ,
    cmt_o_buserr         => alu_cmt_buserr     ,
    cmt_o_badaddr        => alu_cmt_badaddr    ,

    wbck_o_valid         => alu_wbck_o_valid   , 
    wbck_o_ready         => alu_wbck_o_ready   ,
    wbck_o_wdat          => alu_wbck_o_wdat    ,
    wbck_o_rdidx         => alu_wbck_o_rdidx   ,

    csr_ena              => csr_ena     ,
    csr_idx              => csr_idx     ,
    csr_rd_en            => csr_rd_en   ,
    csr_wr_en            => csr_wr_en   ,
    read_csr_dat         => read_csr_dat,
    wbck_csr_dat         => wbck_csr_dat,

    agu_icb_cmd_valid    => agu_icb_cmd_valid,
    agu_icb_cmd_ready    => agu_icb_cmd_ready,
    agu_icb_cmd_addr     => agu_icb_cmd_addr ,
    agu_icb_cmd_read     => agu_icb_cmd_read ,
    agu_icb_cmd_wdata    => agu_icb_cmd_wdata,
    agu_icb_cmd_wmask    => agu_icb_cmd_wmask,
    agu_icb_cmd_lock     => agu_icb_cmd_lock ,
    agu_icb_cmd_excl     => agu_icb_cmd_excl ,
    agu_icb_cmd_size     => agu_icb_cmd_size ,
   
    agu_icb_cmd_back2agu => agu_icb_cmd_back2agu,
    agu_icb_cmd_usign    => agu_icb_cmd_usign   ,
    agu_icb_cmd_itag     => agu_icb_cmd_itag    ,
  
    agu_icb_rsp_valid    => agu_icb_rsp_valid  ,
    agu_icb_rsp_ready    => agu_icb_rsp_ready  ,
    agu_icb_rsp_err      => agu_icb_rsp_err    ,
    agu_icb_rsp_excl_ok  => agu_icb_rsp_excl_ok,
    agu_icb_rsp_rdata    => agu_icb_rsp_rdata  ,

    mdv_nob2b            => mdv_nob2b,

  `if E203_HAS_NICE = "TRUE" then
    nice_req_valid  => nice_req_valid,
    nice_req_ready  => nice_req_ready,
    nice_req_instr  => nice_req_inst ,
    nice_req_rs1    => nice_req_rs1  , 
    nice_req_rs2    => nice_req_rs2  , 
    

    -- RSP channel for itag read. 
    nice_rsp_multicyc_valid => nice_rsp_multicyc_valid, -- I: current insn is multi-cycle.
    nice_rsp_multicyc_ready => nice_rsp_multicyc_ready, -- O:                             

    nice_longp_wbck_valid   => nice_longp_wbck_valid  , --  Handshake valid
    nice_longp_wbck_ready   => nice_longp_wbck_ready  , --  Handshake ready
    nice_o_itag             => nice_o_itag            ,

    i_nice_cmt_off_ilgl     => nice_cmt_off_ilgl      ,
  `end if

    clk                     => clk,
    rst_n                   => rst_n 
  );

  -- Instantiate the Long-pipe Write-Back
  u_e203_exu_longpwbck: entity work.e203_exu_longpwbck port map(

    lsu_wbck_i_valid   => lsu_o_valid      ,
    lsu_wbck_i_ready   => lsu_o_ready      ,
    lsu_wbck_i_wdat    => lsu_o_wbck_wdat  ,
    lsu_wbck_i_itag    => lsu_o_wbck_itag  ,
    lsu_wbck_i_err     => lsu_o_wbck_err   ,
    lsu_cmt_i_ld       => lsu_o_cmt_ld     ,
    lsu_cmt_i_st       => lsu_o_cmt_st     ,
    lsu_cmt_i_badaddr  => lsu_o_cmt_badaddr,
    lsu_cmt_i_buserr   => lsu_o_cmt_buserr ,

    longp_wbck_o_valid   => longp_wbck_o_valid, 
    longp_wbck_o_ready   => longp_wbck_o_ready,
    longp_wbck_o_wdat    => longp_wbck_o_wdat ,
    longp_wbck_o_rdidx   => longp_wbck_o_rdidx,
    longp_wbck_o_rdfpu   => longp_wbck_o_rdfpu,
    longp_wbck_o_flags   => longp_wbck_o_flags,

    longp_excp_o_ready   => longp_excp_o_ready  ,
    longp_excp_o_valid   => longp_excp_o_valid  ,
    longp_excp_o_ld      => longp_excp_o_ld     ,
    longp_excp_o_st      => longp_excp_o_st     ,
    longp_excp_o_buserr  => longp_excp_o_buserr ,
    longp_excp_o_badaddr => longp_excp_o_badaddr,
    longp_excp_o_insterr => longp_excp_o_insterr,
    longp_excp_o_pc      => longp_excp_o_pc     ,

    oitf_ret_rdidx       => oitf_ret_rdidx,
    oitf_ret_rdwen       => oitf_ret_rdwen,
    oitf_ret_rdfpu       => oitf_ret_rdfpu,
    oitf_ret_pc          => oitf_ret_pc   ,
    oitf_empty           => oitf_empty    ,
    oitf_ret_ptr         => oitf_ret_ptr  ,
    oitf_ret_ena         => oitf_ret_ena  ,

  `if E203_HAS_NICE = "TRUE" then
    nice_longp_wbck_i_valid => nice_longp_wbck_valid, 
    nice_longp_wbck_i_ready => nice_longp_wbck_ready, 
    nice_longp_wbck_i_wdat  => nice_rsp_multicyc_dat,
    nice_longp_wbck_i_err   => nice_rsp_multicyc_err,
    nice_longp_wbck_i_itag  => nice_o_itag          ,
  `end if

    clk                     => clk,
    rst_n                   => rst_n 
  );

  -- Instantiate the Final Write-Back
  u_e203_exu_wbck: entity work.e203_exu_wbck port map(
    alu_wbck_i_valid   => alu_wbck_o_valid, 
    alu_wbck_i_ready   => alu_wbck_o_ready,
    alu_wbck_i_wdat    => alu_wbck_o_wdat ,
    alu_wbck_i_rdidx   => alu_wbck_o_rdidx,
     
    longp_wbck_i_valid => longp_wbck_o_valid, 
    longp_wbck_i_ready => longp_wbck_o_ready,
    longp_wbck_i_wdat  => longp_wbck_o_wdat ,
    longp_wbck_i_rdidx => longp_wbck_o_rdidx,
    longp_wbck_i_rdfpu => longp_wbck_o_rdfpu,
    longp_wbck_i_flags => longp_wbck_o_flags,

    rf_wbck_o_ena      => rf_wbck_ena  ,
    rf_wbck_o_wdat     => rf_wbck_wdat ,
    rf_wbck_o_rdidx    => rf_wbck_rdidx,
      

    clk                => clk,
    rst_n              => rst_n 
  );

  
  -- Instantiate the Commit
  u_e203_exu_commit: entity work.e203_exu_commit port map(
    commit_mret             => commit_mret     ,
    commit_trap             => commit_trap     ,
    core_wfi                => core_wfi        ,
    nonflush_cmt_ena        => nonflush_cmt_ena,

    excp_active             => excp_active     ,

    amo_wait                => amo_wait        ,

    wfi_halt_exu_req        => wfi_halt_exu_req,
    wfi_halt_exu_ack        => wfi_halt_exu_ack,
    wfi_halt_ifu_req        => wfi_halt_ifu_req,
    wfi_halt_ifu_ack        => wfi_halt_ifu_ack,

    dbg_irq_r               => dbg_irq_r,
    lcl_irq_r               => lcl_irq_r,
    ext_irq_r               => ext_irq_r,
    sft_irq_r               => sft_irq_r,
    tmr_irq_r               => tmr_irq_r,
    evt_r                   => evt_r    ,

    status_mie_r            => status_mie_r,
    mtie_r                  => mtie_r      ,
    msie_r                  => msie_r      ,
    meie_r                  => meie_r      ,

    alu_cmt_i_valid         => alu_cmt_valid      ,
    alu_cmt_i_ready         => alu_cmt_ready      ,
    alu_cmt_i_pc            => alu_cmt_pc         ,
    alu_cmt_i_instr         => alu_cmt_instr      ,
    alu_cmt_i_pc_vld        => alu_cmt_pc_vld     ,
    alu_cmt_i_imm           => alu_cmt_imm        ,
    alu_cmt_i_rv32          => alu_cmt_rv32       ,
    alu_cmt_i_bjp           => alu_cmt_bjp        ,
    alu_cmt_i_mret          => alu_cmt_mret       ,
    alu_cmt_i_dret          => alu_cmt_dret       ,
    alu_cmt_i_ecall         => alu_cmt_ecall      ,
    alu_cmt_i_ebreak        => alu_cmt_ebreak     ,
    alu_cmt_i_fencei        => alu_cmt_fencei     ,
    alu_cmt_i_wfi           => alu_cmt_wfi        ,
    alu_cmt_i_ifu_misalgn   => alu_cmt_ifu_misalgn,
    alu_cmt_i_ifu_buserr    => alu_cmt_ifu_buserr ,
    alu_cmt_i_ifu_ilegl     => alu_cmt_ifu_ilegl  ,
    alu_cmt_i_bjp_prdt      => alu_cmt_bjp_prdt   ,
    alu_cmt_i_bjp_rslv      => alu_cmt_bjp_rslv   ,
    alu_cmt_i_misalgn       => alu_cmt_misalgn    ,
    alu_cmt_i_ld            => alu_cmt_ld         ,
    alu_cmt_i_stamo         => alu_cmt_stamo      ,
    alu_cmt_i_buserr        => alu_cmt_buserr     ,
    alu_cmt_i_badaddr       => alu_cmt_badaddr    ,

    longp_excp_i_ready      => longp_excp_o_ready  ,
    longp_excp_i_valid      => longp_excp_o_valid  ,
    longp_excp_i_ld         => longp_excp_o_ld     ,
    longp_excp_i_st         => longp_excp_o_st     ,
    longp_excp_i_buserr     => longp_excp_o_buserr ,
    longp_excp_i_badaddr    => longp_excp_o_badaddr,
    longp_excp_i_insterr    => longp_excp_o_insterr,
    longp_excp_i_pc         => longp_excp_o_pc     ,

    dbg_mode                => dbg_mode     ,
    dbg_halt_r              => dbg_halt_r   ,
    dbg_step_r              => dbg_step_r   ,
    dbg_ebreakm_r           => dbg_ebreakm_r,


    oitf_empty              => oitf_empty,
    u_mode                  => u_mode,
    s_mode                  => s_mode,
    h_mode                  => h_mode,
    m_mode                  => m_mode,

    cmt_badaddr             => cmt_badaddr    , 
    cmt_badaddr_ena         => cmt_badaddr_ena,
    cmt_epc                 => cmt_epc        ,
    cmt_epc_ena             => cmt_epc_ena    ,
    cmt_cause               => cmt_cause      ,
    cmt_cause_ena           => cmt_cause_ena  ,
    cmt_instret_ena         => cmt_instret_ena,
    cmt_status_ena          => cmt_status_ena ,
                          
    cmt_dpc                 => cmt_dpc        ,
    cmt_dpc_ena             => cmt_dpc_ena    ,
    cmt_dcause              => cmt_dcause     ,
    cmt_dcause_ena          => cmt_dcause_ena ,

    cmt_mret_ena            => cmt_mret_ena ,
    csr_epc_r               => csr_epc_r    ,
    csr_dpc_r               => csr_dpc_r    ,
    csr_mtvec_r             => csr_mtvec_r  ,

    flush_pulse             => flush_pulse  ,
    flush_req               => flush_req    ,

    pipe_flush_ack          => pipe_flush_ack    ,
    pipe_flush_req          => pipe_flush_req    ,
    pipe_flush_add_op1      => pipe_flush_add_op1,  
    pipe_flush_add_op2      => pipe_flush_add_op2,  
  `if E203_TIMING_BOOST = "TRUE" then
    pipe_flush_pc           => pipe_flush_pc,  
  `end if 

    clk                     => clk,
    rst_n                   => rst_n 
  );
  
  -- The Decode to IFU read-en used for the branch dependency check
  --   only need to check the integer regfile, so here we need to exclude
  --   the FPU condition out
  dec2ifu_rden  <= disp_oitf_rdwen and (not disp_oitf_rdfpu); 
  dec2ifu_rs1en <= disp_oitf_rs1en and (not disp_oitf_rs1fpu);
  dec2ifu_rdidx <= dec_rdidx;
  rf2ifu_rs1    <= rf_rs1;

  u_e203_exu_csr: entity work.e203_exu_csr port map(
    csr_access_ilgl     => csr_access_ilgl,
  `if E203_HAS_NICE = "TRUE" then
    nice_xs_off         => nice_xs_off,
  `end if
    nonflush_cmt_ena    => nonflush_cmt_ena,
    tm_stop             => tm_stop         ,
    itcm_nohold         => itcm_nohold     ,
    mdv_nob2b           => mdv_nob2b       ,
    core_cgstop         => core_cgstop     ,
    tcm_cgstop          => tcm_cgstop      ,
    csr_ena             => csr_ena         ,
    csr_idx             => csr_idx         ,
    csr_rd_en           => csr_rd_en       ,
    csr_wr_en           => csr_wr_en       ,
    read_csr_dat        => read_csr_dat    ,
    wbck_csr_dat        => wbck_csr_dat    ,
   
    cmt_badaddr         => cmt_badaddr    , 
    cmt_badaddr_ena     => cmt_badaddr_ena,
    cmt_epc             => cmt_epc        ,
    cmt_epc_ena         => cmt_epc_ena    ,
    cmt_cause           => cmt_cause      ,
    cmt_cause_ena       => cmt_cause_ena  ,
    cmt_instret_ena     => cmt_instret_ena,
    cmt_status_ena      => cmt_status_ena ,

    cmt_mret_ena    => cmt_mret_ena ,
    csr_epc_r       => csr_epc_r    ,
    csr_dpc_r       => csr_dpc_r    ,
    csr_mtvec_r     => csr_mtvec_r  ,

    wr_dcsr_ena     => wr_dcsr_ena    ,
    wr_dpc_ena      => wr_dpc_ena     ,
    wr_dscratch_ena => wr_dscratch_ena,
                
    wr_csr_nxt      => wr_csr_nxt     ,
                
    dcsr_r          => dcsr_r         ,
    dpc_r           => dpc_r          ,
    dscratch_r      => dscratch_r     ,
                                   
    dbg_mode        => dbg_mode       ,
    dbg_stopcycle   => dbg_stopcycle  ,

    u_mode          => u_mode,
    s_mode          => s_mode,
    h_mode          => h_mode,
    m_mode          => m_mode,

    core_mhartid    => core_mhartid,

    status_mie_r    => status_mie_r,
    mtie_r          => mtie_r      ,
    msie_r          => msie_r      ,
    meie_r          => meie_r      ,

    ext_irq_r       => ext_irq_r,
    sft_irq_r       => sft_irq_r,
    tmr_irq_r       => tmr_irq_r,

    clk_aon         => clk_aon,
    clk             => clk,
    rst_n           => rst_n   
  );

  exu_active <= (not oitf_empty) or i_valid or excp_active;
end impl;
