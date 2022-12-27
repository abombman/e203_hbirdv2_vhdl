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
--    The CPU-TOP module to implement CPU and SRAMs
-- 
-- ====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_cpu_top is
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
         
         -- If this signal is high, then indicate the Core have executed WFI instruction
         --   and entered into the sleep state
         core_wfi:              out std_logic; 

         -- This signal is from our self-defined COUNTERSTOP (0xBFF) CSR's TM field
         --   software can programe this CSR to turn off the MTIME timer to save power
         -- If this signal is high, then the MTIME timer from CLINT module will stop counting
         tm_stop:               out std_logic;
         
         -- This signal can be used to indicate the PC value for the core after reset
         pc_rtvec:               in std_logic_vector(E203_PC_SIZE-1 downto 0);

         -- The interface to Debug Module: Begin
         --
         -- The synced debug interrupt back to Debug module 
         dbg_irq_r:             out std_logic;
         
         -- The debug mode CSR registers control interface from/to Debug module
         cmt_dpc:               out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_dpc_ena:           out std_logic; 
         cmt_dcause:            out std_logic_vector(3-1 downto 0); 
         cmt_dcause_ena:        out std_logic;
         wr_dcsr_ena:           out std_logic; 
         wr_dpc_ena:            out std_logic;
         wr_dscratch_ena:       out std_logic;
         wr_csr_nxt:            out std_logic_vector(32-1 downto 0);
         dcsr_r:                 in std_logic_vector(32-1 downto 0);
         dpc_r:                  in std_logic_vector(E203_PC_SIZE-1 downto 0);
         dscratch_r:             in std_logic_vector(32-1 downto 0);
         
         -- The debug mode control signals from Debug Module
         dbg_mode:               in std_logic;  
         dbg_halt_r:             in std_logic;  
         dbg_step_r:             in std_logic;  
         dbg_ebreakm_r:          in std_logic;  
         dbg_stopcycle:          in std_logic;
         dbg_irq_a:              in std_logic;
         -- The interface to Debug Module: End

         -- This signal can be used to indicate the HART ID for this core
         core_mhartid:           in std_logic_vector(E203_HART_ID_W-1 downto 0);
         
         -- The External Interrupt signal from PLIC
         ext_irq_a:              in std_logic;

         -- The Software Interrupt signal from CLINT
         sft_irq_a:              in std_logic;

         -- The Timer Interrupt signal from CLINT
         tmr_irq_a:              in std_logic;

         -- The PMU control signal from PMU to control the TCM Shutdown
         tcm_sd:                 in std_logic;
         -- The PMU control signal from PMU to control the TCM Deep-Sleep
         tcm_ds:                 in std_logic;

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
         --    * bus cmd channel
         ppi_icb_cmd_valid:      out std_logic; 
         ppi_icb_cmd_ready:       in std_logic;  
         ppi_icb_cmd_addr:       out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ppi_icb_cmd_read:       out std_logic;
         ppi_icb_cmd_wdata:      out std_logic_vector(E203_XLEN-1 downto 0);
         ppi_icb_cmd_wmask:      out std_logic_vector(E203_XLEN/8-1 downto 0);
        
         -- * RSP channel         
         ppi_icb_rsp_valid:       in std_logic; 
         ppi_icb_rsp_ready:      out std_logic; 
         ppi_icb_rsp_err:         in std_logic;
         ppi_icb_rsp_rdata:       in std_logic_vector(E203_XLEN-1 downto 0);

         -- The CLINT Interface (ICB)
         --    * bus cmd channel  
         clint_icb_cmd_valid:    out std_logic; 
         clint_icb_cmd_ready:     in std_logic;  
         clint_icb_cmd_addr:     out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         clint_icb_cmd_read:     out std_logic;
         clint_icb_cmd_wdata:    out std_logic_vector(E203_XLEN-1 downto 0);
         clint_icb_cmd_wmask:    out std_logic_vector(E203_XLEN/8-1 downto 0);
      
         -- * RSP channel       
         clint_icb_rsp_valid:     in std_logic; 
         clint_icb_rsp_ready:    out std_logic; 
         clint_icb_rsp_err:       in std_logic;
         clint_icb_rsp_rdata:     in std_logic_vector(E203_XLEN-1 downto 0);

         -- The PLIC Interface (ICB)
         --    * bus cmd channel   
         plic_icb_cmd_valid:     out std_logic; 
         plic_icb_cmd_ready:      in std_logic;  
         plic_icb_cmd_addr:      out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         plic_icb_cmd_read:      out std_logic;
         plic_icb_cmd_wdata:     out std_logic_vector(E203_XLEN-1 downto 0);
         plic_icb_cmd_wmask:     out std_logic_vector(E203_XLEN/8-1 downto 0);
         
         -- * RSP channel        
         plic_icb_rsp_valid:      in std_logic; 
         plic_icb_rsp_ready:     out std_logic; 
         plic_icb_rsp_err:        in std_logic;
         plic_icb_rsp_rdata:      in std_logic_vector(E203_XLEN-1 downto 0);

         -- The ICB Interface to Fast I/O
         --    * bus cmd channel    
         fio_icb_cmd_valid:      out std_logic; 
         fio_icb_cmd_ready:       in std_logic;  
         fio_icb_cmd_addr:       out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         fio_icb_cmd_read:       out std_logic;
         fio_icb_cmd_wdata:      out std_logic_vector(E203_XLEN-1 downto 0);
         fio_icb_cmd_wmask:      out std_logic_vector(E203_XLEN/8-1 downto 0);
       
         -- * RSP channel        
         fio_icb_rsp_valid:       in std_logic; 
         fio_icb_rsp_ready:      out std_logic; 
         fio_icb_rsp_err:         in std_logic;
         fio_icb_rsp_rdata:       in std_logic_vector(E203_XLEN-1 downto 0);

        
         -- The System Memory Interface (ICB)
         --    * bus cmd channel    
         mem_icb_cmd_valid:      out std_logic; 
         mem_icb_cmd_ready:       in std_logic;  
         mem_icb_cmd_addr:       out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         mem_icb_cmd_read:       out std_logic;
         mem_icb_cmd_wdata:      out std_logic_vector(E203_XLEN-1 downto 0);
         mem_icb_cmd_wmask:      out std_logic_vector(E203_XLEN/8-1 downto 0);
        
         -- * RSP channel       
         mem_icb_rsp_valid:       in std_logic; 
         mem_icb_rsp_ready:      out std_logic; 
         mem_icb_rsp_err:         in std_logic;
         mem_icb_rsp_rdata:       in std_logic_vector(E203_XLEN-1 downto 0);
    
         -- The test mode signal
         test_mode:               in std_logic;

         -- The Clock
         clk:                     in std_logic;

         -- The low-level active reset signal, treated as async
         rst_n:                   in std_logic        
  );
