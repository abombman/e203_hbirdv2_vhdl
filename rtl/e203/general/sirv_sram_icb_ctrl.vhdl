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
--  The icb_ecc_ctrl module control the ICB access requests to SRAM
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_sram_icb_ctrl is 
  generic( DW:           integer := 32; -- Can only support 32 or 64bits, no others choice
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
         i_icb_cmd_valid:     in  std_logic; -- Handshake valid
         i_icb_cmd_ready:    out  std_logic; -- Handshake ready
         i_icb_cmd_read:      in  std_logic; -- Read or write
         i_icb_cmd_addr:      in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:     in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:     in  std_logic_vector(MW-1 downto 0);
         i_icb_cmd_usr:       in  std_logic_vector(USR_W-1 downto 0);

         -- * RSP channel
         i_icb_rsp_valid:    out  std_logic; -- Response valid
         i_icb_rsp_ready:     in  std_logic; -- Response ready
         i_icb_rsp_rdata:    out  std_logic_vector(DW-1 downto 0);
         i_icb_rsp_usr:      out  std_logic_vector(USR_W-1 downto 0);

         
         
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
end sirv_sram_icb_ctrl;

-- We need to use bypbuf to flop one stage for the i_cmd channel to cut 
--   down the back-pressure ready signal
architecture impl of sirv_sram_icb_ctrl is 
  signal byp_icb_cmd_valid: std_ulogic;
  signal byp_icb_cmd_ready: std_ulogic;
  signal byp_icb_cmd_read:  std_ulogic;
  signal byp_icb_cmd_addr:  std_ulogic_vector(AW-1 downto 0);
  signal byp_icb_cmd_wdata: std_ulogic_vector(DW-1 downto 0);
  signal byp_icb_cmd_wmask: std_ulogic_vector(MW-1 downto 0);
  signal byp_icb_cmd_usr:   std_ulogic_vector(USR_W-1 downto 0);

  constant BUF_CMD_PACK_W:  integer:= (AW+DW+MW+USR_W+1);
  signal byp_icb_cmd_o_pack:std_ulogic_vector(BUF_CMD_PACK_W-1 downto 0);
  signal byp_icb_cmd_i_pack:std_ulogic_vector(BUF_CMD_PACK_W-1 downto 0);
  signal sram_active:       std_ulogic;

  component sirv_gnrl_bypbuf is
    generic(
            DP: integer:= 8;
            DW: integer:= 32
    );
    port(                         
          i_vld:  in std_logic;
          i_rdy: out std_logic;
          i_dat:  in std_logic_vector( DW-1 downto 0 );

          o_vld: out std_logic;
          o_rdy:  in std_logic;
          o_dat: out std_logic_vector( DW-1 downto 0 );
          
          clk:    in std_logic;
          rst_n:  in std_logic 
    );
  end component;
  component sirv_1cyc_sram_ctrl is 
    generic( DW:           integer := 32;
             MW:           integer := 4; 
             AW:           integer := 32;
             AW_LSB:       integer := 3; 
             USR_W:        integer := 3         
    );
    port ( sram_ctrl_active: out  std_logic;
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
  end component;
begin
  byp_icb_cmd_i_pack<= (i_icb_cmd_read, i_icb_cmd_addr, i_icb_cmd_wdata, i_icb_cmd_wmask, i_icb_cmd_usr);
  (byp_icb_cmd_read, byp_icb_cmd_addr, byp_icb_cmd_wdata, byp_icb_cmd_wmask, byp_icb_cmd_usr)<= byp_icb_cmd_o_pack;

  -- We really use bypbuf here
  u_byp_icb_cmd_buf: component sirv_gnrl_bypbuf generic map( 1, BUF_CMD_PACK_W )
                                                   port map( i_vld      => i_icb_cmd_valid, 
                                                             i_rdy      => i_icb_cmd_ready, 
                                                             i_dat      => byp_icb_cmd_i_pack,
                                                             o_vld      => byp_icb_cmd_valid, 
                                                             o_rdy      => byp_icb_cmd_ready, 
                                                             o_dat      => byp_icb_cmd_o_pack,     
                                                             clk        => clk,
                                                             rst_n      => rst_n
                                                   	       );
  -- Instantiated the SRAM Ctrl
  u_sirv_1cyc_sram_ctrl: component sirv_1cyc_sram_ctrl generic map( DW    => DW,
                                                                    MW    => MW,
                                                                    AW    => AW,
                                                                    AW_LSB=> AW_LSB,
                                                                    USR_W => USR_W
  	                                                              )
                                                          port map( sram_ctrl_active=> sram_active,
                                                                    tcm_cgstop      => tcm_cgstop,
     
                                                                    uop_cmd_valid   => byp_icb_cmd_valid,
                                                                    uop_cmd_ready   => byp_icb_cmd_ready,
                                                                    uop_cmd_read    => byp_icb_cmd_read,
                                                                    uop_cmd_addr    => byp_icb_cmd_addr, 
                                                                    uop_cmd_wdata   => byp_icb_cmd_wdata, 
                                                                    uop_cmd_wmask   => byp_icb_cmd_wmask, 
                                                                    uop_cmd_usr     => byp_icb_cmd_usr,
    
                                                                    uop_rsp_valid   => i_icb_rsp_valid,
                                                                    uop_rsp_ready   => i_icb_rsp_ready,
                                                                    uop_rsp_rdata   => i_icb_rsp_rdata,
                                                                    uop_rsp_usr     => i_icb_rsp_usr,
 
                                                                    ram_cs          => ram_cs,  
                                                                    ram_we          => ram_we,  
                                                                    ram_addr        => ram_addr, 
                                                                    ram_wem         => ram_wem,
                                                                    ram_din         => ram_din,          
                                                                    ram_dout        => ram_dout,
                                                                    clk_ram         => clk_ram,
     
                                                                    test_mode       => test_mode,
                                                                    clk             => clk,
                                                                    rst_n           => rst_n  
                                                          	      );
  sram_ctrl_active<= i_icb_cmd_valid or byp_icb_cmd_valid or sram_active or i_icb_rsp_valid;
end impl;