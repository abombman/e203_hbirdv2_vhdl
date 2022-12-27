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

entity e203_lsu_ctrl is 
  port(
       commit_mret:      in std_logic;
       commit_trap:      in std_logic;
       lsu_ctrl_active: out std_logic;
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
       lsu_o_cmt_buserr: out std_logic; -- The bus-error exception generated
       lsu_o_cmt_badaddr:out std_logic_vector(E203_ADDR_SIZE -1 downto 0); 
       lsu_o_cmt_ld:     out std_logic;
       lsu_o_cmt_st:     out std_logic;
       
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
     
      `if E203_HAS_NICE = "TRUE" then
       -- The NICE ICB Interface to LSU-ctrl
       nice_mem_holdup:      in std_logic;
       -- * Bus cmd channel
       nice_icb_cmd_valid:   in std_logic;
       nice_icb_cmd_ready:  out std_logic;
       nice_icb_cmd_addr:    in std_logic_vector(E203_ADDR_SIZE-1 downto 0);    
       nice_icb_cmd_read:    in std_logic; 
       nice_icb_cmd_wdata:   in std_logic_vector(E203_XLEN-1 downto 0);        
       nice_icb_cmd_wmask:   in std_logic_vector(E203_XLEN/8-1 downto 0);      
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
     
     
      `if E203_HAS_DCACHE = "TRUE" then 
       -- The ICB Interface to DCache
       --
       -- * Bus cmd channel
       dcache_icb_cmd_valid: out std_logic;
       dcache_icb_cmd_ready:  in std_logic;
       dcache_icb_cmd_addr:  out std_logic_vector(E203_ADDR_SIZE-1 downto 0);    
       dcache_icb_cmd_read:  out std_logic; 
       dcache_icb_cmd_wdata: out std_logic_vector(E203_XLEN-1 downto 0);        
       dcache_icb_cmd_wmask: out std_logic_vector(E203_XLEN/8-1 downto 0);      
       dcache_icb_cmd_lock:  out std_logic;
       dcache_icb_cmd_excl:  out std_logic;
       dcache_icb_cmd_size:  out std_logic_vector(1 downto 0);                   
       --
       -- * Bus RSP channel
       dcache_icb_rsp_valid:    in std_logic;
       dcache_icb_rsp_ready:   out std_logic;
       dcache_icb_rsp_err  :    in std_logic;
       dcache_icb_rsp_excl_ok: out std_logic;
       dcache_icb_rsp_rdata:    in std_logic_vector(E203_XLEN-1 downto 0);        
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
        dtcm_icb_cmd_size:     out std_logic_vector(1 downto 0);                  
       --
       -- * Bus RSP channel
       dtcm_icb_rsp_valid:      in std_logic;
       dtcm_icb_rsp_ready:     out std_logic;
       dtcm_icb_rsp_err  :      in std_logic;
       dtcm_icb_rsp_excl_ok:    in std_logic;
       dtcm_icb_rsp_rdata:      in std_logic_vector(E203_XLEN-1 downto 0);        
      `end if
     
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
     
       clk:                     in std_logic;
       rst_n:                   in std_logic
       );
end e203_lsu_ctrl;

architecture impl of e203_lsu_ctrl is 
  -- The NICE mem holdup signal will override other request to LSU-Ctrl
  signal agu_icb_cmd_valid_pos: std_ulogic;
  signal agu_icb_cmd_ready_pos: std_ulogic;
  
 `if E203_HAS_FPU = "FALSE" then
  constant LSU_ARBT_I_PTR_W:    integer:= 1;
  `if E203_HAS_NICE = "TRUE" then
   constant LSU_ARBT_I_NUM:     integer:= 2;
  `end if
  `if E203_HAS_NICE = "FALSE" then
   constant LSU_ARBT_I_NUM:     integer:= 1;
  `end if
 `end if

  -- NOTE:
  --   * PPI is a must to have
  --   * Either DCache, ITCM, DTCM or SystemITF is must to have
 `if E203_HAS_DTCM = "FALSE" then
   `if E203_HAS_DCACHE = "FALSE" then
     `if E203_HAS_MEM_ITF = "FALSE" then
       `if E203_HAS_ITCM = "FALSE" then
         `error  "There must be something wrong, Either DCache, DTCM, ITCM or SystemITF is must to have. 
                 Otherwise where to access the data?"
       `end if
     `end if
   `end if
 `end if
 
 `if E203_HAS_NICE = "TRUE" then
  signal nice_icb_cmd_wr_mask:    std_ulogic_vector(E203_XLEN_MW-1 downto 0);           
 `end if

  signal pre_agu_icb_rsp_valid:   std_ulogic;
  signal pre_agu_icb_rsp_ready:   std_ulogic;
  signal pre_agu_icb_rsp_err  :   std_ulogic;
  signal pre_agu_icb_rsp_excl_ok: std_ulogic;
  signal pre_agu_icb_rsp_rdata:   std_ulogic_vector(E203_XLEN-1 downto 0);
  signal pre_agu_icb_rsp_back2agu: std_ulogic; 
  signal pre_agu_icb_rsp_usign:    std_ulogic;
  signal pre_agu_icb_rsp_read:     std_ulogic;
  signal pre_agu_icb_rsp_excl:     std_ulogic;
  signal pre_agu_icb_rsp_size:     std_ulogic_vector(2-1 downto 0);
  signal pre_agu_icb_rsp_itag:    std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);
  signal pre_agu_icb_rsp_addr:     std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
  constant USR_W:                  integer:= (E203_ITAG_WIDTH+6+E203_ADDR_SIZE);
  constant USR_PACK_EXCL:          integer:= 0; -- The cmd_excl is in the user 0 bit
  signal agu_icb_cmd_usr:          std_ulogic_vector(USR_W-1 downto 0);

 `if E203_HAS_NICE = "TRUE" then
  signal nice_icb_cmd_usr:         std_ulogic_vector(USR_W-1 downto 0);
 `end if

  signal fpu_icb_cmd_usr:          std_ulogic_vector(USR_W-1 downto 0);
  signal pre_agu_icb_rsp_usr:      std_ulogic_vector(USR_W-1 downto 0);

 `if E203_HAS_NICE = "TRUE" then
  signal nice_icb_rsp_usr:         std_ulogic_vector(USR_W-1 downto 0);
 `end if

  signal fpu_icb_rsp_usr:          std_ulogic_vector(USR_W-1 downto 0);
  signal arbt_icb_cmd_valid:       std_ulogic;
  signal arbt_icb_cmd_ready:       std_ulogic;
  signal arbt_icb_cmd_addr:        std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
  signal arbt_icb_cmd_read:        std_ulogic;
  signal arbt_icb_cmd_wdata:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal arbt_icb_cmd_wmask:       std_ulogic_vector(E203_XLEN/8-1 downto 0);
  signal arbt_icb_cmd_lock:        std_ulogic;
  signal arbt_icb_cmd_excl:        std_ulogic;
  signal arbt_icb_cmd_size:        std_ulogic_vector(1 downto 0);
  signal arbt_icb_cmd_burst:       std_ulogic_vector(1 downto 0);
  signal arbt_icb_cmd_beat:        std_ulogic_vector(1 downto 0);
  signal arbt_icb_cmd_usr:         std_ulogic_vector(USR_W-1 downto 0);

  signal arbt_icb_rsp_valid:       std_ulogic;
  signal arbt_icb_rsp_ready:       std_ulogic;
  signal arbt_icb_rsp_err:         std_ulogic;
  signal arbt_icb_rsp_excl_ok:     std_ulogic;
  signal arbt_icb_rsp_rdata:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal arbt_icb_rsp_usr:         std_ulogic_vector(USR_W-1 downto 0);

  signal arbt_bus_icb_cmd_valid:   std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_ready:   std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_addr:    std_ulogic_vector(LSU_ARBT_I_NUM*E203_ADDR_SIZE-1 downto 0);
  signal arbt_bus_icb_cmd_read:    std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_wdata:   std_ulogic_vector(LSU_ARBT_I_NUM*E203_XLEN-1 downto 0);
  signal arbt_bus_icb_cmd_wmask:   std_ulogic_vector(LSU_ARBT_I_NUM*E203_XLEN/8-1 downto 0);
  signal arbt_bus_icb_cmd_lock:    std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_excl:    std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_size:    std_ulogic_vector(LSU_ARBT_I_NUM*2-1 downto 0);
  signal arbt_bus_icb_cmd_usr:     std_ulogic_vector(LSU_ARBT_I_NUM*USR_W-1 downto 0);
  signal arbt_bus_icb_cmd_burst:   std_ulogic_vector(LSU_ARBT_I_NUM*2-1 downto 0);
  signal arbt_bus_icb_cmd_beat :   std_ulogic_vector(LSU_ARBT_I_NUM*2-1 downto 0);

  signal arbt_bus_icb_rsp_valid:   std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_ready:   std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_err:     std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_excl_ok: std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_rdata:   std_ulogic_vector(LSU_ARBT_I_NUM*E203_XLEN-1 downto 0);
  signal arbt_bus_icb_rsp_usr:     std_ulogic_vector(LSU_ARBT_I_NUM*USR_W-1 downto 0);

  -- CMD Channel
  signal arbt_bus_icb_cmd_valid_raw: std_ulogic_vector(LSU_ARBT_I_NUM*1-1 downto 0);
 
  -- Implement a FIFO to save the outstanding info
 
  signal arbt_icb_cmd_itcm:          std_ulogic;
 
  signal arbt_icb_cmd_dtcm:          std_ulogic;
 
  signal arbt_icb_cmd_dcache:        std_ulogic;

  signal arbt_icb_cmd_biu:           std_ulogic;
  signal splt_fifo_wen:              std_ulogic;
  signal splt_fifo_ren:              std_ulogic;

 `if E203_SUPPORT_AMO = "TRUE" then      
  signal excl_flg_r:                 std_ulogic;
  signal excl_addr_r:                std_ulogic_vector(E203_ADDR_SIZE-1 downto 0);
  signal icb_cmdaddr_eq_excladdr:    std_ulogic;  
  signal excl_flg_set:               std_ulogic;               
  signal excl_flg_clr:               std_ulogic;
  signal excl_flg_ena:               std_ulogic;
  signal excl_flg_nxt:               std_ulogic;  
  signal excl_addr_ena:              std_ulogic;
  signal excl_addr_nxt:              std_ulogic_vector(E203_ADDR_SIZE-1 downto 0); 
  signal arbt_icb_cmd_scond:         std_ulogic;
  signal arbt_icb_cmd_scond_true:    std_ulogic;
 `end if

  signal splt_fifo_i_ready:          std_ulogic;
  signal splt_fifo_i_valid:          std_ulogic;
  signal splt_fifo_full:             std_ulogic;
  signal splt_fifo_o_valid:          std_ulogic;
  signal splt_fifo_o_ready:          std_ulogic;
  signal splt_fifo_empty:            std_ulogic;

  signal arbt_icb_rsp_biu:           std_ulogic;
  signal arbt_icb_rsp_dcache:        std_ulogic;
  signal arbt_icb_rsp_dtcm:          std_ulogic;
  signal arbt_icb_rsp_itcm:          std_ulogic;
  signal arbt_icb_rsp_scond_true:    std_ulogic;

 `if E203_SUPPORT_AMO = "TRUE" then
  constant SPLT_FIFO_W:              integer:= (USR_W+5);
  signal arbt_icb_cmd_wmask_pos:     std_ulogic_vector(E203_XLEN/8-1 downto 0);
 `end if

 `if E203_SUPPORT_AMO = "FALSE" then
  constant SPLT_FIFO_W:              integer:= (USR_W+4);
  signal arbt_icb_cmd_wmask_pos:     std_ulogic_vector(E203_XLEN/8-1 downto 0);
 `end if

  signal splt_fifo_wdat:             std_ulogic_vector(SPLT_FIFO_W-1 downto 0);
  signal splt_fifo_rdat:             std_ulogic_vector(SPLT_FIFO_W-1 downto 0);

  -- Implement the ICB Splitting
  signal cmd_diff_branch:            std_ulogic;

  signal arbt_icb_cmd_addi_condi:    std_ulogic;
  signal arbt_icb_cmd_ready_pos:     std_ulogic;
  signal arbt_icb_cmd_valid_pos:     std_ulogic; 
  signal all_icb_cmd_ready:          std_ulogic;
  signal all_icb_cmd_ready_excp_biu: std_ulogic;
  signal all_icb_cmd_ready_excp_dcach: std_ulogic;
  signal all_icb_cmd_ready_excp_dtcm:  std_ulogic;
  signal all_icb_cmd_ready_excp_itcm:  std_ulogic;
  signal rdata_algn:                   std_ulogic_vector(E203_XLEN-1 downto 0);
  signal rsp_lbu:                      std_ulogic;
  signal rsp_lb :                      std_ulogic;
  signal rsp_lhu:                      std_ulogic;
  signal rsp_lh :                      std_ulogic;
  signal rsp_lw :                      std_ulogic;

 `if E203_SUPPORT_AMO = "TRUE" then      
  signal sc_excl_wdata:                std_ulogic_vector(E203_XLEN-1 downto 0);                
 `end if
  
