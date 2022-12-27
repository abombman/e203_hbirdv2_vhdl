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
--   The Core module to implement the core portion of the cpu
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_core is 
  port ( inspect_pc:     out std_logic_vector(E203_PC_SIZE-1 downto 0);
         
        `if E203_HAS_CSR_NICE = "TRUE" then
         nice_csr_valid: out std_logic;         
         nice_csr_ready:  in std_logic;         
         nice_csr_addr:  out std_logic_vector(31 downto 0); 
         nice_csr_wr:    out std_logic;        
         nice_csr_wdata: out std_logic_vector(31 downto 0); 
         nice_csr_rdata:  in std_logic_vector(31 downto 0); 
        `end if
         core_wfi:       out std_logic; 
         tm_stop:        out std_logic; 
         core_cgstop:    out std_logic; 
         tcm_cgstop:     out std_logic;

         pc_rtvec:        in std_logic_vector(E203_PC_SIZE-1 downto 0);
         
         core_mhartid:    in std_logic_vector(E203_HART_ID_W-1 downto 0);
         dbg_irq_r:       in std_logic;
         lcl_irq_r:       in std_logic_vector(E203_LIRQ_NUM-1 downto 0);
         evt_r:           in std_logic_vector(E203_EVT_NUM-1 downto 0);
         ext_irq_r:       in std_logic;
         sft_irq_r:       in std_logic;
         tmr_irq_r:       in std_logic;

         -- From/To debug ctrl module
         wr_dcsr_ena:    out std_logic; 
         wr_dpc_ena:     out std_logic; 
         wr_dscratch_ena:out std_logic;
    
         wr_csr_nxt:     out std_logic_vector(31 downto 0);
         dcsr_r:          in std_logic_vector(31 downto 0);
         dpc_r:           in std_logic_vector(E203_PC_SIZE-1 downto 0);
         dscratch_r:      in std_logic_vector(31 downto 0); 

         cmt_dpc:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_dpc_ena:    out std_logic;
         cmt_dcause:     out std_logic_vector(3-1 downto 0);
         cmt_dcause_ena: out std_logic;
    
         dbg_mode:        in std_logic;  
         dbg_halt_r:      in std_logic;  
         dbg_step_r:      in std_logic;  
         dbg_ebreakm_r:   in std_logic;  
         dbg_stopcycle:   in std_logic;

        `if E203_HAS_ITCM = "TRUE" then
         -- The ITCM address region indication signal
         itcm_region_indic: in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ifu2itcm_holdup:   in std_logic;
         
         -- Bus Interface to ITCM, internal protocol called ICB (Internal Chip Bus)
         --    * Bus cmd channel
         ifu2itcm_icb_cmd_valid: out std_logic; -- Handshake valid
         ifu2itcm_icb_cmd_ready:  in std_logic; -- Handshake ready
         -- Note: The data on rdata or wdata channel must be naturally
         -- aligned, this is in line with the AXI definition
         ifu2itcm_icb_cmd_addr:  out std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr
         
         -- * Bus RSP channel
         ifu2itcm_icb_rsp_valid:        in  std_logic; -- Response valid 
         ifu2itcm_icb_rsp_ready:       out  std_logic; -- Response ready
         ifu2itcm_icb_rsp_err:          in  std_logic; -- Response error
         -- Note: the RSP rdata is inline with AXI definition
         ifu2itcm_icb_rsp_rdata:        in  std_logic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
        `end if

         -- The ICB Interface to Private Peripheral Interface
         ppi_region_indic:         in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ppi_icb_enable:           in  std_logic;
         --    * bus cmd channel
         ppi_icb_cmd_valid:       out  std_logic; 
         ppi_icb_cmd_ready:        in  std_logic;  
         ppi_icb_cmd_addr:        out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ppi_icb_cmd_read:        out  std_logic;
         ppi_icb_cmd_wdata:       out  std_logic_vector(E203_XLEN-1 downto 0);
         ppi_icb_cmd_wmask:       out  std_logic_vector(E203_XLEN/8-1 downto 0);
         ppi_icb_cmd_lock:        out  std_logic;
         ppi_icb_cmd_excl:        out  std_logic;
         ppi_icb_cmd_size:        out  std_logic_vector(1 downto 0);
        
         -- * RSP channel         
         ppi_icb_rsp_valid:        in  std_logic; 
         ppi_icb_rsp_ready:       out  std_logic; 
         ppi_icb_rsp_err:          in  std_logic;
         ppi_icb_rsp_excl_ok:      in  std_logic;
         ppi_icb_rsp_rdata:        in  std_logic_vector(E203_XLEN-1 downto 0);

         clint_region_indic:       in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         clint_icb_enable:         in  std_logic;
         --    * bus cmd channel  
         clint_icb_cmd_valid:     out  std_logic; 
         clint_icb_cmd_ready:      in  std_logic;  
         clint_icb_cmd_addr:      out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         clint_icb_cmd_read:      out  std_logic;
         clint_icb_cmd_wdata:     out  std_logic_vector(E203_XLEN-1 downto 0);
         clint_icb_cmd_wmask:     out  std_logic_vector(E203_XLEN/8-1 downto 0);
         clint_icb_cmd_lock:      out  std_logic;
         clint_icb_cmd_excl:      out  std_logic;
         clint_icb_cmd_size:      out  std_logic_vector(1 downto 0);
      
         -- * RSP channel       
         clint_icb_rsp_valid:      in  std_logic; 
         clint_icb_rsp_ready:     out  std_logic; 
         clint_icb_rsp_err:        in  std_logic;
         clint_icb_rsp_excl_ok:    in  std_logic;
         clint_icb_rsp_rdata:      in  std_logic_vector(E203_XLEN-1 downto 0);

         plic_region_indic:        in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         plic_icb_enable:          in  std_logic;
         --    * bus cmd channel   
         plic_icb_cmd_valid:      out  std_logic; 
         plic_icb_cmd_ready:       in  std_logic;  
         plic_icb_cmd_addr:       out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         plic_icb_cmd_read:       out  std_logic;
         plic_icb_cmd_wdata:      out  std_logic_vector(E203_XLEN-1 downto 0);
         plic_icb_cmd_wmask:      out  std_logic_vector(E203_XLEN/8-1 downto 0);
         plic_icb_cmd_lock:       out  std_logic;
         plic_icb_cmd_excl:       out  std_logic;
         plic_icb_cmd_size:       out  std_logic_vector(1 downto 0);
       
         -- * RSP channel        
         plic_icb_rsp_valid:       in  std_logic; 
         plic_icb_rsp_ready:      out  std_logic; 
         plic_icb_rsp_err:         in  std_logic;
         plic_icb_rsp_excl_ok:     in  std_logic;
         plic_icb_rsp_rdata:       in  std_logic_vector(E203_XLEN-1 downto 0);

        `if E203_HAS_FIO = "TRUE" then
         -- The ICB Interface to Fast I/O
         fio_region_indic:         in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         fio_icb_enable:           in  std_logic;
         --    * bus cmd channel    
         fio_icb_cmd_valid:       out  std_logic; 
         fio_icb_cmd_ready:        in  std_logic;  
         fio_icb_cmd_addr:        out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         fio_icb_cmd_read:        out  std_logic;
         fio_icb_cmd_wdata:       out  std_logic_vector(E203_XLEN-1 downto 0);
         fio_icb_cmd_wmask:       out  std_logic_vector(E203_XLEN/8-1 downto 0);
         fio_icb_cmd_lock:        out  std_logic;
         fio_icb_cmd_excl:        out  std_logic;
         fio_icb_cmd_size:        out  std_logic_vector(1 downto 0);
        
         -- * RSP channel         
         fio_icb_rsp_valid:        in  std_logic; 
         fio_icb_rsp_ready:       out  std_logic; 
         fio_icb_rsp_err:          in  std_logic;
         fio_icb_rsp_excl_ok:      in  std_logic;
         fio_icb_rsp_rdata:        in  std_logic_vector(E203_XLEN-1 downto 0);
        `end if

        `if E203_HAS_MEM_ITF = "TRUE" then
         -- The ICB Interface from Ifetch
         mem_icb_enable:           in  std_logic;
         --    * bus cmd channel    
         mem_icb_cmd_valid:       out  std_logic; 
         mem_icb_cmd_ready:        in  std_logic;  
         mem_icb_cmd_addr:        out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         mem_icb_cmd_read:        out  std_logic;
         mem_icb_cmd_wdata:       out  std_logic_vector(E203_XLEN-1 downto 0);
         mem_icb_cmd_wmask:       out  std_logic_vector(E203_XLEN/8-1 downto 0);
         mem_icb_cmd_lock:        out  std_logic;
         mem_icb_cmd_excl:        out  std_logic;
         mem_icb_cmd_size:        out  std_logic_vector(1 downto 0);
         mem_icb_cmd_burst:       out  std_logic_vector(1 downto 0);
         mem_icb_cmd_beat:        out  std_logic_vector(1 downto 0);
         -- * RSP channel         
         mem_icb_rsp_valid:        in  std_logic; 
         mem_icb_rsp_ready:       out  std_logic; 
         mem_icb_rsp_err:          in  std_logic;
         mem_icb_rsp_excl_ok:      in  std_logic;
         mem_icb_rsp_rdata:        in  std_logic_vector(E203_XLEN-1 downto 0);
        `end if

        `if E203_HAS_ITCM = "TRUE" then 
         -- The ICB Interface to ITCM
         -- * Bus cmd channel
         lsu2itcm_icb_cmd_valid:  out  std_logic; 
         lsu2itcm_icb_cmd_ready:   in  std_logic;  
         lsu2itcm_icb_cmd_addr:   out  std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
         lsu2itcm_icb_cmd_read:   out  std_logic;
         lsu2itcm_icb_cmd_wdata:  out  std_logic_vector(E203_XLEN-1 downto 0);
         lsu2itcm_icb_cmd_wmask:  out  std_logic_vector(E203_XLEN/8-1 downto 0);
         lsu2itcm_icb_cmd_lock:   out  std_logic;
         lsu2itcm_icb_cmd_excl:   out  std_logic;
         lsu2itcm_icb_cmd_size:   out  std_logic_vector(1 downto 0);
          
         -- * RSP channel     
         lsu2itcm_icb_rsp_valid:   in  std_logic; 
         lsu2itcm_icb_rsp_ready:  out  std_logic; 
         lsu2itcm_icb_rsp_err:     in  std_logic;
         lsu2itcm_icb_rsp_excl_ok: in  std_logic;
         lsu2itcm_icb_rsp_rdata:   in  std_logic_vector(E203_XLEN-1 downto 0);    
        `end if

        `if E203_HAS_DTCM = "TRUE" then 
         dtcm_region_indic:        in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         -- The ICB Interface to ITCM
         -- * Bus cmd channel
         lsu2dtcm_icb_cmd_valid:  out  std_logic; 
         lsu2dtcm_icb_cmd_ready:   in  std_logic;  
         lsu2dtcm_icb_cmd_addr:   out  std_logic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0);
         lsu2dtcm_icb_cmd_read:   out  std_logic;
         lsu2dtcm_icb_cmd_wdata:  out  std_logic_vector(E203_XLEN-1 downto 0);
         lsu2dtcm_icb_cmd_wmask:  out  std_logic_vector(E203_XLEN/8-1 downto 0);
         lsu2dtcm_icb_cmd_lock:   out  std_logic;
         lsu2dtcm_icb_cmd_excl:   out  std_logic;
         lsu2dtcm_icb_cmd_size:   out  std_logic_vector(1 downto 0);
          
         -- * RSP channel     
         lsu2dtcm_icb_rsp_valid:   in  std_logic; 
         lsu2dtcm_icb_rsp_ready:  out  std_logic; 
         lsu2dtcm_icb_rsp_err:     in  std_logic;
         lsu2dtcm_icb_rsp_excl_ok: in  std_logic;
         lsu2dtcm_icb_rsp_rdata:   in  std_logic_vector(E203_XLEN-1 downto 0);    
        `end if

        `if E203_HAS_NICE = "TRUE" then
         nice_mem_holdup:          in  std_logic; -- O: nice occupys the memory. for avoid of dead-loop
         -- nice_req interface
         nice_req_valid:          out  std_logic; -- O: handshake flag, cmd is valid.
         nice_req_ready:           in  std_logic; -- I: handshake flag, cmd is accepted.
         nice_req_inst:           out  std_logic_vector(E203_XLEN-1 downto 0); -- O: inst sent to nice. 
         nice_req_rs1:            out  std_logic_vector(E203_XLEN-1 downto 0); -- O: rs op 1.
         nice_req_rs2:            out  std_logic_vector(E203_XLEN-1 downto 0); -- O: rs op 2.

         -- icb_cmd_rsp interface
         -- for one cycle insn, the rsp data is valid at the same time of insn, so
         -- the handshake flags is useless.
 
         nice_rsp_multicyc_valid:  in  std_logic; -- I: current insn is multi-cycle.
         nice_rsp_multicyc_ready: out  std_logic; -- O: current insn is multi-cycle. 
         nice_rsp_multicyc_dat:    in  std_logic_vector(E203_XLEN-1 downto 0); -- I: one cycle result write-back val.
         nice_rsp_multicyc_err:    in  std_logic;

         -- lsu_req interface 
         nice_icb_cmd_valid:       in  std_logic; -- I: nice access main-mem req valid.
         nice_icb_cmd_ready:      out  std_logic; -- O: nice access req is accepted.
         nice_icb_cmd_addr:        in  std_logic_vector(E203_XLEN-1 downto 0); -- I : nice access main-mem address.
         nice_icb_cmd_read:        in  std_logic; -- I: nice access type.
         nice_icb_cmd_wdata:       in  std_logic_vector(E203_XLEN-1 downto 0); -- I: nice write data.
         nice_icb_cmd_size:        in  std_logic_vector(1 downto 0); -- I: data size input.
          
         -- lsu_rsp interface
         nice_icb_rsp_valid:      out  std_logic; -- O: main core responds result to nice.
         nice_icb_rsp_ready:       in  std_logic; -- I: respond result is accepted.      
         nice_icb_rsp_rdata:      out  std_logic_vector(E203_XLEN-1 downto 0); -- O: rsp data.
         nice_icb_rsp_err:        out  std_logic; -- O : err flag
        `end if
         
         exu_active:              out std_logic; 
         ifu_active:              out std_logic; 
         lsu_active:              out std_logic; 
         biu_active:              out std_logic;

         clk_core_ifu:             in std_logic;  
         clk_core_exu:             in std_logic;  
         clk_core_lsu:             in std_logic;  
         clk_core_biu:             in std_logic;  
         clk_aon:                  in std_logic;
         
         test_mode:                in  std_logic;
         rst_n:                    in  std_logic        
  );
