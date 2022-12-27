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
--   The itcm_ctrl module control the ITCM access requests
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_ITCM = "TRUE" then
entity e203_itcm_ctrl is 
  port(
       itcm_active:      out std_logic;
       -- The cgstop is coming from CSR (0xBFE mcgstop)'s filed 1
       -- This register is our self-defined CSR register to disable the 
       -- DTCM SRAM clock gating for debugging purpose
       tcm_cgstop:        in std_logic;
       -- Note: the DTCM ICB interface only support the single-transaction
       
       -- IFU ICB to DTCM
       --    * Bus cmd channel
       ifu2itcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
       ifu2itcm_icb_cmd_ready: out std_logic;  -- Handshake ready
       -- Note: The data on rdata or wdata channel must be naturally
       --       aligned, this is in line with the AXI definition
       ifu2itcm_icb_cmd_addr:   in std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr 
       ifu2itcm_icb_cmd_read:   in std_logic;  -- Read or write
       ifu2itcm_icb_cmd_wdata:  in std_logic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);         
       ifu2itcm_icb_cmd_wmask:  in std_logic_vector(E203_ITCM_WMSK_WIDTH-1 downto 0);        
     
       -- * Bus RSP channel
       ifu2itcm_icb_rsp_valid: out std_logic;   -- Response valid 
       ifu2itcm_icb_rsp_ready:  in std_logic;   -- Response ready
       ifu2itcm_icb_rsp_err  : out std_logic;   -- Response error
       -- Note: the RSP rdata is inline with AXI definition
       ifu2itcm_icb_rsp_rdata: out std_logic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);        
       ifu2itcm_holdup  :      out std_logic;
       
       -- LSU ICB to DTCM
       --    * Bus cmd channel
       lsu2itcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
       lsu2itcm_icb_cmd_ready: out std_logic;  -- Handshake ready
       -- Note: The data on rdata or wdata channel must be naturally
       --       aligned, this is in line with the AXI definition
       lsu2itcm_icb_cmd_addr:   in std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr 
       lsu2itcm_icb_cmd_read:   in std_logic;  -- Read or write
       lsu2itcm_icb_cmd_wdata:  in std_logic_vector(32-1 downto 0);         
       lsu2itcm_icb_cmd_wmask:  in std_logic_vector(4-1 downto 0);        
     
       -- * Bus RSP channel
       lsu2itcm_icb_rsp_valid: out std_logic;   -- Response valid 
       lsu2itcm_icb_rsp_ready:  in std_logic;   -- Response ready
       lsu2itcm_icb_rsp_err  : out std_logic;   -- Response error
       -- Note: the RSP rdata is inline with AXI definition
       lsu2itcm_icb_rsp_rdata: out std_logic_vector(32-1 downto 0);

      `if E203_HAS_ITCM_EXTITF = "TRUE" then
       -- External-agent ICB to DTCM
       --    * Bus cmd channel
       ext2itcm_icb_cmd_valid:  in std_logic;  -- Handshake valid
       ext2itcm_icb_cmd_ready: out std_logic;  -- Handshake ready
       -- Note: The data on rdata or wdata channel must be naturally
       --       aligned, this is in line with the AXI definition
       ext2itcm_icb_cmd_addr:   in std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0); -- Bus transaction start addr 
       ext2itcm_icb_cmd_read:   in std_logic;  -- Read or write
       ext2itcm_icb_cmd_wdata:  in std_logic_vector(32-1 downto 0);         
       ext2itcm_icb_cmd_wmask:  in std_logic_vector(4-1 downto 0);        
     
       -- * Bus RSP channel
       ext2itcm_icb_rsp_valid: out std_logic;   -- Response valid 
       ext2itcm_icb_rsp_ready:  in std_logic;   -- Response ready
       ext2itcm_icb_rsp_err  : out std_logic;   -- Response error
       -- Note: the RSP rdata is inline with AXI definition
       ext2itcm_icb_rsp_rdata: out std_logic_vector(32-1 downto 0);
      `end if
     
       itcm_ram_cs:            out std_logic; 
       itcm_ram_we:            out std_logic;
       itcm_ram_addr:          out std_logic_vector(E203_ITCM_RAM_AW-1 downto 0); 
       itcm_ram_wem:           out std_logic_vector(E203_ITCM_RAM_MW-1 downto 0); 
       itcm_ram_din:           out std_logic_vector(E203_ITCM_RAM_DW-1 downto 0); 
       itcm_ram_dout:           in std_logic_vector(E203_ITCM_RAM_DW-1 downto 0);     
       clk_itcm_ram:           out std_logic;
       
       test_mode:               in std_logic;
       clk:                     in std_logic;
       rst_n:                   in std_logic
       );