end e203_cpu_top;

architecture impl of e203_cpu_top is 
 `if E203_HAS_ITCM = "TRUE" then
  signal itcm_ls:       std_ulogic;
  signal rst_itcm:      std_ulogic;
  signal itcm_ram_cs:   std_ulogic;
  signal itcm_ram_we:   std_ulogic;
  signal itcm_ram_addr: std_ulogic_vector(E203_ITCM_RAM_AW-1 downto 0);
  signal itcm_ram_wem : std_ulogic_vector(E203_ITCM_RAM_MW-1 downto 0);
  signal itcm_ram_din : std_ulogic_vector(E203_ITCM_RAM_DW-1 downto 0);
 `if E203_HAS_LOCKSTEP = "FALSE" then
  signal itcm_ram_dout: std_ulogic_vector(E203_ITCM_RAM_DW-1 downto 0);
 `end if
  signal clk_itcm_ram:  std_ulogic;
 `end if

  
 `if E203_HAS_DTCM = "TRUE" then
  signal dtcm_ls:       std_ulogic;
  signal rst_dtcm:      std_ulogic;
  signal dtcm_ram_cs:   std_ulogic;
  signal dtcm_ram_we:   std_ulogic;
  signal dtcm_ram_addr: std_ulogic_vector(E203_DTCM_RAM_AW-1 downto 0);
  signal dtcm_ram_wem : std_ulogic_vector(E203_DTCM_RAM_MW-1 downto 0);
  signal dtcm_ram_din : std_ulogic_vector(E203_DTCM_RAM_DW-1 downto 0);
 `if E203_HAS_LOCKSTEP = "FALSE" then
  signal dtcm_ram_dout: std_ulogic_vector(E203_DTCM_RAM_DW-1 downto 0);
 `end if
  signal clk_dtcm_ram : std_ulogic;
 `end if


 `if E203_HAS_LOCKSTEP = "FALSE" then
  signal ppi_icb_rsp_excl_ok  : std_ulogic;
  signal fio_icb_rsp_excl_ok  : std_ulogic;
  signal plic_icb_rsp_excl_ok : std_ulogic;
  signal clint_icb_rsp_excl_ok: std_ulogic;
  signal mem_icb_rsp_excl_ok  : std_ulogic;
 `if E203_HAS_PPI = "TRUE" then
  signal ppi_icb_enable:        std_ulogic;
  signal ppi_region_indic:      std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
 `end if

 `if E203_HAS_PLIC = "TRUE" then
  signal plic_icb_enable:       std_ulogic;
  signal plic_region_indic:     std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
 `end if

 `if E203_HAS_CLINT = "TRUE" then
  signal clint_icb_enable:      std_ulogic;
  signal clint_region_indic:    std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
 `end if

 `if E203_HAS_MEM_ITF = "TRUE" then
  signal mem_icb_enable:        std_ulogic;
 `end if

 `if E203_HAS_FIO = "TRUE" then
  signal fio_icb_enable:        std_ulogic;
  signal fio_region_indic:      std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
 `end if
 `end if

