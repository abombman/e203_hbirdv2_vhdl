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
--   This module to implement the CSR instructions
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_alu_csrctrl is 
  port ( -- The Handshake Interface 
  	     csr_i_valid:  in std_logic; -- Handshake valid
  	     csr_i_ready: out std_logic; -- Handshake ready

  	     csr_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
         csr_i_info:   in std_logic_vector(E203_DECINFO_CSR_WIDTH-1 downto 0);
         csr_i_rdwen:  in std_logic;

         csr_ena:     out std_logic;
         csr_wr_en:   out std_logic;
         csr_rd_en:   out std_logic;
         csr_idx:     out std_logic_vector(12-1 downto 0);

         csr_access_ilgl: in std_logic;
         read_csr_dat:    in std_logic_vector(E203_XLEN-1 downto 0);
         wbck_csr_dat:   out std_logic_vector(E203_XLEN-1 downto 0);

        `if E203_HAS_CSR_NICE = "TRUE" then 
         nice_xs_off:     in std_logic;
         csr_sel_nice:   out std_logic;
         nice_csr_valid: out std_logic;
         nice_csr_ready:  in std_logic;
         nice_csr_addr:  out std_logic_vector(32-1 downto 0);
         nice_csr_wr:    out std_logic;
         nice_csr_wdata: out std_logic_vector(32-1 downto 0);
         nice_csr_rdata:  in std_logic_vector(32-1 downto 0);
        `end if
         
         -- The CSR Write-back/Commit Interface
         csr_o_valid: out std_logic; -- Handshake valid
  	     csr_o_ready:  in std_logic; -- Handshake ready
  	     -- The Write-Back Interface for Special (unaligned ldst and AMO instructions) 
         csr_o_wbck_wdat: out std_logic_vector(E203_XLEN-1 downto 0);
         csr_o_wbck_err:  out std_logic;

         clk:              in std_logic;  
         rst_n:            in std_logic 
  );
end e203_exu_alu_csrctrl;

architecture impl of e203_exu_alu_csrctrl is 
 `if E203_HAS_CSR_NICE = "TRUE" then 
  signal sel_nice:   std_ulogic;
  signal addi_condi: std_ulogic;
 `else
  signal sel_nice:   std_ulogic;
 `end if

  signal csrrw:        std_ulogic;
  signal csrrs:        std_ulogic;
  signal csrrc:        std_ulogic;
  signal rs1imm:       std_ulogic;
  signal rs1is0:       std_ulogic;
  signal zimm:         std_ulogic_vector(4 downto 0);
  signal csridx:       std_ulogic_vector(11 downto 0);
  signal csr_op1:      std_ulogic_vector(E203_XLEN-1 downto 0);
  signal is_csr_rdwen: std_ulogic;
begin
 `if E203_HAS_CSR_NICE = "TRUE" then
  -- If accessed the NICE CSR range then we need to check if the NICE CSR is ready
  csr_sel_nice <= (csr_idx(11 downto 8) ?= 4x"E");
  sel_nice     <= csr_sel_nice and (not nice_xs_off);
  addi_condi   <= nice_csr_ready when sel_nice = '1' else '1'; 

  csr_o_valid  <= csr_i_valid and addi_condi; -- Need to make sure the nice_csr-ready is ready to make sure
                                              --  it can be sent to NICE and O interface same cycle
  nice_csr_valid <= sel_nice and csr_i_valid and csr_o_ready; -- Need to make sure the o-ready is ready to make sure
                                                              --  it can be sent to NICE and O interface same cycle

  csr_i_ready    <= (nice_csr_ready & csr_o_ready) when sel_nice = '1' else csr_o_ready; 

  csr_o_wbck_err   <= csr_access_ilgl;
  csr_o_wbck_wdat  <= nice_csr_rdata when sel_nice = '1' else read_csr_dat;

  nice_csr_addr  <= csr_idx;
  nice_csr_wr    <= csr_wr_en;
  nice_csr_wdata <= wbck_csr_dat;
 `else
  sel_nice         <= '0';
  csr_o_valid      <= csr_i_valid;
  csr_i_ready      <= csr_o_ready;
  csr_o_wbck_err   <= csr_access_ilgl;
  csr_o_wbck_wdat  <= read_csr_dat;
 `end if
  
  csrrw  <= csr_i_info(E203_DECINFO_CSR_CSRRW 'right);
  csrrs  <= csr_i_info(E203_DECINFO_CSR_CSRRS 'right);
  csrrc  <= csr_i_info(E203_DECINFO_CSR_CSRRC 'right);
  rs1imm <= csr_i_info(E203_DECINFO_CSR_RS1IMM'right);
  rs1is0 <= csr_i_info(E203_DECINFO_CSR_RS1IS0'right);
  zimm   <= csr_i_info(E203_DECINFO_CSR_ZIMMM 'range);
  csridx <= csr_i_info(E203_DECINFO_CSR_CSRIDX'range);

  csr_op1 <= (27b"0" & zimm) when rs1imm = '1' else csr_i_rs1;
  
  is_csr_rdwen <= csr_i_rdwen when csrrw = '1' else '0';
  csr_rd_en <= csr_i_valid and 
    (
      is_csr_rdwen      -- the CSRRW only read when the destination reg need to be writen
      or csrrs or csrrc -- The set and clear operation always need to read CSR
    );
  csr_wr_en <= csr_i_valid and 
            (
                  csrrw                             -- CSRRW always write the original RS1 value into the CSR
             or ((csrrs or csrrc) and (not rs1is0)) -- for CSRRS/RC, if the RS is x0, then should not really write                                        
            );                                                                           
                                                                                         
  csr_idx <= csridx;

  csr_ena <= csr_o_valid and csr_o_ready and (not sel_nice);

  wbck_csr_dat <= 
               ((E203_XLEN-1 downto 0 => csrrw) and csr_op1)
            or ((E203_XLEN-1 downto 0 => csrrs) and (     csr_op1  or  read_csr_dat))
            or ((E203_XLEN-1 downto 0 => csrrc) and ((not csr_op1) and read_csr_dat));

end impl;