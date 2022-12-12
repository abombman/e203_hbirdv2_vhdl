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
--   This module to implement the regular ALU instructions
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_NICE = "TRUE" then
entity e203_exu_nice is 
  port ( -- The Handshake Interface 
  	     nice_i_xs_off: in std_logic;
  	     nice_i_valid:  in std_logic; -- Handshake valid
  	     nice_i_ready: out std_logic; -- Handshake ready

  	     nice_i_instr:     in std_logic_vector(E203_XLEN-1 downto 0);
         nice_i_rs1:       in std_logic_vector(E203_XLEN-1 downto 0);
         nice_i_rs2:       in std_logic_vector(E203_XLEN-1 downto 0);
         nice_i_itag:      in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         nice_o_longpipe: out std_logic;

         -- The nice Commit Interface
         nice_o_valid:    out std_logic; -- Handshake valid
  	     nice_o_ready:     in std_logic; -- Handshake ready

  	     -- The nice write-back Interface
  	     nice_o_itag_valid: out std_logic; -- Handshake valid
  	     nice_o_itag_ready:  in std_logic; -- Handshake ready
  	     nice_o_itag:       out std_logic_vector(E203_ITAG_WIDTH-1 downto 0); 
         
         -- The nice Request Interface
         nice_rsp_multicyc_valid:   in std_logic; -- I: current insn is multi-cycle.
         nice_rsp_multicyc_ready:  out std_logic; -- O:  
         
         nice_req_valid:           out std_logic; -- Handshake valid
         nice_req_ready:            in std_logic; -- Handshake ready
         nice_req_instr:           out std_logic_vector(E203_XLEN-1 downto 0);
         nice_req_rs1:             out std_logic_vector(E203_XLEN-1 downto 0);
         nice_req_rs2:             out std_logic_vector(E203_XLEN-1 downto 0);
         
         clk:                       in std_logic;  
         rst_n:                     in std_logic 
  );
end e203_exu_nice;

architecture impl of e203_exu_nice is 
  signal nice_i_hsked:       std_ulogic;
  signal nice_req_valid_pos: std_ulogic;
  signal nice_req_ready_pos: std_ulogic;
  signal fifo_o_vld:         std_ulogic;
  signal itag_fifo_wen:      std_ulogic;
  signal itag_fifo_ren:      std_ulogic;
  signal fifo_i_vld:         std_ulogic;
  signal fifo_i_rdy:         std_ulogic;
  signal fifo_i_dat:         std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);
  signal fifo_o_rdy:         std_ulogic;
  signal fifo_o_dat:         std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);

  component sirv_gnrl_fifo is
    generic(
            CUT_READY: integer:= 0;
            MSKO:      integer:= 0; -- Mask out the data with valid or not
            DP:        integer:= 8; -- FIFO depth
            DW:        integer:= 32 -- FIFO width
    );
    port( 
          i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam    i_vld --> o_vld --> downward
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam  o_rdy --> i_rdy --> upward
          o_dat: out std_logic_vector( DW-1 downto 0 );  ------------

          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
begin
  nice_i_hsked <= nice_i_valid and nice_i_ready;

  -- when there is a valid insn and the cmt is ready, then send out the insn.
  nice_req_valid_pos <= nice_i_valid and nice_o_ready;
  nice_req_valid <= (not nice_i_xs_off) and  nice_req_valid_pos;
  -- when nice is disable, its req_ready is assumed to 1.
  nice_req_ready_pos <= '1' when nice_i_xs_off = '1' else nice_req_ready;
  -- nice reports ready to decode when its cmt is ready and the nice core is ready.
  nice_i_ready <= nice_req_ready_pos and nice_o_ready;
  -- the nice isns is about to cmt when it is truly a valid nice insn and the nice core has accepted.
  nice_o_valid <= nice_i_valid and nice_req_ready_pos;

  nice_rsp_multicyc_ready <= nice_o_itag_ready and fifo_o_vld;

  nice_req_instr <= nice_i_instr;
  nice_req_rs1 <= nice_i_rs1;
  nice_req_rs2 <= nice_i_rs2;

  nice_o_longpipe <= not nice_i_xs_off;

  itag_fifo_wen <= nice_o_longpipe and (nice_req_valid and nice_req_ready); 
  itag_fifo_ren <= nice_rsp_multicyc_valid and nice_rsp_multicyc_ready; 

  fifo_i_vld <= itag_fifo_wen;
  fifo_i_dat <= nice_i_itag;

  fifo_o_rdy <= itag_fifo_ren;
  nice_o_itag_valid <= fifo_o_vld and nice_rsp_multicyc_valid;

  -- ctrl path must be independent with data path to avoid timing-loop.
  nice_o_itag <= fifo_o_dat;

  u_nice_itag_fifo: component sirv_gnrl_fifo generic map(
                                                         DP        => 4,
                                                         DW        => E203_ITAG_WIDTH,
                                                         CUT_READY => 1 
                                                        )
                                                port map(
                                                         i_vld => fifo_i_vld,
                                                         i_rdy => fifo_i_rdy,
                                                         i_dat => fifo_i_dat,
                                                         o_vld => fifo_o_vld,
                                                         o_rdy => fifo_o_rdy,
                                                         o_dat => fifo_o_dat,
                                                         clk   => clk,
                                                         rst_n => rst_n
                                                        );

end impl;
`end if