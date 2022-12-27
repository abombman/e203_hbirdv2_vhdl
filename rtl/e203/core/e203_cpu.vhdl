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

entity e203_cpu is
  generic ( MASTER: integer:= 1
  );
  port ( inspect_pc:            out std_logic_vector(E203_PC_SIZE-1 downto 0);
         inspect_dbg_irq:       out std_logic; 
         inspect_mem_cmd_valid: out std_logic; 
         inspect_mem_cmd_ready: out std_logic; 
         inspect_mem_rsp_valid: out std_logic;
         inspect_mem_rsp_ready: out std_logic; 
         inspect_core_clk:      out std_logic; 
         core_csr_clk:          out std_logic;

        `if E203_HAS_ITCM = "TRUE" then
         rst_itcm:       out std_logic;
        `end if
        `if E203_HAS_DTCM = "TRUE" then
         rst_dtcm:       out std_logic;
        `end if

         core_wfi:       out std_logic; 
         tm_stop:        out std_logic;
         pc_rtvec:        in std_logic_vector(E203_PC_SIZE-1 downto 0);

         -- With the interface to debug module 
         --
         -- The interface with commit stage
         cmt_dpc:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_dpc_ena:    out std_logic; 
         cmt_dcause:     out std_logic_vector(3-1 downto 0); 
         cmt_dcause_ena: out std_logic;
         dbg_irq_r:      out std_logic;

         -- The interface with CSR control
         wr_dcsr_ena:    out std_logic; 
         wr_dpc_ena:     out std_logic;
         wr_dscratch_ena:out std_logic;
         wr_csr_nxt:     out std_logic_vector(32-1 downto 0);
        
         dcsr_r:          in std_logic_vector(32-1 downto 0);
         dpc_r:           in std_logic_vector(E203_PC_SIZE-1 downto 0);
         dscratch_r:      in std_logic_vector(32-1 downto 0);

         dbg_mode:        in std_logic;  
         dbg_halt_r:      in std_logic;  
         dbg_step_r:      in std_logic;  
         dbg_ebreakm_r:   in std_logic;  
         dbg_stopcycle:   in std_logic;
         
         core_mhartid:    in std_logic_vector(E203_HART_ID_W-1 downto 0);
         dbg_irq_a:       in std_logic;
         ext_irq_a:       in std_logic;
         sft_irq_a:       in std_logic;
         tmr_irq_a:       in std_logic;

        `if E203_HAS_ITCM_EXTITF = "TRUE" then
         -- External-agent ICB to DTCM
         --    * Bus cmd channel
         ext2itcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
         ext2itcm_icb_cmd_ready: out std_logic;  -- Handshake ready
         ext2itcm_icb_cmd_addr:   in std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
         ext2itcm_icb_cmd_read:   in std_logic;  -- Read or write
         ext2itcm_icb_cmd_wdata:  in std_logic_vector(E203_XLEN-1 downto 0);         
         ext2itcm_icb_cmd_wmask:  in std_logic_vector(E203_XLEN/8-1 downto 0);        
     
         -- * Bus RSP channel
         ext2itcm_icb_rsp_valid: out std_logic;   -- Response valid 
         ext2itcm_icb_rsp_ready:  in std_logic;   -- Response ready
         ext2itcm_icb_rsp_err  : out std_logic;   -- Response error
         ext2itcm_icb_rsp_rdata: out std_logic_vector(E203_XLEN-1 downto 0);
        `end if
        
        `if E203_HAS_DTCM_EXTITF = "TRUE" then
         -- External-agent ICB to DTCM
         --    * Bus cmd channel
         ext2dtcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
         ext2dtcm_icb_cmd_ready: out std_logic;  -- Handshake ready
         ext2dtcm_icb_cmd_addr:   in std_logic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0);
         ext2dtcm_icb_cmd_read:   in std_logic;  -- Read or write
         ext2dtcm_icb_cmd_wdata:  in std_logic_vector(E203_XLEN-1 downto 0);         
         ext2dtcm_icb_cmd_wmask:  in std_logic_vector(E203_XLEN/8-1 downto 0);        
       
         -- * Bus RSP channel
         ext2dtcm_icb_rsp_valid: out std_logic;   -- Response valid 
         ext2dtcm_icb_rsp_ready:  in std_logic;   -- Response ready
         ext2dtcm_icb_rsp_err  : out std_logic;   -- Response error
         ext2dtcm_icb_rsp_rdata: out std_logic_vector(E203_XLEN-1 downto 0);
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
         itcm_ls:                out std_logic; 
        
         itcm_ram_cs:            out std_logic; 
         itcm_ram_we:            out std_logic;
         itcm_ram_addr:          out std_logic_vector(E203_ITCM_RAM_AW-1 downto 0); 
         itcm_ram_wem:           out std_logic_vector(E203_ITCM_RAM_MW-1 downto 0); 
         itcm_ram_din:           out std_logic_vector(E203_ITCM_RAM_DW-1 downto 0); 
         itcm_ram_dout:           in std_logic_vector(E203_ITCM_RAM_DW-1 downto 0);     
         clk_itcm_ram:           out std_logic;    
        `end if

        `if E203_HAS_DTCM = "TRUE" then         
         dtcm_ls:                out std_logic; 
         dtcm_ram_cs:            out std_logic; 
         dtcm_ram_we:            out std_logic;
         dtcm_ram_addr:          out std_logic_vector(E203_DTCM_RAM_AW-1 downto 0); 
         dtcm_ram_wem:           out std_logic_vector(E203_DTCM_RAM_MW-1 downto 0); 
         dtcm_ram_din:           out std_logic_vector(E203_DTCM_RAM_DW-1 downto 0); 
         dtcm_ram_dout:           in std_logic_vector(E203_DTCM_RAM_DW-1 downto 0);     
         clk_dtcm_ram:           out std_logic;  
        `end if
    
         test_mode:               in std_logic;
         clk:                     in std_logic;
         rst_n:                   in std_logic        
  );