end e203_core;

architecture impl of e203_core is 
 `if E203_HAS_MEM_ITF = "TRUE" then
  signal ifu2biu_icb_cmd_valid:   std_ulogic; 
  signal ifu2biu_icb_cmd_ready:   std_ulogic;  
  signal ifu2biu_icb_cmd_addr:    std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
  -- * RSP channel     
  signal ifu2biu_icb_rsp_valid:   std_ulogic; 
  signal ifu2biu_icb_rsp_ready:   std_ulogic; 
  signal ifu2biu_icb_rsp_err:     std_ulogic;
  signal ifu2biu_icb_rsp_excl_ok: std_ulogic;
  signal ifu2biu_icb_rsp_rdata:   std_ulogic_vector(E203_XLEN-1 downto 0);
 `end if

  signal ifu_o_valid:             std_ulogic;
  signal ifu_o_ready:             std_ulogic;
  signal ifu_o_ir:                std_ulogic_vector(E203_INSTR_SIZE-1 downto 0); 
  signal ifu_o_pc:                std_ulogic_vector(E203_PC_SIZE-1 downto 0);   
  signal ifu_o_pc_vld:            std_ulogic; 
  signal ifu_o_misalgn:           std_ulogic; 
  signal ifu_o_buserr:            std_ulogic; 
  signal ifu_o_rs1idx:            std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal ifu_o_rs2idx:            std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal ifu_o_prdt_taken:        std_ulogic;
  signal ifu_o_muldiv_b2b:        std_ulogic;

  signal wfi_halt_ifu_req:        std_ulogic;
  signal wfi_halt_ifu_ack:        std_ulogic;
  signal pipe_flush_ack:          std_ulogic;
  signal pipe_flush_req:          std_ulogic;
  signal pipe_flush_add_op1:      std_ulogic_vector(E203_PC_SIZE-1 downto 0);   
  signal pipe_flush_add_op2:      std_ulogic_vector(E203_PC_SIZE-1 downto 0); 

 `if E203_TIMING_BOOST = "TRUE" then
  signal pipe_flush_pc:           std_ulogic_vector(E203_PC_SIZE-1 downto 0);   
 `end if

  signal oitf_empty:              std_ulogic;
  signal rf2ifu_x1:               std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal rf2ifu_rs1:              std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal dec2ifu_rden:            std_ulogic;
  signal dec2ifu_rs1en:           std_ulogic;
  signal dec2ifu_rdidx:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0); 
  signal dec2ifu_mulhsu:          std_ulogic;
  signal dec2ifu_div:             std_ulogic;
  signal dec2ifu_rem:             std_ulogic;
  signal dec2ifu_divu:            std_ulogic;
  signal dec2ifu_remu:            std_ulogic;

  signal itcm_nohold:             std_ulogic;
            
  signal lsu_o_valid:             std_ulogic; 
  signal lsu_o_ready:             std_ulogic; 
  signal lsu_o_wbck_wdat:         std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal lsu_o_wbck_itag:         std_ulogic_vector(E203_ITAG_WIDTH -1 downto 0); 
  signal lsu_o_wbck_err:          std_ulogic; 
  signal lsu_o_cmt_buserr:        std_ulogic; 
  signal lsu_o_cmt_ld:            std_ulogic;
  signal lsu_o_cmt_st:            std_ulogic;
  signal lsu_o_cmt_badaddr:       std_ulogic_vector(E203_ADDR_SIZE -1 downto 0);  

  signal agu_icb_cmd_valid:       std_ulogic; 
  signal agu_icb_cmd_ready:       std_ulogic; 
  signal agu_icb_cmd_addr:        std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);    
  signal agu_icb_cmd_read:        std_ulogic;   
  signal agu_icb_cmd_wdata:       std_ulogic_vector(E203_XLEN-1 downto 0);         
  signal agu_icb_cmd_wmask:       std_ulogic_vector(E203_XLEN/8-1 downto 0);       
  signal agu_icb_cmd_lock:        std_ulogic;
  signal agu_icb_cmd_excl:        std_ulogic;
  signal agu_icb_cmd_size:        std_ulogic_vector(1 downto 0);                   
  signal agu_icb_cmd_back2agu:    std_ulogic; 
  signal agu_icb_cmd_usign:       std_ulogic;
  signal agu_icb_cmd_itag:        std_ulogic_vector(E203_ITAG_WIDTH -1 downto 0); 
  signal agu_icb_rsp_valid:       std_ulogic; 
  signal agu_icb_rsp_ready:       std_ulogic; 
  signal agu_icb_rsp_err:         std_ulogic; 
  signal agu_icb_rsp_excl_ok:     std_ulogic; 
  signal agu_icb_rsp_rdata:       std_ulogic_vector(E203_XLEN-1 downto 0);        

  signal commit_mret:             std_ulogic;
  signal commit_trap:             std_ulogic;
  signal excp_active:             std_ulogic;

  signal lsu2biu_icb_cmd_valid:   std_ulogic;
  signal lsu2biu_icb_cmd_ready:   std_ulogic;
  signal lsu2biu_icb_cmd_addr:    std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);    
  signal lsu2biu_icb_cmd_read:    std_ulogic; 
  signal lsu2biu_icb_cmd_wdata:   std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal lsu2biu_icb_cmd_wmask:   std_ulogic_vector(E203_XLEN/8-1 downto 0);      
  signal lsu2biu_icb_cmd_lock:    std_ulogic;
  signal lsu2biu_icb_cmd_excl:    std_ulogic;
  signal lsu2biu_icb_cmd_size:    std_ulogic_vector(1 downto 0);                   

  signal lsu2biu_icb_rsp_valid:   std_ulogic;
  signal lsu2biu_icb_rsp_ready:   std_ulogic;
  signal lsu2biu_icb_rsp_err:     std_ulogic;
  signal lsu2biu_icb_rsp_excl_ok: std_ulogic;
  signal lsu2biu_icb_rsp_rdata:   std_ulogic_vector(E203_XLEN-1 downto 0);        

