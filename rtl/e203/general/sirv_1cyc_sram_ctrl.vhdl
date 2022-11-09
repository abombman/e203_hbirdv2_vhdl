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
--  The 1cyc_sram_ctrl module control the 1 Cycle SRAM access requests
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_1cyc_sram_ctrl is 
  generic( DW:           integer := 32;
           MW:           integer := 4; 
           AW:           integer := 32;
           AW_LSB:       integer := 3; 
           USR_W:        integer := 3         
  );
  port ( sram_ctrl_active: out  std_logic;
  	     
  	     -- The cgstop is coming from CSR (0xBFE mcgstop)'s filed 1
         --   This register is our self-defined CSR register to disable the 
         --   ITCM SRAM clock gating for debugging purpose
  	     tcm_cgstop:        in  std_logic;

  	     -- * Cmd channel
         uop_cmd_valid:     in  std_logic; -- Handshake valid
         uop_cmd_ready:    out  std_logic; -- Handshake ready
         uop_cmd_read:      in  std_logic; -- Read or write
         uop_cmd_addr:      in  std_logic_vector(AW-1 downto 0);
         uop_cmd_wdata:     in  std_logic_vector(DW-1 downto 0);
         uop_cmd_wmask:     in  std_logic_vector(MW-1 downto 0);
         uop_cmd_usr:       in  std_logic_vector(USR_W-1 downto 0);

         -- * RSP channel
         uop_rsp_valid:    out  std_logic; -- Response valid
         uop_rsp_ready:     in  std_logic; -- Response ready
         uop_rsp_rdata:    out  std_logic_vector(DW-1 downto 0);
         uop_rsp_usr:      out  std_logic_vector(USR_W-1 downto 0);
 
         ram_cs:           out  std_logic;
         ram_we:           out  std_logic;
         ram_addr:         out  std_logic_vector(AW-AW_LSB-1 downto 0);
         ram_wem:          out  std_logic_vector(MW-1 downto 0);  
         ram_din:          out  std_logic_vector(DW-1 downto 0);
         ram_dout:          in  std_logic_vector(DW-1 downto 0);
         clk_ram:          out  std_logic;
         test_mode:         in  std_logic;
         clk:               in  std_logic;
         rst_n:             in  std_logic        
  );
end sirv_1cyc_sram_ctrl;

architecture impl of sirv_1cyc_sram_ctrl is 
  component sirv_gnrl_pipe_stage 
    generic( CUT_READY: integer;
             DP:        integer;
             DW:        integer
    );
    port( clk:  in std_logic;
    	  rst_n:  in std_logic;

    	  i_vld:  in std_logic;                          ----------
        i_rdy: out std_logic;                          -- upsteam
        i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
        o_vld: out std_logic;                          ------------
        o_rdy:  in std_logic;                          -- downsteam
        o_dat: out std_logic_vector( DW-1 downto 0 )   ------------
    );
  end component;
  component e203_clkgate is 
  port(
        clk_in:    in std_logic;
        test_mode: in std_logic;
        clock_en:  in std_logic;
        clk_out:  out std_logic 
  );
  end component;

  signal ram_clk_en: std_logic;
begin
  u_e1_stage: component sirv_gnrl_pipe_stage generic map ( CUT_READY => 0,
                                                           DP        => 1,
                                                           DW        => USR_W
                                                         )
                                                port map (i_vld      => uop_cmd_valid, 
                                                          i_rdy      => uop_cmd_ready, 
                                                          i_dat      => uop_cmd_usr,
                                                          o_vld      => uop_rsp_valid, 
                                                          o_rdy      => uop_rsp_ready, 
                                                          o_dat      => uop_rsp_usr,     
                                                          clk        => clk,
                                                          rst_n      => rst_n
                                                         );
  ram_cs  <= uop_cmd_valid and uop_cmd_ready; 
  ram_we  <= (not uop_cmd_read);  
  ram_addr<= uop_cmd_addr(AW-1 downto AW_LSB);          
  ram_wem <= uop_cmd_wmask(MW-1 downto 0);          
  ram_din <= uop_cmd_wdata(DW-1 downto 0);

  ram_clk_en <= ram_cs or tcm_cgstop;

  u_ram_clkgate: component e203_clkgate port map ( clk_in   => clk,
                                                   test_mode=> test_mode,
                                                   clock_en => ram_clk_en,
                                                   clk_out  => clk_ram
  	                                             );
  uop_rsp_rdata <= ram_dout;
  sram_ctrl_active <= uop_cmd_valid or uop_rsp_valid;
end impl;