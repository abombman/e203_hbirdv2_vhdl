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
--  The Clock Ctrl module to implement Clock control
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;

entity e203_clk_ctrl is 
  port(
        clk:       in std_logic;  -- clock
        rst_n:     in std_logic;  -- async reset
        test_mode: in std_logic;  -- test mode
        
        -- The cgstop is coming from CSR (0xBFE mcgstop)'s filed 0
        -- This register is our self-defined CSR register to disable the 
        -- clock gate automatically for CPU logics for debugging purpose
        core_cgstop:  in std_logic;

        -- The Top always on clk and rst
        clk_aon:     out std_logic;

        core_ifu_active:  in std_logic;
        core_exu_active:  in std_logic;
        core_lsu_active:  in std_logic;
        core_biu_active:  in std_logic; 
        
        `if E203_HAS_ITCM = "TRUE" then 
        itcm_active:      in std_logic;
        itcm_ls:         out std_logic;
        `end if
        `if E203_HAS_DTCM = "TRUE" then 
        dtcm_active:      in std_logic;
        dtcm_ls:         out std_logic;
        `end if

        -- The core's clk and rst
        clk_core_ifu:    out std_logic;
        clk_core_exu:    out std_logic;
        clk_core_lsu:    out std_logic;
        clk_core_biu:    out std_logic;

        -- The ITCM/DTCM clk and rst
        `if E203_HAS_ITCM = "TRUE" then 
        clk_itcm:        out std_logic;
        `end if
        `if E203_HAS_DTCM = "TRUE" then 
        clk_dtcm:        out std_logic;
        `end if
        
        core_wfi:         in std_logic
  );
end e203_clk_ctrl;

architecture impl of e203_clk_ctrl is 
  signal ifu_clk_en: std_logic;
  signal exu_clk_en: std_logic;
  signal lsu_clk_en: std_logic;
  signal biu_clk_en: std_logic;

  `if E203_HAS_ITCM = "TRUE" then 
    signal itcm_active_r: std_logic;
    signal itcm_clk_en:   std_logic;
  `end if

  `if E203_HAS_DTCM = "TRUE" then 
    signal dtcm_active_r: std_logic;
    signal dtcm_clk_en:   std_logic; 
  `end if
  
  `if E203_HAS_ITCM = "TRUE" or E203_HAS_DTCM = "TRUE" then
  component sirv_gnrl_dffr is
    generic( DW: integer := 32 );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
  `end if 

  component e203_clkgate is 
    port(
          clk_in:    in std_logic;
          test_mode: in std_logic;
          clock_en:  in std_logic;
          clk_out:  out std_logic 
    );
  end component;
begin
  -- The CSR control bit CGSTOP will override the automatical clock gating here for special debug purpose
  
  -- The IFU is always actively fetching unless it is WFI to override it
  ifu_clk_en <= core_cgstop or (core_ifu_active and (not core_wfi));

  -- The EXU, LSU and BIU module's clock gating does not need to check
  --  WFI because it may have request from external agent
  --  and also, it actually will automactically become inactive regardess
  --  currently is WFI or not, hence we dont need WFI here
  exu_clk_en <= core_cgstop or (core_exu_active);
  lsu_clk_en <= core_cgstop or (core_lsu_active);
  biu_clk_en <= core_cgstop or (core_biu_active);

  u_ifu_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                   test_mode => test_mode   ,
                                                   clock_en  => ifu_clk_en  ,
                                                   clk_out   => clk_core_ifu
  	                                             );
  u_exu_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                   test_mode => test_mode   ,
                                                   clock_en  => exu_clk_en  ,
                                                   clk_out   => clk_core_exu
  	                                             );
  u_lsu_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                   test_mode => test_mode   ,
                                                   clock_en  => lsu_clk_en  ,
                                                   clk_out   => clk_core_lsu
  	                                             );
  u_biu_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                   test_mode => test_mode   ,
                                                   clock_en  => biu_clk_en  ,
                                                   clk_out   => clk_core_biu
  	                                             );

  -- The ITCM and DTCM Ctrl module's clock gating does not need to check
  --  WFI because it may have request from external agent
  --  and also, it actually will automactically become inactive regardess
  --  currently is WFI or not, hence we dont need WFI here
  `if E203_HAS_ITCM = "TRUE" then 
  itcm_active_dffr: component sirv_gnrl_dffr generic map (1)
                                                port map (dnxt(0) => itcm_active,
                                                          qout(0) => itcm_active_r,
                                                          clk     => clk,
                                                          rst_n   => rst_n
                                                	       );
  itcm_clk_en <= core_cgstop or itcm_active or itcm_active_r;
  itcm_ls <= not itcm_clk_en;
  u_itcm_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                    test_mode => test_mode   ,
                                                    clock_en  => itcm_clk_en  ,
                                                    clk_out   => clk_itcm
                                                  );
  `end if
  
  `if E203_HAS_DTCM = "TRUE" then 
  dtcm_active_dffr: component sirv_gnrl_dffr generic map (1)
                                                port map (dnxt(0) => dtcm_active,
                                                          qout(0) => dtcm_active_r,
                                                          clk     => clk,
                                                          rst_n   => rst_n
                                                	       );
  dtcm_clk_en <= core_cgstop or dtcm_active or dtcm_active_r;
  dtcm_ls <= not dtcm_clk_en;
  u_dtcm_clkgate: component e203_clkgate port map ( clk_in    => clk         ,
                                                    test_mode => test_mode   ,
                                                    clock_en  => dtcm_clk_en  ,
                                                    clk_out   => clk_dtcm
                                                  );
  `end if

  -- The Top always on clk and rst
  clk_aon <= clk;

end impl;