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
--   The Write-Back module to arbitrate the write-back request from all 
--   long pipe modules
--
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_longpwbck is 
  port ( -- The LSU Write-Back Interface
  	     lsu_wbck_i_valid:    in std_logic; -- Handshake valid
  	     lsu_wbck_i_ready:   out std_logic; -- Handshake ready
         lsu_wbck_i_wdat:     in std_logic_vector(E203_XLEN-1 downto 0);
         lsu_wbck_i_itag:     in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         lsu_wbck_i_err:      in std_logic; -- The error exception generated
  	     lsu_cmt_i_buserr:    in std_logic; 
         lsu_cmt_i_badaddr:   in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         lsu_cmt_i_ld:        in std_logic;
         lsu_cmt_i_st:        in std_logic;

         -- The Long pipe instruction Wback interface to final wbck module
         longp_wbck_o_valid: out std_logic; -- Handshake valid
  	     longp_wbck_o_ready:  in std_logic; -- Handshake ready
  	     longp_wbck_o_wdat:  out std_logic_vector(E203_FLEN-1 downto 0);
  	     longp_wbck_o_flags: out std_logic_vector(5-1 downto 0);
  	     longp_wbck_o_rdidx: out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         longp_wbck_o_rdfpu: out std_logic;
  	          
  	     --  The Long pipe instruction Exception interface to commit stage
         longp_excp_o_valid:   out std_logic;
         longp_excp_o_ready:    in std_logic;
         longp_excp_o_insterr: out std_logic;
         longp_excp_o_ld:      out std_logic;
         longp_excp_o_st:      out std_logic;
         longp_excp_o_buserr:  out std_logic; -- The load/store bus-error exception generated
         longp_excp_o_badaddr: out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         longp_excp_o_pc:      out std_logic_vector(E203_PC_SIZE-1 downto 0);

         -- The itag of toppest entry of OITF
         oitf_empty:            in std_logic; 
         oitf_ret_ptr:          in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         oitf_ret_rdidx:        in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         oitf_ret_pc:           in std_logic_vector(E203_PC_SIZE-1 downto 0);
         oitf_ret_rdwen:        in std_logic;
         oitf_ret_rdfpu:        in std_logic;
         oitf_ret_ena:         out std_logic;
         
        `if E203_HAS_NICE = "TRUE" then
         nice_longp_wbck_i_valid:  in std_logic; 
         nice_longp_wbck_i_ready: out std_logic; 
         nice_longp_wbck_i_wdat:   in std_logic_vector(E203_XLEN-1 downto 0);
         nice_longp_wbck_i_itag:   in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         nice_longp_wbck_i_err:    in std_logic; 
  	    `end if

         clk:                      in std_logic;  
         rst_n:                    in std_logic  
  	   );
end e203_exu_longpwbck;

architecture impl of e203_exu_longpwbck is 
  signal wbck_ready4lsu:   std_ulogic;
  signal wbck_sel_lsu:     std_ulogic;
 `if E203_HAS_NICE = "TRUE" then
  signal wbck_ready4nice:  std_ulogic;
  signal wbck_sel_nice:    std_ulogic;
 `end if
  signal wbck_i_ready:     std_ulogic;
  signal wbck_i_valid:     std_ulogic;
  signal wbck_i_wdat:      std_ulogic_vector(E203_FLEN-1 downto 0);
  signal wbck_i_flags:     std_ulogic_vector(5-1 downto 0);
  signal wbck_i_rdidx:     std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal wbck_i_pc:        std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal wbck_i_rdwen:     std_ulogic;
  signal wbck_i_rdfpu:     std_ulogic;
  signal wbck_i_err:       std_ulogic;

  signal lsu_wbck_i_wdat_exd:  std_ulogic_vector(E203_FLEN-1 downto 0);
  
 `if E203_HAS_NICE = "TRUE" then
  signal nice_wbck_i_wdat_exd: std_ulogic_vector(E203_FLEN-1 downto 0);
  signal nice_wbck_i_err:      std_ulogic;
 `end if

  signal need_wbck:            std_ulogic;
  signal need_excp:            std_ulogic;

  signal longp_wbck_ready:     std_ulogic;
  signal longp_excp_ready:     std_ulogic;
  
