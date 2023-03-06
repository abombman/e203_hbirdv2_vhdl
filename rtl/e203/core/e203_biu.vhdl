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
--   The BIU module control the ICB request to external memory system
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_biu is 
  port ( biu_active:              out  std_logic;

         --  The ICB Interface from LSU
         lsu2biu_icb_cmd_valid:    in  std_logic; 
         lsu2biu_icb_cmd_ready:   out  std_logic;  
         lsu2biu_icb_cmd_addr:     in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         lsu2biu_icb_cmd_read:     in  std_logic;
         lsu2biu_icb_cmd_wdata:    in  std_logic_vector(E203_XLEN-1 downto 0);
         lsu2biu_icb_cmd_wmask:    in  std_logic_vector(E203_XLEN/8-1 downto 0);
         lsu2biu_icb_cmd_burst:    in  std_logic_vector(1 downto 0);
         lsu2biu_icb_cmd_beat:     in  std_logic_vector(1 downto 0);
         lsu2biu_icb_cmd_lock:     in  std_logic;
         lsu2biu_icb_cmd_excl:     in  std_logic;
         lsu2biu_icb_cmd_size:     in  std_logic_vector(1 downto 0);
          
         -- * RSP channel     
         lsu2biu_icb_rsp_valid:   out  std_logic; 
         lsu2biu_icb_rsp_ready:    in  std_logic; 
         lsu2biu_icb_rsp_err:     out  std_logic;
         lsu2biu_icb_rsp_excl_ok: out  std_logic;
         lsu2biu_icb_rsp_rdata:   out  std_logic_vector(E203_XLEN-1 downto 0);
         
        `if E203_HAS_MEM_ITF = "TRUE" then
         -- the icb interface from ifetch 
         --
         --    * bus cmd channel
         ifu2biu_icb_cmd_valid:    in  std_logic; 
         ifu2biu_icb_cmd_ready:   out  std_logic;  
         ifu2biu_icb_cmd_addr:     in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ifu2biu_icb_cmd_read:     in  std_logic;
         ifu2biu_icb_cmd_wdata:    in  std_logic_vector(E203_XLEN-1 downto 0);
         ifu2biu_icb_cmd_wmask:    in  std_logic_vector(E203_XLEN/8-1 downto 0);
         ifu2biu_icb_cmd_burst:    in  std_logic_vector(1 downto 0);
         ifu2biu_icb_cmd_beat:     in  std_logic_vector(1 downto 0);
         ifu2biu_icb_cmd_lock:     in  std_logic;
         ifu2biu_icb_cmd_excl:     in  std_logic;
         ifu2biu_icb_cmd_size:     in  std_logic_vector(1 downto 0);
          
         -- * RSP channel     
         ifu2biu_icb_rsp_valid:   out  std_logic; 
         ifu2biu_icb_rsp_ready:    in  std_logic; 
         ifu2biu_icb_rsp_err:     out  std_logic;
         ifu2biu_icb_rsp_excl_ok: out  std_logic;
         ifu2biu_icb_rsp_rdata:   out  std_logic_vector(E203_XLEN-1 downto 0);
        `end if

         -- The ICB Interface to Private Peripheral Interface
         --
         ppi_region_indic:         in  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ppi_icb_enable:           in  std_logic;
         --    * bus cmd channel
         ppi_icb_cmd_valid:       out  std_logic; 
         ppi_icb_cmd_ready:        in  std_logic;  
         ppi_icb_cmd_addr:        out  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         ppi_icb_cmd_read:        out  std_logic;
         ppi_icb_cmd_wdata:       out  std_logic_vector(E203_XLEN-1 downto 0);
         ppi_icb_cmd_wmask:       out  std_logic_vector(E203_XLEN/8-1 downto 0);
         ppi_icb_cmd_burst:       out  std_logic_vector(1 downto 0);
         ppi_icb_cmd_beat:        out  std_logic_vector(1 downto 0);
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
         clint_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         clint_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
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
         plic_icb_cmd_burst:      out  std_logic_vector(1 downto 0);
         plic_icb_cmd_beat:       out  std_logic_vector(1 downto 0);
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
         fio_icb_cmd_burst:       out  std_logic_vector(1 downto 0);
         fio_icb_cmd_beat:        out  std_logic_vector(1 downto 0);
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
         mem_icb_cmd_burst:       out  std_logic_vector(1 downto 0);
         mem_icb_cmd_beat:        out  std_logic_vector(1 downto 0);
         mem_icb_cmd_lock:        out  std_logic;
         mem_icb_cmd_excl:        out  std_logic;
         mem_icb_cmd_size:        out  std_logic_vector(1 downto 0);
        
         -- * RSP channel         
         mem_icb_rsp_valid:        in  std_logic; 
         mem_icb_rsp_ready:       out  std_logic; 
         mem_icb_rsp_err:          in  std_logic;
         mem_icb_rsp_excl_ok:      in  std_logic;
         mem_icb_rsp_rdata:        in  std_logic_vector(E203_XLEN-1 downto 0);
        `end if
         
         clk:                      in  std_logic;
         rst_n:                    in  std_logic        
  );
end e203_biu;

architecture impl of e203_biu is 
 `if E203_HAS_MEM_ITF = "TRUE" then
  constant BIU_ARBT_I_NUM:   integer:= 2;
  constant BIU_ARBT_I_PTR_W: integer:= 1;
 `else
  constant BIU_ARBT_I_NUM:   integer:= 1;
  constant BIU_ARBT_I_PTR_W: integer:= 1;
 `end if
  
  -- The SPLT_NUM is the sum of following components
  --   * ppi, clint, plic, SystemITF, Fast-IO, IFU-err
  constant BIU_SPLT_I_NUM_0: integer:= 4;

 `if E203_HAS_MEM_ITF = "TRUE" then
  constant BIU_SPLT_I_NUM_1: integer:= (BIU_SPLT_I_NUM_0 + 1);
 `else
  constant BIU_SPLT_I_NUM_1: integer:= BIU_SPLT_I_NUM_0;
 `end if

 `if E203_HAS_FIO = "TRUE" then
  constant BIU_SPLT_I_NUM_2: integer:= (BIU_SPLT_I_NUM_1 + 1);
 `else
  constant BIU_SPLT_I_NUM_2: integer:= BIU_SPLT_I_NUM_1;
 `end if

  constant BIU_SPLT_I_NUM:   integer:= BIU_SPLT_I_NUM_2;

  signal ifuerr_icb_cmd_valid: std_ulogic;                               
  signal ifuerr_icb_cmd_ready: std_ulogic;                               
  signal ifuerr_icb_cmd_addr:  std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);   
  signal ifuerr_icb_cmd_read:  std_ulogic;                                
  signal ifuerr_icb_cmd_burst: std_ulogic_vector(2-1 downto 0);                
  signal ifuerr_icb_cmd_beat:  std_ulogic_vector(2-1 downto 0);                
  signal ifuerr_icb_cmd_wdata: std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal ifuerr_icb_cmd_wmask: std_ulogic_vector(E203_XLEN/8-1 downto 0);      
  signal ifuerr_icb_cmd_lock:  std_ulogic;                               
  signal ifuerr_icb_cmd_excl:  std_ulogic;                               
  signal ifuerr_icb_cmd_size:  std_ulogic_vector(1 downto 0);                  
  
  signal ifuerr_icb_rsp_valid: std_ulogic;
  signal ifuerr_icb_rsp_ready: std_ulogic;
  signal ifuerr_icb_rsp_err  : std_ulogic;
  signal ifuerr_icb_rsp_excl_ok: std_ulogic;
  signal ifuerr_icb_rsp_rdata:   std_ulogic_vector(E203_XLEN-1 downto 0);        

  signal arbt_icb_cmd_valid:     std_ulogic;
  signal arbt_icb_cmd_ready:     std_ulogic;
  signal arbt_icb_cmd_addr:      std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);   
  signal arbt_icb_cmd_read:      std_ulogic;
  signal arbt_icb_cmd_wdata:     std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal arbt_icb_cmd_wmask:     std_ulogic_vector(E203_XLEN/8-1 downto 0);      
  signal arbt_icb_cmd_burst:     std_ulogic_vector(1 downto 0);                   
  signal arbt_icb_cmd_beat:      std_ulogic_vector(1 downto 0);                   
  signal arbt_icb_cmd_lock:      std_ulogic;
  signal arbt_icb_cmd_excl:      std_ulogic;
  signal arbt_icb_cmd_size:      std_ulogic_vector(1 downto 0);                   
  signal arbt_icb_cmd_usr:       std_ulogic;

  signal arbt_icb_rsp_valid:     std_ulogic;
  signal arbt_icb_rsp_ready:     std_ulogic;
  signal arbt_icb_rsp_err:       std_ulogic;
  signal arbt_icb_rsp_excl_ok:   std_ulogic;
  signal arbt_icb_rsp_rdata:     std_ulogic_vector(E203_XLEN-1 downto 0);        

  signal arbt_bus_icb_cmd_valid: std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_cmd_ready: std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_cmd_addr:  std_ulogic_vector(BIU_ARBT_I_NUM*E203_ADDR_SIZE-1 downto 0); 
  signal arbt_bus_icb_cmd_read:  std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_cmd_wdata: std_ulogic_vector(BIU_ARBT_I_NUM*E203_XLEN-1 downto 0); 
  signal arbt_bus_icb_cmd_wmask: std_ulogic_vector(BIU_ARBT_I_NUM*E203_XLEN/8-1 downto 0); 
  signal arbt_bus_icb_cmd_burst: std_ulogic_vector(BIU_ARBT_I_NUM*2-1 downto 0); 
  signal arbt_bus_icb_cmd_beat:  std_ulogic_vector(BIU_ARBT_I_NUM*2-1 downto 0); 
  signal arbt_bus_icb_cmd_lock:  std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_cmd_excl:  std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_cmd_size:  std_ulogic_vector(BIU_ARBT_I_NUM*2-1 downto 0); 
  signal arbt_bus_icb_cmd_usr:   std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 

  signal arbt_bus_icb_rsp_valid: std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_rsp_ready: std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_rsp_err:   std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_rsp_excl_ok: std_ulogic_vector(BIU_ARBT_I_NUM*1-1 downto 0); 
  signal arbt_bus_icb_rsp_rdata:   std_ulogic_vector(BIU_ARBT_I_NUM*E203_XLEN-1 downto 0); 

  
  signal ifu2biu_icb_cmd_ifu:      std_ulogic;
  signal lsu2biu_icb_cmd_ifu:      std_ulogic;
 
  signal buf_icb_cmd_valid:        std_ulogic;
  signal buf_icb_cmd_ready:        std_ulogic;
  signal buf_icb_cmd_addr:         std_ulogic_vector(E203_ADDR_SIZE-1 downto 0); 
  signal buf_icb_cmd_read:         std_ulogic;
  signal buf_icb_cmd_wdata:        std_ulogic_vector(E203_XLEN-1 downto 0);      
  signal buf_icb_cmd_wmask:        std_ulogic_vector(E203_XLEN/8-1 downto 0);    
  signal buf_icb_cmd_burst:        std_ulogic_vector(1 downto 0);                
  signal buf_icb_cmd_beat:         std_ulogic_vector(1 downto 0);                
  signal buf_icb_cmd_lock:         std_ulogic;
  signal buf_icb_cmd_excl:         std_ulogic;
  signal buf_icb_cmd_size:         std_ulogic_vector(1 downto 0);                 
  signal buf_icb_cmd_usr:          std_ulogic;

  signal buf_icb_cmd_ifu:          std_ulogic;

  signal buf_icb_rsp_valid:        std_ulogic;
  signal buf_icb_rsp_ready:        std_ulogic;
  signal buf_icb_rsp_err:          std_ulogic;
  signal buf_icb_rsp_excl_ok:      std_ulogic;
  signal buf_icb_rsp_rdata:        std_ulogic_vector(E203_XLEN-1 downto 0);      

  signal icb_buffer_active:        std_ulogic;

  signal splt_bus_icb_cmd_valid:   std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_cmd_ready:   std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_cmd_addr:    std_ulogic_vector(BIU_SPLT_I_NUM*E203_ADDR_SIZE-1 downto 0); 
  signal splt_bus_icb_cmd_read:    std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_cmd_wdata:   std_ulogic_vector(BIU_SPLT_I_NUM*E203_XLEN-1 downto 0); 
  signal splt_bus_icb_cmd_wmask:   std_ulogic_vector(BIU_SPLT_I_NUM*E203_XLEN/8-1 downto 0); 
  signal splt_bus_icb_cmd_burst:   std_ulogic_vector(BIU_SPLT_I_NUM*2-1 downto 0); 
  signal splt_bus_icb_cmd_beat:    std_ulogic_vector(BIU_SPLT_I_NUM*2-1 downto 0); 
  signal splt_bus_icb_cmd_lock:    std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_cmd_excl:    std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_cmd_size:    std_ulogic_vector(BIU_SPLT_I_NUM*2-1 downto 0); 

  signal splt_bus_icb_rsp_valid:   std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_rsp_ready:   std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_rsp_err:     std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_rsp_excl_ok: std_ulogic_vector(BIU_SPLT_I_NUM*1-1 downto 0); 
  signal splt_bus_icb_rsp_rdata:   std_ulogic_vector(BIU_SPLT_I_NUM*E203_XLEN-1 downto 0); 

  signal buf_icb_cmd_ppi:          std_ulogic;
  signal buf_icb_sel_ppi:          std_ulogic;

  signal buf_icb_cmd_clint:        std_ulogic;
  signal buf_icb_sel_clint:        std_ulogic;

  signal buf_icb_cmd_plic:         std_ulogic;
  signal buf_icb_sel_plic:         std_ulogic;

 `if E203_HAS_FIO = "TRUE" then
  signal buf_icb_cmd_fio:          std_ulogic;
  signal buf_icb_sel_fio:          std_ulogic;
 `end if

  signal buf_icb_sel_ifuerr:       std_ulogic;

 `if E203_HAS_MEM_ITF = "TRUE" then
  signal buf_icb_sel_mem:          std_ulogic;
 `end if

  signal buf_icb_splt_indic:       std_ulogic_vector(BIU_SPLT_I_NUM-1 downto 0); 
 
