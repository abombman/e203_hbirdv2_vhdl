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
--  module sirv_jtag_dtm
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------

--=====================================================================
--
-- Description:
--  The debug module
--
-- ====================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_debug_module is 
  generic( SUPPORT_JTAG_DTM: integer:= 1;
           ASYNC_FF_LEVELS : integer:= 2;
           PC_SIZE         : integer:= 32;
           HART_NUM        : integer:= 1;
           HART_ID_W       : integer:= 1
  );
  port( inspect_jtag_clk:           out std_logic;

        -- The interface with commit stage
        cmt_dpc:                     in std_logic_vector(PC_SIZE-1 downto 0); 
        cmt_dpc_ena:                 in std_logic;
      
        cmt_dcause:                  in std_logic_vector(3-1 downto 0);
        cmt_dcause_ena:              in std_logic;
      
        dbg_irq_r:                   in std_logic;
      
        -- The interface with CSR control 
        wr_dcsr_ena:                 in std_logic;
        wr_dpc_ena:                  in std_logic;
        wr_dscratch_ena:             in std_logic;
      
      
      
        wr_csr_nxt:                  in std_logic_vector(32-1 downto 0);
      
        dcsr_r:                     out std_logic_vector(32-1 downto 0);
        dpc_r:                      out std_logic_vector(PC_SIZE-1 downto 0);
        dscratch_r:                 out std_logic_vector(32-1 downto 0);
      
        dbg_mode:                   out std_logic;
        dbg_halt_r:                 out std_logic;
        dbg_step_r:                 out std_logic;
        dbg_ebreakm_r:              out std_logic;
        dbg_stopcycle:              out std_logic;
      
      
        -- The system memory bus interface
        i_icb_cmd_valid:             in std_logic;
        i_icb_cmd_ready:            out std_logic;
        i_icb_cmd_addr:              in std_logic_vector(12-1 downto 0); 
        i_icb_cmd_read:              in std_logic; 
        i_icb_cmd_wdata:             in std_logic_vector(32-1 downto 0);
        
        i_icb_rsp_valid:            out std_logic;
        i_icb_rsp_ready:             in std_logic;
        i_icb_rsp_rdata:            out std_logic_vector(32-1 downto 0);
      
      
        io_pads_jtag_TCK_i_ival:     in std_logic;
        io_pads_jtag_TCK_o_oval:    out std_logic;
        io_pads_jtag_TCK_o_oe:      out std_logic;
        io_pads_jtag_TCK_o_ie:      out std_logic;
        io_pads_jtag_TCK_o_pue:     out std_logic;
        io_pads_jtag_TCK_o_ds:      out std_logic;
        io_pads_jtag_TMS_i_ival:     in std_logic;
        io_pads_jtag_TMS_o_oval:    out std_logic;
        io_pads_jtag_TMS_o_oe:      out std_logic;
        io_pads_jtag_TMS_o_ie:      out std_logic;
        io_pads_jtag_TMS_o_pue:     out std_logic;
        io_pads_jtag_TMS_o_ds:      out std_logic;
        io_pads_jtag_TDI_i_ival:     in std_logic;
        io_pads_jtag_TDI_o_oval:    out std_logic;
        io_pads_jtag_TDI_o_oe:      out std_logic;
        io_pads_jtag_TDI_o_ie:      out std_logic;
        io_pads_jtag_TDI_o_pue:     out std_logic;
        io_pads_jtag_TDI_o_ds:      out std_logic;
        io_pads_jtag_TDO_i_ival:     in std_logic;
        io_pads_jtag_TDO_o_oval:    out std_logic;
        io_pads_jtag_TDO_o_oe:      out std_logic;
        io_pads_jtag_TDO_o_ie:      out std_logic;
        io_pads_jtag_TDO_o_pue:     out std_logic;
        io_pads_jtag_TDO_o_ds:      out std_logic;
        io_pads_jtag_TRST_n_i_ival:  in std_logic;
        io_pads_jtag_TRST_n_o_oval: out std_logic;
        io_pads_jtag_TRST_n_o_oe:   out std_logic;
        io_pads_jtag_TRST_n_o_ie:   out std_logic;
        io_pads_jtag_TRST_n_o_pue:  out std_logic;
        io_pads_jtag_TRST_n_o_ds:   out std_logic;
      
        -- To the target hart
        o_dbg_irq:                  out std_logic_vector(HART_NUM-1 downto 0);
        o_ndreset:                  out std_logic_vector(HART_NUM-1 downto 0);
        o_fullreset:                out std_logic_vector(HART_NUM-1 downto 0);
      
        core_csr_clk:                in std_logic;
        hfclk:                       in std_logic;
        corerst:                     in std_logic;
      
        test_mode:                   in std_logic 
  );