end e203_itcm_ctrl;

architecture impl of e203_itcm_ctrl is 
  signal lsu_icb_cmd_valid: std_ulogic;
  signal lsu_icb_cmd_ready: std_ulogic;
  signal lsu_icb_cmd_addr:  std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
  signal lsu_icb_cmd_read:  std_ulogic;
  signal lsu_icb_cmd_wdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
  signal lsu_icb_cmd_wmask: std_ulogic_vector(E203_ITCM_DATA_WIDTH/8-1 downto 0);

  signal lsu_icb_rsp_valid: std_ulogic;
  signal lsu_icb_rsp_ready: std_ulogic;
  signal lsu_icb_rsp_err:   std_ulogic;
  signal lsu_icb_rsp_rdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);

 `if E203_HAS_ITCM_EXTITF = "TRUE" then
  -- EXTITF converted to ICM data width
  --    * Bus cmd channel
  signal ext_icb_cmd_valid: std_ulogic;
  signal ext_icb_cmd_ready: std_ulogic;
  signal ext_icb_cmd_addr:  std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
  signal ext_icb_cmd_read:  std_ulogic;
  signal ext_icb_cmd_wdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
  signal ext_icb_cmd_wmask: std_ulogic_vector(E203_ITCM_WMSK_WIDTH-1 downto 0);
  
  --    * Bus RSP channel
  signal ext_icb_rsp_valid: std_ulogic;
  signal ext_icb_rsp_ready: std_ulogic;
  signal ext_icb_rsp_err:   std_ulogic;
  signal ext_icb_rsp_rdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
 `end if

  signal arbt_icb_cmd_valid: std_ulogic;
  signal arbt_icb_cmd_ready: std_ulogic;
  signal arbt_icb_cmd_addr:  std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
  signal arbt_icb_cmd_read:  std_ulogic;
  signal arbt_icb_cmd_wdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
  signal arbt_icb_cmd_wmask: std_ulogic_vector(E203_ITCM_WMSK_WIDTH-1 downto 0);

  signal arbt_icb_rsp_valid: std_ulogic;
  signal arbt_icb_rsp_ready: std_ulogic;
  signal arbt_icb_rsp_err:   std_ulogic;
  signal arbt_icb_rsp_rdata: std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);

 `if E203_HAS_ITCM_EXTITF = "TRUE" then
  constant ITCM_ARBT_I_NUM:   integer:= 2;
  constant ITCM_ARBT_I_PTR_W: integer:= 1;
 `else 
  constant ITCM_ARBT_I_NUM:   integer:= 1;
  constant ITCM_ARBT_I_PTR_W: integer:= 1;
 `end if

  signal arbt_bus_icb_cmd_valid: std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_ready: std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_addr : std_ulogic_vector(ITCM_ARBT_I_NUM*E203_ITCM_ADDR_WIDTH-1 downto 0);
  signal arbt_bus_icb_cmd_read : std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_cmd_wdata: std_ulogic_vector(ITCM_ARBT_I_NUM*E203_ITCM_DATA_WIDTH-1 downto 0);
  signal arbt_bus_icb_cmd_wmask: std_ulogic_vector(ITCM_ARBT_I_NUM*E203_ITCM_WMSK_WIDTH-1 downto 0);

  signal arbt_bus_icb_rsp_valid: std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_ready: std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_err  : std_ulogic_vector(ITCM_ARBT_I_NUM*1-1 downto 0);
  signal arbt_bus_icb_rsp_rdata: std_ulogic_vector(ITCM_ARBT_I_NUM*E203_ITCM_DATA_WIDTH-1 downto 0);

  signal sram_ready2ifu:         std_ulogic;
  signal sram_ready2arbt:        std_ulogic;

  signal sram_sel_ifu:           std_ulogic;
  signal sram_sel_arbt:          std_ulogic;

  signal sram_icb_cmd_ready:     std_ulogic;
  signal sram_icb_cmd_valid:     std_ulogic;
  signal sram_icb_cmd_addr:      std_ulogic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);
  signal sram_icb_cmd_read:      std_ulogic;
  signal sram_icb_cmd_wdata:     std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
  signal sram_icb_cmd_wmask:     std_ulogic_vector(E203_ITCM_WMSK_WIDTH-1 downto 0);

  signal sram_icb_cmd_ifu:       std_ulogic;
  signal sram_icb_rsp_usr:       std_ulogic_vector(1 downto 0);
  signal sram_icb_cmd_usr:       std_ulogic_vector(1 downto 0);
  signal sram_icb_rsp_ifu:       std_ulogic;
  signal sram_icb_rsp_read:      std_ulogic;

  signal itcm_sram_ctrl_active:  std_ulogic;

  signal sram_icb_rsp_valid:     std_ulogic;
  signal sram_icb_rsp_ready:     std_ulogic;
  signal sram_icb_rsp_rdata:     std_ulogic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);
  signal sram_icb_rsp_err:       std_ulogic;
    
  signal ifu_holdup_r:           std_ulogic;
  signal ifu_holdup_set:         std_ulogic;
  signal ifu_holdup_clr:         std_ulogic;
  signal ifu_holdup_ena:         std_ulogic;
  signal ifu_holdup_nxt:         std_ulogic;
  
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
  u_itcm_icb_lsu2itcm_n2wz: entity work.sirv_gnrl_icb_n2w generic map(
   FIFO_OUTS_NUM  => E203_ITCM_OUTS_NUM,
   FIFO_CUT_READY => 0,
   USR_W          => 1,
   AW             => E203_ITCM_ADDR_WIDTH,
   X_W            => 32,
   Y_W            => E203_ITCM_DATA_WIDTH 
  )
  port map(
   i_icb_cmd_valid        => lsu2itcm_icb_cmd_valid,  
   i_icb_cmd_ready        => lsu2itcm_icb_cmd_ready,
   i_icb_cmd_read(0)      => lsu2itcm_icb_cmd_read ,
   i_icb_cmd_addr         => lsu2itcm_icb_cmd_addr ,
   i_icb_cmd_wdata        => lsu2itcm_icb_cmd_wdata,
   i_icb_cmd_wmask        => lsu2itcm_icb_cmd_wmask,
   i_icb_cmd_burst        => "00",
   i_icb_cmd_beat         => "00",
   i_icb_cmd_lock         => '0',
   i_icb_cmd_excl         => '0',
   i_icb_cmd_size         => "00",
   i_icb_cmd_usr(0)       => '0',
   
   i_icb_rsp_valid        => lsu2itcm_icb_rsp_valid ,
   i_icb_rsp_ready        => lsu2itcm_icb_rsp_ready ,
   i_icb_rsp_err          => lsu2itcm_icb_rsp_err   ,
   i_icb_rsp_excl_ok      => OPEN,
   i_icb_rsp_rdata        => lsu2itcm_icb_rsp_rdata ,
   i_icb_rsp_usr          => OPEN,
                                                
   o_icb_cmd_valid        => lsu_icb_cmd_valid,  
   o_icb_cmd_ready        => lsu_icb_cmd_ready,
   o_icb_cmd_read(0)      => lsu_icb_cmd_read ,
   o_icb_cmd_addr         => lsu_icb_cmd_addr ,
   o_icb_cmd_wdata        => lsu_icb_cmd_wdata,
   o_icb_cmd_wmask        => lsu_icb_cmd_wmask,
   o_icb_cmd_burst        => OPEN,
   o_icb_cmd_beat         => OPEN,
   o_icb_cmd_lock         => OPEN,
   o_icb_cmd_excl         => OPEN,
   o_icb_cmd_size         => OPEN,
   o_icb_cmd_usr          => OPEN,
   
   o_icb_rsp_valid        => lsu_icb_rsp_valid,
   o_icb_rsp_ready        => lsu_icb_rsp_ready,
   o_icb_rsp_err          => lsu_icb_rsp_err  ,
   o_icb_rsp_excl_ok      => '0',
   o_icb_rsp_rdata        => lsu_icb_rsp_rdata,
   o_icb_rsp_usr(0)       => '0',

   clk                    => clk,
   rst_n                  => rst_n                
  );

  `if E203_HAS_ITCM_EXTITF = "TRUE" then

  `if E203_SYSMEM_DATA_WIDTH_IS_32 = "TRUE" then

  `if E203_ITCM_DATA_WIDTH_IS_64 = "TRUE" then
  u_itcm_icb_ext2itcm_n2w: entity work.sirv_gnrl_icb_n2w generic map(
   USR_W           => 1,
   FIFO_OUTS_NUM   => E203_ITCM_OUTS_NUM,
   FIFO_CUT_READY  => 0,
   AW              => E203_ITCM_ADDR_WIDTH,
   X_W             => E203_SYSMEM_DATA_WIDTH, 
   Y_W             => E203_ITCM_DATA_WIDTH 
  )
  port map(
   i_icb_cmd_valid        => ext2itcm_icb_cmd_valid,  
   i_icb_cmd_ready        => ext2itcm_icb_cmd_ready,
   i_icb_cmd_read(0)      => ext2itcm_icb_cmd_read ,
   i_icb_cmd_addr         => ext2itcm_icb_cmd_addr ,
   i_icb_cmd_wdata        => ext2itcm_icb_cmd_wdata,
   i_icb_cmd_wmask        => ext2itcm_icb_cmd_wmask,
   i_icb_cmd_burst        => "00",
   i_icb_cmd_beat         => "00",
   i_icb_cmd_lock         => '0',
   i_icb_cmd_excl         => '0',
   i_icb_cmd_size         => "00",
   i_icb_cmd_usr(0)       => '0',
   
   i_icb_rsp_valid        => ext2itcm_icb_rsp_valid,
   i_icb_rsp_ready        => ext2itcm_icb_rsp_ready,
   i_icb_rsp_err          => ext2itcm_icb_rsp_err  ,
   i_icb_rsp_excl_ok      => OPEN,
   i_icb_rsp_rdata        => ext2itcm_icb_rsp_rdata,
   i_icb_rsp_usr          => OPEN,
                                                
   o_icb_cmd_valid        => ext_icb_cmd_valid,  
   o_icb_cmd_ready        => ext_icb_cmd_ready,
   o_icb_cmd_read(0)      => ext_icb_cmd_read ,
   o_icb_cmd_addr         => ext_icb_cmd_addr ,
   o_icb_cmd_wdata        => ext_icb_cmd_wdata,
   o_icb_cmd_wmask        => ext_icb_cmd_wmask,
   o_icb_cmd_burst        => OPEN,
   o_icb_cmd_beat         => OPEN,
   o_icb_cmd_lock         => OPEN,
   o_icb_cmd_excl         => OPEN,
   o_icb_cmd_size         => OPEN,
   o_icb_cmd_usr          => OPEN,
   
   o_icb_rsp_valid        => ext_icb_rsp_valid,
   o_icb_rsp_ready        => ext_icb_rsp_ready,
   o_icb_rsp_err          => ext_icb_rsp_err  ,
   o_icb_rsp_excl_ok      => '0',
   o_icb_rsp_rdata        => ext_icb_rsp_rdata,
   o_icb_rsp_usr(0)       => '0',

   clk                    => clk,
   rst_n                  => rst_n                
  );
  `end if
  `else
    `error "There must be something wrong, our System interface
            must be 32bits and ITCM must be 64bits to save area and powers!!!"
  `end if
  `end if

  arbt_bus_icb_cmd_valid <=
  -- LSU take higher priority
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_valid,
               `end if
                      lsu_icb_cmd_valid
                    );
  arbt_bus_icb_cmd_addr <=
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_addr,
               `end if
                      lsu_icb_cmd_addr
                    );
  arbt_bus_icb_cmd_read <=
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_read,
               `end if
                      lsu_icb_cmd_read
                    );
  arbt_bus_icb_cmd_wdata <=
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_wdata,
               `end if
                      lsu_icb_cmd_wdata
                    );
  arbt_bus_icb_cmd_wmask <=
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_wmask,
               `end if
                      lsu_icb_cmd_wmask
                    );
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_cmd_ready,
               `end if
                      lsu_icb_cmd_ready
                    ) <= arbt_bus_icb_cmd_ready;


                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_rsp_valid,
               `end if
                      lsu_icb_rsp_valid
                    ) <= arbt_bus_icb_rsp_valid;
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_rsp_err,
               `end if
                      lsu_icb_rsp_err
                    ) <= arbt_bus_icb_rsp_err;
                    (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_rsp_rdata,
               `end if
                      lsu_icb_rsp_rdata
                    ) <= arbt_bus_icb_rsp_rdata;
  arbt_bus_icb_rsp_ready <= (
               `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      ext_icb_rsp_ready,
               `end if
                      lsu_icb_rsp_ready
                    );

  u_itcm_icb_arbt: entity work.sirv_gnrl_icb_arbt generic map(
   ARBT_SCHEME     => 0, -- Priority based
   ALLOW_0CYCL_RSP => 0, -- Dont allow the 0 cycle response because for ITCM and DTCM, 
                         --   Dcache, .etc, definitely they cannot reponse as 0 cycle
   FIFO_OUTS_NUM   => E203_ITCM_OUTS_NUM,
   FIFO_CUT_READY  => 0,
   USR_W           => 1,
   ARBT_NUM        => ITCM_ARBT_I_NUM  ,
   ARBT_PTR_W      => ITCM_ARBT_I_PTR_W,
   AW              => E203_ITCM_ADDR_WIDTH,
   DW              => E203_ITCM_DATA_WIDTH 
  )
  port map(
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
   i_bus_icb_cmd_burst    => (2*ITCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_beat     => (2*ITCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_lock     => (1*ITCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_excl     => (1*ITCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_size     => (2*ITCM_ARBT_I_NUM-1 downto 0 => '0'),
   i_bus_icb_cmd_usr      => (1*ITCM_ARBT_I_NUM-1 downto 0 => '0'),

                                
   i_bus_icb_rsp_valid    => arbt_bus_icb_rsp_valid,
   i_bus_icb_rsp_ready    => arbt_bus_icb_rsp_ready,
   i_bus_icb_rsp_err      => arbt_bus_icb_rsp_err  ,
   i_bus_icb_rsp_rdata    => arbt_bus_icb_rsp_rdata,
   i_bus_icb_rsp_usr      => OPEN,
   i_bus_icb_rsp_excl_ok  => OPEN,
                             
   clk                    => clk,
   rst_n                  => rst_n
  );

  sram_ready2ifu <= '1'
              --The EXT and load/store have higher priotry than the ifetch
                 and (not arbt_icb_cmd_valid);

  sram_ready2arbt <= '1';


  sram_sel_ifu  <= sram_ready2ifu  and ifu2itcm_icb_cmd_valid;
  sram_sel_arbt <= sram_ready2arbt and arbt_icb_cmd_valid;

  ifu2itcm_icb_cmd_ready <= sram_ready2ifu and sram_icb_cmd_ready;
  arbt_icb_cmd_ready <= sram_ready2arbt  and sram_icb_cmd_ready;

  sram_icb_cmd_valid <= (sram_sel_ifu   and ifu2itcm_icb_cmd_valid)
                     or (sram_sel_arbt  and arbt_icb_cmd_valid);

  sram_icb_cmd_addr  <= ((E203_ITCM_ADDR_WIDTH-1 downto 0 => sram_sel_ifu ) and ifu2itcm_icb_cmd_addr)
                     or ((E203_ITCM_ADDR_WIDTH-1 downto 0 => sram_sel_arbt) and arbt_icb_cmd_addr);
  sram_icb_cmd_read  <= (sram_sel_ifu   and ifu2itcm_icb_cmd_read)
                     or (sram_sel_arbt  and arbt_icb_cmd_read);
  sram_icb_cmd_wdata <= ((E203_ITCM_DATA_WIDTH-1 downto 0 => sram_sel_ifu ) and ifu2itcm_icb_cmd_wdata)
                     or ((E203_ITCM_DATA_WIDTH-1 downto 0 => sram_sel_arbt) and arbt_icb_cmd_wdata);
  sram_icb_cmd_wmask <= ((E203_ITCM_WMSK_WIDTH-1 downto 0 => sram_sel_ifu ) and ifu2itcm_icb_cmd_wmask)
                     or ((E203_ITCM_WMSK_WIDTH-1 downto 0 => sram_sel_arbt) and arbt_icb_cmd_wmask);

                        
  sram_icb_cmd_ifu <= sram_sel_ifu;

  sram_icb_cmd_usr <= (sram_icb_cmd_ifu, sram_icb_cmd_read);
  
  (sram_icb_rsp_ifu, sram_icb_rsp_read) <= sram_icb_rsp_usr;
  
 `if E203_HAS_ECC = "FALSE" then
  u_sram_icb_ctrl: entity work.sirv_sram_icb_ctrl generic map(
    DW     => E203_ITCM_DATA_WIDTH,
    AW     => E203_ITCM_ADDR_WIDTH,
    MW     => E203_ITCM_WMSK_WIDTH,
    AW_LSB => 3, -- ITCM is 64bits wide, so the LSB is 3
    USR_W  => 2 
  )
  port map(
    sram_ctrl_active => itcm_sram_ctrl_active,
    tcm_cgstop       => tcm_cgstop,
    
    i_icb_cmd_valid => sram_icb_cmd_valid,
    i_icb_cmd_ready => sram_icb_cmd_ready,
    i_icb_cmd_read  => sram_icb_cmd_read ,
    i_icb_cmd_addr  => sram_icb_cmd_addr , 
    i_icb_cmd_wdata => sram_icb_cmd_wdata, 
    i_icb_cmd_wmask => sram_icb_cmd_wmask, 
    i_icb_cmd_usr   => sram_icb_cmd_usr  ,
  
    i_icb_rsp_valid => sram_icb_rsp_valid,
    i_icb_rsp_ready => sram_icb_rsp_ready,
    i_icb_rsp_rdata => sram_icb_rsp_rdata,
    i_icb_rsp_usr   => sram_icb_rsp_usr  ,
  
    ram_cs          => itcm_ram_cs  ,  
    ram_we          => itcm_ram_we  ,  
    ram_addr        => itcm_ram_addr, 
    ram_wem         => itcm_ram_wem ,
    ram_din         => itcm_ram_din ,          
    ram_dout        => itcm_ram_dout,
    clk_ram         => clk_itcm_ram ,
  
    test_mode       => test_mode,
    clk             => clk,
    rst_n           => rst_n 
  );

  sram_icb_rsp_err <= '0';
 `end if

  -- The E2 pass to IFU RSP channel only when it is IFU access 
  -- The E2 pass to ARBT RSP channel only when it is not IFU access
  sram_icb_rsp_ready <= ifu2itcm_icb_rsp_ready when sram_icb_rsp_ifu = '1' else 
                        arbt_icb_rsp_ready;

  ifu2itcm_icb_rsp_valid <= sram_icb_rsp_valid and sram_icb_rsp_ifu;
  ifu2itcm_icb_rsp_err   <= sram_icb_rsp_err;
  ifu2itcm_icb_rsp_rdata <= sram_icb_rsp_rdata;

  arbt_icb_rsp_valid <= sram_icb_rsp_valid and (not sram_icb_rsp_ifu);
  arbt_icb_rsp_err   <= sram_icb_rsp_err;
  arbt_icb_rsp_rdata <= sram_icb_rsp_rdata;

  -- The holdup indicating the target is not accessed by other agents 
  -- since last accessed by IFU, and the output of it is holding up
  -- last value. Hence,
  --   * The holdup flag it set when there is a succuess (no-error) ifetch
  --       accessed this target
  --   * The holdup flag it clear when when 
  --         ** other agent (non-IFU) accessed this target
  --         ** other agent (non-IFU) accessed this target
  -- for example:
  --    *** The external agent accessed the ITCM
  --    *** I$ updated by cache maintaineice operation
  
  -- The IFU holdup will be set after last time accessed by a IFU access
  ifu_holdup_set <=   sram_icb_cmd_ifu and itcm_ram_cs;
  -- The IFU holdup will be cleared after last time accessed by a non-IFU access
  ifu_holdup_clr <= (not sram_icb_cmd_ifu) and itcm_ram_cs;
  ifu_holdup_ena <= ifu_holdup_set or ifu_holdup_clr;
  ifu_holdup_nxt <= ifu_holdup_set and (not ifu_holdup_clr);
  ifu_holdup_dffl: component sirv_gnrl_dfflr generic map(1)
                                                port map( 
                                                         lden    => ifu_holdup_ena,
                                                         dnxt(0) => ifu_holdup_nxt,
                                                         qout(0) => ifu_holdup_r,
                                                         clk     => clk,
                                                         rst_n   => rst_n
                                                        );

  ifu2itcm_holdup <= ifu_holdup_r;

  itcm_active <= ifu2itcm_icb_cmd_valid or lsu2itcm_icb_cmd_valid or itcm_sram_ctrl_active
                  `if E203_HAS_ITCM_EXTITF = "TRUE" then
                      or ext2itcm_icb_cmd_valid
                  `end if
                      ;

end impl;
`end if