begin
  u_e203_ifu: entity work.e203_ifu port map(
    inspect_pc      => inspect_pc,
    ifu_active      => ifu_active,
    pc_rtvec        => pc_rtvec,  
    itcm_nohold     => itcm_nohold,

 `if E203_HAS_ITCM = "TRUE" then
    ifu2itcm_holdup => ifu2itcm_holdup,

    -- The ITCM address region indication signal
    itcm_region_indic      => itcm_region_indic,

    ifu2itcm_icb_cmd_valid => ifu2itcm_icb_cmd_valid,
    ifu2itcm_icb_cmd_ready => ifu2itcm_icb_cmd_ready,
    ifu2itcm_icb_cmd_addr  => ifu2itcm_icb_cmd_addr ,
    ifu2itcm_icb_rsp_valid => ifu2itcm_icb_rsp_valid,
    ifu2itcm_icb_rsp_ready => ifu2itcm_icb_rsp_ready,
    ifu2itcm_icb_rsp_err   => ifu2itcm_icb_rsp_err  ,
    ifu2itcm_icb_rsp_rdata => ifu2itcm_icb_rsp_rdata,
 `end if

 `if E203_HAS_MEM_ITF = "TRUE" then
    ifu2biu_icb_cmd_valid  => ifu2biu_icb_cmd_valid,
    ifu2biu_icb_cmd_ready  => ifu2biu_icb_cmd_ready,
    ifu2biu_icb_cmd_addr   => ifu2biu_icb_cmd_addr ,
    
    ifu2biu_icb_rsp_valid  => ifu2biu_icb_rsp_valid,
    ifu2biu_icb_rsp_ready  => ifu2biu_icb_rsp_ready,
    ifu2biu_icb_rsp_err    => ifu2biu_icb_rsp_err  ,
    ifu2biu_icb_rsp_rdata  => ifu2biu_icb_rsp_rdata,
 `end if

    ifu_o_valid            => ifu_o_valid         ,
    ifu_o_ready            => ifu_o_ready         ,
    ifu_o_ir               => ifu_o_ir            ,
    ifu_o_pc               => ifu_o_pc            ,
    ifu_o_pc_vld           => ifu_o_pc_vld        ,
    ifu_o_misalgn          => ifu_o_misalgn       , 
    ifu_o_buserr           => ifu_o_buserr        , 
    ifu_o_rs1idx           => ifu_o_rs1idx        ,
    ifu_o_rs2idx           => ifu_o_rs2idx        ,
    ifu_o_prdt_taken       => ifu_o_prdt_taken    ,
    ifu_o_muldiv_b2b       => ifu_o_muldiv_b2b    ,

    ifu_halt_req           => wfi_halt_ifu_req    ,
    ifu_halt_ack           => wfi_halt_ifu_ack    ,
    pipe_flush_ack         => pipe_flush_ack      ,
    pipe_flush_req         => pipe_flush_req      ,
    pipe_flush_add_op1     => pipe_flush_add_op1  ,  
    pipe_flush_add_op2     => pipe_flush_add_op2  ,  
 `if E203_TIMING_BOOST = "TRUE" then
    pipe_flush_pc          => pipe_flush_pc,  
 `end if
                             
    oitf_empty             => oitf_empty   ,
    rf2ifu_x1              => rf2ifu_x1    ,
    rf2ifu_rs1             => rf2ifu_rs1   ,
    dec2ifu_rden           => dec2ifu_rden ,
    dec2ifu_rs1en          => dec2ifu_rs1en,
    dec2ifu_rdidx          => dec2ifu_rdidx,
    dec2ifu_mulhsu         => dec2ifu_mulhsu,
    dec2ifu_div            => dec2ifu_div   ,
    dec2ifu_rem            => dec2ifu_rem   ,
    dec2ifu_divu           => dec2ifu_divu  ,
    dec2ifu_remu           => dec2ifu_remu  ,

    clk                    => clk_core_ifu  ,
    rst_n                  => rst_n          
  );

  u_e203_exu: entity work.e203_exu port map(

 `if E203_HAS_CSR_NICE = "TRUE" then
    nice_csr_valid => nice_csr_valid,
    nice_csr_ready => nice_csr_ready,
    nice_csr_addr  => nice_csr_addr ,
    nice_csr_wr    => nice_csr_wr   ,
    nice_csr_wdata => nice_csr_wdata,
    nice_csr_rdata => nice_csr_rdata,
 `end if

    excp_active     => excp_active,
    commit_mret     => commit_mret,
    commit_trap     => commit_trap,
    test_mode       => test_mode,
    core_wfi        => core_wfi,
    tm_stop         => tm_stop,
    itcm_nohold     => itcm_nohold,
    core_cgstop     => core_cgstop,
    tcm_cgstop      => tcm_cgstop,
    exu_active      => exu_active,

    core_mhartid    => core_mhartid,
    dbg_irq_r       => dbg_irq_r   ,
    lcl_irq_r       => lcl_irq_r   ,
    ext_irq_r       => ext_irq_r   ,
    sft_irq_r       => sft_irq_r   ,
    tmr_irq_r       => tmr_irq_r   ,
    evt_r           => evt_r       ,

    cmt_dpc         => cmt_dpc        ,
    cmt_dpc_ena     => cmt_dpc_ena    ,
    cmt_dcause      => cmt_dcause     ,
    cmt_dcause_ena  => cmt_dcause_ena ,

    wr_dcsr_ena     => wr_dcsr_ena    ,
    wr_dpc_ena      => wr_dpc_ena     ,
    wr_dscratch_ena => wr_dscratch_ena,
                                  
    wr_csr_nxt      => wr_csr_nxt     ,
                                    
    dcsr_r          => dcsr_r         ,
    dpc_r           => dpc_r          ,
    dscratch_r      => dscratch_r     ,

    dbg_mode           => dbg_mode  ,
    dbg_halt_r         => dbg_halt_r,
    dbg_step_r         => dbg_step_r,
    dbg_ebreakm_r      => dbg_ebreakm_r,
    dbg_stopcycle      => dbg_stopcycle,

    i_valid            => ifu_o_valid       ,
    i_ready            => ifu_o_ready       ,
    i_ir               => ifu_o_ir          ,
    i_pc               => ifu_o_pc          ,
    i_pc_vld           => ifu_o_pc_vld      ,
    i_misalgn          => ifu_o_misalgn     , 
    i_buserr           => ifu_o_buserr      , 
    i_rs1idx           => ifu_o_rs1idx      ,
    i_rs2idx           => ifu_o_rs2idx      ,
    i_prdt_taken       => ifu_o_prdt_taken  ,
    i_muldiv_b2b       => ifu_o_muldiv_b2b  ,

    wfi_halt_ifu_req   => wfi_halt_ifu_req  ,
    wfi_halt_ifu_ack   => wfi_halt_ifu_ack  ,

    pipe_flush_ack     => pipe_flush_ack    ,
    pipe_flush_req     => pipe_flush_req    ,
    pipe_flush_add_op1 => pipe_flush_add_op1,  
    pipe_flush_add_op2 => pipe_flush_add_op2,  
 `if E203_TIMING_BOOST = "TRUE" then
    pipe_flush_pc      => pipe_flush_pc,  
 `end if

    lsu_o_valid          => lsu_o_valid      ,
    lsu_o_ready          => lsu_o_ready      ,
    lsu_o_wbck_wdat      => lsu_o_wbck_wdat  ,
    lsu_o_wbck_itag      => lsu_o_wbck_itag  ,
    lsu_o_wbck_err       => lsu_o_wbck_err   ,
    lsu_o_cmt_buserr     => lsu_o_cmt_buserr ,
    lsu_o_cmt_ld         => lsu_o_cmt_ld     ,
    lsu_o_cmt_st         => lsu_o_cmt_st     ,
    lsu_o_cmt_badaddr    => lsu_o_cmt_badaddr,

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

    oitf_empty           => oitf_empty   ,
    rf2ifu_x1            => rf2ifu_x1    ,
    rf2ifu_rs1           => rf2ifu_rs1   ,
    dec2ifu_rden         => dec2ifu_rden ,
    dec2ifu_rs1en        => dec2ifu_rs1en,
    dec2ifu_rdidx        => dec2ifu_rdidx,
    dec2ifu_mulhsu       => dec2ifu_mulhsu,
    dec2ifu_div          => dec2ifu_div   ,
    dec2ifu_rem          => dec2ifu_rem   ,
    dec2ifu_divu         => dec2ifu_divu  ,
    dec2ifu_remu         => dec2ifu_remu  ,

 `if E203_HAS_NICE = "TRUE" then
    nice_req_valid          => nice_req_valid, -- O: handshake flag, cmd is valid
    nice_req_ready          => nice_req_ready, -- I: handshake flag, cmd is accepted.
    nice_req_inst           => nice_req_inst , -- O: inst sent to nice. 
    nice_req_rs1            => nice_req_rs1  , -- O: rs op 1.
    nice_req_rs2            => nice_req_rs2  , -- O: rs op 2.
                                             
    nice_rsp_multicyc_valid => nice_rsp_multicyc_valid, -- I: current insn is multi-cycle.
    nice_rsp_multicyc_ready => nice_rsp_multicyc_ready, -- I: current insn is multi-cycle.
    nice_rsp_multicyc_dat   => nice_rsp_multicyc_dat  , -- I: one cycle result write-back val.
    nice_rsp_multicyc_err   => nice_rsp_multicyc_err  ,
 `end if

    clk_aon                 => clk_aon,
    clk                     => clk_core_exu,
    rst_n                   => rst_n 
  );

  u_e203_lsu: entity work.e203_lsu port map(
    excp_active          => excp_active,
    commit_mret          => commit_mret,
    commit_trap          => commit_trap,
    lsu_active           => lsu_active ,
    lsu_o_valid          => lsu_o_valid,
    lsu_o_ready          => lsu_o_ready,
    lsu_o_wbck_wdat      => lsu_o_wbck_wdat  ,
    lsu_o_wbck_itag      => lsu_o_wbck_itag  ,
    lsu_o_wbck_err       => lsu_o_wbck_err   ,
    lsu_o_cmt_buserr     => lsu_o_cmt_buserr ,
    lsu_o_cmt_ld         => lsu_o_cmt_ld     ,
    lsu_o_cmt_st         => lsu_o_cmt_st     ,
    lsu_o_cmt_badaddr    => lsu_o_cmt_badaddr,
                       
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
    agu_icb_cmd_usign    => agu_icb_cmd_usign,
    agu_icb_cmd_itag     => agu_icb_cmd_itag,
  
    agu_icb_rsp_valid    => agu_icb_rsp_valid ,
    agu_icb_rsp_ready    => agu_icb_rsp_ready ,
    agu_icb_rsp_err      => agu_icb_rsp_err   ,
    agu_icb_rsp_excl_ok  => agu_icb_rsp_excl_ok,
    agu_icb_rsp_rdata    => agu_icb_rsp_rdata,

 `if E203_HAS_ITCM = "TRUE" then
    itcm_region_indic    => itcm_region_indic,
    itcm_icb_cmd_valid   => lsu2itcm_icb_cmd_valid,
    itcm_icb_cmd_ready   => lsu2itcm_icb_cmd_ready,
    itcm_icb_cmd_addr    => lsu2itcm_icb_cmd_addr ,
    itcm_icb_cmd_read    => lsu2itcm_icb_cmd_read ,
    itcm_icb_cmd_wdata   => lsu2itcm_icb_cmd_wdata,
    itcm_icb_cmd_wmask   => lsu2itcm_icb_cmd_wmask,
    itcm_icb_cmd_lock    => lsu2itcm_icb_cmd_lock ,
    itcm_icb_cmd_excl    => lsu2itcm_icb_cmd_excl ,
    itcm_icb_cmd_size    => lsu2itcm_icb_cmd_size ,
    
    itcm_icb_rsp_valid   => lsu2itcm_icb_rsp_valid,
    itcm_icb_rsp_ready   => lsu2itcm_icb_rsp_ready,
    itcm_icb_rsp_err     => lsu2itcm_icb_rsp_err  ,
    itcm_icb_rsp_excl_ok => lsu2itcm_icb_rsp_excl_ok,
    itcm_icb_rsp_rdata   => lsu2itcm_icb_rsp_rdata,

 `end if

 `if E203_HAS_DTCM = "TRUE" then
    dtcm_region_indic    => dtcm_region_indic,

    dtcm_icb_cmd_valid   => lsu2dtcm_icb_cmd_valid,
    dtcm_icb_cmd_ready   => lsu2dtcm_icb_cmd_ready,
    dtcm_icb_cmd_addr    => lsu2dtcm_icb_cmd_addr ,
    dtcm_icb_cmd_read    => lsu2dtcm_icb_cmd_read ,
    dtcm_icb_cmd_wdata   => lsu2dtcm_icb_cmd_wdata,
    dtcm_icb_cmd_wmask   => lsu2dtcm_icb_cmd_wmask,
    dtcm_icb_cmd_lock    => lsu2dtcm_icb_cmd_lock ,
    dtcm_icb_cmd_excl    => lsu2dtcm_icb_cmd_excl ,
    dtcm_icb_cmd_size    => lsu2dtcm_icb_cmd_size ,
    
    dtcm_icb_rsp_valid   => lsu2dtcm_icb_rsp_valid,
    dtcm_icb_rsp_ready   => lsu2dtcm_icb_rsp_ready,
    dtcm_icb_rsp_err     => lsu2dtcm_icb_rsp_err  ,
    dtcm_icb_rsp_excl_ok => lsu2dtcm_icb_rsp_excl_ok,
    dtcm_icb_rsp_rdata   => lsu2dtcm_icb_rsp_rdata,

 `end if

    biu_icb_cmd_valid   => lsu2biu_icb_cmd_valid,
    biu_icb_cmd_ready   => lsu2biu_icb_cmd_ready,
    biu_icb_cmd_addr    => lsu2biu_icb_cmd_addr ,
    biu_icb_cmd_read    => lsu2biu_icb_cmd_read ,
    biu_icb_cmd_wdata   => lsu2biu_icb_cmd_wdata,
    biu_icb_cmd_wmask   => lsu2biu_icb_cmd_wmask,
    biu_icb_cmd_lock    => lsu2biu_icb_cmd_lock ,
    biu_icb_cmd_excl    => lsu2biu_icb_cmd_excl ,
    biu_icb_cmd_size    => lsu2biu_icb_cmd_size ,
    
    biu_icb_rsp_valid   => lsu2biu_icb_rsp_valid,
    biu_icb_rsp_ready   => lsu2biu_icb_rsp_ready,
    biu_icb_rsp_err     => lsu2biu_icb_rsp_err  ,
    biu_icb_rsp_excl_ok => lsu2biu_icb_rsp_excl_ok,
    biu_icb_rsp_rdata   => lsu2biu_icb_rsp_rdata,
 
 `if E203_HAS_NICE = "TRUE" then
    nice_mem_holdup      => nice_mem_holdup,
    nice_icb_cmd_valid   => nice_icb_cmd_valid, 
    nice_icb_cmd_ready   => nice_icb_cmd_ready,
    nice_icb_cmd_addr    => nice_icb_cmd_addr , 
    nice_icb_cmd_read    => nice_icb_cmd_read , 
    nice_icb_cmd_wdata   => nice_icb_cmd_wdata,
    nice_icb_cmd_size    => nice_icb_cmd_size, 
    nice_icb_cmd_wmask   => (E203_XLEN_MW-1 downto 0 => '0'), 
    nice_icb_cmd_lock    => '0', 
    nice_icb_cmd_excl    => '0', 
    
    nice_icb_rsp_valid   => nice_icb_rsp_valid, 
    nice_icb_rsp_ready   => nice_icb_rsp_ready, 
    nice_icb_rsp_rdata   => nice_icb_rsp_rdata, 
    nice_icb_rsp_err     => nice_icb_rsp_err, 
    nice_icb_rsp_excl_ok => OPEN, 
 `end if

    clk           => clk_core_lsu,
    rst_n         => rst_n 
  );


  u_e203_biu: entity work.e203_biu port map(
    biu_active              => biu_active,
    lsu2biu_icb_cmd_valid   => lsu2biu_icb_cmd_valid,
    lsu2biu_icb_cmd_ready   => lsu2biu_icb_cmd_ready,
    lsu2biu_icb_cmd_addr    => lsu2biu_icb_cmd_addr ,
    lsu2biu_icb_cmd_read    => lsu2biu_icb_cmd_read ,
    lsu2biu_icb_cmd_wdata   => lsu2biu_icb_cmd_wdata,
    lsu2biu_icb_cmd_wmask   => lsu2biu_icb_cmd_wmask,
    lsu2biu_icb_cmd_lock    => lsu2biu_icb_cmd_lock ,
    lsu2biu_icb_cmd_excl    => lsu2biu_icb_cmd_excl ,
    lsu2biu_icb_cmd_size    => lsu2biu_icb_cmd_size ,
    lsu2biu_icb_cmd_burst   => "00",
    lsu2biu_icb_cmd_beat    => "00",

    lsu2biu_icb_rsp_valid   => lsu2biu_icb_rsp_valid,
    lsu2biu_icb_rsp_ready   => lsu2biu_icb_rsp_ready,
    lsu2biu_icb_rsp_err     => lsu2biu_icb_rsp_err  ,
    lsu2biu_icb_rsp_excl_ok => lsu2biu_icb_rsp_excl_ok,
    lsu2biu_icb_rsp_rdata   => lsu2biu_icb_rsp_rdata,

 `if E203_HAS_MEM_ITF = "TRUE" then
    ifu2biu_icb_cmd_valid   => ifu2biu_icb_cmd_valid,
    ifu2biu_icb_cmd_ready   => ifu2biu_icb_cmd_ready,
    ifu2biu_icb_cmd_addr    => ifu2biu_icb_cmd_addr ,
    ifu2biu_icb_cmd_read    => '1',
    ifu2biu_icb_cmd_wdata   => (E203_XLEN-1 downto 0 => '0'),
    ifu2biu_icb_cmd_wmask   => (E203_XLEN/8-1 downto 0 => '0'),
    ifu2biu_icb_cmd_lock    => '0' ,
    ifu2biu_icb_cmd_excl    => '0' ,
    ifu2biu_icb_cmd_size    => "10",
    ifu2biu_icb_cmd_burst   => "00",
    ifu2biu_icb_cmd_beat    => "00",
    
    ifu2biu_icb_rsp_valid   => ifu2biu_icb_rsp_valid,
    ifu2biu_icb_rsp_ready   => ifu2biu_icb_rsp_ready,
    ifu2biu_icb_rsp_err     => ifu2biu_icb_rsp_err  ,
    ifu2biu_icb_rsp_excl_ok => ifu2biu_icb_rsp_excl_ok,
    ifu2biu_icb_rsp_rdata   => ifu2biu_icb_rsp_rdata,

 `end if

    ppi_region_indic      => ppi_region_indic ,
    ppi_icb_enable        => ppi_icb_enable   ,
    ppi_icb_cmd_valid     => ppi_icb_cmd_valid,
    ppi_icb_cmd_ready     => ppi_icb_cmd_ready,
    ppi_icb_cmd_addr      => ppi_icb_cmd_addr ,
    ppi_icb_cmd_read      => ppi_icb_cmd_read ,
    ppi_icb_cmd_wdata     => ppi_icb_cmd_wdata,
    ppi_icb_cmd_wmask     => ppi_icb_cmd_wmask,
    ppi_icb_cmd_lock      => ppi_icb_cmd_lock ,
    ppi_icb_cmd_excl      => ppi_icb_cmd_excl ,
    ppi_icb_cmd_size      => ppi_icb_cmd_size ,
    ppi_icb_cmd_burst     => OPEN,
    ppi_icb_cmd_beat      => OPEN,
    
    ppi_icb_rsp_valid     => ppi_icb_rsp_valid,
    ppi_icb_rsp_ready     => ppi_icb_rsp_ready,
    ppi_icb_rsp_err       => ppi_icb_rsp_err  ,
    ppi_icb_rsp_excl_ok   => ppi_icb_rsp_excl_ok,
    ppi_icb_rsp_rdata     => ppi_icb_rsp_rdata,


    plic_icb_enable       => plic_icb_enable,
    plic_region_indic     => plic_region_indic ,
    plic_icb_cmd_valid    => plic_icb_cmd_valid,
    plic_icb_cmd_ready    => plic_icb_cmd_ready,
    plic_icb_cmd_addr     => plic_icb_cmd_addr ,
    plic_icb_cmd_read     => plic_icb_cmd_read ,
    plic_icb_cmd_wdata    => plic_icb_cmd_wdata,
    plic_icb_cmd_wmask    => plic_icb_cmd_wmask,
    plic_icb_cmd_lock     => plic_icb_cmd_lock ,
    plic_icb_cmd_excl     => plic_icb_cmd_excl ,
    plic_icb_cmd_size     => plic_icb_cmd_size ,
    plic_icb_cmd_burst    => OPEN,
    plic_icb_cmd_beat     => OPEN,
    
    plic_icb_rsp_valid    => plic_icb_rsp_valid,
    plic_icb_rsp_ready    => plic_icb_rsp_ready,
    plic_icb_rsp_err      => plic_icb_rsp_err  ,
    plic_icb_rsp_excl_ok  => plic_icb_rsp_excl_ok,
    plic_icb_rsp_rdata    => plic_icb_rsp_rdata,

    clint_icb_enable      => clint_icb_enable,
    clint_region_indic    => clint_region_indic ,
    clint_icb_cmd_valid   => clint_icb_cmd_valid,
    clint_icb_cmd_ready   => clint_icb_cmd_ready,
    clint_icb_cmd_addr    => clint_icb_cmd_addr ,
    clint_icb_cmd_read    => clint_icb_cmd_read ,
    clint_icb_cmd_wdata   => clint_icb_cmd_wdata,
    clint_icb_cmd_wmask   => clint_icb_cmd_wmask,
    clint_icb_cmd_lock    => clint_icb_cmd_lock ,
    clint_icb_cmd_excl    => clint_icb_cmd_excl ,
    clint_icb_cmd_size    => clint_icb_cmd_size ,
    clint_icb_cmd_burst   => OPEN,
    clint_icb_cmd_beat    => OPEN,
    
    clint_icb_rsp_valid   => clint_icb_rsp_valid,
    clint_icb_rsp_ready   => clint_icb_rsp_ready,
    clint_icb_rsp_err     => clint_icb_rsp_err  ,
    clint_icb_rsp_excl_ok => clint_icb_rsp_excl_ok,
    clint_icb_rsp_rdata   => clint_icb_rsp_rdata,


 `if E203_HAS_FIO = "TRUE" then
    fio_region_indic    => fio_region_indic ,
    fio_icb_enable      => fio_icb_enable   ,
    fio_icb_cmd_valid   => fio_icb_cmd_valid,
    fio_icb_cmd_ready   => fio_icb_cmd_ready,
    fio_icb_cmd_addr    => fio_icb_cmd_addr ,
    fio_icb_cmd_read    => fio_icb_cmd_read ,
    fio_icb_cmd_wdata   => fio_icb_cmd_wdata,
    fio_icb_cmd_wmask   => fio_icb_cmd_wmask,
    fio_icb_cmd_lock    => fio_icb_cmd_lock ,
    fio_icb_cmd_excl    => fio_icb_cmd_excl ,
    fio_icb_cmd_size    => fio_icb_cmd_size ,
    fio_icb_cmd_burst   => OPEN,
    fio_icb_cmd_beat    => OPEN,
    
    fio_icb_rsp_valid   => fio_icb_rsp_valid,
    fio_icb_rsp_ready   => fio_icb_rsp_ready,
    fio_icb_rsp_err     => fio_icb_rsp_err  ,
    fio_icb_rsp_excl_ok => fio_icb_rsp_excl_ok,
    fio_icb_rsp_rdata   => fio_icb_rsp_rdata,
 `end if

 `if E203_HAS_MEM_ITF = "TRUE" then
    mem_icb_enable      => mem_icb_enable,
    mem_icb_cmd_valid   => mem_icb_cmd_valid,
    mem_icb_cmd_ready   => mem_icb_cmd_ready,
    mem_icb_cmd_addr    => mem_icb_cmd_addr ,
    mem_icb_cmd_read    => mem_icb_cmd_read ,
    mem_icb_cmd_wdata   => mem_icb_cmd_wdata,
    mem_icb_cmd_wmask   => mem_icb_cmd_wmask,
    mem_icb_cmd_lock    => mem_icb_cmd_lock ,
    mem_icb_cmd_excl    => mem_icb_cmd_excl ,
    mem_icb_cmd_size    => mem_icb_cmd_size ,
    mem_icb_cmd_burst   => mem_icb_cmd_burst,
    mem_icb_cmd_beat    => mem_icb_cmd_beat ,
    
    mem_icb_rsp_valid   => mem_icb_rsp_valid,
    mem_icb_rsp_ready   => mem_icb_rsp_ready,
    mem_icb_rsp_err     => mem_icb_rsp_err  ,
    mem_icb_rsp_excl_ok => mem_icb_rsp_excl_ok,
    mem_icb_rsp_rdata   => mem_icb_rsp_rdata,
 `end if

    clk                 => clk_core_biu,
    rst_n               => rst_n        
  );
end impl;