begin
  -- The NICE mem holdup signal will override other request to LSU-Ctrl
  agu_icb_cmd_valid_pos <= agu_icb_cmd_valid
                          `if E203_HAS_NICE = "TRUE" then
                          and (not nice_mem_holdup)
                          `end if
                          ;
  agu_icb_cmd_ready     <= agu_icb_cmd_ready_pos
                          `if E203_HAS_NICE = "TRUE" then
                          and (not nice_mem_holdup)
                          `end if
                          ;

 `if E203_HAS_NICE = "TRUE" then
  nice_icb_cmd_wr_mask <= 
             ((E203_XLEN_MW-1 downto 0 => (nice_icb_cmd_size ?= "00")) and ("0001" sll to_integer(u_unsigned(nice_icb_cmd_addr(1 downto 0)))))
          or ((E203_XLEN_MW-1 downto 0 => (nice_icb_cmd_size ?= "01")) and ("0011" sll to_integer(u_unsigned'((nice_icb_cmd_addr(1) & '0')))))
          or ((E203_XLEN_MW-1 downto 0 => (nice_icb_cmd_size ?= "10")) and  "1111");
 `end if

  agu_icb_cmd_usr <=
      (
         agu_icb_cmd_back2agu  
        ,agu_icb_cmd_usign
        ,agu_icb_cmd_read
        ,agu_icb_cmd_size
        ,agu_icb_cmd_itag 
        ,agu_icb_cmd_addr 
        ,agu_icb_cmd_excl 
      );

 `if E203_HAS_NICE = "TRUE" then
  nice_icb_cmd_usr <= (USR_W-1 downto 0 => '0'); -- wire [USR_W-1:0] nice_icb_cmd_usr = {USR_W-1{1'b0}}; why?
 `end if

  fpu_icb_cmd_usr <= (USR_W-1 downto 0 => '0');  -- wire [USR_W-1:0] fpu_icb_cmd_usr = {USR_W-1{1'b0}}; why?
 
      (
         pre_agu_icb_rsp_back2agu  
        ,pre_agu_icb_rsp_usign
        ,pre_agu_icb_rsp_read
        ,pre_agu_icb_rsp_size
        ,pre_agu_icb_rsp_itag 
        ,pre_agu_icb_rsp_addr
        ,pre_agu_icb_rsp_excl 
      ) <= pre_agu_icb_rsp_usr;

  -- CMD Channel
  arbt_bus_icb_cmd_valid_raw <=
      -- The NICE take higher priority
                           (
                             agu_icb_cmd_valid
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_valid
                           `end if
                           );

  arbt_bus_icb_cmd_valid <=
      -- The NICE take higher priority
                           (
                             agu_icb_cmd_valid_pos
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_valid
                           `end if
                           );

  arbt_bus_icb_cmd_addr <=
                           (
                             agu_icb_cmd_addr
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_addr
                           `end if
                           );

  arbt_bus_icb_cmd_read <=
                           (
                             agu_icb_cmd_read
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_read
                           `end if
                           );

  arbt_bus_icb_cmd_wdata <=
                           (
                             agu_icb_cmd_wdata
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_wdata
                           `end if
                           );

  arbt_bus_icb_cmd_wmask <=
                           (
                             agu_icb_cmd_wmask
                           `if E203_HAS_NICE = "TRUE" then
                           ,nice_icb_cmd_wr_mask
                           `end if
                           );
                         
  arbt_bus_icb_cmd_lock <=
                           (
                             agu_icb_cmd_lock
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_lock
                           `end if
                           );

  arbt_bus_icb_cmd_burst <=
                           (
                             "00"  -- original version is 1'b0, why?
                           `if E203_HAS_NICE = "TRUE" then
                           , "00"  -- original version is 1'b0, why?
                           `end if
                           );

  arbt_bus_icb_cmd_beat <=
                           (
                             "00"
                           `if E203_HAS_NICE = "TRUE" then
                           , "00"
                           `end if
                           );

  arbt_bus_icb_cmd_excl <=
                           (
                             agu_icb_cmd_excl
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_excl
                           `end if
                           );
                           
  arbt_bus_icb_cmd_size <=
                           (
                             agu_icb_cmd_size
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_size
                           `end if
                           );

  arbt_bus_icb_cmd_usr <=
                           (
                             agu_icb_cmd_usr
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_usr
                           `end if
                           );

                           (
                             agu_icb_cmd_ready_pos
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_cmd_ready
                           `end if
                           ) <= arbt_bus_icb_cmd_ready;
                           

  -- RSP Channel
                    (
                      pre_agu_icb_rsp_valid
                    `if E203_HAS_NICE = "TRUE" then
                    , nice_icb_rsp_valid
                    `end if
                    ) <= arbt_bus_icb_rsp_valid;

                    (
                      pre_agu_icb_rsp_err
                    `if E203_HAS_NICE = "TRUE" then
                    , nice_icb_rsp_err
                    `end if
                    ) <= arbt_bus_icb_rsp_err;

                    (
                      pre_agu_icb_rsp_excl_ok
                    `if E203_HAS_NICE = "TRUE" then
                    , nice_icb_rsp_excl_ok
                    `end if
                    ) <= arbt_bus_icb_rsp_excl_ok;


                    (
                      pre_agu_icb_rsp_rdata
                    `if E203_HAS_NICE = "TRUE" then
                    , nice_icb_rsp_rdata
                    `end if
                    ) <= arbt_bus_icb_rsp_rdata;

                    (
                      pre_agu_icb_rsp_usr
                    `if E203_HAS_NICE = "TRUE" then
                    , nice_icb_rsp_usr
                    `end if
                    ) <= arbt_bus_icb_rsp_usr;

  arbt_bus_icb_rsp_ready <= (
                             pre_agu_icb_rsp_ready
                           `if E203_HAS_NICE = "TRUE" then
                           , nice_icb_rsp_ready
                           `end if
                           );

  u_lsu_icb_arbt: entity work.sirv_gnrl_icb_arbt generic map(
    ARBT_SCHEME     => 0, -- Priority based
    ALLOW_0CYCL_RSP => 0, -- Dont allow the 0 cycle response because in BIU we always have CMD_DP larger than 0
                          --   when the response come back from the external bus, it is at least 1 cycle later
                          --   for ITCM and DTCM, Dcache, .etc, definitely they cannot reponse as 0 cycle
    FIFO_OUTS_NUM   => E203_LSU_OUTS_NUM,
    FIFO_CUT_READY  => 0,
    ARBT_NUM        => LSU_ARBT_I_NUM,
    ARBT_PTR_W      => LSU_ARBT_I_PTR_W,
    USR_W           => USR_W,
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
    o_icb_cmd_usr         => arbt_icb_cmd_usr  ,
                                 
    o_icb_rsp_valid       => arbt_icb_rsp_valid  ,
    o_icb_rsp_ready       => arbt_icb_rsp_ready  ,
    o_icb_rsp_err         => arbt_icb_rsp_err    ,
    o_icb_rsp_excl_ok     => arbt_icb_rsp_excl_ok,
    o_icb_rsp_rdata       => arbt_icb_rsp_rdata  ,
    o_icb_rsp_usr         => arbt_icb_rsp_usr    ,
                                
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
                                 
    i_bus_icb_rsp_valid   => arbt_bus_icb_rsp_valid  ,
    i_bus_icb_rsp_ready   => arbt_bus_icb_rsp_ready  ,
    i_bus_icb_rsp_err     => arbt_bus_icb_rsp_err    ,
    i_bus_icb_rsp_excl_ok => arbt_bus_icb_rsp_excl_ok,
    i_bus_icb_rsp_rdata   => arbt_bus_icb_rsp_rdata  ,
    i_bus_icb_rsp_usr     => arbt_bus_icb_rsp_usr    ,
                            
    clk                   => clk  ,
    rst_n                 => rst_n
    );

  -- Implement a FIFO to save the outstanding info
  --
  --  * The FIFO will be pushed when a ICB CMD handshaked
  --  * The FIFO will be poped  when a ICB RSP handshaked
 `if E203_HAS_ITCM  = "TRUE" then
  arbt_icb_cmd_itcm <= (arbt_icb_cmd_addr(E203_ITCM_BASE_REGION'range) ?=  itcm_region_indic(E203_ITCM_BASE_REGION'range));
 `else
  arbt_icb_cmd_itcm <= '0';
 `end if
 `if E203_HAS_DTCM  = "TRUE" then
  arbt_icb_cmd_dtcm <= (arbt_icb_cmd_addr(E203_DTCM_BASE_REGION'range) ?=  dtcm_region_indic(E203_DTCM_BASE_REGION'range));
 `else
  arbt_icb_cmd_dtcm <= '0';
 `end if
 `if E203_HAS_DCACHE  = "TRUE" then
  arbt_icb_cmd_dcache <= (arbt_icb_cmd_addr(E203_DCACHE_BASE_REGION'range) ?=  dcache_region_indic(E203_DCACHE_BASE_REGION'range));
 `else
  arbt_icb_cmd_dcache <= '0';
 `end if

  arbt_icb_cmd_biu    <= (not arbt_icb_cmd_itcm) and (not arbt_icb_cmd_dtcm) and (not arbt_icb_cmd_dcache);

  splt_fifo_wen <= arbt_icb_cmd_valid and arbt_icb_cmd_ready;
  splt_fifo_ren <= arbt_icb_rsp_valid and arbt_icb_rsp_ready;

 `if E203_SUPPORT_AMO = "TRUE" then
  -- In E200 single core config, we always assume the store-condition is checked by the core itself
  --    because no other core to race
  icb_cmdaddr_eq_excladdr <= (arbt_icb_cmd_addr ?= excl_addr_r);
  -- Set when the Excl-load instruction going
  excl_flg_set <= splt_fifo_wen and arbt_icb_cmd_usr(USR_PACK_EXCL) and arbt_icb_cmd_read and arbt_icb_cmd_excl;
  -- Clear when any going store hit the same address
  --   also clear if there is any trap happened
  excl_flg_clr <= (splt_fifo_wen and (not arbt_icb_cmd_read) and icb_cmdaddr_eq_excladdr and excl_flg_r) 
                   or commit_trap or commit_mret;
  excl_flg_ena <= excl_flg_set or excl_flg_clr;
  excl_flg_nxt <= excl_flg_set or (not excl_flg_clr);
  excl_flg_dffl: entity work.sirv_gnrl_dfflr generic map(1) 
                                                port map(lden    => excl_flg_ena,
                                                         dnxt(0) => excl_flg_nxt,
                                                         qout(0) => excl_flg_r, 
                                                         clk     => clk, 
                                                         rst_n   => rst_n);
  
  -- The address is set when excl-load instruction going
  excl_addr_ena <= excl_flg_set;
  excl_addr_nxt <= arbt_icb_cmd_addr;
  excl_addr_dffl: entity work.sirv_gnrl_dfflr generic map(E203_ADDR_SIZE)  
                                                 port map(excl_addr_ena, excl_addr_nxt, excl_addr_r, clk, rst_n);

  -- For excl-store (scond) instruction, it will be true if the flag is true and the address is matching
  arbt_icb_cmd_scond <= arbt_icb_cmd_usr(USR_PACK_EXCL) and (not arbt_icb_cmd_read);
  arbt_icb_cmd_scond_true <= arbt_icb_cmd_scond and icb_cmdaddr_eq_excladdr and excl_flg_r;
 `end if

  splt_fifo_i_valid <= splt_fifo_wen;
  splt_fifo_full    <= (not splt_fifo_i_ready);
  splt_fifo_o_ready <= splt_fifo_ren;
  splt_fifo_empty   <= (not splt_fifo_o_valid);

 `if E203_SUPPORT_AMO = "TRUE" then
  arbt_icb_cmd_wmask_pos <= (E203_XLEN/8-1 downto 0 => '0') when (arbt_icb_cmd_scond and (not arbt_icb_cmd_scond_true)) = '1' else
                            arbt_icb_cmd_wmask;
 `end if

 `if E203_SUPPORT_AMO = "FALSE" then
  arbt_icb_cmd_wmask_pos <= arbt_icb_cmd_wmask;
 `end if

  splt_fifo_wdat <=  (
          arbt_icb_cmd_biu &
          arbt_icb_cmd_dcache &
          arbt_icb_cmd_dtcm &
          arbt_icb_cmd_itcm &
 `if E203_SUPPORT_AMO = "TRUE" then
          arbt_icb_cmd_scond_true &
 `end if
          arbt_icb_cmd_usr 
          );
   
      (
          arbt_icb_rsp_biu,
          arbt_icb_rsp_dcache,
          arbt_icb_rsp_dtcm,
          arbt_icb_rsp_itcm,
 `if E203_SUPPORT_AMO = "TRUE" then
          arbt_icb_rsp_scond_true, 
 `end if
          arbt_icb_rsp_usr 
          ) <= splt_fifo_rdat and (SPLT_FIFO_W-1 downto 0 => splt_fifo_o_valid);
          -- The output signals will be used as 
          --   control signals, so need to be masked

  
 `if E203_LSU_OUTS_NUM_IS_1 = "TRUE" then
  u_e203_lsu_splt_stage: entity work.sirv_gnrl_pipe_stage generic map(
    CUT_READY => 0,
    DP => 1,
    DW => SPLT_FIFO_W
    ) 
    port map(
    i_vld => splt_fifo_i_valid,
    i_rdy => splt_fifo_i_ready,
    i_dat => splt_fifo_wdat,
    o_vld => splt_fifo_o_valid,
    o_rdy => splt_fifo_o_ready,  
    o_dat => splt_fifo_rdat,  
  
    clk   => clk,
    rst_n => rst_n
    );
 `else
  u_e203_lsu_splt_fifo: entity work.sirv_gnrl_fifo generic map(
    CUT_READY =>0, -- When entry is clearing, it can also accept new one
    MSKO      =>0,
    -- The depth of OITF determined how many oustanding can be dispatched to long pipeline
    DP  => E203_LSU_OUTS_NUM,
    DW  => SPLT_FIFO_W
    )  
    port map(
    i_vld => splt_fifo_i_valid,
    i_rdy => splt_fifo_i_ready,
    i_dat => splt_fifo_wdat,
    o_vld => splt_fifo_o_valid,
    o_rdy => splt_fifo_o_ready,  
    o_dat => splt_fifo_rdat,  
    clk   => clk,
    rst_n => rst_n
    );
 `end if

  -- Implement the ICB Splitting
 `if E203_LSU_OUTS_NUM_IS_1  = "TRUE" then
  cmd_diff_branch <= '0'; -- If the LSU outstanding is only 1, there is no chance to 
                          --   happen several outsanding ops, not to mention 
                          --   with different branches
 `else
  -- The next transaction can only be issued if there is no any outstanding 
  --   transactions to different targets
  cmd_diff_branch <= (not splt_fifo_empty) and 
        (not ((arbt_icb_cmd_biu & arbt_icb_cmd_dcache & arbt_icb_cmd_dtcm & arbt_icb_cmd_itcm)
        ?= (arbt_icb_rsp_biu & arbt_icb_rsp_dcache & arbt_icb_rsp_dtcm & arbt_icb_rsp_itcm)));
 `end if

  arbt_icb_cmd_addi_condi <= (not splt_fifo_full) and (not cmd_diff_branch);
  arbt_icb_cmd_valid_pos <= arbt_icb_cmd_addi_condi and arbt_icb_cmd_valid;
  arbt_icb_cmd_ready     <= arbt_icb_cmd_addi_condi and arbt_icb_cmd_ready_pos;

 `if E203_HAS_DCACHE = "TRUE" then
  dcache_icb_cmd_valid <= arbt_icb_cmd_valid_pos and arbt_icb_cmd_dcache and all_icb_cmd_ready_excp_dcach;
  dcache_icb_cmd_addr  <= arbt_icb_cmd_addr ; 
  dcache_icb_cmd_read  <= arbt_icb_cmd_read ; 
  dcache_icb_cmd_wdata <= arbt_icb_cmd_wdata;
  dcache_icb_cmd_wmask <= arbt_icb_cmd_wmask_pos;
  dcache_icb_cmd_lock  <= arbt_icb_cmd_lock ;
  dcache_icb_cmd_excl  <= arbt_icb_cmd_excl ;
  dcache_icb_cmd_size  <= arbt_icb_cmd_size ;
 `end if

 `if E203_HAS_DTCM  = "TRUE" then
  dtcm_icb_cmd_valid <= arbt_icb_cmd_valid_pos and arbt_icb_cmd_dtcm and all_icb_cmd_ready_excp_dtcm;
  dtcm_icb_cmd_addr  <= arbt_icb_cmd_addr(E203_DTCM_ADDR_WIDTH-1 downto 0); 
  dtcm_icb_cmd_read  <= arbt_icb_cmd_read ; 
  dtcm_icb_cmd_wdata <= arbt_icb_cmd_wdata;
  dtcm_icb_cmd_wmask <= arbt_icb_cmd_wmask_pos;
  dtcm_icb_cmd_lock  <= arbt_icb_cmd_lock ;
  dtcm_icb_cmd_excl  <= arbt_icb_cmd_excl ;
  dtcm_icb_cmd_size  <= arbt_icb_cmd_size ;
 `end if

 `if E203_HAS_ITCM  = "TRUE" then
  itcm_icb_cmd_valid <= arbt_icb_cmd_valid_pos and arbt_icb_cmd_itcm and all_icb_cmd_ready_excp_itcm;
  itcm_icb_cmd_addr  <= arbt_icb_cmd_addr(E203_ITCM_ADDR_WIDTH-1 downto 0); 
  itcm_icb_cmd_read  <= arbt_icb_cmd_read ; 
  itcm_icb_cmd_wdata <= arbt_icb_cmd_wdata;
  itcm_icb_cmd_wmask <= arbt_icb_cmd_wmask_pos;
  itcm_icb_cmd_lock  <= arbt_icb_cmd_lock ;
  itcm_icb_cmd_excl  <= arbt_icb_cmd_excl ;
  itcm_icb_cmd_size  <= arbt_icb_cmd_size ;
 `end if

  biu_icb_cmd_valid <= arbt_icb_cmd_valid_pos and arbt_icb_cmd_biu and all_icb_cmd_ready_excp_biu;
  biu_icb_cmd_addr  <= arbt_icb_cmd_addr ; 
  biu_icb_cmd_read  <= arbt_icb_cmd_read ; 
  biu_icb_cmd_wdata <= arbt_icb_cmd_wdata;
  biu_icb_cmd_wmask <= arbt_icb_cmd_wmask_pos;
  biu_icb_cmd_lock  <= arbt_icb_cmd_lock ;
  biu_icb_cmd_excl  <= arbt_icb_cmd_excl ;
  biu_icb_cmd_size  <= arbt_icb_cmd_size ;
  
  -- To cut the in2out path from addr to the cmd_ready signal
  --   we just always use the simplified logic
  --   to always ask for all of the downstream components
  --   to be ready, this may impact performance a little
  --   bit in corner case, but doesnt really hurt the common 
  --   case
  --
  all_icb_cmd_ready <=  
              (biu_icb_cmd_ready ) 
             `if E203_HAS_DCACHE  = "TRUE" then
          and (dcache_icb_cmd_ready) 
             `end if
             `if E203_HAS_DTCM  = "TRUE" then
          and (dtcm_icb_cmd_ready) 
             `end if
             `if E203_HAS_ITCM  = "TRUE" then
          and (itcm_icb_cmd_ready) 
             `end if
             ;

  all_icb_cmd_ready_excp_biu <=  
              '1'
             `if E203_HAS_DCACHE  = "TRUE" then
          and (dcache_icb_cmd_ready) 
             `end if
             `if E203_HAS_DTCM  = "TRUE" then
          and (dtcm_icb_cmd_ready) 
             `end if
             `if E203_HAS_ITCM  = "TRUE" then
          and (itcm_icb_cmd_ready) 
             `end if
             ;

  all_icb_cmd_ready_excp_dcach <=  
              (biu_icb_cmd_ready ) 
             `if E203_HAS_DCACHE  = "TRUE" then
          and '1'
             `end if
             `if E203_HAS_DTCM  = "TRUE" then
          and (dtcm_icb_cmd_ready) 
             `end if
             `if E203_HAS_ITCM  = "TRUE" then
          and (itcm_icb_cmd_ready) 
             `end if
             ;
  all_icb_cmd_ready_excp_dtcm <=  
              (biu_icb_cmd_ready ) 
             `if E203_HAS_DCACHE  = "TRUE" then
          and (dcache_icb_cmd_ready) 
             `end if
             `if E203_HAS_DTCM  = "TRUE" then
          and '1'
             `end if
             `if E203_HAS_ITCM  = "TRUE" then
          and (itcm_icb_cmd_ready) 
             `end if
             ;

  all_icb_cmd_ready_excp_itcm <=  
              (biu_icb_cmd_ready ) 
             `if E203_HAS_DCACHE  = "TRUE" then
          and (dcache_icb_cmd_ready) 
             `end if
             `if E203_HAS_DTCM  = "TRUE" then
          and (dtcm_icb_cmd_ready) 
             `end if
             `if E203_HAS_ITCM  = "TRUE" then
          and '1'
             `end if
             ;

  arbt_icb_cmd_ready_pos <= all_icb_cmd_ready;  

  (
      arbt_icb_rsp_valid 
    , arbt_icb_rsp_err 
    , arbt_icb_rsp_excl_ok 
    , arbt_icb_rsp_rdata 
  ) <=
     ((E203_XLEN+3-1 downto 0 => arbt_icb_rsp_biu) and
                ( biu_icb_rsp_valid 
                & biu_icb_rsp_err 
                & biu_icb_rsp_excl_ok 
                & biu_icb_rsp_rdata 
                )
     ) 
 `if E203_HAS_DCACHE  = "TRUE" then
  or ((E203_XLEN+3-1 downto 0 => arbt_icb_rsp_dcache) and
                ( dcache_icb_rsp_valid 
                & dcache_icb_rsp_err 
                & dcache_icb_rsp_excl_ok 
                & dcache_icb_rsp_rdata 
                )
     ) 
 `end if
 `if E203_HAS_DTCM  = "TRUE" then
  or ((E203_XLEN+3-1 downto 0 => arbt_icb_rsp_dtcm) and
                ( dtcm_icb_rsp_valid 
                & dtcm_icb_rsp_err 
                & dtcm_icb_rsp_excl_ok 
                & dtcm_icb_rsp_rdata 
                )
     ) 
 `end if
 `if E203_HAS_ITCM  = "TRUE" then
  or ((E203_XLEN+3-1 downto 0 => arbt_icb_rsp_itcm) and
                ( itcm_icb_rsp_valid 
                & itcm_icb_rsp_err 
                & itcm_icb_rsp_excl_ok 
                & itcm_icb_rsp_rdata 
                )
     ) 
 `end if
     ;

  biu_icb_rsp_ready    <= arbt_icb_rsp_biu    and arbt_icb_rsp_ready;
 `if E203_HAS_DCACHE  = "TRUE" then
  dcache_icb_rsp_ready <= arbt_icb_rsp_dcache and arbt_icb_rsp_ready;
 `end if
 `if E203_HAS_DTCM  = "TRUE" then
  dtcm_icb_rsp_ready   <= arbt_icb_rsp_dtcm   and arbt_icb_rsp_ready;
 `end if
 `if E203_HAS_ITCM  = "TRUE" then
  itcm_icb_rsp_ready   <= arbt_icb_rsp_itcm   and arbt_icb_rsp_ready;
 `end if


  
  -- Pass the ICB response back to AGU or LSU-Writeback if it need back2agu or not
  lsu_o_valid       <= pre_agu_icb_rsp_valid and (not pre_agu_icb_rsp_back2agu);
  agu_icb_rsp_valid <= pre_agu_icb_rsp_valid and      pre_agu_icb_rsp_back2agu;

  pre_agu_icb_rsp_ready <= agu_icb_rsp_ready when pre_agu_icb_rsp_back2agu = '1' else
                           lsu_o_ready; 

  agu_icb_rsp_err     <= pre_agu_icb_rsp_err;
  agu_icb_rsp_excl_ok <= pre_agu_icb_rsp_excl_ok;
  agu_icb_rsp_rdata   <= pre_agu_icb_rsp_rdata;

  lsu_o_wbck_itag     <= pre_agu_icb_rsp_itag;

  rdata_algn <= 
      (pre_agu_icb_rsp_rdata srl to_integer(u_unsigned((pre_agu_icb_rsp_addr(1 downto 0) & "000"))));

  rsp_lbu <= (pre_agu_icb_rsp_size ?= "00") and (pre_agu_icb_rsp_usign ?= '1');
  rsp_lb  <= (pre_agu_icb_rsp_size ?= "00") and (pre_agu_icb_rsp_usign ?= '0');
  rsp_lhu <= (pre_agu_icb_rsp_size ?= "01") and (pre_agu_icb_rsp_usign ?= '1');
  rsp_lh  <= (pre_agu_icb_rsp_size ?= "01") and (pre_agu_icb_rsp_usign ?= '0');
  rsp_lw  <= (pre_agu_icb_rsp_size ?= "10");

 `if E203_SUPPORT_AMO = "TRUE" then
  -- In E200 single core config, we always assume the store-condition is checked by the core itself
  --    because no other core to race. So we dont use the returned excl-ok, but use the LSU tracked
  --    scond_true
  sc_excl_wdata <= (E203_XLEN-1 downto 0 => '0') when arbt_icb_rsp_scond_true = '1' else
                   (E203_XLEN-1 downto 0 => '1'); 
  -- If it is scond (excl-write), then need to update the regfile
  lsu_o_wbck_wdat <= sc_excl_wdata when ((not pre_agu_icb_rsp_read) and pre_agu_icb_rsp_excl) = '1' else 
 `end if
 `if E203_SUPPORT_AMO = "FALSE" then
  -- If not support the store-condition instructions, then we have no chance to issue excl transaction
  -- no need to consider the store-condition result write-back
  lsu_o_wbck_wdat <= 
 `end if
          (  ((E203_XLEN-1 downto 0 => rsp_lbu) and ((24-1 downto 0 =>            '0') & rdata_algn( 7 downto 0)))
          or ((E203_XLEN-1 downto 0 => rsp_lb ) and ((24-1 downto 0 =>  rdata_algn(7)) & rdata_algn( 7 downto 0)))
          or ((E203_XLEN-1 downto 0 => rsp_lhu) and ((16-1 downto 0 =>            '0') & rdata_algn(15 downto 0)))
          or ((E203_XLEN-1 downto 0 => rsp_lh ) and ((16-1 downto 0 => rdata_algn(15)) & rdata_algn(15 downto 0))) 
          or ((E203_XLEN-1 downto 0 => rsp_lw ) and rdata_algn(31 downto 0)));
          
  lsu_o_wbck_err    <= pre_agu_icb_rsp_err;
  lsu_o_cmt_buserr  <= pre_agu_icb_rsp_err; -- The bus-error exception generated
  lsu_o_cmt_badaddr <= pre_agu_icb_rsp_addr;
  lsu_o_cmt_ld      <= pre_agu_icb_rsp_read;
  lsu_o_cmt_st      <= not pre_agu_icb_rsp_read;

  lsu_ctrl_active <= (or arbt_bus_icb_cmd_valid_raw) or splt_fifo_o_valid;
end impl;