end e203_cpu;

architecture impl of e203_cpu is 
  signal core_cgstop:     std_ulogic;
  signal tcm_cgstop:      std_ulogic;
  signal core_ifu_active: std_ulogic;
  signal core_exu_active: std_ulogic;
  signal core_lsu_active: std_ulogic;
  signal core_biu_active: std_ulogic;

  -- The core's clk and rst
  signal rst_core:        std_ulogic;
  signal clk_core_ifu:    std_ulogic;
  signal clk_core_exu:    std_ulogic;
  signal clk_core_lsu:    std_ulogic;
  signal clk_core_biu:    std_ulogic;

 `if E203_HAS_ITCM = "TRUE" then 
  signal clk_itcm:        std_ulogic;
  signal itcm_active:     std_ulogic;
 `end if
 `if E203_HAS_DTCM = "TRUE" then
  signal clk_dtcm:        std_ulogic;
  signal dtcm_active:     std_ulogic;
 `end if
  
  -- The Top always on clk and rst
  signal rst_aon:         std_ulogic;
  signal clk_aon:         std_ulogic;

  signal ext_irq_r:       std_ulogic;
  signal sft_irq_r:       std_ulogic;
  signal tmr_irq_r:       std_ulogic;

 `if E203_HAS_ITCM = "TRUE" then
  signal ifu2itcm_holdup: std_ulogic;

  signal ifu2itcm_icb_cmd_valid: std_ulogic;
  signal ifu2itcm_icb_cmd_ready: std_ulogic;
  signal ifu2itcm_icb_cmd_addr:  std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);

  signal ifu2itcm_icb_rsp_valid: std_ulogic;
  signal ifu2itcm_icb_rsp_ready: std_ulogic;
  signal ifu2itcm_icb_rsp_err:   std_ulogic;
  signal ifu2itcm_icb_rsp_rdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0); 

  signal lsu2itcm_icb_cmd_valid: std_ulogic;
  signal lsu2itcm_icb_cmd_ready: std_ulogic;
  signal lsu2itcm_icb_cmd_addr:  std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0); 
  signal lsu2itcm_icb_cmd_read:  std_ulogic; 
  signal lsu2itcm_icb_cmd_wdata: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal lsu2itcm_icb_cmd_wmask: std_ulogic_vector(E203_XLEN/8-1 downto 0);
  signal lsu2itcm_icb_cmd_lock:  std_ulogic;
  signal lsu2itcm_icb_cmd_excl:  std_ulogic;
  signal lsu2itcm_icb_cmd_size:  std_ulogic_vector(1 downto 0);
  signal lsu2itcm_icb_rsp_valid: std_ulogic;
  signal lsu2itcm_icb_rsp_ready: std_ulogic;
  signal lsu2itcm_icb_rsp_err  : std_ulogic;
  signal lsu2itcm_icb_rsp_rdata: std_ulogic_vector(E203_XLEN-1 downto 0);
 `end if

  `if E203_HAS_DTCM = "TRUE" then
  signal lsu2dtcm_icb_cmd_valid: std_ulogic;
  signal lsu2dtcm_icb_cmd_ready: std_ulogic;
  signal lsu2dtcm_icb_cmd_addr:  std_ulogic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0); 
  signal lsu2dtcm_icb_cmd_read:  std_ulogic; 
  signal lsu2dtcm_icb_cmd_wdata: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal lsu2dtcm_icb_cmd_wmask: std_ulogic_vector(E203_XLEN/8-1 downto 0);
  signal lsu2dtcm_icb_cmd_lock:  std_ulogic;
  signal lsu2dtcm_icb_cmd_excl:  std_ulogic;
  signal lsu2dtcm_icb_cmd_size:  std_ulogic_vector(1 downto 0);
  signal lsu2dtcm_icb_rsp_valid: std_ulogic;
  signal lsu2dtcm_icb_rsp_ready: std_ulogic;
  signal lsu2dtcm_icb_rsp_err:   std_ulogic;
  signal lsu2dtcm_icb_rsp_rdata: std_ulogic_vector(E203_XLEN-1 downto 0);
 `end if

 `if E203_HAS_CSR_NICE = "TRUE" then
  signal nice_csr_valid: std_ulogic;
  signal nice_csr_ready: std_ulogic;
  signal nice_csr_addr:  std_ulogic_vector(31 downto 0);
  signal nice_csr_wr:    std_ulogic;
  signal nice_csr_wdata: std_ulogic_vector(31 downto 0);
  signal nice_csr_rdata: std_ulogic_vector(31 downto 0);
 `end if

 `if E203_HAS_NICE = "TRUE" then
  signal nice_mem_holdup: std_ulogic; 
  signal nice_req_valid:  std_ulogic; 
  signal nice_req_ready:  std_ulogic; 
  signal nice_req_inst:   std_ulogic_vector(E203_XLEN-1 downto 0);  
  signal nice_req_rs1:    std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal nice_req_rs2:    std_ulogic_vector(E203_XLEN-1 downto 0); 

  signal nice_rsp_multicyc_valid: std_ulogic; 
  signal nice_rsp_multicyc_ready: std_ulogic;                              
  signal nice_rsp_multicyc_dat:   std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal nice_rsp_multicyc_err:   std_ulogic;

  signal nice_icb_cmd_valid: std_ulogic; 
  signal nice_icb_cmd_ready: std_ulogic;
  signal nice_icb_cmd_addr:  std_ulogic_vector(E203_XLEN-1 downto 0); 
  signal nice_icb_cmd_read:  std_ulogic;  
  signal nice_icb_cmd_wdata: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal nice_icb_cmd_size:  std_ulogic_vector(1 downto 0); 

  signal nice_icb_rsp_valid: std_ulogic; 
  signal nice_icb_rsp_ready: std_ulogic;
  signal nice_icb_rsp_rdata: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal nice_icb_rsp_err:   std_ulogic; 
 `end if
