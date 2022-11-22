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

--=====================================================================
--
-- Description:
--  The module to implement the core's debug control and relevant CSRs
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_debug_csr is 
  generic( PC_SIZE: integer:= 32
  );
  port( cmt_dpc:         in std_logic_vector(PC_SIZE-1 downto 0);
  	    cmt_dpc_ena:     in std_logic;

  	    cmt_dcause:      in std_logic_vector(3-1 downto 0);
  	    cmt_dcause_ena:  in std_logic;

  	    dbg_irq_r:       in std_logic;

  	    -- The interface with CSR control 
        wr_dcsr_ena:     in std_logic;
        wr_dpc_ena:      in std_logic;
        wr_dscratch_ena: in std_logic;

        wr_csr_nxt:      in std_logic_vector(32-1 downto 0);

        dcsr_r:         out std_logic_vector(32-1 downto 0);
        dpc_r:          out std_logic_vector(PC_SIZE-1 downto 0);
        dscratch_r:     out std_logic_vector(32-1 downto 0);

        dbg_mode:       out std_logic;
        dbg_halt_r:     out std_logic;
        dbg_step_r:     out std_logic;
        dbg_ebreakm_r:  out std_logic;
        dbg_stopcycle:  out std_logic;

        clk:             in std_logic;
        rst_n:           in std_logic
  );
end sirv_debug_csr;

architecture impl of sirv_debug_csr is 
  signal dpc_ena: std_logic;
  signal dpc_nxt: std_logic_vector(PC_SIZE-1 downto 0);
  
  signal dscratch_ena: std_logic;
  signal dscratch_nxt: std_logic_vector(32-1 downto 0);

  signal ndreset_ena: std_logic;
  signal ndreset_nxt: std_logic_vector(1-1 downto 0);
  signal ndreset_r:   std_logic_vector(1-1 downto 0);

  signal fullreset_ena: std_logic;
  signal fullreset_nxt: std_logic_vector(1-1 downto 0);
  signal fullreset_r:   std_logic_vector(1-1 downto 0);

  signal dcause_ena: std_logic;
  signal dcause_nxt: std_logic_vector(3-1 downto 0);
  signal dcause_r:   std_logic_vector(3-1 downto 0);

  signal halt_ena: std_logic;
  signal halt_nxt: std_logic_vector(1-1 downto 0);
  signal halt_r:   std_logic_vector(1-1 downto 0);

  signal step_ena: std_logic;
  signal step_nxt: std_logic_vector(1-1 downto 0);
  signal step_r:   std_logic_vector(1-1 downto 0);

  signal ebreakm_ena: std_logic;
  signal ebreakm_nxt: std_logic_vector(1-1 downto 0);
  signal ebreakm_r:   std_logic_vector(1-1 downto 0);

  component sirv_gnrl_dfflr is
    generic( DW: integer );
    port( 
    	  lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
begin
  -- Implement DPC reg
  dpc_ena<= wr_dpc_ena or cmt_dpc_ena;
  dpc_nxt(PC_SIZE-1 downto 1)<= cmt_dpc(PC_SIZE-1 downto 1) when cmt_dpc_ena = '1' else
  	                            wr_csr_nxt(PC_SIZE-1 downto 1);
  dpc_nxt(0) <= '0';
  dpc_dfflr: component sirv_gnrl_dfflr generic map(PC_SIZE)
                                          port map(dpc_ena, dpc_nxt, dpc_r, clk, rst_n);
            
  -- Implement Dbg Scratch reg
  dscratch_ena <= wr_dscratch_ena;
  dscratch_nxt <= wr_csr_nxt;
  dscratch_dfflr: component sirv_gnrl_dfflr generic map(32)
                                               port map(dscratch_ena, dscratch_nxt, dscratch_r, clk, rst_n);
  
  -- We dont support the HW Trigger Module yet now

  -- Implement dcsr reg
  --
  -- The ndreset field
  ndreset_ena <= wr_dcsr_ena and wr_csr_nxt(29);
  ndreset_nxt(0) <= wr_csr_nxt(29);
  ndreset_dfflr: component sirv_gnrl_dfflr generic map(1)
                                              port map(ndreset_ena, ndreset_nxt, ndreset_r, clk, rst_n);

  -- This bit is not used as rocket impelmentation
  --
  -- The fullreset field
  fullreset_ena <= wr_dcsr_ena and wr_csr_nxt(28);
  fullreset_nxt(0) <= wr_csr_nxt(28);
  fullreset_dfflr: component sirv_gnrl_dfflr generic map(1)
                                                port map(fullreset_ena, fullreset_nxt, fullreset_r, clk, rst_n);

  -- This bit is not used as rocket impelmentation
  --
  -- The cause field
  dcause_ena <= cmt_dcause_ena;
  dcause_nxt <= cmt_dcause;
  dcause_dfflr: component sirv_gnrl_dfflr generic map(3)
                                             port map(dcause_ena, dcause_nxt, dcause_r, clk, rst_n);

  -- The halt field
  halt_ena <= wr_dcsr_ena;
  halt_nxt(0) <= wr_csr_nxt(3);
  halt_dfflr: component sirv_gnrl_dfflr generic map(1)
                                           port map(halt_ena, halt_nxt, halt_r, clk, rst_n);

  -- The step field
  step_ena <= wr_dcsr_ena;
  step_nxt(0) <= wr_csr_nxt(2);
  step_dfflr: component sirv_gnrl_dfflr generic map(1)
                                           port map(step_ena, step_nxt, step_r, clk, rst_n);

  -- The ebreakm field
  ebreakm_ena <= wr_dcsr_ena;
  ebreakm_nxt(0) <= wr_csr_nxt(15);
  ebreakm_dfflr: component sirv_gnrl_dfflr generic map(1)
                                              port map(ebreakm_ena, ebreakm_nxt, ebreakm_r, clk, rst_n);

  -- The stopcycle field
  -- stopcycle_ena <= wr_dcsr_ena;
  -- stopcycle_nxt <= wr_csr_nxt(10);
  -- stopcycle_dfflr: component sirv_gnrl_dfflr generic map(1)
  --                                               port map(stopcycle_ena, stopcycle_nxt, stopcycle_r, clk, rst_n);

  -- The stoptime field
  -- stoptime_ena <= wr_dcsr_ena;
  -- stoptime_nxt <= wr_csr_nxt(9);
  -- stoptime_dfflr: component sirv_gnrl_dfflr generic map(1)
  --                                              port map(stoptime_ena, stoptime_nxt, stoptime_r, clk, rst_n);

  dbg_stopcycle         <= '1'; 

  dcsr_r (31 downto 30) <= "11";
  dcsr_r (29 downto 16) <= 14b"0";
  dcsr_r (15 downto 12) <= (15 downto 12 => ebreakm_r(0));  -- we replicated the ebreakm for all ebreakh/s/u
  dcsr_r (11)           <= '0';
  dcsr_r (10)           <= dbg_stopcycle; -- Not writeable this bit is constant
  dcsr_r (9)            <= '0';           -- stoptime_r; Not use this bit same as rocket implmementation
  dcsr_r (8 downto 6)   <= dcause_r; 
  dcsr_r (5)            <= dbg_irq_r; 
  dcsr_r (4)            <= '0';
  dcsr_r (3)            <= halt_r(0);
  dcsr_r (2)            <= step_r(0);
  dcsr_r (1 downto 0)   <= "11";

  dbg_mode              <= not (dcause_r ?= "000");


  dbg_halt_r            <= halt_r(0);
  dbg_step_r            <= step_r(0);
  dbg_ebreakm_r         <= ebreakm_r(0);

end impl;