begin
  ppi_icb_rsp_excl_ok   <= '0';
  fio_icb_rsp_excl_ok   <= '0';
  plic_icb_rsp_excl_ok  <= '0';
  clint_icb_rsp_excl_ok <= '0';
  mem_icb_rsp_excl_ok   <= '0';

 `if E203_HAS_PPI = "TRUE" then
  ppi_icb_enable <= '1';
  ppi_region_indic <= std_logic_vector(E203_PPI_ADDR_BASE);
 `else
  ppi_icb_enable <= '0';
 `end if

 `if E203_HAS_PLIC = "TRUE" then
  plic_icb_enable <= '1';
  plic_region_indic <= std_logic_vector(E203_PLIC_ADDR_BASE);
 `else
  plic_icb_enable <= '0';
 `end if

 `if E203_HAS_CLINT = "TRUE" then
  clint_icb_enable <= '1';
  clint_region_indic <= std_logic_vector(E203_CLINT_ADDR_BASE);
 `else
  clint_icb_enable <= '0';
 `end if

 `if E203_HAS_MEM_ITF = "TRUE" then
  mem_icb_enable <= '1';
 `else
  mem_icb_enable <= '0';
 `end if

 `if E203_HAS_FIO = "TRUE" then
  fio_icb_enable <= '1';
  fio_region_indic <= std_logic_vector(E203_FIO_ADDR_BASE);
 `else
  fio_icb_enable <= '0';
 `end if

  u_e203_cpu: entity work.e203_cpu generic map( 1 )
  port map(
   inspect_pc               => inspect_pc, 
   inspect_dbg_irq          => inspect_dbg_irq      ,
   inspect_mem_cmd_valid    => inspect_mem_cmd_valid, 
   inspect_mem_cmd_ready    => inspect_mem_cmd_ready, 
   inspect_mem_rsp_valid    => inspect_mem_rsp_valid,
   inspect_mem_rsp_ready    => inspect_mem_rsp_ready,
   inspect_core_clk         => inspect_core_clk     ,

   core_csr_clk             => core_csr_clk,

   tm_stop                  => tm_stop,
   pc_rtvec                 => pc_rtvec,
 `if E203_HAS_ITCM = "TRUE" then
   itcm_ls                  => itcm_ls,
 `end if
 `if E203_HAS_DTCM = "TRUE" then
   dtcm_ls         => dtcm_ls,
 `end if
   core_wfi        => core_wfi       ,
   dbg_irq_r       => dbg_irq_r      ,

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

   dbg_mode        => dbg_mode,
   dbg_halt_r      => dbg_halt_r,
   dbg_step_r      => dbg_step_r,
   dbg_ebreakm_r   => dbg_ebreakm_r,
   dbg_stopcycle   => dbg_stopcycle,

   core_mhartid    => core_mhartid,  
   dbg_irq_a       => dbg_irq_a,
   ext_irq_a       => ext_irq_a,
   sft_irq_a       => sft_irq_a,
   tmr_irq_a       => tmr_irq_a,

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

   ppi_region_indic      => ppi_region_indic,
   ppi_icb_enable        => ppi_icb_enable,
   ppi_icb_cmd_valid     => ppi_icb_cmd_valid,
   ppi_icb_cmd_ready     => ppi_icb_cmd_ready,
   ppi_icb_cmd_addr      => ppi_icb_cmd_addr ,
   ppi_icb_cmd_read      => ppi_icb_cmd_read ,
   ppi_icb_cmd_wdata     => ppi_icb_cmd_wdata,
   ppi_icb_cmd_wmask     => ppi_icb_cmd_wmask,
   ppi_icb_cmd_lock      => OPEN,
   ppi_icb_cmd_excl      => OPEN,
   ppi_icb_cmd_size      => OPEN,
   
   ppi_icb_rsp_valid     => ppi_icb_rsp_valid,
   ppi_icb_rsp_ready     => ppi_icb_rsp_ready,
   ppi_icb_rsp_err       => ppi_icb_rsp_err  ,
   ppi_icb_rsp_excl_ok   => ppi_icb_rsp_excl_ok,
   ppi_icb_rsp_rdata     => ppi_icb_rsp_rdata,

   clint_region_indic    => clint_region_indic,
   clint_icb_enable      => clint_icb_enable,
   clint_icb_cmd_valid   => clint_icb_cmd_valid,
   clint_icb_cmd_ready   => clint_icb_cmd_ready,
   clint_icb_cmd_addr    => clint_icb_cmd_addr ,
   clint_icb_cmd_read    => clint_icb_cmd_read ,
   clint_icb_cmd_wdata   => clint_icb_cmd_wdata,
   clint_icb_cmd_wmask   => clint_icb_cmd_wmask,
   clint_icb_cmd_lock    => OPEN,
   clint_icb_cmd_excl    => OPEN,
   clint_icb_cmd_size    => OPEN,
   
   clint_icb_rsp_valid   => clint_icb_rsp_valid,
   clint_icb_rsp_ready   => clint_icb_rsp_ready,
   clint_icb_rsp_err     => clint_icb_rsp_err  ,
   clint_icb_rsp_excl_ok => clint_icb_rsp_excl_ok,
   clint_icb_rsp_rdata   => clint_icb_rsp_rdata,

   plic_region_indic     => plic_region_indic,
   plic_icb_enable       => plic_icb_enable,
   plic_icb_cmd_valid    => plic_icb_cmd_valid,
   plic_icb_cmd_ready    => plic_icb_cmd_ready,
   plic_icb_cmd_addr     => plic_icb_cmd_addr ,
   plic_icb_cmd_read     => plic_icb_cmd_read ,
   plic_icb_cmd_wdata    => plic_icb_cmd_wdata,
   plic_icb_cmd_wmask    => plic_icb_cmd_wmask,
   plic_icb_cmd_lock     => OPEN,
   plic_icb_cmd_excl     => OPEN,
   plic_icb_cmd_size     => OPEN,
   
   plic_icb_rsp_valid    => plic_icb_rsp_valid,
   plic_icb_rsp_ready    => plic_icb_rsp_ready,
   plic_icb_rsp_err      => plic_icb_rsp_err  ,
   plic_icb_rsp_excl_ok  => plic_icb_rsp_excl_ok,
   plic_icb_rsp_rdata    => plic_icb_rsp_rdata,


 `if E203_HAS_FIO = "TRUE" then
   fio_icb_enable        => fio_icb_enable,
   fio_region_indic      => fio_region_indic,
   fio_icb_cmd_valid     => fio_icb_cmd_valid,
   fio_icb_cmd_ready     => fio_icb_cmd_ready,
   fio_icb_cmd_addr      => fio_icb_cmd_addr ,
   fio_icb_cmd_read      => fio_icb_cmd_read ,
   fio_icb_cmd_wdata     => fio_icb_cmd_wdata,
   fio_icb_cmd_wmask     => fio_icb_cmd_wmask,
   fio_icb_cmd_lock      => OPEN,
   fio_icb_cmd_excl      => OPEN,
   fio_icb_cmd_size      => OPEN,
   
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
   mem_icb_cmd_lock      => OPEN,
   mem_icb_cmd_excl      => OPEN,
   mem_icb_cmd_size      => OPEN,
   mem_icb_cmd_burst     => OPEN,
   mem_icb_cmd_beat      => OPEN,
   
   mem_icb_rsp_valid     => mem_icb_rsp_valid,
   mem_icb_rsp_ready     => mem_icb_rsp_ready,
   mem_icb_rsp_err       => mem_icb_rsp_err  ,
   mem_icb_rsp_excl_ok   => mem_icb_rsp_excl_ok,
   mem_icb_rsp_rdata     => mem_icb_rsp_rdata,
 `end if

 `if E203_HAS_ITCM = "TRUE" then
   itcm_ram_cs           => itcm_ram_cs  ,
   itcm_ram_we           => itcm_ram_we  ,
   itcm_ram_addr         => itcm_ram_addr, 
   itcm_ram_wem          => itcm_ram_wem ,
   itcm_ram_din          => itcm_ram_din ,         
   itcm_ram_dout         => itcm_ram_dout,
   clk_itcm_ram          => clk_itcm_ram ,  
   rst_itcm              => rst_itcm     ,
 `end if

 `if E203_HAS_DTCM = "TRUE" then
   dtcm_ram_cs           => dtcm_ram_cs  ,
   dtcm_ram_we           => dtcm_ram_we  ,
   dtcm_ram_addr         => dtcm_ram_addr, 
   dtcm_ram_wem          => dtcm_ram_wem ,
   dtcm_ram_din          => dtcm_ram_din ,         
   dtcm_ram_dout         => dtcm_ram_dout,
   clk_dtcm_ram          => clk_dtcm_ram ,  
   rst_dtcm              => rst_dtcm,
 `end if
   test_mode             => test_mode, 
 `if E203_HAS_LOCKSTEP = "FALSE" then
 `end if
   rst_n                 => rst_n,
   clk                   => clk 
  );

  u_e203_srams: entity work.e203_srams port map(
 `if E203_HAS_DTCM = "TRUE" then
  dtcm_ram_sd   => tcm_sd,
  dtcm_ram_ds   => tcm_ds,
  dtcm_ram_ls   => dtcm_ls,

  dtcm_ram_cs   => dtcm_ram_cs  ,
  dtcm_ram_we   => dtcm_ram_we  ,
  dtcm_ram_addr => dtcm_ram_addr, 
  dtcm_ram_wem  => dtcm_ram_wem ,
  dtcm_ram_din  => dtcm_ram_din ,         
  dtcm_ram_dout => dtcm_ram_dout,
  clk_dtcm_ram  => clk_dtcm_ram ,  
  rst_dtcm      => rst_dtcm,
 `end if 

 `if E203_HAS_ITCM = "TRUE" then
  itcm_ram_sd   => tcm_sd,
  itcm_ram_ds   => tcm_ds,
  itcm_ram_ls   => itcm_ls,

  itcm_ram_cs   => itcm_ram_cs  ,
  itcm_ram_we   => itcm_ram_we  ,
  itcm_ram_addr => itcm_ram_addr, 
  itcm_ram_wem  => itcm_ram_wem ,
  itcm_ram_din  => itcm_ram_din ,         
  itcm_ram_dout => itcm_ram_dout,
  clk_itcm_ram  => clk_itcm_ram ,  
  rst_itcm      => rst_itcm     ,
 `end if
  test_mode     => test_mode 
 );
end impl;