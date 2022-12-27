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
--   The dtcm_ctrl module control the DTCM access requests
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_DTCM = "TRUE" then
entity e203_dtcm_ctrl is 
  port(
       dtcm_active:      out std_logic;
       -- The cgstop is coming from CSR (0xBFE mcgstop)'s filed 1
       -- This register is our self-defined CSR register to disable the 
       -- DTCM SRAM clock gating for debugging purpose
       tcm_cgstop:        in std_logic;
       -- Note: the DTCM ICB interface only support the single-transaction
       
       -- LSU ICB to DTCM
       --    * Bus cmd channel
       lsu2dtcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
       lsu2dtcm_icb_cmd_ready: out std_logic;  -- Handshake ready
       -- Note: The data on rdata or wdata channel must be naturally
       --       aligned, this is in line with the AXI definition
       lsu2dtcm_icb_cmd_addr:   in std_logic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr 
       lsu2dtcm_icb_cmd_read:   in std_logic;  -- Read or write
       lsu2dtcm_icb_cmd_wdata:  in std_logic_vector(32-1 downto 0);         
       lsu2dtcm_icb_cmd_wmask:  in std_logic_vector(4-1 downto 0);        
     
       -- * Bus RSP channel
       lsu2dtcm_icb_rsp_valid: out std_logic;   -- Response valid 
       lsu2dtcm_icb_rsp_ready:  in std_logic;   -- Response ready
       lsu2dtcm_icb_rsp_err  : out std_logic;   -- Response error
       -- Note: the RSP rdata is inline with AXI definition
       lsu2dtcm_icb_rsp_rdata: out std_logic_vector(32-1 downto 0);        

      `if E203_HAS_DTCM_EXTITF = "TRUE" then
       -- External-agent ICB to DTCM
       --    * Bus cmd channel
       ext2dtcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
       ext2dtcm_icb_cmd_ready: out std_logic;  -- Handshake ready
       -- Note: The data on rdata or wdata channel must be naturally
       --       aligned, this is in line with the AXI definition
       ext2dtcm_icb_cmd_addr:   in std_logic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr 
       ext2dtcm_icb_cmd_read:   in std_logic;  -- Read or write
       ext2dtcm_icb_cmd_wdata:  in std_logic_vector(32-1 downto 0);         
       ext2dtcm_icb_cmd_wmask:  in std_logic_vector(4-1 downto 0);        
     
       -- * Bus RSP channel
       ext2dtcm_icb_rsp_valid: out std_logic;   -- Response valid 
       ext2dtcm_icb_rsp_ready:  in std_logic;   -- Response ready
       ext2dtcm_icb_rsp_err  : out std_logic;   -- Response error
       -- Note: the RSP rdata is inline with AXI definition
       ext2dtcm_icb_rsp_rdata: out std_logic_vector(32-1 downto 0);
      `end if
     
       dtcm_ram_cs:            out std_logic; 
       dtcm_ram_we:            out std_logic;
       dtcm_ram_addr:          out std_logic_vector(E203_DTCM_RAM_AW-1 downto 0); 
       dtcm_ram_wem:           out std_logic_vector(E203_DTCM_RAM_MW-1 downto 0); 
       dtcm_ram_din:           out std_logic_vector(E203_DTCM_RAM_DW-1 downto 0); 
       dtcm_ram_dout:           in std_logic_vector(E203_DTCM_RAM_DW-1 downto 0);     
       clk_dtcm_ram:           out std_logic;
       
       test_mode:               in std_logic;
       clk:                     in std_logic;
       rst_n:                   in std_logic
       );
end e203_dtcm_ctrl;