begin
  -- CMD Channel
  arbt_bus_icb_cmd_valid <=
  -- The  LSU take higher priority
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_valid,
                           `end if
                             lsu2biu_icb_cmd_valid
                           );

  arbt_bus_icb_cmd_addr <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_addr,
                           `end if
                             lsu2biu_icb_cmd_addr
                           );

  arbt_bus_icb_cmd_read <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_read,
                           `end if
                             lsu2biu_icb_cmd_read
                           );

  arbt_bus_icb_cmd_wdata <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_wdata,
                           `end if
                             lsu2biu_icb_cmd_wdata
                           );

  arbt_bus_icb_cmd_wmask <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_wmask,
                           `end if
                             lsu2biu_icb_cmd_wmask
                           );
                         
  arbt_bus_icb_cmd_burst <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_burst,
                           `end if
                             lsu2biu_icb_cmd_burst
                           );
                         
  arbt_bus_icb_cmd_beat <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_beat,
                           `end if
                             lsu2biu_icb_cmd_beat
                           );
                         
  arbt_bus_icb_cmd_lock <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_lock,
                           `end if
                             lsu2biu_icb_cmd_lock
                           );

  arbt_bus_icb_cmd_excl <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_excl,
                           `end if
                             lsu2biu_icb_cmd_excl
                           );
                           
  arbt_bus_icb_cmd_size <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_size,
                           `end if
                             lsu2biu_icb_cmd_size
                           );

 ifu2biu_icb_cmd_ifu <= '1';
 lsu2biu_icb_cmd_ifu <= '0';
 arbt_bus_icb_cmd_usr <=
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_ifu,
                           `end if
                             lsu2biu_icb_cmd_ifu
                           ) ;

                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_cmd_ready,
                           `end if
                             lsu2biu_icb_cmd_ready
                           ) <= arbt_bus_icb_cmd_ready;

  -- RSP Channel
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_rsp_valid,
                           `end if
                             lsu2biu_icb_rsp_valid
                           ) <= arbt_bus_icb_rsp_valid;

                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_rsp_err,
                           `end if
                             lsu2biu_icb_rsp_err
                           ) <= arbt_bus_icb_rsp_err;

                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_rsp_excl_ok,
                           `end if
                             lsu2biu_icb_rsp_excl_ok
                           ) <= arbt_bus_icb_rsp_excl_ok;
                           
                           (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_rsp_rdata,
                           `end if
                             lsu2biu_icb_rsp_rdata
                           ) <= arbt_bus_icb_rsp_rdata;

  arbt_bus_icb_rsp_ready <= (
                           `if E203_HAS_MEM_ITF = "TRUE" then
                             ifu2biu_icb_rsp_ready,
                           `end if
                             lsu2biu_icb_rsp_ready
                           );

  u_biu_icb_arbt: entity work.sirv_gnrl_icb_arbt generic map(
    ARBT_SCHEME     => 0, -- Priority based
    ALLOW_0CYCL_RSP => 0, -- Dont allow the 0 cycle response because in BIU we always have CMD_DP larger than 0
                          --   when the response come back from the external bus, it is at least 1 cycle later
    FIFO_OUTS_NUM   => E203_BIU_OUTS_NUM,
    FIFO_CUT_READY  => E203_BIU_CMD_CUT_READY,
    ARBT_NUM        => BIU_ARBT_I_NUM,
    ARBT_PTR_W      => BIU_ARBT_I_PTR_W,
    USR_W           => 1,
    AW              => E203_ADDR_SIZE,
    DW              => E203_XLEN 
    ) 
    port map(
    o_icb_cmd_valid       => arbt_icb_cmd_valid,
    o_icb_cmd_ready       => arbt_icb_cmd_ready,
    o_icb_cmd_read(0)     => arbt_icb_cmd_read ,
    o_icb_cmd_addr        => arbt_icb_cmd_addr ,
    o_icb_cmd_wdata       => arbt_icb_cmd_wdata,
    o_icb_cmd_wmask       => arbt_icb_cmd_wmask,
    o_icb_cmd_burst       => arbt_icb_cmd_burst,
    o_icb_cmd_beat        => arbt_icb_cmd_beat ,
    o_icb_cmd_excl        => arbt_icb_cmd_excl ,
    o_icb_cmd_lock        => arbt_icb_cmd_lock ,
    o_icb_cmd_size        => arbt_icb_cmd_size ,
    o_icb_cmd_usr(0)      => arbt_icb_cmd_usr  ,
                                
    o_icb_rsp_valid       => arbt_icb_rsp_valid,
    o_icb_rsp_ready       => arbt_icb_rsp_ready,
    o_icb_rsp_err         => arbt_icb_rsp_err  ,
    o_icb_rsp_excl_ok     => arbt_icb_rsp_excl_ok,
    o_icb_rsp_rdata       => arbt_icb_rsp_rdata  ,
    o_icb_rsp_usr         => (others => '0'),
                               
    i_bus_icb_cmd_ready   => arbt_bus_icb_cmd_ready,
    i_bus_icb_cmd_valid   => arbt_bus_icb_cmd_valid,
    i_bus_icb_cmd_read    => arbt_bus_icb_cmd_read ,
    i_bus_icb_cmd_addr    => arbt_bus_icb_cmd_addr ,
    i_bus_icb_cmd_wdata   => arbt_bus_icb_cmd_wdata,
    i_bus_icb_cmd_wmask   => arbt_bus_icb_cmd_wmask,
    i_bus_icb_cmd_burst   => arbt_bus_icb_cmd_burst,
    i_bus_icb_cmd_beat    => arbt_bus_icb_cmd_beat ,
    i_bus_icb_cmd_excl    => arbt_bus_icb_cmd_excl ,
    i_bus_icb_cmd_lock    => arbt_bus_icb_cmd_lock ,
    i_bus_icb_cmd_size    => arbt_bus_icb_cmd_size ,
    i_bus_icb_cmd_usr     => arbt_bus_icb_cmd_usr  ,
                                
    i_bus_icb_rsp_valid   => arbt_bus_icb_rsp_valid,
    i_bus_icb_rsp_ready   => arbt_bus_icb_rsp_ready,
    i_bus_icb_rsp_err     => arbt_bus_icb_rsp_err  ,
    i_bus_icb_rsp_excl_ok => arbt_bus_icb_rsp_excl_ok,
    i_bus_icb_rsp_rdata   => arbt_bus_icb_rsp_rdata  ,
    i_bus_icb_rsp_usr     => OPEN,
                             
    clk                   => clk,
    rst_n                 => rst_n
    );

  --// To breakup the dead-lock cases, when incoming load/store request to the BIU but not granted 
  --//  This kind of potential deadlock case only happened at the low end core, where the ifetch response
  --//  provided to IFU, but IFU cannot accept it because it is waiting the IR stage to be cleared, and IR
  --//  stage is waiting the LSU to be cleared, and LSU is waiting this BIU to be cleared.
  --// At any mid of high end core (or with multiple oustandings), we definitely will update IFU
  --//  to make sure it always can accept any oustanding transactions traded with area cost.
  --// So back to this very low end core, to save areas, we prefetch without knowing if IR can accept
  --//  the response or not, and also in very low end core it is just 1 oustanding (multiple oustanding 
  --//  belong to mid or high end core), so to cut off this deadlocks, we just let the BIU to trigger
  --//  and replay indication if LSU cannot get granted, if IFU just overkilly forced to be replayed, it
  --//  just lost performance, but we dont care, because in low end core, ifetch to system mem is not
  --//  guranteed by performance. If IFU really suppose to be replayed, then good luck to break this deadlock.
  --wire ifu_replay_r;
  --// The IFU replay will be set when:
  --//    * Accessed by non-IFU access
  --//    * Or non-IFU access is to access ITCM, but not granted
  --wire ifu_replay_set = (arbt_icb_cmd_valid & arbt_icb_cmd_ready & lsu2biu_icb_cmd_valid)
  --               | (lsu2biu_icb_cmd_valid & (~lsu2biu_icb_cmd_ready));
  --// The IFU replay will be cleared after accessed by a IFU access
  --wire ifu_replay_clr = (arbt_icb_cmd_valid & arbt_icb_cmd_ready & ifu2biu_icb_cmd_valid);
  --wire ifu_replay_ena = ifu_replay_set | ifu_replay_clr;
  --wire ifu_replay_nxt = ifu_replay_set | (~ifu_replay_clr);
  --sirv_gnrl_dfflr #(1)ifu_replay_dffl(ifu_replay_ena, ifu_replay_nxt, ifu_replay_r, clk, rst_n);
  --assign ifu2biu_replay = ifu_replay_r;

  buf_icb_cmd_ifu <= buf_icb_cmd_usr;

  u_sirv_gnrl_icb_buffer: entity work.sirv_gnrl_icb_buffer generic map(
    OUTS_CNT_W    => E203_BIU_OUTS_CNT_W,
    AW            => E203_ADDR_SIZE,
    DW            => E203_XLEN, 
    CMD_DP        => E203_BIU_CMD_DP,
    RSP_DP        => E203_BIU_RSP_DP,
    CMD_CUT_READY => E203_BIU_CMD_CUT_READY,
    RSP_CUT_READY => E203_BIU_RSP_CUT_READY,
    USR_W         => 1
    )
  port map(
    icb_buffer_active => icb_buffer_active ,
    i_icb_cmd_valid   => arbt_icb_cmd_valid,
    i_icb_cmd_ready   => arbt_icb_cmd_ready,
    i_icb_cmd_read(0) => arbt_icb_cmd_read ,
    i_icb_cmd_addr    => arbt_icb_cmd_addr ,
    i_icb_cmd_wdata   => arbt_icb_cmd_wdata,
    i_icb_cmd_wmask   => arbt_icb_cmd_wmask,
    i_icb_cmd_lock    => arbt_icb_cmd_lock ,
    i_icb_cmd_excl    => arbt_icb_cmd_excl ,
    i_icb_cmd_size    => arbt_icb_cmd_size ,
    i_icb_cmd_burst   => arbt_icb_cmd_burst,
    i_icb_cmd_beat    => arbt_icb_cmd_beat ,
    i_icb_cmd_usr(0)  => arbt_icb_cmd_usr  ,
                    
    i_icb_rsp_valid   => arbt_icb_rsp_valid,
    i_icb_rsp_ready   => arbt_icb_rsp_ready,
    i_icb_rsp_err     => arbt_icb_rsp_err  ,
    i_icb_rsp_excl_ok => arbt_icb_rsp_excl_ok,
    i_icb_rsp_rdata   => arbt_icb_rsp_rdata,
    i_icb_rsp_usr     => OPEN,
    
    o_icb_cmd_valid   => buf_icb_cmd_valid,
    o_icb_cmd_ready   => buf_icb_cmd_ready,
    o_icb_cmd_read(0) => buf_icb_cmd_read ,
    o_icb_cmd_addr    => buf_icb_cmd_addr ,
    o_icb_cmd_wdata   => buf_icb_cmd_wdata,
    o_icb_cmd_wmask   => buf_icb_cmd_wmask,
    o_icb_cmd_lock    => buf_icb_cmd_lock ,
    o_icb_cmd_excl    => buf_icb_cmd_excl ,
    o_icb_cmd_size    => buf_icb_cmd_size ,
    o_icb_cmd_burst   => buf_icb_cmd_burst,
    o_icb_cmd_beat    => buf_icb_cmd_beat ,
    o_icb_cmd_usr(0)  => buf_icb_cmd_usr  ,
                        
    o_icb_rsp_valid   => buf_icb_rsp_valid,
    o_icb_rsp_ready   => buf_icb_rsp_ready,
    o_icb_rsp_err     => buf_icb_rsp_err  ,
    o_icb_rsp_excl_ok => buf_icb_rsp_excl_ok,
    o_icb_rsp_rdata   => buf_icb_rsp_rdata,
    o_icb_rsp_usr     => (others => '0'),

    clk               => clk,
    rst_n             => rst_n
  );

  -- CMD Channel
  (
    ifuerr_icb_cmd_valid
  , ppi_icb_cmd_valid
  , clint_icb_cmd_valid
  , plic_icb_cmd_valid
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_valid
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_valid
  `end if
  ) <= splt_bus_icb_cmd_valid;

  (
    ifuerr_icb_cmd_addr
  , ppi_icb_cmd_addr
  , clint_icb_cmd_addr
  , plic_icb_cmd_addr
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_addr
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_addr
  `end if
  ) <= splt_bus_icb_cmd_addr;

  (
    ifuerr_icb_cmd_read
  , ppi_icb_cmd_read
  , clint_icb_cmd_read
  , plic_icb_cmd_read
  `if E203_HAS_FIO  = "TRUE" then
  , fio_icb_cmd_read
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_read
  `end if
  ) <= splt_bus_icb_cmd_read;

  (
    ifuerr_icb_cmd_wdata
  , ppi_icb_cmd_wdata
  , clint_icb_cmd_wdata
  , plic_icb_cmd_wdata
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_wdata
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_wdata
  `end if
  ) <= splt_bus_icb_cmd_wdata;

  (
    ifuerr_icb_cmd_wmask
  , ppi_icb_cmd_wmask
  , clint_icb_cmd_wmask
  , plic_icb_cmd_wmask
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_wmask
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_wmask
  `end if
  ) <= splt_bus_icb_cmd_wmask;
                  
  (
  ifuerr_icb_cmd_burst
  , ppi_icb_cmd_burst
  , clint_icb_cmd_burst
  , plic_icb_cmd_burst
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_burst
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_burst
  `end if
  ) <= splt_bus_icb_cmd_burst;
                  
  (
    ifuerr_icb_cmd_beat
  , ppi_icb_cmd_beat
  , clint_icb_cmd_beat
  , plic_icb_cmd_beat
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_beat
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_beat
  `end if
  ) <= splt_bus_icb_cmd_beat;
                  
  (
    ifuerr_icb_cmd_lock
  , ppi_icb_cmd_lock
  , clint_icb_cmd_lock
  , plic_icb_cmd_lock
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_lock
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_lock
  `end if
  ) <= splt_bus_icb_cmd_lock;

  (
    ifuerr_icb_cmd_excl
  , ppi_icb_cmd_excl
  , clint_icb_cmd_excl
  , plic_icb_cmd_excl
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_excl
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_excl
  `end if
  ) <= splt_bus_icb_cmd_excl;
                    
  (
    ifuerr_icb_cmd_size
  , ppi_icb_cmd_size
  , clint_icb_cmd_size
  , plic_icb_cmd_size
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_cmd_size
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_cmd_size
  `end if
  ) <= splt_bus_icb_cmd_size;

  splt_bus_icb_cmd_ready <= (
                             ifuerr_icb_cmd_ready
                           , ppi_icb_cmd_ready
                           , clint_icb_cmd_ready
                           , plic_icb_cmd_ready
                           `if E203_HAS_FIO = "TRUE" then
                           , fio_icb_cmd_ready
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then
                           , mem_icb_cmd_ready
                           `end if
                           );

  -- RSP Channel
  splt_bus_icb_rsp_valid <= (
                             ifuerr_icb_rsp_valid
                           , ppi_icb_rsp_valid
                           , clint_icb_rsp_valid
                           , plic_icb_rsp_valid
                           `if E203_HAS_FIO = "TRUE" then
                           , fio_icb_rsp_valid
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then
                           , mem_icb_rsp_valid
                           `end if
                           );

  splt_bus_icb_rsp_err <= (
                             ifuerr_icb_rsp_err
                           , ppi_icb_rsp_err
                           , clint_icb_rsp_err
                           , plic_icb_rsp_err
                           `if E203_HAS_FIO = "TRUE" then
                           , fio_icb_rsp_err
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then
                           , mem_icb_rsp_err
                           `end if
                           );

  splt_bus_icb_rsp_excl_ok <= (
                             ifuerr_icb_rsp_excl_ok
                           , ppi_icb_rsp_excl_ok
                           , clint_icb_rsp_excl_ok
                           , plic_icb_rsp_excl_ok
                           `if E203_HAS_FIO = "TRUE" then
                           , fio_icb_rsp_excl_ok
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then
                           , mem_icb_rsp_excl_ok
                           `end if
                           );

  splt_bus_icb_rsp_rdata <= (
                             ifuerr_icb_rsp_rdata
                           , ppi_icb_rsp_rdata
                           , clint_icb_rsp_rdata
                           , plic_icb_rsp_rdata
                           `if E203_HAS_FIO = "TRUE" then
                           , fio_icb_rsp_rdata
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then
                           , mem_icb_rsp_rdata
                           `end if
                           );

  (
    ifuerr_icb_rsp_ready
  , ppi_icb_rsp_ready
  , clint_icb_rsp_ready
  , plic_icb_rsp_ready
  `if E203_HAS_FIO = "TRUE" then
  , fio_icb_rsp_ready
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
  , mem_icb_rsp_ready
  `end if
  ) <= splt_bus_icb_rsp_ready;

  buf_icb_cmd_ppi <= ppi_icb_enable and (buf_icb_cmd_addr(E203_PPI_BASE_REGION'range) ?=  ppi_region_indic(E203_PPI_BASE_REGION'range));
  buf_icb_sel_ppi <= buf_icb_cmd_ppi and (not buf_icb_cmd_ifu);

  buf_icb_cmd_clint <= clint_icb_enable and (buf_icb_cmd_addr(E203_CLINT_BASE_REGION'range) ?=  clint_region_indic(E203_CLINT_BASE_REGION'range));
  buf_icb_sel_clint <= buf_icb_cmd_clint and (not buf_icb_cmd_ifu);

  buf_icb_cmd_plic <= plic_icb_enable and (buf_icb_cmd_addr(E203_PLIC_BASE_REGION'range) ?=  plic_region_indic(E203_PLIC_BASE_REGION'range));
  buf_icb_sel_plic <= buf_icb_cmd_plic and (not buf_icb_cmd_ifu);

 `if E203_HAS_FIO = "TRUE" then
  buf_icb_cmd_fio <= fio_icb_enable and (buf_icb_cmd_addr(E203_FIO_BASE_REGION'range) ?=  fio_region_indic(E203_FIO_BASE_REGION'range));
  buf_icb_sel_fio <= buf_icb_cmd_fio and (not buf_icb_cmd_ifu);
 `end if

  buf_icb_sel_ifuerr <=(
                            buf_icb_cmd_ppi 
                          or buf_icb_cmd_clint 
                          or buf_icb_cmd_plic
                           `if E203_HAS_FIO = "TRUE" then
                          or buf_icb_cmd_fio
                           `end if
                           ) and buf_icb_cmd_ifu;

 `if E203_HAS_MEM_ITF = "TRUE" then
  buf_icb_sel_mem <= mem_icb_enable 
                             and (not buf_icb_sel_ifuerr)
                             and (not buf_icb_sel_ppi)
                             and (not buf_icb_sel_clint)
                             and (not buf_icb_sel_plic)
                          `if E203_HAS_FIO = "TRUE" then
                             and (not buf_icb_sel_fio)
                          `end if
                             ;
 `end if

  buf_icb_splt_indic <= 
      (
                             buf_icb_sel_ifuerr
                           , buf_icb_sel_ppi
                           , buf_icb_sel_clint
                           , buf_icb_sel_plic
                           `if E203_HAS_FIO = "TRUE" then
                           , buf_icb_sel_fio
                           `end if
                           `if E203_HAS_MEM_ITF = "TRUE" then 
                           , buf_icb_sel_mem
                           `end if
      );

  u_biu_icb_splt: entity work.sirv_gnrl_icb_splt generic map(
    ALLOW_DIFF      => 0,  -- Dont allow different branches oustanding
    ALLOW_0CYCL_RSP => 1,  -- Allow the 0 cycle response because in BIU the splt
                           --  is after the buffer, and will directly talk to the external
                           --  bus, where maybe the ROM is 0 cycle responsed.
    FIFO_OUTS_NUM   => E203_BIU_OUTS_NUM,
    FIFO_CUT_READY  => E203_BIU_CMD_CUT_READY,
    SPLT_NUM        => BIU_SPLT_I_NUM,
    SPLT_PTR_W      => BIU_SPLT_I_NUM,
    SPLT_PTR_1HOT   => 1,
    USR_W           => 1,
    AW              => E203_ADDR_SIZE,
    DW              => E203_XLEN 
    ) 
    port map(
    i_icb_splt_indic      => buf_icb_splt_indic,        

    i_icb_cmd_valid       => buf_icb_cmd_valid,
    i_icb_cmd_ready       => buf_icb_cmd_ready,
    i_icb_cmd_read(0)     => buf_icb_cmd_read ,
    i_icb_cmd_addr        => buf_icb_cmd_addr ,
    i_icb_cmd_wdata       => buf_icb_cmd_wdata,
    i_icb_cmd_wmask       => buf_icb_cmd_wmask,
    i_icb_cmd_burst       => buf_icb_cmd_burst,
    i_icb_cmd_beat        => buf_icb_cmd_beat ,
    i_icb_cmd_excl        => buf_icb_cmd_excl ,
    i_icb_cmd_lock        => buf_icb_cmd_lock ,
    i_icb_cmd_size        => buf_icb_cmd_size ,
    i_icb_cmd_usr         => (others => '0')  ,
 
    i_icb_rsp_valid       => buf_icb_rsp_valid  ,
    i_icb_rsp_ready       => buf_icb_rsp_ready  ,
    i_icb_rsp_err         => buf_icb_rsp_err    ,
    i_icb_rsp_excl_ok     => buf_icb_rsp_excl_ok,
    i_icb_rsp_rdata       => buf_icb_rsp_rdata  ,
    i_icb_rsp_usr         => OPEN               ,
                              
    o_bus_icb_cmd_ready   => splt_bus_icb_cmd_ready,
    o_bus_icb_cmd_valid   => splt_bus_icb_cmd_valid,
    o_bus_icb_cmd_read    => splt_bus_icb_cmd_read ,
    o_bus_icb_cmd_addr    => splt_bus_icb_cmd_addr ,
    o_bus_icb_cmd_wdata   => splt_bus_icb_cmd_wdata,
    o_bus_icb_cmd_wmask   => splt_bus_icb_cmd_wmask,
    o_bus_icb_cmd_burst   => splt_bus_icb_cmd_burst,
    o_bus_icb_cmd_beat    => splt_bus_icb_cmd_beat ,
    o_bus_icb_cmd_excl    => splt_bus_icb_cmd_excl ,
    o_bus_icb_cmd_lock    => splt_bus_icb_cmd_lock ,
    o_bus_icb_cmd_size    => splt_bus_icb_cmd_size ,
    o_bus_icb_cmd_usr     => OPEN                  ,
  
    o_bus_icb_rsp_valid   => splt_bus_icb_rsp_valid,
    o_bus_icb_rsp_ready   => splt_bus_icb_rsp_ready,
    o_bus_icb_rsp_err     => splt_bus_icb_rsp_err  ,
    o_bus_icb_rsp_excl_ok => splt_bus_icb_rsp_excl_ok,
    o_bus_icb_rsp_rdata   => splt_bus_icb_rsp_rdata  ,
    o_bus_icb_rsp_usr     => (BIU_SPLT_I_NUM-1 downto 0 => '0'),
                           
    clk                   => clk,
    rst_n                 => rst_n
  );

  biu_active <= ifu2biu_icb_cmd_valid or lsu2biu_icb_cmd_valid or icb_buffer_active; 

  -- Implement the IFU-accessed-Peripheral region error
  ifuerr_icb_cmd_ready <= ifuerr_icb_rsp_ready;
  
  -- 0 Cycle response
  ifuerr_icb_rsp_valid   <= ifuerr_icb_cmd_valid;
  ifuerr_icb_rsp_err     <= '1';
  ifuerr_icb_rsp_excl_ok <= '0';
  ifuerr_icb_rsp_rdata   <= (E203_XLEN-1 downto 0 => '0');
end impl;