begin
  -- The reset ctrl and clock ctrl should be in the power always-on domain

  u_e203_reset_ctrl: entity work.e203_reset_ctrl generic map( MASTER )
  port map(
    clk        => clk_aon  ,
    rst_n      => rst_n    ,
    test_mode  => test_mode,
    rst_core   => rst_core ,
 `if E203_HAS_ITCM = "TRUE" then
    rst_itcm   => rst_itcm,
 `end if
 `if E203_HAS_DTCM = "TRUE" then
    rst_dtcm   => rst_dtcm,
 `end if
    rst_aon    => rst_aon 
  );

  u_e203_clk_ctrl: entity work.e203_clk_ctrl port map(
    clk          => clk        ,
    rst_n        => rst_aon    ,
    test_mode    => test_mode  ,                              
    clk_aon      => clk_aon    ,
    core_cgstop  => core_cgstop,
    
    clk_core_ifu => clk_core_ifu,
    clk_core_exu => clk_core_exu,
    clk_core_lsu => clk_core_lsu,
    clk_core_biu => clk_core_biu,
 `if E203_HAS_ITCM = "TRUE" then
    clk_itcm     => clk_itcm   ,
    itcm_active  => itcm_active,
    itcm_ls      => itcm_ls    ,
 `end if
 `if E203_HAS_DTCM = "TRUE" then
    clk_dtcm     => clk_dtcm   ,
    dtcm_active  => dtcm_active,
    dtcm_ls      => dtcm_ls    ,
 `end if

    core_ifu_active => core_ifu_active,
    core_exu_active => core_exu_active,
    core_lsu_active => core_lsu_active,
    core_biu_active => core_biu_active,
    core_wfi        => core_wfi
  );

  u_e203_irq_sync: entity work.e203_irq_sync generic map( MASTER )
  port map(
    clk       => clk_aon,
    rst_n     => rst_aon,
                        
    dbg_irq_a => dbg_irq_a,
    dbg_irq_r => dbg_irq_r,

    ext_irq_a => ext_irq_a,
    sft_irq_a => sft_irq_a,
    tmr_irq_a => tmr_irq_a,
    ext_irq_r => ext_irq_r,
    sft_irq_r => sft_irq_r,
    tmr_irq_r => tmr_irq_r 
  );

 `if E203_HAS_CSR_NICE = "TRUE" then
  -- This is an empty module to just connect the NICE CSR interface, 
  --  user can hack it to become a real one
  u_e203_extend_csr: entity work.e203_extend_csr port map(
    nice_csr_valid => nice_csr_valid,
    nice_csr_ready => nice_csr_ready,
    nice_csr_addr  => nice_csr_addr ,
    nice_csr_wr    => nice_csr_wr   ,
    nice_csr_wdata => nice_csr_wdata,
    nice_csr_rdata => nice_csr_rdata,
    clk            => clk_core_exu  ,
    rst_n          => rst_core
   );
 `end if

 `if E203_HAS_NICE = "TRUE" then
  u_e203_nice_core: entity work.e203_subsys_nice_core port map(
    nice_clk             => clk_aon,
    nice_rst_n           => rst_aon,
    nice_active          => OPEN,
    nice_mem_holdup      => nice_mem_holdup,
    
    nice_req_valid       => nice_req_valid,
    nice_req_ready       => nice_req_ready,
    nice_req_inst        => nice_req_inst,
    nice_req_rs1         => nice_req_rs1,
    nice_req_rs2         => nice_req_rs2,
    
    nice_rsp_valid       => nice_rsp_multicyc_valid,
    nice_rsp_ready       => nice_rsp_multicyc_ready,
    nice_rsp_rdat        => nice_rsp_multicyc_dat,
    nice_rsp_err         => nice_rsp_multicyc_err,
    
    nice_icb_cmd_valid   => nice_icb_cmd_valid,
    nice_icb_cmd_ready   => nice_icb_cmd_ready,
    nice_icb_cmd_addr    => nice_icb_cmd_addr,
    nice_icb_cmd_read    => nice_icb_cmd_read,
    nice_icb_cmd_wdata   => nice_icb_cmd_wdata,
    nice_icb_cmd_size    => nice_icb_cmd_size,
    
    nice_icb_rsp_valid   => nice_icb_rsp_valid,
    nice_icb_rsp_ready   => nice_icb_rsp_ready,
    nice_icb_rsp_rdata   => nice_icb_rsp_rdata,
    nice_icb_rsp_err     => nice_icb_rsp_err 
  );
 `end if

  u_e203_core: entity work.e203_core port map(
    inspect_pc     => inspect_pc,
 `if E203_HAS_CSR_NICE = "TRUE" then
    nice_csr_valid => nice_csr_valid,
    nice_csr_ready => nice_csr_ready,
    nice_csr_addr  => nice_csr_addr ,
    nice_csr_wr    => nice_csr_wr   ,
    nice_csr_wdata => nice_csr_wdata,
    nice_csr_rdata => nice_csr_rdata,
 `end if
    tcm_cgstop     => tcm_cgstop,
    core_cgstop    => core_cgstop,
    tm_stop        => tm_stop,

    pc_rtvec       => pc_rtvec,

    ifu_active     => core_ifu_active,
    exu_active     => core_exu_active,
    lsu_active     => core_lsu_active,
    biu_active     => core_biu_active,
    core_wfi       => core_wfi,

    core_mhartid   => core_mhartid,  
    dbg_irq_r      => dbg_irq_r,
    lcl_irq_r      => (E203_LIRQ_NUM-1 downto 0 => '0'), -- Not implemented now
    ext_irq_r      => ext_irq_r,
    sft_irq_r      => sft_irq_r,
    tmr_irq_r      => tmr_irq_r,
    evt_r          => (E203_EVT_NUM-1 downto 0 => '0'), -- Not implemented now

    cmt_dpc        => cmt_dpc       ,
    cmt_dpc_ena    => cmt_dpc_ena   ,
    cmt_dcause     => cmt_dcause    ,
    cmt_dcause_ena => cmt_dcause_ena,

    wr_dcsr_ena     => wr_dcsr_ena    ,
    wr_dpc_ena      => wr_dpc_ena     ,
    wr_dscratch_ena => wr_dscratch_ena,
                                 
    wr_csr_nxt      => wr_csr_nxt,
                                    
    dcsr_r          => dcsr_r    ,
    dpc_r           => dpc_r     ,
    dscratch_r      => dscratch_r,
                                            
    dbg_mode        => dbg_mode  ,
    dbg_halt_r      => dbg_halt_r,
    dbg_step_r      => dbg_step_r,
    dbg_ebreakm_r   => dbg_ebreakm_r,
    dbg_stopcycle   => dbg_stopcycle,

 `if E203_HAS_ITCM = "TRUE" then
    --.itcm_region_indic       (itcm_region_indic),
    itcm_region_indic => std_logic_vector(E203_ITCM_ADDR_BASE),
 `end if
 `if E203_HAS_DTCM = "TRUE" then
    --.dtcm_region_indic       (dtcm_region_indic),
    dtcm_region_indic => std_logic_vector(E203_DTCM_ADDR_BASE),
 `end if

 `if E203_HAS_ITCM = "TRUE" then

    ifu2itcm_holdup          => ifu2itcm_holdup       ,
    --.ifu2itcm_replay         (ifu2itcm_replay       ),

    ifu2itcm_icb_cmd_valid   => ifu2itcm_icb_cmd_valid,
    ifu2itcm_icb_cmd_ready   => ifu2itcm_icb_cmd_ready,
    ifu2itcm_icb_cmd_addr    => ifu2itcm_icb_cmd_addr ,
    ifu2itcm_icb_rsp_valid   => ifu2itcm_icb_rsp_valid,
    ifu2itcm_icb_rsp_ready   => ifu2itcm_icb_rsp_ready,
    ifu2itcm_icb_rsp_err     => ifu2itcm_icb_rsp_err  ,
    ifu2itcm_icb_rsp_rdata   => ifu2itcm_icb_rsp_rdata,

    lsu2itcm_icb_cmd_valid   => lsu2itcm_icb_cmd_valid,
    lsu2itcm_icb_cmd_ready   => lsu2itcm_icb_cmd_ready,
    lsu2itcm_icb_cmd_addr    => lsu2itcm_icb_cmd_addr ,
    lsu2itcm_icb_cmd_read    => lsu2itcm_icb_cmd_read ,
    lsu2itcm_icb_cmd_wdata   => lsu2itcm_icb_cmd_wdata,
    lsu2itcm_icb_cmd_wmask   => lsu2itcm_icb_cmd_wmask,
    lsu2itcm_icb_cmd_lock    => lsu2itcm_icb_cmd_lock ,
    lsu2itcm_icb_cmd_excl    => lsu2itcm_icb_cmd_excl ,
    lsu2itcm_icb_cmd_size    => lsu2itcm_icb_cmd_size ,
    
    lsu2itcm_icb_rsp_valid   => lsu2itcm_icb_rsp_valid,
    lsu2itcm_icb_rsp_ready   => lsu2itcm_icb_rsp_ready,
    lsu2itcm_icb_rsp_err     => lsu2itcm_icb_rsp_err  ,
    lsu2itcm_icb_rsp_excl_ok => '0',
    lsu2itcm_icb_rsp_rdata   => lsu2itcm_icb_rsp_rdata,
 `end if

 `if E203_HAS_DTCM = "TRUE" then
    lsu2dtcm_icb_cmd_valid   => lsu2dtcm_icb_cmd_valid,
    lsu2dtcm_icb_cmd_ready   => lsu2dtcm_icb_cmd_ready,
    lsu2dtcm_icb_cmd_addr    => lsu2dtcm_icb_cmd_addr ,
    lsu2dtcm_icb_cmd_read    => lsu2dtcm_icb_cmd_read ,
    lsu2dtcm_icb_cmd_wdata   => lsu2dtcm_icb_cmd_wdata,
    lsu2dtcm_icb_cmd_wmask   => lsu2dtcm_icb_cmd_wmask,
    lsu2dtcm_icb_cmd_lock    => lsu2dtcm_icb_cmd_lock ,
    lsu2dtcm_icb_cmd_excl    => lsu2dtcm_icb_cmd_excl ,
    lsu2dtcm_icb_cmd_size    => lsu2dtcm_icb_cmd_size ,
    
    lsu2dtcm_icb_rsp_valid   => lsu2dtcm_icb_rsp_valid,
    lsu2dtcm_icb_rsp_ready   => lsu2dtcm_icb_rsp_ready,
    lsu2dtcm_icb_rsp_err     => lsu2dtcm_icb_rsp_err  ,
    lsu2dtcm_icb_rsp_excl_ok => '0',
    lsu2dtcm_icb_rsp_rdata   => lsu2dtcm_icb_rsp_rdata,
 `end if

    ppi_icb_enable        => ppi_icb_enable,
    ppi_region_indic      => ppi_region_indic ,
    ppi_icb_cmd_valid     => ppi_icb_cmd_valid,
    ppi_icb_cmd_ready     => ppi_icb_cmd_ready,
    ppi_icb_cmd_addr      => ppi_icb_cmd_addr ,
    ppi_icb_cmd_read      => ppi_icb_cmd_read ,
    ppi_icb_cmd_wdata     => ppi_icb_cmd_wdata,
    ppi_icb_cmd_wmask     => ppi_icb_cmd_wmask,
    ppi_icb_cmd_lock      => ppi_icb_cmd_lock ,
    ppi_icb_cmd_excl      => ppi_icb_cmd_excl ,
    ppi_icb_cmd_size      => ppi_icb_cmd_size ,
    
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
    
    clint_icb_rsp_valid   => clint_icb_rsp_valid,
    clint_icb_rsp_ready   => clint_icb_rsp_ready,
    clint_icb_rsp_err     => clint_icb_rsp_err  ,
    clint_icb_rsp_excl_ok => clint_icb_rsp_excl_ok,
    clint_icb_rsp_rdata   => clint_icb_rsp_rdata,

 `if E203_HAS_FIO = "TRUE" then
    fio_icb_enable        => fio_icb_enable,
    fio_region_indic      => fio_region_indic ,
    fio_icb_cmd_valid     => fio_icb_cmd_valid,
    fio_icb_cmd_ready     => fio_icb_cmd_ready,
    fio_icb_cmd_addr      => fio_icb_cmd_addr ,
    fio_icb_cmd_read      => fio_icb_cmd_read ,
    fio_icb_cmd_wdata     => fio_icb_cmd_wdata,
    fio_icb_cmd_wmask     => fio_icb_cmd_wmask,
    fio_icb_cmd_lock      => fio_icb_cmd_lock ,
    fio_icb_cmd_excl      => fio_icb_cmd_excl ,
    fio_icb_cmd_size      => fio_icb_cmd_size ,
    
    fio_icb_rsp_valid     => fio_icb_rsp_valid,
    fio_icb_rsp_ready     => fio_icb_rsp_ready,
    fio_icb_rsp_err       => fio_icb_rsp_err  ,
    fio_icb_rsp_excl_ok   => fio_icb_rsp_excl_ok,
    fio_icb_rsp_rdata     => fio_icb_rsp_rdata,
 `end if

 `if E203_HAS_MEM_ITF = "TRUE" then
    mem_icb_enable        => mem_icb_enable,
    mem_icb_cmd_valid     => mem_icb_cmd_valid,
    mem_icb_cmd_ready     => mem_icb_cmd_ready,
    mem_icb_cmd_addr      => mem_icb_cmd_addr ,
    mem_icb_cmd_read      => mem_icb_cmd_read ,
    mem_icb_cmd_wdata     => mem_icb_cmd_wdata,
    mem_icb_cmd_wmask     => mem_icb_cmd_wmask,
    mem_icb_cmd_lock      => mem_icb_cmd_lock ,
    mem_icb_cmd_excl      => mem_icb_cmd_excl ,
    mem_icb_cmd_size      => mem_icb_cmd_size ,
    mem_icb_cmd_burst     => mem_icb_cmd_burst,
    mem_icb_cmd_beat      => mem_icb_cmd_beat ,
    
    mem_icb_rsp_valid     => mem_icb_rsp_valid,
    mem_icb_rsp_ready     => mem_icb_rsp_ready,
    mem_icb_rsp_err       => mem_icb_rsp_err  ,
    mem_icb_rsp_excl_ok   => mem_icb_rsp_excl_ok,
    mem_icb_rsp_rdata     => mem_icb_rsp_rdata,
 `end if

 `if E203_HAS_NICE = "TRUE" then   
    -- The nice interface
    nice_mem_holdup       => nice_mem_holdup, -- I: nice occupys the memory. for avoid of dead-loop.
    -- nice_req interface
    nice_req_valid        => nice_req_valid,     -- O: handshake flag, cmd is valid
    nice_req_ready        => nice_req_ready,     -- I: handshake flag, cmd is accepted.
    nice_req_inst         => nice_req_inst ,     -- O: inst sent to nice. 
    nice_req_rs1          => nice_req_rs1  ,     -- O: rs op 1.
    nice_req_rs2          => nice_req_rs2  ,     -- O: rs op 2.
    --.nice_req_mmode     (nice_req_mmode   ), // O: 

    -- icb_cmd_rsp interface
    -- for one cycle insn, the rsp data is valid at the same time of insn, so
    -- the handshake flags is useless.
                                              
    nice_rsp_multicyc_valid => nice_rsp_multicyc_valid, -- I: current insn is multi-cycle.
    nice_rsp_multicyc_ready => nice_rsp_multicyc_ready, -- I: current insn is multi-cycle.
    nice_rsp_multicyc_dat   => nice_rsp_multicyc_dat  , -- I: one cycle result write-back val.
    nice_rsp_multicyc_err   => nice_rsp_multicyc_err  ,

    -- lsu_req interface                                         
    nice_icb_cmd_valid      => nice_icb_cmd_valid, -- I: nice access main-mem req valid.
    nice_icb_cmd_ready      => nice_icb_cmd_ready, -- O: nice access req is accepted.
    nice_icb_cmd_addr       => nice_icb_cmd_addr , -- I: nice access main-mem address.
    nice_icb_cmd_read       => nice_icb_cmd_read , -- I: nice access type. 
    nice_icb_cmd_wdata      => nice_icb_cmd_wdata, -- I: nice write data.
    nice_icb_cmd_size       => nice_icb_cmd_size,  -- I: data size input.

    -- lsu_rsp interface                                         
    nice_icb_rsp_valid      => nice_icb_rsp_valid, -- O: main core responds result to nice.
    nice_icb_rsp_ready      => nice_icb_rsp_ready, -- I: respond result is accepted.
    nice_icb_rsp_rdata      => nice_icb_rsp_rdata, -- O: rsp data.
    nice_icb_rsp_err        => nice_icb_rsp_err,   -- O: err flag
 `end if

    clk_aon                 => clk_aon     ,
    clk_core_ifu            => clk_core_ifu,
    clk_core_exu            => clk_core_exu,
    clk_core_lsu            => clk_core_lsu,
    clk_core_biu            => clk_core_biu,
    test_mode               => test_mode,
    rst_n                   => rst_core
  );

 `if E203_HAS_ITCM = "TRUE" then
  u_e203_itcm_ctrl: entity work.e203_itcm_ctrl port map(
    tcm_cgstop              => tcm_cgstop,
    itcm_active             => itcm_active,
    ifu2itcm_icb_cmd_valid  => ifu2itcm_icb_cmd_valid,
    ifu2itcm_icb_cmd_ready  => ifu2itcm_icb_cmd_ready,
    ifu2itcm_icb_cmd_addr   => ifu2itcm_icb_cmd_addr ,
    ifu2itcm_icb_cmd_read   => '1',
    ifu2itcm_icb_cmd_wdata  => (E203_ITCM_DATA_WIDTH-1 downto 0 => '0'),
    ifu2itcm_icb_cmd_wmask  => (E203_ITCM_DATA_WIDTH/8-1 downto 0 => '0'),

    ifu2itcm_icb_rsp_valid  => ifu2itcm_icb_rsp_valid,
    ifu2itcm_icb_rsp_ready  => ifu2itcm_icb_rsp_ready,
    ifu2itcm_icb_rsp_err    => ifu2itcm_icb_rsp_err  ,
    ifu2itcm_icb_rsp_rdata  => ifu2itcm_icb_rsp_rdata,
    ifu2itcm_holdup         => ifu2itcm_holdup       ,
    --.ifu2itcm_replay         (ifu2itcm_replay       ),

    lsu2itcm_icb_cmd_valid  => lsu2itcm_icb_cmd_valid,
    lsu2itcm_icb_cmd_ready  => lsu2itcm_icb_cmd_ready,
    lsu2itcm_icb_cmd_addr   => lsu2itcm_icb_cmd_addr ,
    lsu2itcm_icb_cmd_read   => lsu2itcm_icb_cmd_read ,
    lsu2itcm_icb_cmd_wdata  => lsu2itcm_icb_cmd_wdata,
    lsu2itcm_icb_cmd_wmask  => lsu2itcm_icb_cmd_wmask,
    
    lsu2itcm_icb_rsp_valid  => lsu2itcm_icb_rsp_valid,
    lsu2itcm_icb_rsp_ready  => lsu2itcm_icb_rsp_ready,
    lsu2itcm_icb_rsp_err    => lsu2itcm_icb_rsp_err  ,
    lsu2itcm_icb_rsp_rdata  => lsu2itcm_icb_rsp_rdata,

    itcm_ram_cs             => itcm_ram_cs  ,
    itcm_ram_we             => itcm_ram_we  ,
    itcm_ram_addr           => itcm_ram_addr, 
    itcm_ram_wem            => itcm_ram_wem ,
    itcm_ram_din            => itcm_ram_din ,         
    itcm_ram_dout           => itcm_ram_dout,
    clk_itcm_ram            => clk_itcm_ram ,

 `if E203_HAS_ITCM_EXTITF = "TRUE" then
    ext2itcm_icb_cmd_valid  => ext2itcm_icb_cmd_valid,
    ext2itcm_icb_cmd_ready  => ext2itcm_icb_cmd_ready,
    ext2itcm_icb_cmd_addr   => ext2itcm_icb_cmd_addr ,
    ext2itcm_icb_cmd_read   => ext2itcm_icb_cmd_read ,
    ext2itcm_icb_cmd_wdata  => ext2itcm_icb_cmd_wdata,
    ext2itcm_icb_cmd_wmask  => ext2itcm_icb_cmd_wmask,
    
    ext2itcm_icb_rsp_valid  => ext2itcm_icb_rsp_valid,
    ext2itcm_icb_rsp_ready  => ext2itcm_icb_rsp_ready,
    ext2itcm_icb_rsp_err    => ext2itcm_icb_rsp_err  ,
    ext2itcm_icb_rsp_rdata  => ext2itcm_icb_rsp_rdata,
 `end if
    test_mode               => test_mode,
    clk                     => clk_itcm,
    rst_n                   => rst_itcm 
  );
 `end if

 `if E203_HAS_DTCM = "TRUE" then
  u_e203_dtcm_ctrl: entity work.e203_dtcm_ctrl port map(
    tcm_cgstop              => tcm_cgstop,
    dtcm_active             => dtcm_active,
    lsu2dtcm_icb_cmd_valid  => lsu2dtcm_icb_cmd_valid,
    lsu2dtcm_icb_cmd_ready  => lsu2dtcm_icb_cmd_ready,
    lsu2dtcm_icb_cmd_addr   => lsu2dtcm_icb_cmd_addr ,
    lsu2dtcm_icb_cmd_read   => lsu2dtcm_icb_cmd_read ,
    lsu2dtcm_icb_cmd_wdata  => lsu2dtcm_icb_cmd_wdata,
    lsu2dtcm_icb_cmd_wmask  => lsu2dtcm_icb_cmd_wmask,
    
    lsu2dtcm_icb_rsp_valid  => lsu2dtcm_icb_rsp_valid,
    lsu2dtcm_icb_rsp_ready  => lsu2dtcm_icb_rsp_ready,
    lsu2dtcm_icb_rsp_err    => lsu2dtcm_icb_rsp_err  ,
    lsu2dtcm_icb_rsp_rdata  => lsu2dtcm_icb_rsp_rdata,

    dtcm_ram_cs             => dtcm_ram_cs  ,
    dtcm_ram_we             => dtcm_ram_we  ,
    dtcm_ram_addr           => dtcm_ram_addr, 
    dtcm_ram_wem            => dtcm_ram_wem ,
    dtcm_ram_din            => dtcm_ram_din ,         
    dtcm_ram_dout           => dtcm_ram_dout,
    clk_dtcm_ram            => clk_dtcm_ram ,

 `if E203_HAS_DTCM_EXTITF = "TRUE" then
    ext2dtcm_icb_cmd_valid  => ext2dtcm_icb_cmd_valid,
    ext2dtcm_icb_cmd_ready  => ext2dtcm_icb_cmd_ready,
    ext2dtcm_icb_cmd_addr   => ext2dtcm_icb_cmd_addr ,
    ext2dtcm_icb_cmd_read   => ext2dtcm_icb_cmd_read ,
    ext2dtcm_icb_cmd_wdata  => ext2dtcm_icb_cmd_wdata,
    ext2dtcm_icb_cmd_wmask  => ext2dtcm_icb_cmd_wmask,
    
    ext2dtcm_icb_rsp_valid  => ext2dtcm_icb_rsp_valid,
    ext2dtcm_icb_rsp_ready  => ext2dtcm_icb_rsp_ready,
    ext2dtcm_icb_rsp_err    => ext2dtcm_icb_rsp_err  ,
    ext2dtcm_icb_rsp_rdata  => ext2dtcm_icb_rsp_rdata,
 `end if
    test_mode               => test_mode,
    clk                     => clk_dtcm,
    rst_n                   => rst_dtcm 
  );
 `end if

  inspect_dbg_irq       <= dbg_irq_a;
  inspect_mem_cmd_valid <= mem_icb_cmd_valid;
  inspect_mem_cmd_ready <= mem_icb_cmd_ready;
  inspect_mem_rsp_valid <= mem_icb_rsp_valid;
  inspect_mem_rsp_ready <= mem_icb_rsp_ready;
  inspect_core_clk   <= clk;
  core_csr_clk       <= clk_core_exu;
end impl;