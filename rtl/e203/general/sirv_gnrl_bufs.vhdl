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
--  Some of the basic functions like pipeline stage and buffers
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_pipe_stage is
    generic(
    -- When the depth is 1, the ready signal may relevant to next stage's ready, hence become logic
    -- chains. Use CUT_READY to control it        
            CUT_READY: integer:= 0;
            DP:        integer:= 1;
            DW:        integer:= 32
    );
    port( clk:   in std_logic;
    	    rst_n: in std_logic;

    	    i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam
          o_dat: out std_logic_vector( DW-1 downto 0 )   ------------
    );
end sirv_gnrl_pipe_stage;

architecture impl of sirv_gnrl_pipe_stage is 
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

  component sirv_gnrl_dffl is
    generic( DW: integer );
    port(       
          lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
  end component;
begin
  dp_eq_0: if DP = 0 generate                            -- pass through
  begin  
    o_vld <= i_vld;                                      -- downsteam
    i_rdy <= o_rdy;                                      -- upsteam
    o_dat <= i_dat;                                      -- dataflow
  end generate;

  dp_gt_0: if DP > 0 generate
    signal vld_set: std_ulogic;
    signal vld_clr: std_ulogic;
    signal vld_ena: std_ulogic;
    signal vld_r:   std_ulogic;
    signal vld_nxt: std_ulogic;
  begin
    -- The valid will be set when input handshaked
    vld_set <= i_vld and i_rdy;
    -- The valid will be clr when output handshaked
    vld_clr <= o_vld and o_rdy;

    vld_ena <= vld_set or vld_clr;
    vld_nxt <= vld_set or (not vld_clr);

    vld_dfflr: entity work.sirv_gnrl_dfflr(impl_better) 
               generic map(1) 
               port map(lden=> vld_ena, dnxt(0)=> vld_nxt, qout(0)=> vld_r, clk=> clk, rst_n=> rst_n);

    o_vld <= vld_r;

    dat_dfflr: component sirv_gnrl_dffl generic map(DW) port map(vld_set, i_dat, o_dat, clk);

    cut_ready_gen: if CUT_READY = 1 generate
    begin
      -- If cut ready, then only accept when stage is not full
      i_rdy <= not vld_r;
    end generate;

    no_cut_ready_gen: if CUT_READY = 0 generate
    begin
      -- If not cut ready, then can accept when stage is not full or it is popping 
      i_rdy <= (not vld_r) or vld_clr;
    end generate;
  end generate;
end impl;

-- ===========================================================================
--
-- Description:
--  Syncer to taking asynchronous signal to synced signal as general module

library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_sync is
    generic(
            DP:        integer:= 2;
            DW:        integer:= 32
    );
    port(                         
          din_a:  in std_logic_vector( DW-1 downto 0 );
          dout:  out std_logic_vector( DW-1 downto 0 );
          rst_n:  in std_logic;
          clk:    in std_logic 
    );
end sirv_gnrl_sync;

architecture impl of sirv_gnrl_sync is  
  component sirv_gnrl_dffr is
    generic( DW: integer );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
  --subtype Data_Word is std_logic_vector range (DW-1) downto 0;            -- Wrong defination
  --type sync_dat_type is array(DP-1 downto 0, DW-1 downto 0) of std_logic; -- Right but two dimentional array type can't be use as single raw type or column type seperately
  type sync_dat_type is array( DP-1 downto 0 ) of std_ulogic_vector( DW-1 downto 0 );
  signal sync_dat: sync_dat_type;
begin
  sync_gen: for i in 0 to (DP-1) generate
    i_is_0: if i = 0 generate
      sync_dffr: entity work.sirv_gnrl_dffr(impl_better) 
                 generic map(DW) 
                 port map(din_a, sync_dat(0), clk, rst_n);
    end generate;
    i_gt_0: if i > 0 generate
      sync_dffr: entity work.sirv_gnrl_dffr(impl_better) 
                 generic map(DW) 
                 port map(sync_dat(i-1), sync_dat(i), clk, rst_n);
    end generate;
  end generate;
  dout <= sync_dat(DP-1);
end impl;

-- ====================================================================
-- Description:
--  Module sirv_gnrl_cdc_rx to receive the async handshake interface 
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_cdc_rx is
    generic(
            DW:        integer:= 32;
            SYNC_DP:   integer:= 2
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
end sirv_gnrl_cdc_rx;

architecture impl of sirv_gnrl_cdc_rx is 
  component sirv_gnrl_sync is
    generic(
            DP:        integer;
            DW:        integer
    );
    port(                         
          din_a:  in std_logic_vector( DW-1 downto 0 );
          dout:  out std_logic_vector( DW-1 downto 0 );
          rst_n:  in std_logic;
          clk:    in std_logic 
    );
  end component;
  component sirv_gnrl_dffr is
    generic( DW: integer );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
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

  signal i_vld_sync:       std_ulogic;
  signal i_vld_sync_r:     std_ulogic;
  signal i_vld_sync_nedge: std_ulogic;
  signal buf_rdy:          std_ulogic;
  signal i_rdy_r:          std_ulogic;
  signal i_rdy_set:        std_ulogic;
  signal i_rdy_clr:        std_ulogic;
  signal i_rdy_ena:        std_ulogic;
  signal i_rdy_nxt:        std_ulogic;
  signal buf_vld_r:        std_ulogic;
  signal buf_dat_r:        std_ulogic_vector( DW-1 downto 0 );
  signal buf_dat_ena:      std_ulogic;
  signal buf_vld_set:      std_ulogic;
  signal buf_vld_clr:      std_ulogic;
  signal buf_vld_ena:      std_ulogic;
  signal buf_vld_nxt:      std_ulogic;

begin
  u_i_vld_sync:    component sirv_gnrl_sync 
                   generic map(SYNC_DP, 1) 
                   port map(din_a(0)=> i_vld_a, dout(0)=> i_vld_sync, rst_n=> rst_n, clk=> clk);
  
  i_vld_sync_dffr: entity work.sirv_gnrl_dffr(impl_better) 
                   generic map(1) 
                   port map(dnxt(0)=> i_vld_sync, qout(0)=> i_vld_sync_r, clk=> clk, rst_n=> rst_n);

  i_vld_sync_nedge <= (not i_vld_sync) and i_vld_sync_r;
  
  -- Because it is a 4-phases handshake, so 
  -- The i_rdy is set (assert to high) when the buf is ready (can save data) and incoming valid detected
  -- The i_rdy is clear when i_vld neg-edge is detected
  i_rdy_set <= buf_rdy and i_vld_sync and (not i_rdy_r);
  i_rdy_clr <= i_vld_sync_nedge;
  i_rdy_ena <= i_rdy_set or i_rdy_clr;
  i_rdy_nxt <= i_rdy_set or (not i_rdy_clr);
  i_rdy_dfflr: entity work.sirv_gnrl_dfflr(impl_better)
               generic map(1) 
               port map(lden=> i_rdy_ena, dnxt(0)=> i_rdy_nxt, qout(0)=> i_rdy_r, clk=> clk, rst_n=> rst_n);
  
  i_rdy     <= i_rdy_r;
  
  -- The buf will being loaded with data when i_rdy is set high (i.e., 
  -- when the buf is ready (can save data) and incoming valid detected
  buf_dat_ena <= i_rdy_set;
  buf_dat_dfflr: entity work.sirv_gnrl_dfflr(impl_better) 
                 generic map(DW) 
                 port map(buf_dat_ena, i_dat, buf_dat_r, clk, rst_n);
  
  -- The buf_vld is set when the buf is loaded with data
  buf_vld_set <= buf_dat_ena;
  -- The buf_vld is clr when the buf is handshaked at the out-end
  buf_vld_clr <= o_vld and o_rdy;
  buf_vld_ena <= buf_vld_set or buf_vld_clr;
  buf_vld_nxt <= buf_vld_set or (not buf_vld_clr);
  buf_vld_dfflr: entity work.sirv_gnrl_dfflr(impl_better) 
                 generic map(1) 
                 port map(lden=> buf_vld_ena, dnxt(0)=> buf_vld_nxt, qout(0)=> buf_vld_r, clk=> clk, rst_n=> rst_n);
  
  -- The buf is ready when the buf is empty
  buf_rdy <= (not buf_vld_r);
  
  o_vld <= buf_vld_r;
  o_dat <= buf_dat_r;
end impl;

-- ===========================================================================
--
-- Description:
--  Module sirv_gnrl_cdc_tx to transmit the async handshake interface 
--
--  Configuration-dependent macro definitions
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_cdc_tx is
    generic(
            DW:        integer:= 32;
            SYNC_DP:   integer:= 2
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
end sirv_gnrl_cdc_tx;

architecture impl of sirv_gnrl_cdc_tx is 
  component sirv_gnrl_sync is
    generic(
            DP:        integer;
            DW:        integer
    );
    port(                         
          din_a:  in std_logic_vector( DW-1 downto 0 );
          dout:  out std_logic_vector( DW-1 downto 0 );
          rst_n:  in std_logic;
          clk:    in std_logic 
    );
  end component;
  component sirv_gnrl_dffr is
    generic( DW: integer );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
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

  signal o_rdy_sync:       std_ulogic;
  signal vld_r:            std_ulogic;
  signal dat_r:            std_ulogic_vector( DW-1 downto 0 );
  signal vld_set:          std_ulogic;
  signal vld_clr:          std_ulogic;
  signal vld_ena:          std_ulogic;
  signal vld_nxt:          std_ulogic;
  signal o_rdy_sync_r:     std_ulogic;
  signal o_rdy_nedge:      std_ulogic;
  signal nrdy_r:           std_ulogic;
  signal nrdy_set:         std_ulogic;
  signal nrdy_clr:         std_ulogic;
  signal nrdy_ena:         std_ulogic;
  signal nrdy_nxt:         std_ulogic;
  signal buf_vld_ena:      std_ulogic;
  signal buf_vld_nxt:      std_ulogic;
  begin
    u_o_rdy_sync:  component sirv_gnrl_sync 
                   generic map(SYNC_DP, 1) 
                   port map(din_a(0)=> o_rdy_a, dout(0)=> o_rdy_sync, rst_n=> rst_n, clk=> clk);
    -- Valid set when it is handshaked
    vld_set <= i_vld and i_rdy;
    -- Valid clr when the TX o_rdy is high
    vld_clr <= o_vld and o_rdy_sync;
    vld_ena <= vld_set or vld_clr;
    vld_nxt <= vld_set or (not vld_clr);
    vld_dfflr: entity work.sirv_gnrl_dfflr(impl_better)
               generic map(1) 
               port map(lden=> vld_ena, dnxt(0)=> vld_nxt, qout(0)=> vld_r, clk=> clk, rst_n=> rst_n);
    
    -- The data buf is only loaded when the vld is set
    dat_dfflr: entity work.sirv_gnrl_dfflr(impl_better)
               generic map(DW) 
               port map(lden=> vld_set, dnxt=> i_dat, qout=> dat_r, clk=> clk, rst_n=> rst_n);

    -- Detect the neg-edge
    o_rdy_sync_dffr: entity work.sirv_gnrl_dffr(impl_better) 
                     generic map(1) 
                     port map(dnxt(0)=> o_rdy_sync, qout(0)=> o_rdy_sync_r, clk=> clk, rst_n=> rst_n);
    o_rdy_nedge <= (not o_rdy_sync) and o_rdy_sync_r;

    -- Not-ready indication
    -- Not-ready is set when the vld_r is set
    nrdy_set <= vld_set;
    -- Not-ready is clr when the o_rdy neg-edge is detected
    nrdy_clr <= o_rdy_nedge;
    nrdy_ena <= nrdy_set or nrdy_clr;
    nrdy_nxt <= nrdy_set or (not nrdy_clr);
    buf_nrdy_dfflr: entity work.sirv_gnrl_dfflr(impl_better)
                    generic map(1) 
                    port map(lden=> nrdy_ena, dnxt(0)=> nrdy_nxt, qout(0)=> nrdy_r, clk=> clk, rst_n=> rst_n);

    -- The output valid
    o_vld <= vld_r;
    -- The output data
    o_dat <= dat_r;

    -- The input is ready when the  Not-ready indication is low or under clearing
    i_rdy <= (not nrdy_r) or nrdy_clr;
  end impl;

--=====================================================================
--
-- Description:
--  Module as bypass buffer
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_bypbuf is
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
end sirv_gnrl_bypbuf;

architecture impl of sirv_gnrl_bypbuf is 
  signal fifo_i_vld: std_ulogic;
  signal fifo_i_rdy: std_ulogic;
  signal fifo_i_dat: std_ulogic_vector( DW-1 downto 0 );
 
  signal fifo_o_vld: std_ulogic;
  signal fifo_o_rdy: std_ulogic;
  signal fifo_o_dat: std_ulogic_vector( DW-1 downto 0 );
 
  signal byp:        std_ulogic;

  component sirv_gnrl_fifo is
  generic(
          CUT_READY: integer:= 0;
          MSKO:      integer:= 0;  -- Mask out the data with valid or not
          DP:        integer:= 8;  -- FIFO depth
          DW:        integer:= 32  -- FIFO width
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
  u_bypbuf_fifo: component sirv_gnrl_fifo generic map(DP=> DP, DW=> DW, CUT_READY=> 1)
                                             port map(fifo_i_vld, fifo_i_rdy, fifo_i_dat, fifo_o_vld, fifo_o_rdy, fifo_o_dat, clk, rst_n);
  
  -- This module is a super-weapon for timing fix,
  -- but it is tricky, think it harder when you are reading, or contact Bob Hu
  
  i_rdy <= fifo_i_rdy;
  
  -- The FIFO is bypassed when:
  --   * fifo is empty, and o_rdy is high
  byp <= i_vld and o_rdy and (not fifo_o_vld);

  -- FIFO o-ready just use the o_rdy
  fifo_o_rdy <= o_rdy;
  
  -- The output is valid if FIFO or input have valid
  o_vld <= fifo_o_vld or i_vld;

  -- The output data select the FIFO as high priority
  o_dat <=  fifo_o_dat when fifo_o_vld = '1' else
            i_dat;

  fifo_i_dat  <= i_dat; 

  -- Only pass to FIFO i-valid if FIFO is not bypassed
  fifo_i_vld <= i_vld and (not byp);
end impl;

--=====================================================================
--
-- Description:
--  The general sync FIFO module
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;


entity sirv_gnrl_fifo is
    generic(
    -- When the depth is 1, the ready signal may relevant to next stage's ready, hence become logic
    -- chains. Use CUT_READY to control it
    -- When fifo depth is 1, the fifo is a signle stage
    -- if CUT_READY is set, then the back-pressure ready signal will be cut off, 
    -- and it can only pass 1 data every 2 cycles
    -- When fifo depth is > 1, then it is actually a really fifo
    -- The CUT_READY parameter have no impact to any logics

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
end sirv_gnrl_fifo;

architecture impl of sirv_gnrl_fifo is 
  
begin
  dp_eq0: if DP = 0 generate -- pass through when it is 0 entries
    o_vld <= i_vld;
    i_rdy <= o_rdy;
    o_dat <= i_dat;
  end generate;

  dp_gt0: if DP > 0 generate 
    type fifo_type is array( DP-1 downto 0 ) of std_ulogic_vector( DW-1 downto 0 );
    --  FIFO registers
    signal fifo_rf_r: fifo_type;
    signal fifo_rf_en: std_ulogic_vector(DP-1 downto 0);
    signal wen: std_ulogic;
    signal ren: std_ulogic;
    
    --  Read-Pointer and Write-Pointer
    signal rptr_vec_nxt: std_ulogic_vector(DP-1 downto 0);
    signal rptr_vec_r:   std_ulogic_vector(DP-1 downto 0);
    signal wptr_vec_nxt: std_ulogic_vector(DP-1 downto 0);
    signal wptr_vec_r:   std_ulogic_vector(DP-1 downto 0);

    signal i_vec:        std_ulogic_vector(DP downto 0);
    signal o_vec:        std_ulogic_vector(DP downto 0);
    signal vec_nxt:      std_ulogic_vector(DP downto 0);
    signal vec_r:        std_ulogic_vector(DP downto 0);
    signal vec_en:       std_ulogic;

    signal mux_rdat:     std_ulogic_vector(DW-1 downto 0):= (others=> '0');

    component sirv_gnrl_dfflrs is
    generic( DW: integer );
    port( 
          lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
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
    component sirv_gnrl_dffl is
    generic( DW: integer := 32 );
    port(     
          lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
    end component;

  begin
    --  read/write enable
    wen <= i_vld and i_rdy;
    ren <= o_vld and o_rdy;

    --  next_read pointer setting 
    rptr_dp_1: if DP = 1 generate 
      rptr_vec_nxt <= "1"; -- only one bit
    end generate;
    rptr_dp_not_1: if DP > 1 generate
      rptr_vec_nxt <= ('1', others=> '0') when rptr_vec_r(DP-1) = '1'  -- multi bits, if MSB of rptr_vec_r is '1' then 
                                                                       -- rptr_vec_nxt will point back to LSB of rptr_vec_r
                      else (rptr_vec_r sll 1);                         -- else rptr_vec_nxt will point to leftshift one bit of rptr_vec_r
    end generate;
  
    -- next_write pointer setting 
    wptr_dp_1: if DP = 1 generate 
      wptr_vec_nxt <= "1"; -- only one bit
    end generate;
    wptr_dp_not_1: if DP > 1 generate
      wptr_vec_nxt <= ('1', others=> '0') when wptr_vec_r(DP-1) = '1'  -- multi bits, if MSB of wptr_vec_r is '1' then 
                                                                       -- wptr_vec_nxt will point back to LSB of wptr_vec_r
                      else wptr_vec_r sll 1;                           -- else wptr_vec_nxt will point to leftshift one bit of wptr_vec_r
    end generate;

    rptr_vec_0_dfflrs: entity work.sirv_gnrl_dfflrs(impl_better) generic map(1) 
                                                                    port map(ren, rptr_vec_nxt(0 downto 0), rptr_vec_r(0 downto 0), clk, rst_n);
    wptr_vec_0_dfflrs: entity work.sirv_gnrl_dfflrs(impl_better) generic map(1) 
                                                                    port map(wen, wptr_vec_nxt(0 downto 0), wptr_vec_r(0 downto 0), clk, rst_n);
    
    dp_gt1: if DP > 1 generate
      rptr_vec_31_dfflr: entity work.sirv_gnrl_dfflr(impl_better) generic map(DP-1) 
                                                                     port map(ren, rptr_vec_nxt(DP-1 downto 1), rptr_vec_r(DP-1 downto 1), clk, rst_n);
      wptr_vec_31_dfflr: entity work.sirv_gnrl_dfflr(impl_better) generic map(DP-1) 
                                                                     port map(wen, wptr_vec_nxt(DP-1 downto 1), wptr_vec_r(DP-1 downto 1), clk, rst_n);
    end generate;

    --------------------------------------------------------------------------------
    --  Vec register to easy full and empty and the o_vld generation with flop-clean
    vec_en  <= (ren xor wen );
    vec_nxt <= (vec_r(DP-1 downto 0) & '1') when wen = '1' else
               (vec_r srl 1);

    vec_0_dfflrs: entity work.sirv_gnrl_dfflrs(impl_better) generic map(1)
                                                               port map(vec_en, vec_nxt(0 downto 0), vec_r(0 downto 0), clk, rst_n);
    vec_31_dfflr: entity work.sirv_gnrl_dfflr(impl_better)  generic map(DP)
                                                               port map(vec_en, vec_nxt(DP downto 1), vec_r(DP downto 1), clk, rst_n);
    
    i_vec <= '0' & vec_r(DP downto 1);
    o_vec <= '0' & vec_r(DP downto 1);

    cut_dp_eq1: if DP = 1 generate
    begin
      cut_ready_gen: if CUT_READY = 1 generate
          -- if cut ready, then only accept when fifo is not full
          i_rdy <= not i_vec(DP-1);
      end generate;
      no_cut_ready: if CUT_READY = 0 generate
          -- If not cut ready, then can accept when fifo is not full or it is popping 
          i_rdy <= (not i_vec(DP-1)) or ren;
      end generate;
    end generate;
    no_cut_dp_gt1: if DP > 1 generate
      i_rdy <= not i_vec(DP-1);
    end generate;

    --  write fifo
    fifo_rf: for i in 0 to (DP-1) generate
      fifo_rf_en(i) <= wen and wptr_vec_r(i);
      fifo_rf_dffl: component sirv_gnrl_dffl generic map(DW)
                                                     port map(fifo_rf_en(i), i_dat, fifo_rf_r(i), clk);
    end generate;
    
    --  One-Hot Mux as the read path
    rd_port_PROC: process(all) is
      variable tmp: std_ulogic_vector(DW-1 downto 0):= (others=> '0');
    begin
      for j in 0 to (DP-1) loop
        tmp := tmp or ( (DW-1 downto 0=> rptr_vec_r(j)) and fifo_rf_r(j) );
      end loop ;
      mux_rdat<= tmp;
    end process; -- rd_port_PROC
  
    mask_output: if (MSKO = 1) generate 
      -- Mask the data with valid since the FIFO register is not reset and as X 
      o_dat <= (DW-1 downto 0 => o_vld) and mux_rdat;
    end generate;
    no_mask_output: if (MSKO = 0) generate 
      -- Not Mask the data with valid since no care with X for datapath
      o_dat <= mux_rdat;
    end generate;

    -- o_vld as flop-clean
    o_vld <= o_vec(0);
  end generate;
end impl;