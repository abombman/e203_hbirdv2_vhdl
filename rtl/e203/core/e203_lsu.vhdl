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
--   The lsu_ctrl module control the LSU access requests
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_lsu is 
  port(
       commit_mret:      in std_logic;
       commit_trap:      in std_logic;
       excp_active:      in std_logic;
       lsu_active:      out std_logic;

      `if E203_HAS_ITCM = "TRUE" then
       itcm_region_indic: in std_logic_vector(E203_ADDR_SIZE-1 downto 0); 
      `end if
      `if E203_HAS_DTCM = "TRUE" then
       dtcm_region_indic: in std_logic_vector(E203_ADDR_SIZE-1 downto 0); 
      `end if
     
       
       -- The LSU Write-Back Interface
       lsu_o_valid:      out std_logic; -- Handshake valid
       lsu_o_ready:       in std_logic; -- Handshake ready
       lsu_o_wbck_wdat:  out std_logic_vector(E203_XLEN-1 downto 0); 
       lsu_o_wbck_itag:  out std_logic_vector(E203_ITAG_WIDTH -1 downto 0); 
       lsu_o_wbck_err:   out std_logic; -- The error no need to write back regfile
       lsu_o_cmt_ld:     out std_logic;
       lsu_o_cmt_st:     out std_logic;
       lsu_o_cmt_badaddr:out std_logic_vector(E203_ADDR_SIZE -1 downto 0); 
       lsu_o_cmt_buserr: out std_logic; -- The bus-error exception generated
       
       -- The AGU ICB Interface to LSU-ctrl
       --    * Bus cmd channel
       agu_icb_cmd_valid:  in std_logic;  -- Handshake valid
       agu_icb_cmd_ready: out std_logic;  -- Handshake ready
       agu_icb_cmd_addr:   in std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr 
       agu_icb_cmd_read:   in std_logic;  -- Read or write
       agu_icb_cmd_wdata:  in std_logic_vector(E203_XLEN-1 downto 0);         
       agu_icb_cmd_wmask:  in std_logic_vector(E203_XLEN/8-1 downto 0);       
       agu_icb_cmd_lock:   in std_logic;
       agu_icb_cmd_excl:   in std_logic;
       agu_icb_cmd_size:   in std_logic_vector(1 downto 0);                   
     
       -- Several additional side channel signals
       --   Indicate LSU-ctrl module to
       --     return the ICB response channel back to AGU
       --     this is only used by AMO or unaligned load/store 1st uop
       --     to return the response
       agu_icb_cmd_back2agu: in std_logic; 
       -- Sign extension or not
       agu_icb_cmd_usign:    in std_logic;
       -- RD Regfile index
       agu_icb_cmd_itag:     in std_logic_vector(E203_ITAG_WIDTH -1 downto 0); 
     
       -- * Bus RSP channel
       agu_icb_rsp_valid:   out std_logic;   -- Response valid 
       agu_icb_rsp_ready:    in std_logic;   -- Response ready
       agu_icb_rsp_err  :   out std_logic;   -- Response error
       agu_icb_rsp_excl_ok: out std_logic; -- Response exclusive okay
       agu_icb_rsp_rdata:   out std_logic_vector(E203_XLEN-1 downto 0);        
       
      `if E203_HAS_ITCM = "TRUE" then
       -- The ICB Interface to ITCM
       --
       -- * Bus cmd channel
       itcm_icb_cmd_valid:     out std_logic;
       itcm_icb_cmd_ready:      in std_logic;
       itcm_icb_cmd_addr:      out std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);    
       itcm_icb_cmd_read:      out std_logic; 
       itcm_icb_cmd_wdata:     out std_logic_vector(E203_XLEN-1 downto 0);        
       itcm_icb_cmd_wmask:     out std_logic_vector(E203_XLEN/8-1 downto 0);      
       itcm_icb_cmd_lock:      out std_logic;
       itcm_icb_cmd_excl:      out std_logic;
       itcm_icb_cmd_size:      out std_logic_vector(1 downto 0);                   
       --
       -- * Bus RSP channel
       itcm_icb_rsp_valid:      in std_logic;
       itcm_icb_rsp_ready:     out std_logic;
       itcm_icb_rsp_err  :      in std_logic;
       itcm_icb_rsp_excl_ok:    in std_logic;
       itcm_icb_rsp_rdata:      in std_logic_vector(E203_XLEN-1 downto 0);        
      `end if

      `if E203_HAS_DTCM = "TRUE" then
       -- The ICB Interface to DTCM
       --
       -- * Bus cmd channel
       dtcm_icb_cmd_valid:     out std_logic;
       dtcm_icb_cmd_ready:      in std_logic;
       dtcm_icb_cmd_addr:      out std_logic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0);    
       dtcm_icb_cmd_read:      out std_logic; 
       dtcm_icb_cmd_wdata:     out std_logic_vector(E203_XLEN-1 downto 0);        
       dtcm_icb_cmd_wmask:     out std_logic_vector(E203_XLEN/8-1 downto 0);      
       dtcm_icb_cmd_lock:      out std_logic;
       dtcm_icb_cmd_excl:      out std_logic;
       dtcm_icb_cmd_size:      out std_logic_vector(1 downto 0);                  
       --
       -- * Bus RSP channel
       dtcm_icb_rsp_valid:      in std_logic;
       dtcm_icb_rsp_ready:     out std_logic;
       dtcm_icb_rsp_err  :      in std_logic;
       dtcm_icb_rsp_excl_ok:    in std_logic;
       dtcm_icb_rsp_rdata:      in std_logic_vector(E203_XLEN-1 downto 0);        
      `end if
       
       -- The ICB Interface to BIU
       --
       -- * Bus cmd channel
       biu_icb_cmd_valid:      out std_logic;
       biu_icb_cmd_ready:       in std_logic;
       biu_icb_cmd_addr:       out std_logic_vector(E203_ADDR_SIZE-1 downto 0);    
       biu_icb_cmd_read:       out std_logic; 
       biu_icb_cmd_wdata:      out std_logic_vector(E203_XLEN-1 downto 0);        
       biu_icb_cmd_wmask:      out std_logic_vector(E203_XLEN/8-1 downto 0);      
       biu_icb_cmd_lock:       out std_logic;
       biu_icb_cmd_excl:       out std_logic;
       biu_icb_cmd_size:       out std_logic_vector(1 downto 0);                   
       --
       -- * Bus RSP channel
       biu_icb_rsp_valid:       in std_logic;
       biu_icb_rsp_ready:      out std_logic;
       biu_icb_rsp_err  :       in std_logic;
       biu_icb_rsp_excl_ok:     in std_logic;
       biu_icb_rsp_rdata:       in std_logic_vector(E203_XLEN-1 downto 0);        

      `if E203_HAS_NICE = "TRUE" then
       -- The NICE ICB Interface to LSU-ctrl
       nice_mem_holdup:      in std_logic;
       -- * Bus cmd channel
       nice_icb_cmd_valid:   in std_logic;
       nice_icb_cmd_ready:  out std_logic;
       nice_icb_cmd_addr:    in std_logic_vector(E203_ADDR_SIZE-1 downto 0);    
       nice_icb_cmd_read:    in std_logic; 
       nice_icb_cmd_wdata:   in std_logic_vector(E203_XLEN-1 downto 0);        
       nice_icb_cmd_wmask:   in std_logic_vector(E203_XLEN_MW-1 downto 0);      
       nice_icb_cmd_lock:    in std_logic;
       nice_icb_cmd_excl:    in std_logic;
       nice_icb_cmd_size:    in std_logic_vector(1 downto 0);                   
     
       -- * Bus RSP channel
       nice_icb_rsp_valid:   out std_logic;
       nice_icb_rsp_ready:    in std_logic;
       nice_icb_rsp_err  :   out std_logic;
       nice_icb_rsp_excl_ok: out std_logic;
       nice_icb_rsp_rdata:   out std_logic_vector(E203_XLEN-1 downto 0);        
      `end if
      
       clk:                     in std_logic;
       rst_n:                   in std_logic
       );