begin
  -- The Long-pipe instruction can write-back only when it's itag 
  --   is same as the itag of toppest entry of OITF
  wbck_ready4lsu <= (lsu_wbck_i_itag ?= oitf_ret_ptr) and (not oitf_empty);
  wbck_sel_lsu <= lsu_wbck_i_valid and wbck_ready4lsu;

 `if E203_HAS_NICE = "TRUE" then
  wbck_ready4nice <= (nice_longp_wbck_i_itag ?= oitf_ret_ptr) and (not oitf_empty);
  wbck_sel_nice <= nice_longp_wbck_i_valid and wbck_ready4nice; 
 `end if

  -- assign longp_excp_o_ld   = wbck_sel_lsu & lsu_cmt_i_ld;
  -- assign longp_excp_o_st   = wbck_sel_lsu & lsu_cmt_i_st;
  -- assign longp_excp_o_buserr = wbck_sel_lsu & lsu_cmt_i_buserr;
  -- assign longp_excp_o_badaddr = wbck_sel_lsu ? lsu_cmt_i_badaddr : `E203_ADDR_SIZE'b0;

  ( longp_excp_o_insterr,
  	longp_excp_o_ld,
  	longp_excp_o_st,
  	longp_excp_o_buserr,
  	longp_excp_o_badaddr) <= 
                              ((E203_ADDR_SIZE+4-1 downto 0 => wbck_sel_lsu) and 
                               std_ulogic_vector'( '0' &
                                                   lsu_cmt_i_ld &
                                                   lsu_cmt_i_st &
                                                   lsu_cmt_i_buserr &
                                                   lsu_cmt_i_badaddr
                                                 )
                              );

  -- ////////////////////////////////////////////////////////////
  --  The Final arbitrated Write-Back Interface
  lsu_wbck_i_ready <= wbck_ready4lsu and wbck_i_ready;

  wbck_i_valid <=     (wbck_sel_lsu and lsu_wbck_i_valid)
              `if E203_HAS_NICE = "TRUE" then
                  or (wbck_sel_nice and nice_longp_wbck_i_valid)
              `end if
                  ;
 `if E203_FLEN_IS_32 = "TRUE" then
  lsu_wbck_i_wdat_exd <= lsu_wbck_i_wdat;
  `if E203_HAS_NICE = "TRUE" then
  nice_wbck_i_wdat_exd <= nice_longp_wbck_i_wdat;
  `end if
 `else
  lsu_wbck_i_wdat_exd <= ((E203_FLEN-1 downto E203_XLEN => '0') & lsu_wbck_i_wdat);
  `if E203_HAS_NICE = "TRUE" then
  nice_wbck_i_wdat_exd <= ((E203_FLEN-1 downto E203_XLEN => '0') & nice_longp_wbck_i_wdat);
  `end if
 `end if
 
  
  wbck_i_wdat <= ((E203_FLEN-1 downto 0 => wbck_sel_lsu) and lsu_wbck_i_wdat_exd)
              `if E203_HAS_NICE = "TRUE" then
                 or ((E203_FLEN-1 downto 0 => wbck_sel_nice) and nice_wbck_i_wdat_exd)
              `end if
                 ;
  wbck_i_flags <= 5b"0";

 `if E203_HAS_NICE = "TRUE" then
  nice_wbck_i_err <= nice_longp_wbck_i_err;
 `end if

  wbck_i_err   <= wbck_sel_lsu and lsu_wbck_i_err;
  wbck_i_pc    <= oitf_ret_pc;
  wbck_i_rdidx <= oitf_ret_rdidx;
  wbck_i_rdwen <= oitf_ret_rdwen;
  wbck_i_rdfpu <= oitf_ret_rdfpu;

  -- If the instruction have no error and it have the rdwen, then it need to 
  --   write back into regfile, otherwise, it does not need to write regfile
  need_wbck <= wbck_i_rdwen and (not wbck_i_err);

  -- If the long pipe instruction have error result, then it need to handshake
  --   with the commit module.
  need_excp <= wbck_i_err
            `if E203_HAS_NICE = "TRUE" then
               and (not (wbck_sel_nice and nice_wbck_i_err))   
            `end if
               ;
  longp_wbck_ready <= longp_wbck_o_ready when need_wbck = '1' else '1';
  longp_excp_ready <= longp_excp_o_ready when need_excp = '1' else '1';
  wbck_i_ready     <= longp_wbck_ready and longp_excp_ready;

  longp_wbck_o_valid <= need_wbck and wbck_i_valid and longp_excp_ready;
  longp_excp_o_valid <= need_excp and wbck_i_valid and longp_wbck_ready;

  longp_wbck_o_wdat  <= wbck_i_wdat ;
  longp_wbck_o_flags <= wbck_i_flags;
  longp_wbck_o_rdfpu <= wbck_i_rdfpu;
  longp_wbck_o_rdidx <= wbck_i_rdidx;

  longp_excp_o_pc    <= wbck_i_pc;

  oitf_ret_ena <= wbck_i_valid and wbck_i_ready;

 `if E203_HAS_NICE = "TRUE" then
  nice_longp_wbck_i_ready <= wbck_ready4nice and wbck_i_ready;
 `end if
end impl;