architecture impl of e203_dtcm_ctrl is 
  signal arbt_icb_cmd_valid: std_ulogic;
  signal arbt_icb_cmd_ready: std_ulogic;
  signal arbt_icb_cmd_addr:  std_ulogic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0);
  signal arbt_icb_cmd_read:  std_ulogic;
  signal arbt_icb_cmd_wdata: std_ulogic_vector(E203_DTCM_DATA_WIDTH-1 downto 0);
  signal arbt_icb_cmd_wmask: std_ulogic_vector(E203_DTCM_WMSK_WIDTH-1 downto 0);

  signal arbt_icb_rsp_valid: std_ulogic;
  signal arbt_icb_rsp_ready: std_ulogic;
  signal arbt_icb_rsp_err:   std_ulogic;
  signal arbt_icb_rsp_rdata: std_ulogic_vector(E203_DTCM_DATA_WIDTH-1 downto 0);

 `if E203_HAS_DTCM_EXTITF = "TRUE" then
  constant DTCM_ARBT_I_NUM:   integer:= 2;
  constant DTCM_ARBT_I_PTR_W: integer:= 1;
 `else 
  constant DTCM_ARBT_I_NUM:   integer:= 1;
  constant DTCM_ARBT_I_PTR_W: integer:= 1;
 `end if

  signal arbt_bus_icb_cmd_valid: std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_ready: std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_addr : std_ulogic_vector(DTCM_ARBT_I_NUM*E203_DTCM_ADDR_WIDTH-1 downto 0);
  signal arbt_bus_icb_cmd_read : std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_wdata: std_ulogic_vector(DTCM_ARBT_I_NUM*E203_DTCM_DATA_WIDTH-1 downto 0);
  signal arbt_bus_icb_cmd_wmask: std_ulogic_vector(DTCM_ARBT_I_NUM*E203_DTCM_WMSK_WIDTH-1 downto 0);

  signal arbt_bus_icb_rsp_valid: std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_ready: std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_err  : std_ulogic_vector(DTCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_rdata: std_ulogic_vector(DTCM_ARBT_I_NUM*E203_DTCM_DATA_WIDTH-1 downto 0);

  signal sram_icb_cmd_ready: std_ulogic;
  signal sram_icb_cmd_valid: std_ulogic;
  signal sram_icb_cmd_addr:  std_ulogic_vector(E203_DTCM_ADDR_WIDTH-1 downto 0);
  signal sram_icb_cmd_read:  std_ulogic;
  signal sram_icb_cmd_wdata: std_ulogic_vector(E203_DTCM_DATA_WIDTH-1 downto 0);
  signal sram_icb_cmd_wmask: std_ulogic_vector(E203_DTCM_WMSK_WIDTH-1 downto 0);

  signal sram_icb_rsp_valid: std_ulogic;
  signal sram_icb_rsp_ready: std_ulogic;
  signal sram_icb_rsp_rdata: std_ulogic_vector(E203_DTCM_DATA_WIDTH-1 downto 0);
  signal sram_icb_rsp_err:   std_ulogic;

  signal dtcm_sram_ctrl_active: std_ulogic;

  signal sram_icb_rsp_read:     std_ulogic;
begin
  arbt_bus_icb_cmd_valid <=
  -- LSU take higher priority
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_valid,
                `end if
                       lsu2dtcm_icb_cmd_valid
                     );
   arbt_bus_icb_cmd_addr <=
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_addr,
                `end if
                       lsu2dtcm_icb_cmd_addr
                     );
   arbt_bus_icb_cmd_read <=
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_read,
                `end if
                       lsu2dtcm_icb_cmd_read
                     );
   arbt_bus_icb_cmd_wdata <=
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_wdata,
                `end if
                       lsu2dtcm_icb_cmd_wdata
                     );
   arbt_bus_icb_cmd_wmask <=
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_wmask,
                `end if
                       lsu2dtcm_icb_cmd_wmask
                     );
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_cmd_ready,
                `end if
                       lsu2dtcm_icb_cmd_ready
                     ) <= arbt_bus_icb_cmd_ready;


                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_rsp_valid,
                `end if
                       lsu2dtcm_icb_rsp_valid
                     ) <= arbt_bus_icb_rsp_valid;
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_rsp_err,
                `end if
                       lsu2dtcm_icb_rsp_err
                     ) <= arbt_bus_icb_rsp_err;
                     (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_rsp_rdata,
                `end if
                       lsu2dtcm_icb_rsp_rdata
                     ) <= arbt_bus_icb_rsp_rdata;
   arbt_bus_icb_rsp_ready <= (
                `if E203_HAS_DTCM_EXTITF = "TRUE" then
                       ext2dtcm_icb_rsp_ready,
                `end if
                       lsu2dtcm_icb_rsp_ready
                     );

  u_dtcm_icb_arbt: entity work.sirv_gnrl_icb_arbt generic map(
   ARBT_SCHEME     => 0, -- Priority based
   ALLOW_0CYCL_RSP => 0, -- Dont allow the 0 cycle response because for ITCM and DTCM, 
                         --   Dcache, .etc, definitely they cannot reponse as 0 cycle
   FIFO_OUTS_NUM   => E203_DTCM_OUTS_NUM,
   FIFO_CUT_READY  => 0,
   USR_W           => 1,
   ARBT_NUM        => DTCM_ARBT_I_NUM  ,
   ARBT_PTR_W      => DTCM_ARBT_I_PTR_W,
   AW              => E203_DTCM_ADDR_WIDTH,
   DW              => E203_DTCM_DATA_WIDTH 
  ) port map(
   o_icb_cmd_valid        => arbt_icb_cmd_valid,
   o_icb_cmd_ready        => arbt_icb_cmd_ready,
   o_icb_cmd_read(0)      => arbt_icb_cmd_read ,
   o_icb_cmd_addr         => arbt_icb_cmd_addr ,
   o_icb_cmd_wdata        => arbt_icb_cmd_wdata,
   o_icb_cmd_wmask        => arbt_icb_cmd_wmask,
   o_icb_cmd_burst        => OPEN,
   o_icb_cmd_beat         => OPEN,
   o_icb_cmd_lock         => OPEN,
   o_icb_cmd_excl         => OPEN,
   o_icb_cmd_size         => OPEN,
   o_icb_cmd_usr          => OPEN,
                                
   o_icb_rsp_valid        => arbt_icb_rsp_valid,
   o_icb_rsp_ready        => arbt_icb_rsp_ready,
   o_icb_rsp_err          => arbt_icb_rsp_err  ,
   o_icb_rsp_rdata        => arbt_icb_rsp_rdata,
   o_icb_rsp_usr(0)       => '0',
   o_icb_rsp_excl_ok      => '0',
                               
   i_bus_icb_cmd_ready    => arbt_bus_icb_cmd_ready,
   i_bus_icb_cmd_valid    => arbt_bus_icb_cmd_valid,
   i_bus_icb_cmd_read     => arbt_bus_icb_cmd_read ,
   i_bus_icb_cmd_addr     => arbt_bus_icb_cmd_addr ,
   i_bus_icb_cmd_wdata    => arbt_bus_icb_cmd_wdata,
   i_bus_icb_cmd_wmask    => arbt_bus_icb_cmd_wmask,
   i_bus_icb_cmd_burst    => (2*DTCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_beat     => (2*DTCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_lock     => (1*DTCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_excl     => (1*DTCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_size     => (2*DTCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_usr      => (1*DTCM_ARBT_I_NUM-1 downto 0 => '0'),

                               
   i_bus_icb_rsp_valid    => arbt_bus_icb_rsp_valid,
   i_bus_icb_rsp_ready    => arbt_bus_icb_rsp_ready,
   i_bus_icb_rsp_err      => arbt_bus_icb_rsp_err  ,
   i_bus_icb_rsp_rdata    => arbt_bus_icb_rsp_rdata,
   i_bus_icb_rsp_usr      => OPEN,
   i_bus_icb_rsp_excl_ok  => OPEN,
                             
   clk                    => clk,
   rst_n                  => rst_n
  );

  arbt_icb_cmd_ready <= sram_icb_cmd_ready;

  sram_icb_cmd_valid <= arbt_icb_cmd_valid;
  sram_icb_cmd_addr  <= arbt_icb_cmd_addr;
  sram_icb_cmd_read  <= arbt_icb_cmd_read;
  sram_icb_cmd_wdata <= arbt_icb_cmd_wdata;
  sram_icb_cmd_wmask <= arbt_icb_cmd_wmask;

 `if E203_HAS_ECC = "FALSE" then
  u_sram_icb_ctrl: entity work.sirv_sram_icb_ctrl generic map(
      DW     => E203_DTCM_DATA_WIDTH,
      AW     => E203_DTCM_ADDR_WIDTH,
      MW     => E203_DTCM_WMSK_WIDTH,
      AW_LSB => 2, -- DTCM is 32bits wide, so the LSB is 2
      USR_W  => 1 
  ) 
  port map(
     sram_ctrl_active => dtcm_sram_ctrl_active,
     tcm_cgstop       => tcm_cgstop,
     
     i_icb_cmd_valid => sram_icb_cmd_valid,
     i_icb_cmd_ready => sram_icb_cmd_ready,
     i_icb_cmd_read  => sram_icb_cmd_read ,
     i_icb_cmd_addr  => sram_icb_cmd_addr , 
     i_icb_cmd_wdata => sram_icb_cmd_wdata, 
     i_icb_cmd_wmask => sram_icb_cmd_wmask, 
     i_icb_cmd_usr(0)=> sram_icb_cmd_read ,
  
     i_icb_rsp_valid => sram_icb_rsp_valid,
     i_icb_rsp_ready => sram_icb_rsp_ready,
     i_icb_rsp_rdata => sram_icb_rsp_rdata,
     i_icb_rsp_usr(0)=> sram_icb_rsp_read ,
  
     ram_cs   => dtcm_ram_cs  ,  
     ram_we   => dtcm_ram_we  ,  
     ram_addr => dtcm_ram_addr, 
     ram_wem  => dtcm_ram_wem ,
     ram_din  => dtcm_ram_din ,          
     ram_dout => dtcm_ram_dout,
     clk_ram  => clk_dtcm_ram ,
  
     test_mode => test_mode   ,
     clk      => clk  ,
     rst_n    => rst_n  
    );

  sram_icb_rsp_err <= '0';
 `end if

  sram_icb_rsp_ready <= arbt_icb_rsp_ready;

  arbt_icb_rsp_valid <= sram_icb_rsp_valid;
  arbt_icb_rsp_err   <= sram_icb_rsp_err;
  arbt_icb_rsp_rdata <= sram_icb_rsp_rdata;


  dtcm_active <= lsu2dtcm_icb_cmd_valid or dtcm_sram_ctrl_active
       `if E203_HAS_DTCM_EXTITF = "TRUE" then
                     or ext2dtcm_icb_cmd_valid
       `end if
          ;
end impl;
`end if