end e203_lsu;

architecture impl of e203_lsu is 
 `if E203_HAS_DCACHE = "TRUE" then 
  -- The ICB Interface to DCache
  --
  -- * Bus cmd channel
  signal dcache_icb_cmd_valid:   std_ulogic;
  signal dcache_icb_cmd_ready:   std_ulogic;
  signal dcache_icb_cmd_addr:    std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);    
  signal dcache_icb_cmd_read:    std_ulogic; 
  signal dcache_icb_cmd_wdata:   std_ulogic_vector(E203_XLEN-1 downto 0);        
  signal dcache_icb_cmd_wmask:   std_ulogic_vector(E203_XLEN/8-1 downto 0);      
  signal dcache_icb_cmd_lock:    std_ulogic;
  signal dcache_icb_cmd_excl:    std_ulogic;
  signal dcache_icb_cmd_size:    std_ulogic_vector(1 downto 0);                   
  --
  -- * Bus RSP channel
  signal dcache_icb_rsp_valid:   std_ulogic;
  signal dcache_icb_rsp_ready:   std_ulogic;
  signal dcache_icb_rsp_err  :   std_ulogic;
  signal dcache_icb_rsp_excl_ok: std_ulogic;
  signal dcache_icb_rsp_rdata:   std_ulogic_vector(E203_XLEN-1 downto 0);        
 `end if

  signal lsu_ctrl_active:        std_ulogic;