end sirv_debug_module;  
  
architecture impl of sirv_debug_module is 
  signal dm_rst:       std_ulogic;
  signal dm_rst_n:     std_ulogic;
  signal dm_clk:       std_ulogic;

  signal jtag_TCK:     std_ulogic;
  signal jtag_reset:   std_ulogic;
  signal jtag_TDI:     std_ulogic;
  signal jtag_TDO:     std_ulogic;
  signal jtag_TMS:     std_ulogic;
  signal jtag_TRST:    std_ulogic;
  signal jtag_DRV_TDO: std_ulogic;

  signal dtm_req_valid:  std_ulogic;
  signal dtm_req_ready:  std_ulogic;
  signal dtm_req_bits:   std_ulogic_vector(41-1 downto 0);
  signal dtm_resp_valid: std_ulogic;
  signal dtm_resp_ready: std_ulogic;
  signal dtm_resp_bits:  std_ulogic_vector(36-1 downto 0);

  signal i_dtm_req_valid:  std_ulogic;
  signal i_dtm_req_ready:  std_ulogic;
  signal i_dtm_req_bits:   std_ulogic_vector(41-1 downto 0);
  signal i_dtm_resp_valid: std_ulogic;
  signal i_dtm_resp_ready: std_ulogic;
  signal i_dtm_resp_bits:  std_ulogic_vector(36-1 downto 0);
  
  signal i_dtm_req_hsked:  std_ulogic;

  signal dtm_req_bits_addr:  std_ulogic_vector( 4 downto 0);
  signal dtm_req_bits_data:  std_ulogic_vector(33 downto 0);
  signal dtm_req_bits_op:    std_ulogic_vector( 1 downto 0);

  signal dtm_resp_bits_data: std_ulogic_vector(33 downto 0);
  signal dtm_resp_bits_resp: std_ulogic_vector( 1 downto 0);

  signal dtm_req_rd:         std_ulogic;
  signal dtm_req_wr:         std_ulogic;

  signal dtm_req_sel_dbgram:   std_ulogic;
  signal dtm_req_sel_dmcontrl: std_ulogic;
  signal dtm_req_sel_dminfo:   std_ulogic;
  signal dtm_req_sel_haltstat: std_ulogic;

  signal dminfo_r:             std_ulogic_vector(33 downto 0);
  signal dmcontrol_r:          std_ulogic_vector(33 downto 0);

  signal dm_haltnot_r:         std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_debint_r:          std_ulogic_vector(HART_NUM-1 downto 0);

  signal ram_dout:             std_ulogic_vector(31 downto 0);

  signal icb_access_dbgram_ena:std_ulogic;
  signal i_dtm_req_condi:      std_ulogic;

  signal dm_hartid_r:          std_ulogic_vector(HART_ID_W-1 downto 0);
  signal dm_debint_arr:        std_ulogic_vector(1 downto 0);
  signal dm_haltnot_arr:       std_ulogic_vector(1 downto 0);
  
  signal dtm_wr_dmcontrol:     std_ulogic;
  signal dtm_wr_dbgram:        std_ulogic;
  
  signal dtm_wr_interrupt_ena: std_ulogic;
  signal dtm_wr_haltnot_ena:   std_ulogic;
  signal dtm_wr_hartid_ena:    std_ulogic;
  signal dtm_wr_dbgram_ena:    std_ulogic;

  signal dtm_access_dbgram_ena:std_ulogic;

  signal dm_hartid_ena:        std_ulogic;
  signal dm_hartid_nxt:        std_ulogic_vector(HART_ID_W-1 downto 0);

  signal i_icb_cmd_hsked:      std_ulogic;
  signal icb_wr_ena:           std_ulogic;
  signal icb_sel_cleardebint:  std_ulogic;
  signal icb_sel_sethaltnot:   std_ulogic;
  signal icb_sel_dbgrom:       std_ulogic;
  signal icb_sel_dbgram:       std_ulogic;
  
  signal icb_wr_cleardebint_ena: std_ulogic;
  signal icb_wr_sethaltnot_ena:  std_ulogic;

  signal cleardebint_ena:        std_ulogic;
  signal cleardebint_r:          std_ulogic_vector(HART_ID_W-1 downto 0);
  signal cleardebint_nxt:        std_ulogic_vector(HART_ID_W-1 downto 0);

  signal sethaltnot_ena:         std_ulogic;
  signal sethaltnot_r:           std_ulogic_vector(HART_ID_W-1 downto 0);
  signal sethaltnot_nxt:         std_ulogic_vector(HART_ID_W-1 downto 0);

  signal rom_dout:               std_ulogic_vector(31 downto 0);

  signal ram_cs:                 std_ulogic;
  signal ram_addr:               std_ulogic_vector(3-1 downto 0);
  signal ram_rd:                 std_ulogic;
  signal ram_wdat:               std_ulogic_vector(32-1 downto 0);

  signal dm_haltnot_set:         std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_haltnot_clr:         std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_haltnot_ena:         std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_haltnot_nxt:         std_ulogic_vector(HART_NUM-1 downto 0);
  
  signal i_icb_cmd_wdata_comp:   std_ulogic;
  signal dm_hartid_r_comp:       std_ulogic;

  signal dm_debint_set:          std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_debint_clr:          std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_debint_ena:          std_ulogic_vector(HART_NUM-1 downto 0);
  signal dm_debint_nxt:          std_ulogic_vector(HART_NUM-1 downto 0);
  
  component sirv_ResetCatchAndSync_2 is 
  port( clock:          in std_logic;
        reset:          in std_logic;
        test_mode:      in std_logic;
        io_sync_reset: out std_logic
    );
  end component;
  component sirv_ResetCatchAndSync is 
  port( clock:          in std_logic;
        reset:          in std_logic;
        test_mode:      in std_logic;
        io_sync_reset: out std_logic
    );
  end component; 
  component  sirv_jtaggpioport is 
    port( clock                :  in std_logic;
          reset                :  in std_logic;
          io_jtag_TCK          : out std_logic;
          io_jtag_TMS          : out std_logic;
          io_jtag_TDI          : out std_logic;
          io_jtag_TDO          :  in std_logic;
          io_jtag_TRST         : out std_logic;
          io_jtag_DRV_TDO      :  in std_logic;
          io_pins_TCK_i_ival   :  in std_logic;
          io_pins_TCK_o_oval   : out std_logic;
          io_pins_TCK_o_oe     : out std_logic;
          io_pins_TCK_o_ie     : out std_logic;
          io_pins_TCK_o_pue    : out std_logic;
          io_pins_TCK_o_ds     : out std_logic;
          io_pins_TMS_i_ival   :  in std_logic;
          io_pins_TMS_o_oval   : out std_logic;
          io_pins_TMS_o_oe     : out std_logic;
          io_pins_TMS_o_ie     : out std_logic;
          io_pins_TMS_o_pue    : out std_logic;
          io_pins_TMS_o_ds     : out std_logic;
          io_pins_TDI_i_ival   :  in std_logic;
          io_pins_TDI_o_oval   : out std_logic;
          io_pins_TDI_o_oe     : out std_logic; 
          io_pins_TDI_o_ie     : out std_logic;
          io_pins_TDI_o_pue    : out std_logic;
          io_pins_TDI_o_ds     : out std_logic; 
          io_pins_TDO_i_ival   :  in std_logic;
          io_pins_TDO_o_oval   : out std_logic;
          io_pins_TDO_o_oe     : out std_logic;
          io_pins_TDO_o_ie     : out std_logic;
          io_pins_TDO_o_pue    : out std_logic;
          io_pins_TDO_o_ds     : out std_logic;
          io_pins_TRST_n_i_ival:  in std_logic;
          io_pins_TRST_n_o_oval: out std_logic;
          io_pins_TRST_n_o_oe  : out std_logic;
          io_pins_TRST_n_o_ie  : out std_logic;
          io_pins_TRST_n_o_pue : out std_logic;
          io_pins_TRST_n_o_ds  : out std_logic
    );
  end component;
  component sirv_debug_csr is 
    generic( PC_SIZE: integer
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
  end component;
  component sirv_jtag_dtm is 
    generic( -- Parameter Declarations
           ASYNC_FF_LEVELS: integer:= 2;

           DEBUG_DATA_BITS: integer:= 34;
           DEBUG_ADDR_BITS: integer:= 5;  -- Spec allows values are 5-7 
           DEBUG_OP_BITS:   integer:= 2;  -- OP and RESP are the same size.

           JTAG_VERSION:    std_logic_vector(3 downto 0):= "0001";
           DBUS_IDLE_CYCLES: std_logic_vector(2 downto 0):= "101"
    );
    port( -- JTAG Interface
          -- JTAG SIDE
          jtag_TDI:        in std_logic;
          jtag_TDO:       out std_logic;
          jtag_TCK:        in std_logic;
          jtag_TMS:        in std_logic;
          jtag_TRST:       in std_logic;
  
          jtag_DRV_TDO:   out std_logic; -- To allow tri-state outside of this block.
  
          -- RISC-V Core Side
          dtm_req_valid:  out std_logic;
          dtm_req_ready:   in std_logic;
          dtm_req_bits:   out std_logic_vector(40 downto 0);
          
          dtm_resp_valid:  in std_logic;
          dtm_resp_ready: out std_logic;
          dtm_resp_bits:   in std_logic_vector(35 downto 0)
    );
  end component;
  component sirv_gnrl_cdc_tx is
    generic(
            DW:        integer;
            SYNC_DP:   integer
    );
    port(                         
          -- The 4-phases handshake interface at in-side
          -- There are 4 steps required for a full transaction. 
          --     (1) The i_vld is asserted high 
          --     (2) The i_rdy is asserted high
          --     (3) The i_vld is asserted low 
          --     (4) The i_rdy is asserted low

          i_vld:  in std_logic;
          i_rdy: out std_logic;
          i_dat:  in std_logic_vector( DW-1 downto 0 );

          -- The regular handshake interface at out-side
          -- Just the regular handshake o_vld & o_rdy like AXI

          o_vld: out std_logic;
          o_rdy_a:in std_logic;
          o_dat: out std_logic_vector( DW-1 downto 0 );
          
          clk:    in std_logic;
          rst_n:  in std_logic 
    );
  end component;
  component sirv_gnrl_cdc_rx is
    generic(
            DW:        integer;
            SYNC_DP:   integer
    );
    port(                         
          -- The 4-phases handshake interface at in-side
          -- There are 4 steps required for a full transaction. 
          --     (1) The i_vld is asserted high 
          --     (2) The i_rdy is asserted high
          --     (3) The i_vld is asserted low 
          --     (4) The i_rdy is asserted low

          i_vld_a:in std_logic;
          i_rdy: out std_logic;
          i_dat:  in std_logic_vector( DW-1 downto 0 );

          -- The regular handshake interface at out-side
          -- Just the regular handshake o_vld & o_rdy like AXI

          o_vld: out std_logic;
          o_rdy:  in std_logic;
          o_dat: out std_logic_vector( DW-1 downto 0 );
          
          clk:    in std_logic;
          rst_n:  in std_logic 
    );
end component;
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
  component sirv_debug_rom is 
    port(  
           rom_addr:  in std_logic_vector( 7-1 downto 2);   
           rom_dout: out std_logic_vector(32-1 downto 0)  
    );
  end component;
  component sirv_debug_ram is 
    port(  clk:       in std_logic;
           rst_n:     in std_logic;
           ram_cs:    in std_logic;
           ram_rd:    in std_logic;
           ram_addr:  in std_logic_vector( 3-1 downto 0); 
           ram_wdat:  in std_logic_vector(32-1 downto 0);  
           ram_dout: out std_logic_vector(32-1 downto 0)  
    );
  end component;
begin 
  --This is to reset Debug module's logic, the debug module have same clock domain 
  --  as the main domain, so just use the same reset.
  u_dm_ResetCatchAndSync_2_1: component sirv_ResetCatchAndSync_2 port map( test_mode     => test_mode,
                                                                           clock         => hfclk,  -- Use same clock as main domain
                                                                           reset         => corerst,
                                                                           io_sync_reset => dm_rst
                                                                         );
  dm_rst_n <= not dm_rst;
  
  --This is to reset the JTAG_CLK relevant logics, since the chip does not 
  --  have the JTAG_RST used really, so we need to use the global chip reset to reset
  --  JTAG relevant logics
  u_jtag_ResetCatchAndSync_3_1: component sirv_ResetCatchAndSync port map( test_mode     => test_mode,
                                                                           clock         => jtag_TCK, 
                                                                           reset         => corerst,
                                                                           io_sync_reset => jtag_reset
                                                                         );
  dm_clk <= hfclk; -- Currently Debug Module have same clock domain as core

  u_jtag_pins: component sirv_jtaggpioport port map( clock                => '0',
                                                     reset                => '1',
                                                     io_jtag_TCK          => jtag_TCK,
                                                     io_jtag_TMS          => jtag_TMS,
                                                     io_jtag_TDI          => jtag_TDI,
                                                     io_jtag_TDO          => jtag_TDO,
                                                     io_jtag_TRST         => jtag_TRST,
                                                     io_jtag_DRV_TDO      => jtag_DRV_TDO,
                                                     io_pins_TCK_i_ival   => io_pads_jtag_TCK_i_ival,
                                                     io_pins_TCK_o_oval   => io_pads_jtag_TCK_o_oval,
                                                     io_pins_TCK_o_oe     => io_pads_jtag_TCK_o_oe,
                                                     io_pins_TCK_o_ie     => io_pads_jtag_TCK_o_ie,
                                                     io_pins_TCK_o_pue    => io_pads_jtag_TCK_o_pue,
                                                     io_pins_TCK_o_ds     => io_pads_jtag_TCK_o_ds,
                                                     io_pins_TMS_i_ival   => io_pads_jtag_TMS_i_ival,
                                                     io_pins_TMS_o_oval   => io_pads_jtag_TMS_o_oval,
                                                     io_pins_TMS_o_oe     => io_pads_jtag_TMS_o_oe,
                                                     io_pins_TMS_o_ie     => io_pads_jtag_TMS_o_ie,
                                                     io_pins_TMS_o_pue    => io_pads_jtag_TMS_o_pue,
                                                     io_pins_TMS_o_ds     => io_pads_jtag_TMS_o_ds,
                                                     io_pins_TDI_i_ival   => io_pads_jtag_TDI_i_ival,
                                                     io_pins_TDI_o_oval   => io_pads_jtag_TDI_o_oval,
                                                     io_pins_TDI_o_oe     => io_pads_jtag_TDI_o_oe,
                                                     io_pins_TDI_o_ie     => io_pads_jtag_TDI_o_ie,
                                                     io_pins_TDI_o_pue    => io_pads_jtag_TDI_o_pue,
                                                     io_pins_TDI_o_ds     => io_pads_jtag_TDI_o_ds,
                                                     io_pins_TDO_i_ival   => io_pads_jtag_TDO_i_ival,
                                                     io_pins_TDO_o_oval   => io_pads_jtag_TDO_o_oval,
                                                     io_pins_TDO_o_oe     => io_pads_jtag_TDO_o_oe,
                                                     io_pins_TDO_o_ie     => io_pads_jtag_TDO_o_ie,
                                                     io_pins_TDO_o_pue    => io_pads_jtag_TDO_o_pue,
                                                     io_pins_TDO_o_ds     => io_pads_jtag_TDO_o_ds,
                                                     io_pins_TRST_n_i_ival=> io_pads_jtag_TRST_n_i_ival,
                                                     io_pins_TRST_n_o_oval=> io_pads_jtag_TRST_n_o_oval,
                                                     io_pins_TRST_n_o_oe  => io_pads_jtag_TRST_n_o_oe,
                                                     io_pins_TRST_n_o_ie  => io_pads_jtag_TRST_n_o_ie,
                                                     io_pins_TRST_n_o_pue => io_pads_jtag_TRST_n_o_pue,
                                                     io_pins_TRST_n_o_ds  => io_pads_jtag_TRST_n_o_ds
                                                   );
  
  u_sirv_debug_csr: component sirv_debug_csr generic map(PC_SIZE=> PC_SIZE)
                                                port map( dbg_stopcycle  => dbg_stopcycle  ,
                                                          dbg_irq_r      => dbg_irq_r      ,

                                                          cmt_dpc        => cmt_dpc        ,
                                                          cmt_dpc_ena    => cmt_dpc_ena    ,
                                                          cmt_dcause     => cmt_dcause     ,
                                                          cmt_dcause_ena => cmt_dcause_ena ,

                                                          wr_dcsr_ena    => wr_dcsr_ena    ,
                                                          wr_dpc_ena     => wr_dpc_ena     ,
                                                          wr_dscratch_ena=> wr_dscratch_ena,

                                                          wr_csr_nxt     => wr_csr_nxt     ,
                                                                      
                                                          dcsr_r         => dcsr_r         ,
                                                          dpc_r          => dpc_r          ,
                                                          dscratch_r     => dscratch_r     ,

                                                          dbg_mode       => dbg_mode       ,
                                                          dbg_halt_r     => dbg_halt_r     ,
                                                          dbg_step_r     => dbg_step_r     ,
                                                          dbg_ebreakm_r  => dbg_ebreakm_r  ,

                                                          clk            => core_csr_clk   ,
                                                          rst_n          => dm_rst_n        
                                                        );

  -- The debug bus interface
  jtag_dtm_gen: if SUPPORT_JTAG_DTM = 1 generate
    u_sirv_jtag_dtm: component sirv_jtag_dtm generic map(ASYNC_FF_LEVELS => ASYNC_FF_LEVELS)
                                                port map( jtag_TDI       => jtag_TDI      ,
                                                          jtag_TDO       => jtag_TDO      ,
                                                          jtag_TCK       => jtag_TCK      ,
                                                          jtag_TMS       => jtag_TMS      ,
                                                          jtag_TRST      => jtag_reset    ,
                                                          jtag_DRV_TDO   => jtag_DRV_TDO  ,
                                                                            
                                                          dtm_req_valid  => dtm_req_valid ,
                                                          dtm_req_ready  => dtm_req_ready ,
                                                          dtm_req_bits   => dtm_req_bits  ,
                                                                           
                                                          dtm_resp_valid => dtm_resp_valid,
                                                          dtm_resp_ready => dtm_resp_ready,
                                                          dtm_resp_bits  => dtm_resp_bits 
                                                        );
  end generate;
  no_jtag_dtm_gen: if SUPPORT_JTAG_DTM /= 1 generate
    jtag_TDI       <= '0';
    jtag_TDO       <= '0';
    jtag_TCK       <= '0';
    jtag_TMS       <= '0';
    jtag_DRV_TDO   <= '0';
    dtm_req_valid  <= '0';
    dtm_req_bits   <= 41b"0";
    dtm_resp_ready <= '0';
  end generate;

  u_dm2dtm_cdc_tx: component sirv_gnrl_cdc_tx generic map( DW      => 36,
                                                           SYNC_DP => ASYNC_FF_LEVELS
                                                         )
                                                 port map( o_vld  => dtm_resp_valid, 
                                                           o_rdy_a=> dtm_resp_ready, 
                                                           o_dat  => dtm_resp_bits ,
                                                           i_vld  => i_dtm_resp_valid,
                                                           i_rdy  => i_dtm_resp_ready,
                                                           i_dat  => i_dtm_resp_bits ,
                                                           clk    => dm_clk,
                                                           rst_n  => dm_rst_n
                                                         );
  u_dm2dtm_cdc_rx: component sirv_gnrl_cdc_rx generic map( DW      => 41,
                                                           SYNC_DP => ASYNC_FF_LEVELS
                                                         )
                                                 port map( i_vld_a=> dtm_req_valid, 
                                                           i_rdy  => dtm_req_ready, 
                                                           i_dat  => dtm_req_bits ,
                                                           o_vld  => i_dtm_req_valid,
                                                           o_rdy  => i_dtm_req_ready,
                                                           o_dat  => i_dtm_req_bits ,
                                                           clk    => dm_clk,
                                                           rst_n  => dm_rst_n
                                                         );
  i_dtm_req_hsked <= i_dtm_req_valid and i_dtm_req_ready;

  dtm_req_bits_addr <= i_dtm_req_bits(40 downto 36);
  dtm_req_bits_data <= i_dtm_req_bits(35 downto 2);
  dtm_req_bits_op   <= i_dtm_req_bits( 1 downto 0);
  i_dtm_resp_bits   <= (dtm_resp_bits_data, dtm_resp_bits_resp);

  -- The OP field
  --   0: Ignore data. (nop)
  --   1: Read from address. (read)
  --   2: Read from address. Then write data to address. (write) 
  --   3: Reserved.
  dtm_req_rd <= '1' when (dtm_req_bits_op ?= "01") else '0';
  dtm_req_wr <= '1' when (dtm_req_bits_op ?= "10") else '0';

  dtm_req_sel_dbgram   <= (dtm_req_bits_addr(4 downto 3) ?= "00") and (not (dtm_req_bits_addr(2 downto 0) ?= "111")); -- 0x00-0x06
  dtm_req_sel_dmcontrl <= (dtm_req_bits_addr ?= 5x"10");
  dtm_req_sel_dminfo   <= (dtm_req_bits_addr ?= 5x"11");
  dtm_req_sel_haltstat <= (dtm_req_bits_addr ?= 5x"1C");

  --In the future if it is multi-core, then we need to add the core ID, to support this
  --   text from the debug_spec_v0.11
  --   At the cost of more hardware, this can be resolved in two ways. If
  --   the bus knows an ID for the originator, then the Debug Module can refuse write
  --   accesses to originators that don't match the hart ID set in hartid of dmcontrol.
  --

  -- The Resp field
  --   0: The previous operation completed successfully.
  --   1: Reserved.
  --   2: The previous operation failed. The data scanned into dbus in this access
  --      will be ignored. This status is sticky and can be cleared by writing dbusreset in dtmcontrol.
  --   3: The previous operation is still in progress. The data scanned into dbus
  --      in this access will be ignored. 
  dtm_resp_bits_data <=    ((33 downto 0 => dtm_req_sel_dbgram  ) and (dmcontrol_r(33 downto 32), ram_dout))
                        or ((33 downto 0 => dtm_req_sel_dmcontrl) and dmcontrol_r)
                        or ((33 downto 0 => dtm_req_sel_dminfo  ) and dminfo_r)
                        or ((33 downto 0 => dtm_req_sel_haltstat) and ((33-HART_ID_W downto 0 => '0'), dm_haltnot_r));
  
  dtm_resp_bits_resp <= "00";
  
  i_dtm_req_condi  <= (not icb_access_dbgram_ena) when dtm_req_sel_dbgram = '1' else '1';
  i_dtm_req_ready  <= i_dtm_req_condi and i_dtm_resp_ready;
  i_dtm_resp_valid <= i_dtm_req_condi and i_dtm_req_valid;

  -- DMINFORdData_reserved0 = 2'h0;
  -- DMINFORdData_abussize = 7'h0;
  -- DMINFORdData_serialcount = 4'h0;
  -- DMINFORdData_access128 = 1'h0;
  -- DMINFORdData_access64 = 1'h0;
  -- DMINFORdData_access32 = 1'h0;
  -- DMINFORdData_access16 = 1'h0;
  -- DMINFORdData_accesss8 = 1'h0;
  -- DMINFORdData_dramsize = 6'h6;
  -- DMINFORdData_haltsum = 1'h0;
  -- DMINFORdData_reserved1 = 3'h0;
  -- DMINFORdData_authenticated = 1'h1;
  -- DMINFORdData_authbusy = 1'h0;
  -- DMINFORdData_authtype = 2'h0;
  -- DMINFORdData_version = 2'h1;
  dminfo_r(33 downto 16) <= 18b"0";
  dminfo_r(15 downto 10) <= 6x"6";
  dminfo_r(9 downto 6)   <= 4b"0";
  dminfo_r(5)            <= '1';
  dminfo_r(4 downto 2)   <= "000";
  dminfo_r(1 downto 0)   <= "01";

  dm_debint_arr             <= ('0', dm_debint_r );
  dm_haltnot_arr            <= ('0', dm_haltnot_r);
  dmcontrol_r(33)           <= dm_debint_arr (to_integer(u_unsigned(dm_hartid_r)));
  dmcontrol_r(32)           <= dm_haltnot_arr(to_integer(u_unsigned(dm_hartid_r)));
  dmcontrol_r(31 downto 12) <= 20b"0";
  dmcontrol_r(11 downto 2)  <= ((10-HART_ID_W-1 downto 0 => '0'), dm_hartid_r);
  dmcontrol_r(1 downto 0)   <= "00";

  dtm_wr_dmcontrol <= dtm_req_sel_dmcontrl and dtm_req_wr;
  dtm_wr_dbgram    <= dtm_req_sel_dbgram   and dtm_req_wr;

  dtm_wr_interrupt_ena <= i_dtm_req_hsked and (dtm_wr_dmcontrol or dtm_wr_dbgram) and dtm_req_bits_data(33); -- W1
  dtm_wr_haltnot_ena   <= i_dtm_req_hsked and (dtm_wr_dmcontrol or dtm_wr_dbgram) and (not dtm_req_bits_data(32)); --W0
  dtm_wr_hartid_ena    <= i_dtm_req_hsked and dtm_wr_dmcontrol;
  dtm_wr_dbgram_ena    <= i_dtm_req_hsked and dtm_wr_dbgram;

  dtm_access_dbgram_ena<= i_dtm_req_hsked and dtm_req_sel_dbgram;

  dm_hartid_ena <= dtm_wr_hartid_ena;
  dm_hartid_nxt <= dtm_req_bits_data(HART_ID_W+2-1 downto 2);
  dm_hartid_dfflr: component sirv_gnrl_dfflr generic map (HART_ID_W)
                                                port map (dm_hartid_ena, dm_hartid_nxt, dm_hartid_r, dm_clk, dm_rst_n);

  --////////////////////////////////////////////////////////////
  -- Impelement the DM ICB system bus agent
  --   0x100 - 0x2ff Debug Module registers described in Section 7.12.
  --       * Only two registers needed, others are not supported
  --                  cleardebint, at 0x100 
  --                  sethaltnot,  at 0x10c 
  --   0x400 - 0x4ff Up to 256 bytes of Debug RAM. Each unique address species 8 bits.
  --       * Since this is remapped to each core's ITCM, we dont handle it at this module
  --   0x800 - 0x9ff Up to 512 bytes of Debug ROM.
  --    
  i_icb_cmd_hsked     <= i_icb_cmd_valid and i_icb_cmd_ready;
  icb_wr_ena          <= i_icb_cmd_hsked and (not i_icb_cmd_read);
  icb_sel_cleardebint <= (i_icb_cmd_addr ?= 12x"100");
  icb_sel_sethaltnot  <= (i_icb_cmd_addr ?= 12x"10c");
  icb_sel_dbgrom      <= (i_icb_cmd_addr(12-1 downto 8) ?= 4x"8");
  icb_sel_dbgram      <= (i_icb_cmd_addr(12-1 downto 8) ?= 4x"4");


  icb_wr_cleardebint_ena <= icb_wr_ena and icb_sel_cleardebint;
  icb_wr_sethaltnot_ena  <= icb_wr_ena and icb_sel_sethaltnot ;

  icb_access_dbgram_ena  <= i_icb_cmd_hsked and icb_sel_dbgram;

  cleardebint_ena <= icb_wr_cleardebint_ena;
  cleardebint_nxt <= i_icb_cmd_wdata(HART_ID_W-1 downto 0);
  cleardebint_dfflr: component sirv_gnrl_dfflr generic map (HART_ID_W)
                                                  port map (cleardebint_ena, cleardebint_nxt, cleardebint_r, dm_clk, dm_rst_n);
  
  sethaltnot_ena <= icb_wr_sethaltnot_ena;
  sethaltnot_nxt <= i_icb_cmd_wdata(HART_ID_W-1 downto 0);
  sethaltnot_dfflr: component sirv_gnrl_dfflr generic map (HART_ID_W)
                                                 port map (sethaltnot_ena, sethaltnot_nxt, sethaltnot_r, dm_clk, dm_rst_n);

  i_icb_rsp_valid <= i_icb_cmd_valid; -- Just directly pass back the valid in 0 cycle
  i_icb_cmd_ready <= i_icb_rsp_ready;

  i_icb_rsp_rdata <=    ((31 downto 0 => icb_sel_cleardebint) and ((32-HART_ID_W-1 downto 0 => '0'), cleardebint_r)) 
                     or ((31 downto 0 => icb_sel_sethaltnot ) and ((32-HART_ID_W-1 downto 0 => '0'), sethaltnot_r))
                     or ((31 downto 0 => icb_sel_dbgrom     ) and rom_dout) 
                     or ((31 downto 0 => icb_sel_dbgram     ) and ram_dout);

  u_sirv_debug_rom: component sirv_debug_rom port map ( rom_addr=> i_icb_cmd_addr(7-1 downto 2),
                                                        rom_dout=> rom_dout 
                                                      );

  ram_cs   <= dtm_access_dbgram_ena or icb_access_dbgram_ena;
  ram_addr <= dtm_req_bits_addr(2 downto 0)  when dtm_access_dbgram_ena = '1' else i_icb_cmd_addr(4 downto 2); 
  ram_rd   <= dtm_req_rd                     when dtm_access_dbgram_ena = '1' else i_icb_cmd_read; 
  ram_wdat <= dtm_req_bits_data(31 downto 0) when dtm_access_dbgram_ena = '1' else i_icb_cmd_wdata;
  u_sirv_debug_ram: component sirv_debug_ram port map ( clk     => dm_clk,
                                                        rst_n   => dm_rst_n, 
                                                        ram_cs  => ram_cs,
                                                        ram_rd  => ram_rd,
                                                        ram_addr=> ram_addr,
                                                        ram_wdat=> ram_wdat,
                                                        ram_dout=> ram_dout  
                                                      );

  dm_halt_int_gen: for i in 0 to HART_NUM-1 generate 
    i_icb_cmd_wdata_comp <= '1' when to_integer(u_unsigned(i_icb_cmd_wdata(HART_ID_W-1 downto 0))) = i else '0';
    dm_hartid_r_comp     <= '1' when to_integer(u_unsigned(dm_hartid_r)) = i else '0';
    
    -- The haltnot will be set by system bus set its ID to sethaltnot_r
    dm_haltnot_set(i) <= icb_wr_sethaltnot_ena and i_icb_cmd_wdata_comp;
    -- The haltnot will be cleared by DTM write 0 to haltnot
    dm_haltnot_clr(i) <= dtm_wr_haltnot_ena and dm_hartid_r_comp;
    dm_haltnot_ena(i) <= dm_haltnot_set(i) or dm_haltnot_clr(i);
    dm_haltnot_nxt(i) <= dm_haltnot_set(i) or (not dm_haltnot_clr(i));
    dm_haltnot_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                   port map (lden   => dm_haltnot_ena(i), 
                                                             dnxt(0)=> dm_haltnot_nxt(i),
                                                             qout(0)=> dm_haltnot_r(i),
                                                             clk    => dm_clk,
                                                             rst_n  => dm_rst_n
                                                             );

    -- The debug intr will be set by DTM write 1 to interrupt
    dm_debint_set(i) <= dtm_wr_interrupt_ena and dm_hartid_r_comp;
    -- The debug intr will be clear by system bus set its ID to cleardebint_r
    dm_debint_clr(i) <= icb_wr_cleardebint_ena and i_icb_cmd_wdata_comp;
    dm_debint_ena(i) <= dm_debint_set(i) or dm_debint_clr(i);
    dm_debint_nxt(i) <= dm_debint_set(i) or (not dm_debint_clr(i));
    dm_debint_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                  port map (lden   => dm_debint_ena(i),
                                                            dnxt(0)=> dm_debint_nxt(i),
                                                            qout(0)=> dm_debint_r(i),
                                                            clk    => dm_clk,
                                                            rst_n  => dm_rst_n
                                                            );
  end generate;
    
  o_dbg_irq        <= dm_debint_r;

  o_ndreset        <= (HART_NUM-1 downto 0 => '0');
  o_fullreset      <= (HART_NUM-1 downto 0 => '0');

  inspect_jtag_clk <= jtag_TCK;

end impl;