begin
  u_e203_lsu_ctrl: entity work.e203_lsu_ctrl port map(
    commit_mret           => commit_mret,
    commit_trap           => commit_trap,
    lsu_ctrl_active       => lsu_ctrl_active,
  `if E203_HAS_ITCM = "TRUE" then
    itcm_region_indic     => itcm_region_indic,
  `end if
  `if E203_HAS_DTCM = "TRUE" then
    dtcm_region_indic     => dtcm_region_indic,
  `end if
    lsu_o_valid           => lsu_o_valid ,
    lsu_o_ready           => lsu_o_ready ,
    lsu_o_wbck_wdat       => lsu_o_wbck_wdat,
    lsu_o_wbck_itag       => lsu_o_wbck_itag,
    lsu_o_wbck_err        => lsu_o_wbck_err ,
    lsu_o_cmt_buserr      => lsu_o_cmt_buserr  ,
    lsu_o_cmt_badaddr     => lsu_o_cmt_badaddr ,
    lsu_o_cmt_ld          => lsu_o_cmt_ld ,
    lsu_o_cmt_st          => lsu_o_cmt_st ,
    
    agu_icb_cmd_valid     => agu_icb_cmd_valid,
    agu_icb_cmd_ready     => agu_icb_cmd_ready,
    agu_icb_cmd_addr      => agu_icb_cmd_addr ,
    agu_icb_cmd_read      => agu_icb_cmd_read ,
    agu_icb_cmd_wdata     => agu_icb_cmd_wdata,
    agu_icb_cmd_wmask     => agu_icb_cmd_wmask,
    agu_icb_cmd_lock      => agu_icb_cmd_lock,
    agu_icb_cmd_excl      => agu_icb_cmd_excl,
    agu_icb_cmd_size      => agu_icb_cmd_size,
   
    agu_icb_cmd_back2agu  => agu_icb_cmd_back2agu,
    agu_icb_cmd_usign     => agu_icb_cmd_usign,
    agu_icb_cmd_itag      => agu_icb_cmd_itag,
  
    agu_icb_rsp_valid     => agu_icb_rsp_valid ,
    agu_icb_rsp_ready     => agu_icb_rsp_ready ,
    agu_icb_rsp_err       => agu_icb_rsp_err   ,
    agu_icb_rsp_excl_ok   => agu_icb_rsp_excl_ok,
    agu_icb_rsp_rdata     => agu_icb_rsp_rdata,

  `if E203_HAS_NICE = "TRUE" then
    nice_mem_holdup       => nice_mem_holdup   ,
    nice_icb_cmd_valid    => nice_icb_cmd_valid,
    nice_icb_cmd_ready    => nice_icb_cmd_ready,
    nice_icb_cmd_addr     => nice_icb_cmd_addr ,
    nice_icb_cmd_read     => nice_icb_cmd_read ,
    nice_icb_cmd_wdata    => nice_icb_cmd_wdata,
    nice_icb_cmd_wmask    => nice_icb_cmd_wmask,
    nice_icb_cmd_lock     => '0',
    nice_icb_cmd_excl     => '0',
    nice_icb_cmd_size     => nice_icb_cmd_size,
    
    nice_icb_rsp_valid    => nice_icb_rsp_valid,
    nice_icb_rsp_ready    => nice_icb_rsp_ready,
    nice_icb_rsp_err      => nice_icb_rsp_err  ,
    nice_icb_rsp_excl_ok  => nice_icb_rsp_excl_ok,
    nice_icb_rsp_rdata    => nice_icb_rsp_rdata,
  `end if
  `if E203_HAS_DCACHE = "TRUE" then
    dcache_icb_cmd_valid  => dcache_icb_cmd_valid,
    dcache_icb_cmd_ready  => dcache_icb_cmd_ready,
    dcache_icb_cmd_addr   => dcache_icb_cmd_addr ,
    dcache_icb_cmd_read   => dcache_icb_cmd_read ,
    dcache_icb_cmd_wdata  => dcache_icb_cmd_wdata,
    dcache_icb_cmd_wmask  => dcache_icb_cmd_wmask,
    dcache_icb_cmd_lock   => dcache_icb_cmd_lock,
    dcache_icb_cmd_excl   => dcache_icb_cmd_excl,
    dcache_icb_cmd_size   => dcache_icb_cmd_size,
    
    dcache_icb_rsp_valid  => dcache_icb_rsp_valid,
    dcache_icb_rsp_ready  => dcache_icb_rsp_ready,
    dcache_icb_rsp_err    => dcache_icb_rsp_err  ,
    dcache_icb_rsp_excl_ok=> dcache_icb_rsp_excl_ok,
    dcache_icb_rsp_rdata  => dcache_icb_rsp_rdata,
  `end if 

  `if E203_HAS_DTCM = "TRUE" then
    dtcm_icb_cmd_valid    => dtcm_icb_cmd_valid,
    dtcm_icb_cmd_ready    => dtcm_icb_cmd_ready,
    dtcm_icb_cmd_addr     => dtcm_icb_cmd_addr ,
    dtcm_icb_cmd_read     => dtcm_icb_cmd_read ,
    dtcm_icb_cmd_wdata    => dtcm_icb_cmd_wdata,
    dtcm_icb_cmd_wmask    => dtcm_icb_cmd_wmask,
    dtcm_icb_cmd_lock     => dtcm_icb_cmd_lock,
    dtcm_icb_cmd_excl     => dtcm_icb_cmd_excl,
    dtcm_icb_cmd_size     => dtcm_icb_cmd_size,
    
    dtcm_icb_rsp_valid    => dtcm_icb_rsp_valid,
    dtcm_icb_rsp_ready    => dtcm_icb_rsp_ready,
    dtcm_icb_rsp_err      => dtcm_icb_rsp_err  ,
    dtcm_icb_rsp_excl_ok  => dtcm_icb_rsp_excl_ok,
    dtcm_icb_rsp_rdata    => dtcm_icb_rsp_rdata,
  `end if            
    
  `if E203_HAS_ITCM = "TRUE" then
    itcm_icb_cmd_valid    => itcm_icb_cmd_valid,
    itcm_icb_cmd_ready    => itcm_icb_cmd_ready,
    itcm_icb_cmd_addr     => itcm_icb_cmd_addr ,
    itcm_icb_cmd_read     => itcm_icb_cmd_read ,
    itcm_icb_cmd_wdata    => itcm_icb_cmd_wdata,
    itcm_icb_cmd_wmask    => itcm_icb_cmd_wmask,
    itcm_icb_cmd_lock     => itcm_icb_cmd_lock,
    itcm_icb_cmd_excl     => itcm_icb_cmd_excl,
    itcm_icb_cmd_size     => itcm_icb_cmd_size,
    
    itcm_icb_rsp_valid    => itcm_icb_rsp_valid,
    itcm_icb_rsp_ready    => itcm_icb_rsp_ready,
    itcm_icb_rsp_err      => itcm_icb_rsp_err  ,
    itcm_icb_rsp_excl_ok  => itcm_icb_rsp_excl_ok,
    itcm_icb_rsp_rdata    => itcm_icb_rsp_rdata,
   `end if 
    
    biu_icb_cmd_valid     => biu_icb_cmd_valid,
    biu_icb_cmd_ready     => biu_icb_cmd_ready,
    biu_icb_cmd_addr      => biu_icb_cmd_addr ,
    biu_icb_cmd_read      => biu_icb_cmd_read ,
    biu_icb_cmd_wdata     => biu_icb_cmd_wdata,
    biu_icb_cmd_wmask     => biu_icb_cmd_wmask,
    biu_icb_cmd_lock      => biu_icb_cmd_lock,
    biu_icb_cmd_excl      => biu_icb_cmd_excl,
    biu_icb_cmd_size      => biu_icb_cmd_size,
   
    biu_icb_rsp_valid     => biu_icb_rsp_valid,
    biu_icb_rsp_ready     => biu_icb_rsp_ready,
    biu_icb_rsp_err       => biu_icb_rsp_err  ,
    biu_icb_rsp_excl_ok   => biu_icb_rsp_excl_ok,
    biu_icb_rsp_rdata     => biu_icb_rsp_rdata,
 
    clk                   => clk,
    rst_n                 => rst_n
  	);
  lsu_active <= lsu_ctrl_active 
                -- When interrupts comes, need to update the exclusive monitor
                -- so also need to turn on the clock
                or excp_active;
end impl;