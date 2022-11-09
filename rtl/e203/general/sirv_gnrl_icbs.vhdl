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
--  All of the general modules for ICB relevant functions
--
-- ====================================================================

-- ===========================================================================
--
-- Description:
--  The module to handle the ICB bus arbitration
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb_arbt is 
  generic(  
           AW:             integer := 32;
           DW:             integer := 64;
           USR_W:          integer := 1;
           ARBT_SCHEME:    integer := 0; --0: priority based; 1: rrobin 
           -- The number of outstanding transactions supported
           FIFO_OUTS_NUM:  integer := 1;
           FIFO_CUT_READY: integer := 0;
           -- ARBT_NUM=4 ICB ports, so 2 bits for port id
           ARBT_NUM:       integer := 4;
           ALLOW_0CYCL_RSP:integer := 1;
           ARBT_PTR_W:     integer := 2       
  );
  port ( -- * Cmd channel
         o_icb_cmd_valid:         out  std_logic; 
         o_icb_cmd_ready:          in  std_logic; 
         o_icb_cmd_read:          out  std_logic_vector(1-1 downto 0); 
         o_icb_cmd_addr:          out  std_logic_vector(AW-1 downto 0);
         o_icb_cmd_wdata:         out  std_logic_vector(DW-1 downto 0);
         o_icb_cmd_wmask:         out  std_logic_vector(DW/8-1 downto 0);
         o_icb_cmd_burst:         out  std_logic_vector(2-1 downto 0);
         o_icb_cmd_beat:          out  std_logic_vector(2-1 downto 0);
         o_icb_cmd_lock:          out  std_logic;
         o_icb_cmd_excl:          out  std_logic;
         o_icb_cmd_size:          out  std_logic_vector(1 downto 0);
         o_icb_cmd_usr:           out  std_logic_vector(USR_W-1 downto 0);
     
         -- * RSP channel     
         o_icb_rsp_valid:          in  std_logic; 
         o_icb_rsp_ready:         out  std_logic; 
         o_icb_rsp_err:            in  std_logic;
         o_icb_rsp_excl_ok:        in  std_logic;
         o_icb_rsp_rdata:          in  std_logic_vector(DW-1 downto 0);
         o_icb_rsp_usr:            in  std_logic_vector(USR_W-1 downto 0);

         -- * Cmd channel
         i_bus_icb_cmd_ready:     out  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_cmd_valid:      in  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_cmd_read:       in  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_cmd_addr:       in  std_logic_vector(ARBT_NUM*AW-1 downto 0);
         i_bus_icb_cmd_wdata:      in  std_logic_vector(ARBT_NUM*DW-1 downto 0);
         i_bus_icb_cmd_wmask:      in  std_logic_vector(ARBT_NUM*DW/8-1 downto 0);
         i_bus_icb_cmd_burst:      in  std_logic_vector(ARBT_NUM*2-1 downto 0);
         i_bus_icb_cmd_beat:       in  std_logic_vector(ARBT_NUM*2-1 downto 0);
         i_bus_icb_cmd_lock:       in  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_cmd_excl:       in  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_cmd_size:       in  std_logic_vector(ARBT_NUM*2-1 downto 0);
         i_bus_icb_cmd_usr:        in  std_logic_vector(ARBT_NUM*USR_W-1 downto 0);
         
         -- * RSP channel
         i_bus_icb_rsp_valid:     out  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_rsp_ready:      in  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_rsp_err:       out  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_rsp_excl_ok:   out  std_logic_vector(ARBT_NUM*1-1 downto 0);
         i_bus_icb_rsp_rdata:     out  std_logic_vector(ARBT_NUM*DW-1 downto 0);
         i_bus_icb_rsp_usr:       out  std_logic_vector(ARBT_NUM*USR_W-1 downto 0);

         clk:                      in  std_logic;
         rst_n:                    in  std_logic        
  );
end sirv_gnrl_icb_arbt;

architecture impl of sirv_gnrl_icb_arbt is 
  type ARBT_VEC_1     is array (ARBT_NUM-1 downto 0) of std_logic_vector(1-1 downto 0)    ;
  type ARBT_VEC_2     is array (ARBT_NUM-1 downto 0) of std_logic_vector(2-1 downto 0)    ;
  type ARBT_VEC_AW    is array (ARBT_NUM-1 downto 0) of std_logic_vector(AW-1 downto 0)   ;
  type ARBT_VEC_DW    is array (ARBT_NUM-1 downto 0) of std_logic_vector(DW-1 downto 0)   ;
  type ARBT_VEC_DW_8  is array (ARBT_NUM-1 downto 0) of std_logic_vector(DW/8-1 downto 0) ;
  type ARBT_VEC_USR_W is array (ARBT_NUM-1 downto 0) of std_logic_vector(USR_W-1 downto 0);
  
  signal i_bus_icb_cmd_grt_vec: std_logic_vector(ARBT_NUM-1 downto 0);
  signal i_bus_icb_cmd_sel:     std_logic_vector(ARBT_NUM-1 downto 0);
  signal o_icb_cmd_valid_real:  std_logic;
  signal o_icb_cmd_ready_real:  std_logic;
  
  signal i_icb_cmd_read:  ARBT_VEC_1;
  signal i_icb_cmd_addr:  ARBT_VEC_AW;
  signal i_icb_cmd_wdata: ARBT_VEC_DW;
  signal i_icb_cmd_wmask: ARBT_VEC_DW_8;
  signal i_icb_cmd_burst: ARBT_VEC_2;
  signal i_icb_cmd_beat:  ARBT_VEC_2;
  signal i_icb_cmd_lock:  ARBT_VEC_1;
  signal i_icb_cmd_excl:  ARBT_VEC_1;
  signal i_icb_cmd_size:  ARBT_VEC_2;
  signal i_icb_cmd_usr:   ARBT_VEC_USR_W;

  signal sel_o_icb_cmd_read:  std_logic_vector(1-1 downto 0);
  signal sel_o_icb_cmd_addr:  std_logic_vector(AW-1 downto 0);
  signal sel_o_icb_cmd_wdata: std_logic_vector(DW-1 downto 0);
  signal sel_o_icb_cmd_wmask: std_logic_vector(DW/8-1 downto 0);
  signal sel_o_icb_cmd_burst: std_logic_vector(2-1 downto 0);
  signal sel_o_icb_cmd_beat:  std_logic_vector(2-1 downto 0);
  signal sel_o_icb_cmd_lock:  std_logic_vector(1-1 downto 0);
  signal sel_o_icb_cmd_excl:  std_logic_vector(1-1 downto 0);
  signal sel_o_icb_cmd_size:  std_logic_vector(2-1 downto 0);
  signal sel_o_icb_cmd_usr:   std_logic_vector(USR_W-1 downto 0);

  signal o_icb_rsp_ready_pre: std_logic;
  signal o_icb_rsp_valid_pre: std_logic;
  
  signal rspid_fifo_bypass:   std_logic;
  signal rspid_fifo_wen:      std_logic;
  signal rspid_fifo_ren:      std_logic;

  signal i_icb_rsp_port_id:   std_logic_vector(ARBT_PTR_W-1 downto 0);
  
  signal rspid_fifo_i_valid:  std_logic;
  signal rspid_fifo_o_valid:  std_logic;
  signal rspid_fifo_i_ready:  std_logic;
  signal rspid_fifo_o_ready:  std_logic;

  signal rspid_fifo_rdat:     std_logic_vector(ARBT_PTR_W-1 downto 0);
  signal rspid_fifo_wdat:     std_logic_vector(ARBT_PTR_W-1 downto 0);

  signal rspid_fifo_full:     std_logic;
  signal rspid_fifo_empty:    std_logic;
  signal i_arbt_indic_id:     std_logic_vector(ARBT_PTR_W-1 downto 0);
  
  

  signal i_icb_cmd_ready_pre: std_logic;
  signal i_icb_cmd_valid_pre: std_logic;
  
  signal arbt_ena:            std_logic;

  signal o_icb_rsp_port_id:   std_logic_vector(ARBT_PTR_W-1 downto 0);
  component sirv_gnrl_rrobin
    generic(ARBT_NUM: integer
    );
    port(grt_vec:  out std_logic_vector(ARBT_NUM-1 downto 0);
         req_vec:   in std_logic_vector(ARBT_NUM-1 downto 0);
         arbt_ena:  in std_logic;   
         clk:       in std_logic;
         rst_n:     in std_logic
    );
  end component;
  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam    i_vld --> o_vld --> downward
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam  o_rdy --> i_rdy --> upward
          o_dat: out std_logic_vector( DW-1 downto 0 );  ------------

          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
  component sirv_gnrl_pipe_stage is
    generic(CUT_READY: integer;
            DP:        integer;
            DW:        integer
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
  end component;
begin
  arbt_num_eq_1_gen: if ARBT_NUM = 1 generate
    i_bus_icb_cmd_ready(0)   <= o_icb_cmd_ready    ;
    o_icb_cmd_valid          <= i_bus_icb_cmd_valid(0);
    o_icb_cmd_read           <= i_bus_icb_cmd_read ;
    o_icb_cmd_addr           <= i_bus_icb_cmd_addr ;
    o_icb_cmd_wdata          <= i_bus_icb_cmd_wdata;
    o_icb_cmd_wmask          <= i_bus_icb_cmd_wmask;
    o_icb_cmd_burst          <= i_bus_icb_cmd_burst;
    o_icb_cmd_beat           <= i_bus_icb_cmd_beat ;
    o_icb_cmd_lock           <= i_bus_icb_cmd_lock(0);
    o_icb_cmd_excl           <= i_bus_icb_cmd_excl(0);
    o_icb_cmd_size           <= i_bus_icb_cmd_size ;
    o_icb_cmd_usr            <= i_bus_icb_cmd_usr  ;
                             
    o_icb_rsp_ready          <= i_bus_icb_rsp_ready(0);
    i_bus_icb_rsp_valid(0)   <= o_icb_rsp_valid    ;
    i_bus_icb_rsp_err(0)     <= o_icb_rsp_err      ;
    i_bus_icb_rsp_excl_ok(0) <= o_icb_rsp_excl_ok  ;
    i_bus_icb_rsp_rdata      <= o_icb_rsp_rdata    ;
    i_bus_icb_rsp_usr        <= o_icb_rsp_usr      ;
  end generate;
  arbt_num_gt_1_gen: if ARBT_NUM > 1 generate
    
    o_icb_cmd_valid       <= o_icb_cmd_valid_real and (not rspid_fifo_full);
    o_icb_cmd_ready_real  <= o_icb_cmd_ready and (not rspid_fifo_full); 
    -- Distract the icb from the bus declared ports

    icb_distract_gen: for i in 0 to (ARBT_NUM-1) generate
      signal id_compare: std_logic;
    begin
      i_icb_cmd_read (i) <= i_bus_icb_cmd_read ( (i+1)*1     -1 downto i*1      );
      i_icb_cmd_addr (i) <= i_bus_icb_cmd_addr ( (i+1)*AW    -1 downto i*AW     );
      i_icb_cmd_wdata(i) <= i_bus_icb_cmd_wdata( (i+1)*DW    -1 downto i*DW     );
      i_icb_cmd_wmask(i) <= i_bus_icb_cmd_wmask( (i+1)*(DW/8)-1 downto i*(DW/8) );
      i_icb_cmd_burst(i) <= i_bus_icb_cmd_burst( (i+1)*2     -1 downto i*2      );
      i_icb_cmd_beat (i) <= i_bus_icb_cmd_beat ( (i+1)*2     -1 downto i*2      );
      i_icb_cmd_lock (i) <= i_bus_icb_cmd_lock ( (i+1)*1     -1 downto i*1      );
      i_icb_cmd_excl (i) <= i_bus_icb_cmd_excl ( (i+1)*1     -1 downto i*1      );
      i_icb_cmd_size (i) <= i_bus_icb_cmd_size ( (i+1)*2     -1 downto i*2      );
      i_icb_cmd_usr  (i) <= i_bus_icb_cmd_usr  ( (i+1)*USR_W -1 downto i*USR_W  );

      i_bus_icb_cmd_ready(i) <= i_bus_icb_cmd_grt_vec(i) and o_icb_cmd_ready_real;
      -- i_bus_icb_rsp_valid(i) <= o_icb_rsp_valid_pre and ((unsigned(o_icb_rsp_port_id)) ?= i); 
      -- get VHDL warning at numeric_std_vhdl2008.vhd(4554): 
      -- equality comparison of non constant with static metalogical value is always evaluated 'false' ;
      -- may cause simulation-synthesis differences
      -- rewrite below
      id_compare             <= '1' when to_integer(unsigned(o_icb_rsp_port_id)) = i else
                                '0';
      i_bus_icb_rsp_valid(i) <= i_bus_icb_cmd_grt_vec(i) and id_compare;
      -- no warning
      -- func '?=' return std_ulogic; func '=' return boolean
    end generate;
    
    priorty_arbt: if (ARBT_SCHEME = 0) generate
      signal arbt_ena: std_logic := '0';  -- No use
    begin
      priroty_grt_vec_gen: for i in 0 to (ARBT_NUM-1) generate
        i_is_0: if(i = 0) generate
          i_bus_icb_cmd_grt_vec(i) <= '1';
        end generate;
        i_is_not_0: if(i > 0) generate
          i_bus_icb_cmd_grt_vec(i) <= not (or_reduce(i_bus_icb_cmd_valid(i-1 downto 0)));
                              -- could be (       or(i_bus_icb_cmd_valid(i-1 downto 0)));
        end generate;
        i_bus_icb_cmd_sel(i) <= i_bus_icb_cmd_grt_vec(i) and i_bus_icb_cmd_valid(i);
      end generate;
    end generate;

    rrobin_arbt: if (ARBT_SCHEME = 1) generate
      arbt_ena <= o_icb_cmd_valid and o_icb_cmd_ready;
      u_sirv_gnrl_rrobin: component sirv_gnrl_rrobin generic map ( ARBT_NUM )
                                                        port map ( grt_vec => i_bus_icb_cmd_grt_vec,  
                                                                   req_vec => i_bus_icb_cmd_valid,  
                                                                   arbt_ena=> arbt_ena,   
                                                                   clk     => clk,
                                                                   rst_n   => rst_n
                                                                 );
      i_bus_icb_cmd_sel <= i_bus_icb_cmd_grt_vec;
    end generate;

    sel_o_apb_cmd_ready_PROC: process(all)    
      variable var_sel_o_icb_cmd_read : std_logic_vector(1-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_addr : std_logic_vector(AW-1    downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_wdata: std_logic_vector(DW-1    downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_wmask: std_logic_vector(DW/8-1  downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_burst: std_logic_vector(2-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_beat : std_logic_vector(2-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_lock : std_logic_vector(1-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_excl : std_logic_vector(1-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_size : std_logic_vector(2-1     downto 0):= (others=> '0');
      variable var_sel_o_icb_cmd_usr  : std_logic_vector(USR_W-1 downto 0):= (others=> '0');
    begin
      for i in 0 to (ARBT_NUM-1) loop
        var_sel_o_icb_cmd_read  := var_sel_o_icb_cmd_read  or ( (1-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_read (i) );
        var_sel_o_icb_cmd_addr  := var_sel_o_icb_cmd_addr  or ( (AW-1    downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_addr (i) );
        var_sel_o_icb_cmd_wdata := var_sel_o_icb_cmd_wdata or ( (DW-1    downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_wdata(i) );
        var_sel_o_icb_cmd_wmask := var_sel_o_icb_cmd_wmask or ( (DW/8-1  downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_wmask(i) );
        var_sel_o_icb_cmd_burst := var_sel_o_icb_cmd_burst or ( (2-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_burst(i) );
        var_sel_o_icb_cmd_beat  := var_sel_o_icb_cmd_beat  or ( (2-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_beat (i) );
        var_sel_o_icb_cmd_lock  := var_sel_o_icb_cmd_lock  or ( (1-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_lock (i) );
        var_sel_o_icb_cmd_excl  := var_sel_o_icb_cmd_excl  or ( (1-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_excl (i) );
        var_sel_o_icb_cmd_size  := var_sel_o_icb_cmd_size  or ( (2-1     downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_size (i) );
        var_sel_o_icb_cmd_usr   := var_sel_o_icb_cmd_usr   or ( (USR_W-1 downto 0 => i_bus_icb_cmd_sel(i)) and i_icb_cmd_usr  (i) );  	
      end loop;
      sel_o_icb_cmd_read  <= var_sel_o_icb_cmd_read ;
      sel_o_icb_cmd_addr  <= var_sel_o_icb_cmd_addr ;
      sel_o_icb_cmd_wdata <= var_sel_o_icb_cmd_wdata;
      sel_o_icb_cmd_wmask <= var_sel_o_icb_cmd_wmask;
      sel_o_icb_cmd_burst <= var_sel_o_icb_cmd_burst;
      sel_o_icb_cmd_beat  <= var_sel_o_icb_cmd_beat ;
      sel_o_icb_cmd_lock  <= var_sel_o_icb_cmd_lock ;
      sel_o_icb_cmd_excl  <= var_sel_o_icb_cmd_excl ;
      sel_o_icb_cmd_size  <= var_sel_o_icb_cmd_size ;
      sel_o_icb_cmd_usr   <= var_sel_o_icb_cmd_usr  ;
    end process;

    o_icb_cmd_valid_real <= or(i_bus_icb_cmd_valid);

    i_arbt_indic_id_PROC: process(all)
      variable var_i_arbt_indic_id: std_logic_vector(ARBT_PTR_W-1 downto 0):= (others=> '0');
    begin
      for j in 0 to (ARBT_NUM-1) loop
        var_i_arbt_indic_id := var_i_arbt_indic_id or ((ARBT_PTR_W-1 downto 0 => i_bus_icb_cmd_sel(j)) and to_slv(std_ulogic_vector(to_unsigned(j, ARBT_PTR_W))));
      end loop;
      i_arbt_indic_id<= var_i_arbt_indic_id;
    end process;

    rspid_fifo_wen <= o_icb_cmd_valid and o_icb_cmd_ready;
    rspid_fifo_ren <= o_icb_rsp_valid and o_icb_rsp_ready;

    allow_0rsp: if(ALLOW_0CYCL_RSP = 1) generate 
      rspid_fifo_bypass <= rspid_fifo_empty and rspid_fifo_wen and rspid_fifo_ren;
      o_icb_rsp_port_id <= rspid_fifo_wdat when rspid_fifo_empty = '1' else
      	                   rspid_fifo_rdat;
      -- We dont need this empty qualifications because we allow the 0 cyle response
      o_icb_rsp_valid_pre <= o_icb_rsp_valid;
      o_icb_rsp_ready     <= o_icb_rsp_ready_pre;
    end generate;
    no_allow_0rsp:  if(ALLOW_0CYCL_RSP = 0) generate
      rspid_fifo_bypass   <= '0';
      o_icb_rsp_port_id   <= (ARBT_PTR_W-1 downto 0 => '0') when rspid_fifo_empty = '1' else
      	                     rspid_fifo_rdat;
      o_icb_rsp_valid_pre <= (not rspid_fifo_empty) and o_icb_rsp_valid;
      o_icb_rsp_ready     <= (not rspid_fifo_empty) and o_icb_rsp_ready_pre;
    end generate;
    
    rspid_fifo_i_valid <= rspid_fifo_wen and (not rspid_fifo_bypass);
    rspid_fifo_full    <= (not rspid_fifo_i_ready);
    rspid_fifo_o_ready <= rspid_fifo_ren and (not rspid_fifo_bypass);
    rspid_fifo_empty   <= (not rspid_fifo_o_valid);

    rspid_fifo_wdat    <= i_arbt_indic_id;

    dp_1: if(FIFO_OUTS_NUM = 1) generate 
      u_sirv_gnrl_rspid_fifo: component sirv_gnrl_pipe_stage generic map ( CUT_READY => FIFO_CUT_READY,
                                                                           DP        => 1,
                                                                           DW        => ARBT_PTR_W
      	                                                                 )
                                                                port map ( i_vld => rspid_fifo_i_valid,
                                                                           i_rdy => rspid_fifo_i_ready,
                                                                           i_dat => rspid_fifo_wdat,
                                                                           o_vld => rspid_fifo_o_valid,
                                                                           o_rdy => rspid_fifo_o_ready,  
                                                                           o_dat => rspid_fifo_rdat,  
                                                                           clk   => clk,
                                                                           rst_n => rst_n
                                                                	     );

    end generate;
    dp_gt1: if(FIFO_OUTS_NUM > 1) generate 
      u_sirv_gnrl_rspid_fifo: component sirv_gnrl_fifo generic map ( CUT_READY => FIFO_CUT_READY,
                                                                     MSKO      => 0,
                                                                     DP        => FIFO_OUTS_NUM,
                                                                     DW        => ARBT_PTR_W
      	                                                           )
                                                          port map ( i_vld  => rspid_fifo_i_valid,
                                                                     i_rdy  => rspid_fifo_i_ready,
                                                                     i_dat  => rspid_fifo_wdat,
                                                                     o_vld  => rspid_fifo_o_valid,
                                                                     o_rdy  => rspid_fifo_o_ready,  
                                                                     o_dat  => rspid_fifo_rdat,  
                                                                     clk    => clk,
                                                                     rst_n  => rst_n
                                                          	       );
    end generate;
    o_icb_cmd_read        <= sel_o_icb_cmd_read ; 
    o_icb_cmd_addr        <= sel_o_icb_cmd_addr ; 
    o_icb_cmd_wdata       <= sel_o_icb_cmd_wdata; 
    o_icb_cmd_wmask       <= sel_o_icb_cmd_wmask;
    o_icb_cmd_burst       <= sel_o_icb_cmd_burst;
    o_icb_cmd_beat        <= sel_o_icb_cmd_beat ;
    o_icb_cmd_lock        <= sel_o_icb_cmd_lock(0) ;
    o_icb_cmd_excl        <= sel_o_icb_cmd_excl(0) ;
    o_icb_cmd_size        <= sel_o_icb_cmd_size ;
    o_icb_cmd_usr         <= sel_o_icb_cmd_usr  ;
  
    o_icb_rsp_ready_pre   <= i_bus_icb_rsp_ready(to_integer(unsigned(o_icb_rsp_port_id))); 

    i_bus_icb_rsp_err     <= (ARBT_NUM-1 downto 0 => o_icb_rsp_err    );  
    i_bus_icb_rsp_excl_ok <= (ARBT_NUM-1 downto 0 => o_icb_rsp_excl_ok);  
    i_bus_icb_rsp_rdata_gen: for i in 0 to ARBT_NUM-1 generate
      i_bus_icb_rsp_rdata(DW*(i+1)-1 downto DW*i) <=  o_icb_rsp_rdata; 
    end generate;
    i_bus_icb_rsp_usr_gen: for i in 0 to USR_W-1 generate
      i_bus_icb_rsp_usr(USR_W*(i+1)-1 downto USR_W*i) <= o_icb_rsp_usr;
    end generate;
  end generate;
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the ICB bus buffer stages
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb_buffer is 
  generic( OUTS_CNT_W:     integer := 1; 
           AW:             integer := 32;
           DW:             integer := 32;
           CMD_CUT_READY:  integer := 0;
           RSP_CUT_READY:  integer := 0;
           CMD_DP:         integer := 0;
           RSP_DP:         integer := 0; 
           USR_W:          integer := 1         
  );
  port ( icb_buffer_active:   out  std_logic;
         
         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         i_icb_cmd_lock:       in  std_logic;
         i_icb_cmd_excl:       in  std_logic;
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
         i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
         i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
         i_icb_cmd_usr:        in  std_logic_vector(USR_W-1 downto 0);
         
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_excl_ok:   out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
         i_icb_rsp_usr:       out  std_logic_vector(USR_W-1 downto 0);
 
         o_icb_cmd_valid:     out  std_logic; 
         o_icb_cmd_ready:      in  std_logic; 
         o_icb_cmd_read:      out  std_logic_vector(1-1 downto 0); 
         o_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o_icb_cmd_lock:      out  std_logic;
         o_icb_cmd_excl:      out  std_logic;
         o_icb_cmd_size:      out  std_logic_vector(1 downto 0);
         o_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o_icb_cmd_usr:       out  std_logic_vector(USR_W-1 downto 0);
     
         o_icb_rsp_valid:      in  std_logic; 
         o_icb_rsp_ready:     out  std_logic; 
         o_icb_rsp_err:        in  std_logic;
         o_icb_rsp_excl_ok:    in  std_logic;
         o_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);
         o_icb_rsp_usr:        in  std_logic_vector(USR_W-1 downto 0);
   
         clk:                      in  std_logic;
         rst_n:                    in  std_logic        
  );
end sirv_gnrl_icb_buffer;
  
architecture impl of sirv_gnrl_icb_buffer is 
  constant CMD_PACK_W: integer:= (1+AW+DW+(DW/8)+1+1+2+2+2+USR_W);
  constant RSP_PACK_W: integer:= (2+DW+USR_W);

  signal cmd_fifo_i_dat, cmd_fifo_o_dat: std_logic_vector(CMD_PACK_W-1 downto 0);
  signal rsp_fifo_i_dat, rsp_fifo_o_dat: std_logic_vector(RSP_PACK_W-1 downto 0);
  signal outs_cnt_inc: std_logic;
  signal outs_cnt_dec: std_logic;
  signal outs_cnt_ena: std_logic;
  signal outs_cnt_r:   std_logic_vector(OUTS_CNT_W-1 downto 0);
  signal outs_cnt_nxt: std_logic_vector(OUTS_CNT_W-1 downto 0);
  signal outs_cnt_r_compare: std_logic;

  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam    i_vld --> o_vld --> downward
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam  o_rdy --> i_rdy --> upward
          o_dat: out std_logic_vector( DW-1 downto 0 );  ------------

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
begin
  cmd_fifo_i_dat<= ( i_icb_cmd_read, 
                     i_icb_cmd_addr, 
                     i_icb_cmd_wdata, 
                     i_icb_cmd_wmask,
                     i_icb_cmd_lock,
                     i_icb_cmd_excl,
                     i_icb_cmd_size,
                     i_icb_cmd_burst,
                     i_icb_cmd_beat,
                     i_icb_cmd_usr);
  ( o_icb_cmd_read, 
    o_icb_cmd_addr, 
    o_icb_cmd_wdata, 
    o_icb_cmd_wmask,
    o_icb_cmd_lock,
    o_icb_cmd_excl,
    o_icb_cmd_size,
    o_icb_cmd_burst,
    o_icb_cmd_beat,
    o_icb_cmd_usr)<= cmd_fifo_o_dat;
  u_sirv_gnrl_cmd_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CMD_CUT_READY,
                                                              MSKO      => 0,
                                                              DP        => CMD_DP,
                                                              DW        => CMD_PACK_W
                                                            )
                                                    port map( i_vld  => i_icb_cmd_valid,
                                                              i_rdy  => i_icb_cmd_ready,
                                                              i_dat  => cmd_fifo_i_dat,
                                                              o_vld  => o_icb_cmd_valid,
                                                              o_rdy  => o_icb_cmd_ready,  
                                                              o_dat  => cmd_fifo_o_dat,  
                                                              clk    => clk,
                                                              rst_n  => rst_n
                                                            );
  
  rsp_fifo_i_dat <= ( o_icb_rsp_err,
                      o_icb_rsp_excl_ok,
                      o_icb_rsp_rdata, 
                      o_icb_rsp_usr);
  ( i_icb_rsp_err,
    i_icb_rsp_excl_ok,
    i_icb_rsp_rdata, 
    i_icb_rsp_usr) <= rsp_fifo_o_dat;
  u_sirv_gnrl_rsp_fifo: component sirv_gnrl_fifo generic map( CUT_READY => RSP_CUT_READY,
                                                              MSKO      => 0,
                                                              DP        => RSP_DP,
                                                              DW        => RSP_PACK_W
                                                            )
                                                    port map( i_vld  => o_icb_rsp_valid,
                                                              i_rdy  => o_icb_rsp_ready,
                                                              i_dat  => rsp_fifo_i_dat,
                                                              o_vld  => i_icb_rsp_valid,
                                                              o_rdy  => i_icb_rsp_ready,  
                                                              o_dat  => rsp_fifo_o_dat,  
                                                              clk    => clk,
                                                              rst_n  => rst_n
                                                            );
  
  outs_cnt_inc <= i_icb_cmd_valid and i_icb_cmd_ready;
  outs_cnt_dec <= i_icb_rsp_valid and i_icb_rsp_ready;
  -- If meanwhile no or have set and clear, then no changes
  outs_cnt_ena <= outs_cnt_inc xor outs_cnt_dec;
  -- If only inc or only dec
  outs_cnt_nxt <= std_logic_vector(unsigned(outs_cnt_r) + '1') when outs_cnt_inc = '1' else
                  std_logic_vector(unsigned(outs_cnt_r) - '1');
  outs_cnt_dfflr: component sirv_gnrl_dfflr generic map( OUTS_CNT_W
                                                       )
                                               port map( outs_cnt_ena,
                                                         outs_cnt_nxt,
                                                         outs_cnt_r,
                                                         clk,
                                                         rst_n
                                                       );
  
  --icb_buffer_active <= i_icb_cmd_valid or (not( unsigned(outs_cnt_r) ?= 0 )); -- get warning
  outs_cnt_r_compare             <= '1' when to_integer(unsigned(outs_cnt_r)) = 0 else
                                    '0';
  icb_buffer_active <= i_icb_cmd_valid or (not outs_cnt_r_compare);
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the ICB bus width conversion from 32bits to 64bits
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb_n2w is 
  generic( 
           AW:             integer := 32;
           USR_W:          integer := 1;        
           FIFO_OUTS_NUM:  integer := 8;
           FIFO_CUT_READY: integer := 0;
           X_W:            integer := 32;
           Y_W:            integer := 64 
  );
  port ( 
         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(X_W-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(X_W/8-1 downto 0);
         i_icb_cmd_lock:       in  std_logic;
         i_icb_cmd_excl:       in  std_logic;
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
         i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
         i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
         i_icb_cmd_usr:        in  std_logic_vector(USR_W-1 downto 0);
         
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_excl_ok:   out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(X_W-1 downto 0);
         i_icb_rsp_usr:       out  std_logic_vector(USR_W-1 downto 0);
 
         o_icb_cmd_valid:     out  std_logic; 
         o_icb_cmd_ready:      in  std_logic; 
         o_icb_cmd_read:      out  std_logic_vector(1-1 downto 0); 
         o_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o_icb_cmd_wdata:     out  std_logic_vector(Y_W-1 downto 0);
         o_icb_cmd_wmask:     out  std_logic_vector(Y_W/8-1 downto 0);
         o_icb_cmd_lock:      out  std_logic;
         o_icb_cmd_excl:      out  std_logic;
         o_icb_cmd_size:      out  std_logic_vector(1 downto 0);
         o_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o_icb_cmd_usr:       out  std_logic_vector(USR_W-1 downto 0);
     
         o_icb_rsp_valid:      in  std_logic; 
         o_icb_rsp_ready:     out  std_logic; 
         o_icb_rsp_err:        in  std_logic;
         o_icb_rsp_excl_ok:    in  std_logic;
         o_icb_rsp_rdata:      in  std_logic_vector(Y_W-1 downto 0);
         o_icb_rsp_usr:        in  std_logic_vector(USR_W-1 downto 0);
   
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
end sirv_gnrl_icb_n2w;

architecture impl of sirv_gnrl_icb_n2w is
  signal cmd_y_lo_hi:      std_logic_vector(0 downto 0);
  signal rsp_y_lo_hi:      std_logic_vector(0 downto 0);
  signal n2w_fifo_wen:     std_logic;
  signal n2w_fifo_ren:     std_logic;
  signal n2w_fifo_i_ready: std_logic;
  signal n2w_fifo_i_valid: std_logic;
  signal n2w_fifo_full:    std_logic;
  signal n2w_fifo_o_valid: std_logic;
  signal n2w_fifo_o_ready: std_logic;
  signal n2w_fifo_empty:   std_logic;
  
  component sirv_gnrl_pipe_stage is
    generic(
            CUT_READY: integer;
            DP:        integer;
            DW:        integer
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
  end component;
  component sirv_gnrl_fifo is
    generic(
            CUT_READY: integer;
            MSKO:      integer; 
            DP:        integer; 
            DW:        integer
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
  n2w_fifo_wen          <= i_icb_cmd_valid and i_icb_cmd_ready;
  n2w_fifo_ren          <= i_icb_rsp_valid and i_icb_rsp_ready;
  n2w_fifo_i_valid      <= n2w_fifo_wen;
  n2w_fifo_full         <= (not n2w_fifo_i_ready);
  n2w_fifo_o_ready      <= n2w_fifo_ren;
  n2w_fifo_empty        <= (not n2w_fifo_o_valid);

  fifo_dp_1: if FIFO_OUTS_NUM = 1 generate
    u_sirv_gnrl_n2w_fifo: component sirv_gnrl_pipe_stage generic map( CUT_READY => FIFO_CUT_READY,
                                                                      DP        => 1,
                                                                      DW        => 1
                                                                    )
                                                            port map( i_vld => n2w_fifo_i_valid,
                                                                      i_rdy => n2w_fifo_i_ready,
                                                                      i_dat => cmd_y_lo_hi,
                                                                      o_vld => n2w_fifo_o_valid,
                                                                      o_rdy => n2w_fifo_o_ready,  
                                                                      o_dat => rsp_y_lo_hi,  
      
                                                                      clk   => clk,
                                                                      rst_n => rst_n
                                                                    );
  end generate;
  fifo_dp_gt_1: if FIFO_OUTS_NUM > 1 generate
    u_sirv_gnrl_n2w_fifo: component sirv_gnrl_fifo generic map( CUT_READY => FIFO_CUT_READY,
                                                                MSKO      => 0,
                                                                DP        => FIFO_OUTS_NUM,
                                                                DW        => 1
                                                              )
                                                      port map( i_vld => n2w_fifo_i_valid,
                                                                i_rdy => n2w_fifo_i_ready,
                                                                i_dat => cmd_y_lo_hi,
                                                                o_vld => n2w_fifo_o_valid,
                                                                o_rdy => n2w_fifo_o_ready,  
                                                                o_dat => rsp_y_lo_hi,  
      
                                                                clk   => clk,
                                                                rst_n => rst_n
                                                              );
  end generate;

  x_w_32: if X_W = 32 generate
    y_w_64: if Y_W = 64 generate
      cmd_y_lo_hi(0) <= i_icb_cmd_addr(2);
    end generate;
  end generate;

  o_icb_cmd_valid <= (not n2w_fifo_full) and i_icb_cmd_valid; 
  i_icb_cmd_ready <= (not n2w_fifo_full) and o_icb_cmd_ready; 
  o_icb_cmd_read  <= i_icb_cmd_read ;
  o_icb_cmd_addr  <= i_icb_cmd_addr ;
  o_icb_cmd_lock  <= i_icb_cmd_lock ;
  o_icb_cmd_excl  <= i_icb_cmd_excl ;
  o_icb_cmd_size  <= i_icb_cmd_size ;
  o_icb_cmd_burst <= i_icb_cmd_burst;
  o_icb_cmd_beat  <= i_icb_cmd_beat ;
  o_icb_cmd_usr   <= i_icb_cmd_usr  ;

  o_icb_cmd_wdata <= (i_icb_cmd_wdata,i_icb_cmd_wdata);
  o_icb_cmd_wmask <= (i_icb_cmd_wmask, (X_W/8-1 downto 0 => '0')) when cmd_y_lo_hi(0) = '1' else
                     ((X_W/8-1 downto 0 => '0'), i_icb_cmd_wmask);

  i_icb_rsp_valid <= o_icb_rsp_valid;
  i_icb_rsp_err   <= o_icb_rsp_err  ;
  i_icb_rsp_excl_ok <= o_icb_rsp_excl_ok;
  i_icb_rsp_rdata <= o_icb_rsp_rdata(Y_W-1 downto X_W) when rsp_y_lo_hi(0) = '1' else
                     o_icb_rsp_rdata(X_W-1 downto 0);
  i_icb_rsp_usr   <= o_icb_rsp_usr  ;
  o_icb_rsp_ready <= i_icb_rsp_ready;  
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the ICB bus de-mux
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb_splt is 
  generic( 
           AW:             integer := 32;
           DW:             integer := 64;
           -- The number of outstanding supported        
           FIFO_OUTS_NUM:  integer := 8;
           FIFO_CUT_READY: integer := 0;
           -- SPLT_NUM=4 ports, so 2 bits for port id
           SPLT_NUM:       integer := 4;
           SPLT_PTR_1HOT:  integer := 1; -- Currently we always use 1HOT (i.e., this is configured as 1)
                                         -- do not try to configure it as 0, becuase we never use it and verify it
           SPLT_PTR_W:     integer := 4;
           ALLOW_DIFF:     integer := 1;
           ALLOW_0CYCL_RSP:integer := 1;
           VLD_MSK_PAYLOAD:integer := 0;
           USR_W:          integer := 1
  );
  port ( 
         i_icb_splt_indic:     in  std_logic_vector(SPLT_NUM-1 downto 0);

         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
         i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
         i_icb_cmd_lock:       in  std_logic;
         i_icb_cmd_excl:       in  std_logic;
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0); 
         i_icb_cmd_usr:        in  std_logic_vector(USR_W-1 downto 0);
         
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_excl_ok:   out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
         i_icb_rsp_usr:       out  std_logic_vector(USR_W-1 downto 0);
 
         o_bus_icb_cmd_ready:  in  std_logic_vector(SPLT_NUM*1-1 downto 0); 
         o_bus_icb_cmd_valid: out  std_logic_vector(SPLT_NUM*1-1 downto 0);     
         o_bus_icb_cmd_read:  out  std_logic_vector(SPLT_NUM*1-1 downto 0); 
         o_bus_icb_cmd_addr:  out  std_logic_vector(SPLT_NUM*AW-1 downto 0);
         o_bus_icb_cmd_wdata: out  std_logic_vector(SPLT_NUM*DW-1 downto 0);
         o_bus_icb_cmd_wmask: out  std_logic_vector(SPLT_NUM*DW/8-1 downto 0);
         o_bus_icb_cmd_burst: out  std_logic_vector(SPLT_NUM*2-1 downto 0);
         o_bus_icb_cmd_beat:  out  std_logic_vector(SPLT_NUM*2-1 downto 0);
         o_bus_icb_cmd_lock:  out  std_logic_vector(SPLT_NUM*1-1 downto 0);
         o_bus_icb_cmd_excl:  out  std_logic_vector(SPLT_NUM*1-1 downto 0);
         o_bus_icb_cmd_size:  out  std_logic_vector(SPLT_NUM*2-1 downto 0);
         o_bus_icb_cmd_usr:   out  std_logic_vector(SPLT_NUM*USR_W-1 downto 0);
     
         o_bus_icb_rsp_valid:  in  std_logic_vector(SPLT_NUM*1-1 downto 0); 
         o_bus_icb_rsp_ready: out  std_logic_vector(SPLT_NUM*1-1 downto 0); 
         o_bus_icb_rsp_err:    in  std_logic_vector(SPLT_NUM*1-1 downto 0);
         o_bus_icb_rsp_excl_ok:in  std_logic_vector(SPLT_NUM*1-1 downto 0);
         o_bus_icb_rsp_rdata:  in  std_logic_vector(SPLT_NUM*DW-1 downto 0);
         o_bus_icb_rsp_usr:    in  std_logic_vector(SPLT_NUM*USR_W-1 downto 0);
   
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
end sirv_gnrl_icb_splt;
  
architecture impl of sirv_gnrl_icb_splt is 
  signal o_icb_cmd_valid: std_logic_vector(SPLT_NUM-1 downto 0);
  signal o_icb_cmd_ready: std_logic_vector(SPLT_NUM-1 downto 0);

  type o_icb_cmd_read_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(1-1 downto 0);
  signal o_icb_cmd_read:  o_icb_cmd_read_t;

  type o_icb_cmd_addr_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(AW-1 downto 0);
  signal o_icb_cmd_addr:  o_icb_cmd_addr_t;

  type o_icb_data_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(DW-1 downto 0);
  signal o_icb_cmd_wdata: o_icb_data_t;

  type o_icb_cmd_wmask_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(DW/8-1 downto 0);
  signal o_icb_cmd_wmask: o_icb_cmd_wmask_t;

  type o_icb_cmd_2element_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(1 downto 0);
  signal o_icb_cmd_burst: o_icb_cmd_2element_t;
  signal o_icb_cmd_beat:  o_icb_cmd_2element_t;
  signal o_icb_cmd_size:  o_icb_cmd_2element_t;

  signal o_icb_cmd_lock:  std_logic_vector(SPLT_NUM-1 downto 0); 
  signal o_icb_cmd_excl:  std_logic_vector(SPLT_NUM-1 downto 0); 

  type o_icb_usr_w_t is array(SPLT_NUM-1 downto 0) of std_logic_vector(USR_W-1 downto 0);
  signal o_icb_cmd_usr:   o_icb_usr_w_t;
  
  signal o_icb_rsp_valid:     std_logic_vector(SPLT_NUM-1 downto 0); 
  signal o_icb_rsp_ready:     std_logic_vector(SPLT_NUM-1 downto 0); 
  signal o_icb_rsp_err:       std_logic_vector(SPLT_NUM-1 downto 0); 
  signal o_icb_rsp_excl_ok:   std_logic_vector(SPLT_NUM-1 downto 0); 
  signal o_icb_rsp_rdata:     o_icb_data_t;
  signal o_icb_rsp_usr:       o_icb_usr_w_t;

  signal sel_o_apb_cmd_ready: std_logic;
  
  signal rspid_fifo_bypass:   std_logic;
  signal rspid_fifo_wen:      std_logic;
  signal rspid_fifo_ren:      std_logic;
  
  signal o_icb_rsp_port_id:   std_logic_vector(SPLT_PTR_W-1 downto 0);

  signal rspid_fifo_i_valid:  std_logic;
  signal rspid_fifo_o_valid:  std_logic;
  signal rspid_fifo_i_ready:  std_logic;
  signal rspid_fifo_o_ready:  std_logic;
  signal rspid_fifo_rdat:     std_logic_vector(SPLT_PTR_W-1 downto 0);
  signal rspid_fifo_wdat:     std_logic_vector(SPLT_PTR_W-1 downto 0);

  signal rspid_fifo_full:     std_logic;
  signal rspid_fifo_empty:    std_logic;
  signal i_splt_indic_id:     std_logic_vector(SPLT_PTR_W-1 downto 0);

  signal i_icb_cmd_ready_pre: std_logic;
  signal i_icb_cmd_valid_pre: std_logic;

  signal i_icb_rsp_ready_pre: std_logic;
  signal i_icb_rsp_valid_pre: std_logic;

  component sirv_gnrl_pipe_stage is
    generic(CUT_READY: integer;
            DP:        integer;
            DW:        integer
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
  end component;
  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
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
  splt_num_eq_1_gen: if(SPLT_NUM = 1) generate
    i_icb_cmd_ready        <= o_bus_icb_cmd_ready(0); 
    o_bus_icb_cmd_valid(0) <= i_icb_cmd_valid; 
    o_bus_icb_cmd_read     <= i_icb_cmd_read ; 
    o_bus_icb_cmd_addr     <= i_icb_cmd_addr ; 
    o_bus_icb_cmd_wdata    <= i_icb_cmd_wdata; 
    o_bus_icb_cmd_wmask    <= i_icb_cmd_wmask;
    o_bus_icb_cmd_burst    <= i_icb_cmd_burst;
    o_bus_icb_cmd_beat     <= i_icb_cmd_beat ;
    o_bus_icb_cmd_lock(0)  <= i_icb_cmd_lock ;
    o_bus_icb_cmd_excl(0)  <= i_icb_cmd_excl ;
    o_bus_icb_cmd_size     <= i_icb_cmd_size ;
    o_bus_icb_cmd_usr      <= i_icb_cmd_usr  ;

    o_bus_icb_rsp_ready(0) <= i_icb_rsp_ready; 
    i_icb_rsp_valid        <= o_bus_icb_rsp_valid(0); 
    i_icb_rsp_err          <= o_bus_icb_rsp_err(0);
    i_icb_rsp_excl_ok      <= o_bus_icb_rsp_excl_ok(0);
    i_icb_rsp_rdata        <= o_bus_icb_rsp_rdata;
    i_icb_rsp_usr          <= o_bus_icb_rsp_usr;
  end generate;
  splt_num_gt_1_gen: if(SPLT_NUM > 1) generate
    icb_distract_gen: for i in 0 to (SPLT_NUM - 1) generate
      o_icb_cmd_ready(i)                                  <= o_bus_icb_cmd_ready  (i); 
      o_bus_icb_cmd_valid(i)                              <= o_icb_cmd_valid      (i);
      o_bus_icb_cmd_read ((i+1)*1     -1 downto i*1     ) <= o_icb_cmd_read       (i);
      o_bus_icb_cmd_addr ((i+1)*AW    -1 downto i*AW    ) <= o_icb_cmd_addr       (i);
      o_bus_icb_cmd_wdata((i+1)*DW    -1 downto i*DW    ) <= o_icb_cmd_wdata      (i);
      o_bus_icb_cmd_wmask((i+1)*(DW/8)-1 downto i*(DW/8)) <= o_icb_cmd_wmask      (i);
      o_bus_icb_cmd_burst((i+1)*2     -1 downto i*2     ) <= o_icb_cmd_burst      (i);
      o_bus_icb_cmd_beat ((i+1)*2     -1 downto i*2     ) <= o_icb_cmd_beat       (i);
      o_bus_icb_cmd_lock (i)                              <= o_icb_cmd_lock       (i);
      o_bus_icb_cmd_excl (i)                              <= o_icb_cmd_excl       (i);
      o_bus_icb_cmd_size ((i+1)*2     -1 downto i*2     ) <= o_icb_cmd_size       (i);
      o_bus_icb_cmd_usr  ((i+1)*USR_W -1 downto i*USR_W ) <= o_icb_cmd_usr        (i);

      o_bus_icb_rsp_ready(i)                              <= o_icb_rsp_ready      (i); 
      o_icb_rsp_valid    (i)                              <= o_bus_icb_rsp_valid  (i); 
      o_icb_rsp_err      (i)                              <= o_bus_icb_rsp_err    (i);
      o_icb_rsp_excl_ok  (i)                              <= o_bus_icb_rsp_excl_ok(i);
      o_icb_rsp_rdata    (i)                              <= o_bus_icb_rsp_rdata  ((i+1)*DW-1    downto i*DW);
      o_icb_rsp_usr      (i)                              <= o_bus_icb_rsp_usr    ((i+1)*USR_W-1 downto i*USR_W);
    end generate;
  end generate; 
  
  --/////////////////////
  -- Input ICB will be accepted when
  -- (*) The targeted icb have "ready" asserted
  -- (*) The FIFO is not full

  sel_o_apb_cmd_ready_PROC: process(all)
    variable var_sel_o_apb_cmd_ready: std_logic:= '0';
  begin
    for j in 0 to (SPLT_NUM-1) loop
      var_sel_o_apb_cmd_ready:= var_sel_o_apb_cmd_ready or (i_icb_splt_indic(j) and o_icb_cmd_ready(j));
    end loop; 
    sel_o_apb_cmd_ready<= var_sel_o_apb_cmd_ready;
  end process;

  i_icb_cmd_ready_pre <= sel_o_apb_cmd_ready;

  allow_diff_gen: if(ALLOW_DIFF = 1) generate
    i_icb_cmd_valid_pre <= i_icb_cmd_valid     and (not rspid_fifo_full);
    i_icb_cmd_ready     <= i_icb_cmd_ready_pre and (not rspid_fifo_full);
  end generate;
  not_allow_diff: if(ALLOW_DIFF /= 1) generate
    -- The next transaction can only be issued if there is no any outstanding 
    --   transactions to different targets
    signal cmd_diff_branch: std_logic;
  begin
    cmd_diff_branch <=  (not rspid_fifo_empty) and (not(rspid_fifo_wdat ?= rspid_fifo_rdat));
    i_icb_cmd_valid_pre <= i_icb_cmd_valid     and (not cmd_diff_branch) and (not rspid_fifo_full);
    i_icb_cmd_ready     <= i_icb_cmd_ready_pre and (not cmd_diff_branch) and (not rspid_fifo_full);
  end generate;

  ptr_1hot: if(SPLT_PTR_1HOT = 1) generate
    i_splt_indic_id_PROC: process(all) begin
      i_splt_indic_id <= i_icb_splt_indic;
    end process;
  end generate;
  ptr_not_1hot: if(SPLT_PTR_1HOT /= 1) generate
    i_splt_indic_id_PROC: process(all)
    variable var_i_splt_indic_id: unsigned(SPLT_PTR_W-1 downto 0):= (others=> '0');
    begin
      for j in 0 to (SPLT_NUM-1) loop
      var_i_splt_indic_id := var_i_splt_indic_id or ((SPLT_PTR_W-1 downto 0 => i_icb_splt_indic(j)) and to_unsigned(j, SPLT_PTR_W));
      end loop;
      i_splt_indic_id<= std_logic_vector(var_i_splt_indic_id);
    end process;
  end generate;

  rspid_fifo_wen <= i_icb_cmd_valid and i_icb_cmd_ready;
  rspid_fifo_ren <= i_icb_rsp_valid and i_icb_rsp_ready;

  allow_0rsp: if(ALLOW_0CYCL_RSP = 1) generate
    rspid_fifo_bypass <= rspid_fifo_empty and rspid_fifo_wen and rspid_fifo_ren;
    o_icb_rsp_port_id <= rspid_fifo_wdat when rspid_fifo_empty = '1' else
                         rspid_fifo_rdat;
    -- We dont need this empty qualifications because we allow the 0 cyle response
    i_icb_rsp_valid     <= i_icb_rsp_valid_pre;
    i_icb_rsp_ready_pre <= i_icb_rsp_ready;
  end generate;
  no_allow_0rsp: if(ALLOW_0CYCL_RSP /= 1) generate
    rspid_fifo_bypass <= '0';
    o_icb_rsp_port_id <= (others => '0') when rspid_fifo_empty = '1' else
                         rspid_fifo_rdat;
    i_icb_rsp_valid     <= (not rspid_fifo_empty) and i_icb_rsp_valid_pre;
    i_icb_rsp_ready_pre <= (not rspid_fifo_empty) and i_icb_rsp_ready;
  end generate;
  
  rspid_fifo_i_valid <= rspid_fifo_wen and (not rspid_fifo_bypass);
  rspid_fifo_full    <= (not rspid_fifo_i_ready);
  rspid_fifo_o_ready <= rspid_fifo_ren and (not rspid_fifo_bypass);
  rspid_fifo_empty   <= (not rspid_fifo_o_valid);
  rspid_fifo_wdat    <= i_splt_indic_id;

  fifo_dp_1: if FIFO_OUTS_NUM = 1 generate
    u_sirv_gnrl_rspid_fifo: component sirv_gnrl_pipe_stage  generic map( CUT_READY => FIFO_CUT_READY,
                                                                         DP        => 1,
                                                                         DW        => SPLT_PTR_W
                                                                       )
                                                            port map( i_vld => rspid_fifo_i_valid,
                                                                      i_rdy => rspid_fifo_i_ready,
                                                                      i_dat => rspid_fifo_wdat,
                                                                      o_vld => rspid_fifo_o_valid,
                                                                      o_rdy => rspid_fifo_o_ready,  
                                                                      o_dat => rspid_fifo_rdat,  
      
                                                                      clk   => clk,
                                                                      rst_n => rst_n
                                                                    );
  end generate;
  fifo_dp_gt_1: if FIFO_OUTS_NUM > 1 generate
    u_sirv_gnrl_rspid_fifo: component sirv_gnrl_fifo  generic map( CUT_READY => FIFO_CUT_READY,
                                                                   MSKO      => 0,
                                                                   DP        => FIFO_OUTS_NUM,
                                                                   DW        => SPLT_PTR_W
                                                                 )
                                                      port map( i_vld => rspid_fifo_i_valid,
                                                                i_rdy => rspid_fifo_i_ready,
                                                                i_dat => rspid_fifo_wdat,
                                                                o_vld => rspid_fifo_o_valid,
                                                                o_rdy => rspid_fifo_o_ready,  
                                                                o_dat => rspid_fifo_rdat,  
      
                                                                clk   => clk,
                                                                rst_n => rst_n
                                                              );
  end generate;

  o_icb_cmd_valid_gen: for i in 0 to (SPLT_NUM-1) generate
    o_icb_cmd_valid(i) <= i_icb_splt_indic(i) and i_icb_cmd_valid_pre;
    no_vld_msk_payload: if VLD_MSK_PAYLOAD = 0 generate
      o_icb_cmd_read (i) <= i_icb_cmd_read ;
      o_icb_cmd_addr (i) <= i_icb_cmd_addr ;
      o_icb_cmd_wdata(i) <= i_icb_cmd_wdata;
      o_icb_cmd_wmask(i) <= i_icb_cmd_wmask;
      o_icb_cmd_burst(i) <= i_icb_cmd_burst;
      o_icb_cmd_beat (i) <= i_icb_cmd_beat ;
      o_icb_cmd_lock (i) <= i_icb_cmd_lock ;
      o_icb_cmd_excl (i) <= i_icb_cmd_excl ;
      o_icb_cmd_size (i) <= i_icb_cmd_size ;
      o_icb_cmd_usr  (i) <= i_icb_cmd_usr  ;
    end generate;
    vld_msk_payload_gen: if VLD_MSK_PAYLOAD /= 0 generate
      o_icb_cmd_read (i) <= (1    -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_read ;
      o_icb_cmd_addr (i) <= (AW   -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_addr ;
      o_icb_cmd_wdata(i) <= (DW   -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_wdata;
      o_icb_cmd_wmask(i) <= (DW/8 -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_wmask;
      o_icb_cmd_burst(i) <= (2    -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_burst;
      o_icb_cmd_beat (i) <= (2    -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_beat ;
      o_icb_cmd_lock (i) <=                       o_icb_cmd_valid(i) and i_icb_cmd_lock ;
      o_icb_cmd_excl (i) <=                       o_icb_cmd_valid(i) and i_icb_cmd_excl ;
      o_icb_cmd_size (i) <= (2    -1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_size ;
      o_icb_cmd_usr  (i) <= (USR_W-1 downto 0 => o_icb_cmd_valid(i)) and i_icb_cmd_usr  ;
    end generate;
  end generate;
  
  ptr_1hot_rsp: if (SPLT_PTR_1HOT = 1) generate  
  begin
    o_icb_rsp_ready_gen: for i in 0 to SPLT_NUM-1 generate
      o_icb_rsp_ready(i) <= (o_icb_rsp_port_id(i) and i_icb_rsp_ready_pre);
    end generate;
    
    i_icb_rsp_valid_pre <= or(o_icb_rsp_valid and o_icb_rsp_port_id);
      
    sel_icb_rsp_PROC: process(all)
      variable sel_i_icb_rsp_err:     std_logic:= '0';
      variable sel_i_icb_rsp_excl_ok: std_logic:= '0';
      variable sel_i_icb_rsp_rdata:   std_logic_vector(DW-1 downto 0):= (others=> '0');
      variable sel_i_icb_rsp_usr:     std_logic_vector(USR_W-1 downto 0):= (others=> '0');
    begin
      for j in 0 to SPLT_NUM-1 loop
        sel_i_icb_rsp_err     := sel_i_icb_rsp_err     or (                     o_icb_rsp_port_id(j)  and o_icb_rsp_err    (j));
        sel_i_icb_rsp_excl_ok := sel_i_icb_rsp_excl_ok or (                     o_icb_rsp_port_id(j)  and o_icb_rsp_excl_ok(j));
        sel_i_icb_rsp_rdata   := sel_i_icb_rsp_rdata   or ((DW-1    downto 0 => o_icb_rsp_port_id(j)) and o_icb_rsp_rdata  (j));
        sel_i_icb_rsp_usr     := sel_i_icb_rsp_usr     or ((USR_W-1 downto 0 => o_icb_rsp_port_id(j)) and o_icb_rsp_usr    (j));
      end loop;
      i_icb_rsp_err     <= sel_i_icb_rsp_err    ;
      i_icb_rsp_excl_ok <= sel_i_icb_rsp_excl_ok;
      i_icb_rsp_rdata   <= sel_i_icb_rsp_rdata  ;
      i_icb_rsp_usr     <= sel_i_icb_rsp_usr    ;
    end process;    
  end generate;
  ptr_not_1hot_rsp: if (SPLT_PTR_1HOT /= 1) generate
    o_icb_rsp_ready_gen: for i in 0 to SPLT_NUM-1 generate
      signal id_compare: std_logic;
    begin
      id_compare <= '1' when (to_integer(unsigned(o_icb_rsp_port_id)) = i) else
                    '0';
      o_icb_rsp_ready(i) <= id_compare and i_icb_rsp_ready_pre;
    end generate;

    i_icb_rsp_valid_pre <= o_icb_rsp_valid  (to_integer(unsigned(o_icb_rsp_port_id))); 
    i_icb_rsp_err       <= o_icb_rsp_err    (to_integer(unsigned(o_icb_rsp_port_id))); 
    i_icb_rsp_excl_ok   <= o_icb_rsp_excl_ok(to_integer(unsigned(o_icb_rsp_port_id))); 
    i_icb_rsp_rdata     <= o_icb_rsp_rdata  (to_integer(unsigned(o_icb_rsp_port_id))); 
    i_icb_rsp_usr       <= o_icb_rsp_usr    (to_integer(unsigned(o_icb_rsp_port_id))); 
  end generate;
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the simple-ICB bus to AXI bus conversion 
--
-- ===========================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb2axi is 
  generic( AXI_FIFO_DP:        integer := 0;  -- This is to optionally add the pipeline stage for AXI bus
                                              --   if the depth is 0, then means pass through, not add pipeline
                                              --   if the depth is 2, then means added one ping-pong buffer stage
           AXI_FIFO_CUT_READY: integer := 1;
           AW:             integer := 32;           
           FIFO_OUTS_NUM:  integer := 8;
           FIFO_CUT_READY: integer := 0;        
           DW:             integer := 64      -- 64 or 32 bits
  );
  port ( 
         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
                  
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);

         o_axi_arvalid:       out  std_logic;
         o_axi_arready:        in  std_logic;       
         o_axi_araddr:        out  std_logic_vector(AW-1 downto 0);
         o_axi_arcache:       out  std_logic_vector(3 downto 0);
         o_axi_arprot:        out  std_logic_vector(2 downto 0);
         o_axi_arlock:        out  std_logic_vector(1 downto 0); 
         o_axi_arburst:       out  std_logic_vector(1 downto 0);
         o_axi_arlen:         out  std_logic_vector(3 downto 0);
         o_axi_arsize:        out  std_logic_vector(2 downto 0);

         o_axi_awvalid:       out  std_logic;
         o_axi_awready:        in  std_logic;       
         o_axi_awaddr:        out  std_logic_vector(AW-1 downto 0);
         o_axi_awcache:       out  std_logic_vector(3 downto 0);
         o_axi_awprot:        out  std_logic_vector(2 downto 0);
         o_axi_awlock:        out  std_logic_vector(1 downto 0); 
         o_axi_awburst:       out  std_logic_vector(1 downto 0);
         o_axi_awlen:         out  std_logic_vector(3 downto 0);
         o_axi_awsize:        out  std_logic_vector(2 downto 0);

         o_axi_rvalid:         in  std_logic;
         o_axi_rready:        out  std_logic;
         o_axi_rdata:          in  std_logic_vector(DW-1 downto 0);
         o_axi_rresp:          in  std_logic_vector(1 downto 0);
         o_axi_rlast:          in  std_logic; 
         
         o_axi_wvalid:        out  std_logic; 
         o_axi_wready:         in  std_logic;         
         o_axi_wdata:         out  std_logic_vector(DW-1 downto 0);
         o_axi_wstrb:         out  std_logic_vector((DW/8)-1 downto 0);
         o_axi_wlast:         out  std_logic; 

         o_axi_bvalid:         in  std_logic;
         o_axi_bready:        out  std_logic;
         o_axi_bresp:          in  std_logic_vector(1 downto 0); 
         
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
end sirv_gnrl_icb2axi;

architecture impl of sirv_gnrl_icb2axi is 
  signal i_axi_arvalid: std_logic;
  signal i_axi_arready: std_logic;
  signal i_axi_araddr:  std_logic_vector(AW-1 downto 0);
  signal i_axi_arcache: std_logic_vector(3 downto 0);
  signal i_axi_arprot:  std_logic_vector(2 downto 0); 
  signal i_axi_arlock:  std_logic_vector(1 downto 0);
  signal i_axi_arburst: std_logic_vector(1 downto 0);
  signal i_axi_arlen:   std_logic_vector(3 downto 0);
  signal i_axi_arsize:  std_logic_vector(2 downto 0); 
 
  signal i_axi_awvalid: std_logic;
  signal i_axi_awready: std_logic; 
  signal i_axi_awaddr:  std_logic_vector(AW-1 downto 0);
  signal i_axi_awcache: std_logic_vector(3 downto 0);
  signal i_axi_awprot:  std_logic_vector(2 downto 0);
  signal i_axi_awlock:  std_logic_vector(1 downto 0);
  signal i_axi_awburst: std_logic_vector(1 downto 0);
  signal i_axi_awlen:   std_logic_vector(3 downto 0);
  signal i_axi_awsize:  std_logic_vector(2 downto 0);
 
 
  signal i_axi_rvalid:  std_logic;
  signal i_axi_rready:  std_logic;
  signal i_axi_rdata:   std_logic_vector(DW-1 downto 0);
  signal i_axi_rresp:   std_logic_vector(1 downto 0);
  signal i_axi_rlast:   std_logic;
 
  signal i_axi_wvalid:  std_logic;
  signal i_axi_wready:  std_logic;
  signal i_axi_wdata:   std_logic_vector(DW-1 downto 0);
  signal i_axi_wstrb:   std_logic_vector((DW/8)-1 downto 0);
  signal i_axi_wlast:   std_logic;
   
  signal i_axi_bvalid:  std_logic;
  signal i_axi_bready:  std_logic;
  signal i_axi_bresp:   std_logic_vector(1 downto 0);
  
  signal tmp:           std_logic;
  signal rw_fifo_full:  std_logic;
  signal rw_fifo_empty: std_logic;

  signal rw_fifo_wen:   std_logic;
  signal rw_fifo_ren:   std_logic;

  signal rw_fifo_i_ready:   std_logic;
  signal rw_fifo_i_valid:   std_logic;
  signal rw_fifo_o_valid:   std_logic;
  signal rw_fifo_o_ready:   std_logic;

  signal i_icb_rsp_read:    std_logic_vector(0 downto 0);

  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam    i_vld --> o_vld --> downward
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam  o_rdy --> i_rdy --> upward
          o_dat: out std_logic_vector( DW-1 downto 0 );  ------------

          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;

  component sirv_gnrl_axi_buffer is 
  generic( CHNL_FIFO_DP:        integer;  
           CHNL_FIFO_CUT_READY: integer;
           AW:                  integer;           
           DW:                  integer
  );
  port ( 
         i_axi_arvalid:        in  std_logic;
         i_axi_arready:       out  std_logic;       
         i_axi_araddr:         in  std_logic_vector(AW-1 downto 0);
         i_axi_arcache:        in  std_logic_vector(3 downto 0);
         i_axi_arprot:         in  std_logic_vector(2 downto 0);
         i_axi_arlock:         in  std_logic_vector(1 downto 0); 
         i_axi_arburst:        in  std_logic_vector(1 downto 0);
         i_axi_arlen:          in  std_logic_vector(3 downto 0);
         i_axi_arsize:         in  std_logic_vector(2 downto 0);

         i_axi_awvalid:        in  std_logic;
         i_axi_awready:       out  std_logic;       
         i_axi_awaddr:         in  std_logic_vector(AW-1 downto 0);
         i_axi_awcache:        in  std_logic_vector(3 downto 0);
         i_axi_awprot:         in  std_logic_vector(2 downto 0);
         i_axi_awlock:         in  std_logic_vector(1 downto 0); 
         i_axi_awburst:        in  std_logic_vector(1 downto 0);
         i_axi_awlen:          in  std_logic_vector(3 downto 0);
         i_axi_awsize:         in  std_logic_vector(2 downto 0);

         i_axi_rvalid:        out std_logic;
         i_axi_rready:         in std_logic;
         i_axi_rdata:         out std_logic_vector(DW-1 downto 0);
         i_axi_rresp:         out std_logic_vector(1 downto 0);
         i_axi_rlast:         out std_logic;
 
         i_axi_wvalid:         in std_logic;
         i_axi_wready:        out std_logic;
         i_axi_wdata:          in std_logic_vector(DW-1 downto 0);
         i_axi_wstrb:          in std_logic_vector((DW/8)-1 downto 0);
         i_axi_wlast:          in std_logic;
               
         i_axi_bvalid:        out std_logic;
         i_axi_bready:         in std_logic;
         i_axi_bresp:         out std_logic_vector(1 downto 0);

         o_axi_arvalid:       out  std_logic;
         o_axi_arready:        in  std_logic;       
         o_axi_araddr:        out  std_logic_vector(AW-1 downto 0);
         o_axi_arcache:       out  std_logic_vector(3 downto 0);
         o_axi_arprot:        out  std_logic_vector(2 downto 0);
         o_axi_arlock:        out  std_logic_vector(1 downto 0); 
         o_axi_arburst:       out  std_logic_vector(1 downto 0);
         o_axi_arlen:         out  std_logic_vector(3 downto 0);
         o_axi_arsize:        out  std_logic_vector(2 downto 0);

         o_axi_awvalid:       out  std_logic;
         o_axi_awready:        in  std_logic;       
         o_axi_awaddr:        out  std_logic_vector(AW-1 downto 0);
         o_axi_awcache:       out  std_logic_vector(3 downto 0);
         o_axi_awprot:        out  std_logic_vector(2 downto 0);
         o_axi_awlock:        out  std_logic_vector(1 downto 0); 
         o_axi_awburst:       out  std_logic_vector(1 downto 0);
         o_axi_awlen:         out  std_logic_vector(3 downto 0);
         o_axi_awsize:        out  std_logic_vector(2 downto 0);

         o_axi_rvalid:         in  std_logic;
         o_axi_rready:        out  std_logic;
         o_axi_rdata:          in  std_logic_vector(DW-1 downto 0);
         o_axi_rresp:          in  std_logic_vector(1 downto 0);
         o_axi_rlast:          in  std_logic; 
         
         o_axi_wvalid:        out  std_logic; 
         o_axi_wready:         in  std_logic;         
         o_axi_wdata:         out  std_logic_vector(DW-1 downto 0);
         o_axi_wstrb:         out  std_logic_vector((DW/8)-1 downto 0);
         o_axi_wlast:         out  std_logic; 

         o_axi_bvalid:         in  std_logic;
         o_axi_bready:        out  std_logic;
         o_axi_bresp:          in  std_logic_vector(1 downto 0); 
         
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
  end component;
begin
  --////////////////////////////////////////////////////////////////
  --////////////////////////////////////////////////////////////////
  -- Convert the ICB to AXI Read/Write address and Wdata channel
  --
  --   Generate the AXI address channel valid which is direct got 
  --     from ICB command channel
  i_axi_arvalid <= i_icb_cmd_valid and i_icb_cmd_read(0);

  -- If it is the read transaction, need to pass to AR channel only
  -- If it is the write transaction, need to pass to AW and W channel both
  -- But in all case, need to check FIFO is not ful

  tmp<= i_axi_arready when i_icb_cmd_read(0) = '1' else
        (i_axi_awready and i_axi_wready);
  i_icb_cmd_ready <= (not rw_fifo_full) and tmp;
  i_axi_awvalid <= i_icb_cmd_valid and (not i_icb_cmd_read(0)) and i_axi_wready  and (not rw_fifo_full);
  i_axi_wvalid  <= i_icb_cmd_valid and (not i_icb_cmd_read(0)) and i_axi_awready and (not rw_fifo_full);  

  --   Generate the AXI address channel address which is direct got 
  --     from ICB command channel
  i_axi_araddr <= i_icb_cmd_addr;
  i_axi_awaddr <= i_icb_cmd_addr;
  
  -- For these attribute signals we just make it tied to zero
  i_axi_arcache <= "0000";
  i_axi_awcache <= "0000";
  i_axi_arprot  <= "000";
  i_axi_awprot  <= "000";
  i_axi_arlock  <= "00";
  i_axi_awlock  <= "00";

  -- The ICB does not support burst now, so just make it fixed
  i_axi_arburst <= "00";
  i_axi_awburst <= "00";
  i_axi_arlen   <= "0000";
  i_axi_awlen   <= "0000";

  dw_32: if(DW=32) generate
    i_axi_arsize <= "010";
    i_axi_awsize <= "010";
  end generate;
  dw_64: if(DW=64) generate
    i_axi_arsize <= "011";
    i_axi_awsize <= "011";
  end generate;

  -- Generate the Write data channel
  i_axi_wdata <= i_icb_cmd_wdata;
  i_axi_wstrb <= i_icb_cmd_wmask;
  i_axi_wlast <= '1';
  
  rw_fifo_wen <= i_icb_cmd_valid and i_icb_cmd_ready;
  rw_fifo_ren <= i_icb_rsp_valid and i_icb_rsp_ready;

  rw_fifo_i_valid <= rw_fifo_wen;
  rw_fifo_o_ready <= rw_fifo_ren;

  rw_fifo_full    <= (not rw_fifo_i_ready);
  rw_fifo_empty   <= (not rw_fifo_o_valid);

  u_sirv_gnrl_rw_fifo: component sirv_gnrl_fifo generic map( CUT_READY => FIFO_CUT_READY,
                                                             MSKO      => 1,
                                                             DP        => FIFO_OUTS_NUM,
                                                             DW        => 1
                                                           )
                                                   port map( i_vld => rw_fifo_i_valid,
                                                             i_rdy => rw_fifo_i_ready,
                                                             i_dat => i_icb_cmd_read,
                                                             o_vld => rw_fifo_o_valid,
                                                             o_rdy => rw_fifo_o_ready,  
                                                             o_dat => i_icb_rsp_read,  
   
                                                             clk   => clk,
                                                             rst_n => rst_n
                                                           );

  -- Generate the response channel
  i_icb_rsp_valid <= i_axi_rvalid when i_icb_rsp_read(0) = '1' else
                    i_axi_bvalid;
  i_axi_rready    <= i_icb_rsp_read(0) and i_icb_rsp_ready;
  i_axi_bready    <= (not i_icb_rsp_read(0)) and i_icb_rsp_ready;

  i_icb_rsp_err   <= i_axi_rresp(1) when i_icb_rsp_read(0) = '1' else --SLVERR or DECERR 
                     i_axi_bresp(1);
  i_icb_rsp_rdata <= i_axi_rdata when i_icb_rsp_read(0) = '1' else
                     (DW-1 downto 0 => '0'); 
  
  u_sirv_gnrl_axi_buffer: component sirv_gnrl_axi_buffer generic map(
                                                                      CHNL_FIFO_DP        => AXI_FIFO_DP, 
                                                                      CHNL_FIFO_CUT_READY => AXI_FIFO_CUT_READY,
                                                                      AW                  => AW,
                                                                      DW                  => DW
                                                                    )
                                                            port map(
                                                                      i_axi_arvalid   => i_axi_arvalid,
                                                                      i_axi_arready   => i_axi_arready,
                                                                      i_axi_araddr    => i_axi_araddr ,
                                                                      i_axi_arcache   => i_axi_arcache,
                                                                      i_axi_arprot    => i_axi_arprot ,
                                                                      i_axi_arlock    => i_axi_arlock ,
                                                                      i_axi_arburst   => i_axi_arburst,
                                                                      i_axi_arlen     => i_axi_arlen  ,
                                                                      i_axi_arsize    => i_axi_arsize ,
                                                                                                 
                                                                      i_axi_awvalid   => i_axi_awvalid,
                                                                      i_axi_awready   => i_axi_awready,
                                                                      i_axi_awaddr    => i_axi_awaddr ,
                                                                      i_axi_awcache   => i_axi_awcache,
                                                                      i_axi_awprot    => i_axi_awprot ,
                                                                      i_axi_awlock    => i_axi_awlock ,
                                                                      i_axi_awburst   => i_axi_awburst,
                                                                      i_axi_awlen     => i_axi_awlen  ,
                                                                      i_axi_awsize    => i_axi_awsize ,
                                                                                                   
                                                                      i_axi_rvalid    => i_axi_rvalid ,
                                                                      i_axi_rready    => i_axi_rready ,
                                                                      i_axi_rdata     => i_axi_rdata  ,
                                                                      i_axi_rresp     => i_axi_rresp  ,
                                                                      i_axi_rlast     => i_axi_rlast  ,
                                                                                                   
                                                                      i_axi_wvalid    => i_axi_wvalid ,
                                                                      i_axi_wready    => i_axi_wready ,
                                                                      i_axi_wdata     => i_axi_wdata  ,
                                                                      i_axi_wstrb     => i_axi_wstrb  ,
                                                                      i_axi_wlast     => i_axi_wlast  ,
                                                                                                   
                                                                      i_axi_bvalid    => i_axi_bvalid ,
                                                                      i_axi_bready    => i_axi_bready ,
                                                                      i_axi_bresp     => i_axi_bresp  ,
                                                                                                  
                                                                      o_axi_arvalid   => o_axi_arvalid,
                                                                      o_axi_arready   => o_axi_arready,
                                                                      o_axi_araddr    => o_axi_araddr ,
                                                                      o_axi_arcache   => o_axi_arcache,
                                                                      o_axi_arprot    => o_axi_arprot ,
                                                                      o_axi_arlock    => o_axi_arlock ,
                                                                      o_axi_arburst   => o_axi_arburst,
                                                                      o_axi_arlen     => o_axi_arlen  ,
                                                                      o_axi_arsize    => o_axi_arsize ,
                                                                                      
                                                                      o_axi_awvalid   => o_axi_awvalid,
                                                                      o_axi_awready   => o_axi_awready,
                                                                      o_axi_awaddr    => o_axi_awaddr ,
                                                                      o_axi_awcache   => o_axi_awcache,
                                                                      o_axi_awprot    => o_axi_awprot ,
                                                                      o_axi_awlock    => o_axi_awlock ,
                                                                      o_axi_awburst   => o_axi_awburst,
                                                                      o_axi_awlen     => o_axi_awlen  ,
                                                                      o_axi_awsize    => o_axi_awsize ,

                                                                      o_axi_rvalid    => o_axi_rvalid ,
                                                                      o_axi_rready    => o_axi_rready ,
                                                                      o_axi_rdata     => o_axi_rdata  ,
                                                                      o_axi_rresp     => o_axi_rresp  ,
                                                                      o_axi_rlast     => o_axi_rlast  ,
                                                                                     
                                                                      o_axi_wvalid    => o_axi_wvalid ,
                                                                      o_axi_wready    => o_axi_wready ,
                                                                      o_axi_wdata     => o_axi_wdata  ,
                                                                      o_axi_wstrb     => o_axi_wstrb  ,
                                                                      o_axi_wlast     => o_axi_wlast  ,
                                                                                    
                                                                      o_axi_bvalid    => o_axi_bvalid ,
                                                                      o_axi_bready    => o_axi_bready ,
                                                                      o_axi_bresp     => o_axi_bresp  ,
                                                                        
                                                                      clk             => clk          ,
                                                                      rst_n           => rst_n
                                                                    );
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the simple-ICB bus to Wishbone bus conversion 
--  Note: in order to support the open source I2C IP, which is 8 bits
--       wide bus and byte-addresable, so here this module is just ICB to 
--       wishbone 8-bits bus conversion
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb32towishb8 is 
  generic( 
           AW: integer := 32
  );
  port ( 
         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(32-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(32/8-1 downto 0);
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
                  
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(32-1 downto 0);
         
         -- The 8bits wishbone slave (e.g., I2C) must be accessed by load/store byte instructions         
         wb_adr:              out  std_logic_vector(AW-1 downto 0);  -- lower address bits
         wb_dat_w:            out  std_logic_vector(8-1 downto 0);   -- databus input
         wb_dat_r:             in  std_logic_vector(8-1 downto 0);   -- databus output
         wb_we:               out  std_logic;                        -- write enable input
         wb_stb:              out  std_logic;                        -- stobe/core select signal
         wb_cyc:              out  std_logic;                        -- valid bus cycle input
         wb_ack:               in  std_logic;                        -- bus cycle acknowledge output
         
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
end sirv_gnrl_icb32towishb8;

architecture impl of sirv_gnrl_icb32towishb8 is 
  signal wb_dat_r_remap: std_logic_vector(32-1 downto 0);

  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
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
  wb_adr   <= i_icb_cmd_addr;
  wb_we    <= not i_icb_cmd_read(0);

  -- The 32bits bus to 8bits bus remapping
  wb_dat_w <= i_icb_cmd_wdata(31 downto 24) when i_icb_cmd_wmask(3) = '1' else
              i_icb_cmd_wdata(23 downto 16) when i_icb_cmd_wmask(2) = '1' else
              i_icb_cmd_wdata(15 downto  8) when i_icb_cmd_wmask(1) = '1' else
              i_icb_cmd_wdata( 7 downto  0) when i_icb_cmd_wmask(0) = '1' else
              (others=> '0');
  
  wb_dat_r_remap<= ((31 downto 8 => '0'),wb_dat_r) sll to_integer(unsigned(i_icb_cmd_addr(1 downto 0) & "000"));

  -- Since the Wishbone reponse channel does not have handhake scheme, but the
  --   ICB have, so the response may not be accepted by the upstream master
  --   So in order to make sure the functionality is correct, we must put
  --   a reponse bypass-buffer here, to always be able to accept response from wishbone
  u_rsp_fifo: component sirv_gnrl_fifo generic map( CUT_READY => 1,
                                                    MSKO      => 0,
                                                    DP        => 1,
                                                    DW        => 32
                                                  )
                                          port map( i_vld => wb_ack,
                                                    i_rdy => OPEN,
                                                    i_dat => wb_dat_r_remap,
                                                    o_vld => i_icb_rsp_valid,
                                                    o_rdy => i_icb_rsp_ready,  
                                                    o_dat => i_icb_rsp_rdata,
                                                    clk   => clk,
                                                    rst_n => rst_n
                                                  );
  -- We only initiate the reqeust when the response buffer is empty, to make
  --   sure when the response back from wishbone we can alway be able to 
  --   accept it
  wb_stb          <= (not i_icb_rsp_valid) and i_icb_cmd_valid;
  wb_cyc          <= (not i_icb_rsp_valid) and i_icb_cmd_valid;
  i_icb_cmd_ready <= (not i_icb_rsp_valid) and wb_ack;

  i_icb_rsp_err   <= '0'; -- Wishbone have no error response
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the simple-ICB bus to APB bus conversion 
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb2apb is 
  generic( 
           AW:             integer := 32;
           FIFO_OUTS_NUM:  integer := 8;
           FIFO_CUT_READY: integer := 0;
           DW:             integer := 64 -- 64 or 32 bits
  );
  port ( 
         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;
         i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
                  
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
         
         apb_paddr:           out  std_logic_vector(AW-1 downto 0);  
         apb_pwrite:          out  std_logic;   
         apb_pselx:           out  std_logic;                        
         apb_penable:         out  std_logic;   
         apb_pwdata:          out  std_logic_vector(DW-1 downto 0);                        
         apb_prdata:           in  std_logic_vector(DW-1 downto 0);                        
         
         clk:                  in  std_logic;
         rst_n:                in  std_logic        
  );
end sirv_gnrl_icb2apb;

-- Since the APB reponse channel does not have handhake scheme, but the
--   ICB have, so the response may not be accepted by the upstream master
--   So in order to make sure the functionality is correct, we must put
--   a reponse bypass-buffer here, to always be able to accept response from apb
architecture impl of sirv_gnrl_icb2apb is 
  signal apb_enable_r:   std_logic_vector(0 downto 0);
  signal apb_enable_set: std_logic;
  signal apb_enable_clr: std_logic;
  signal apb_enable_ena: std_logic;
  signal apb_enable_nxt: std_logic_vector(0 downto 0);

  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
          i_rdy: out std_logic;                          -- upsteam    i_vld --> o_vld --> downward
          i_dat:  in std_logic_vector( DW-1 downto 0 );  ----------
          
          o_vld: out std_logic;                          ------------
          o_rdy:  in std_logic;                          -- downsteam  o_rdy --> i_rdy --> upward
          o_dat: out std_logic_vector( DW-1 downto 0 );  ------------

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
begin
  u_rsp_fifo: component sirv_gnrl_fifo generic map( CUT_READY => 1,
                                                    MSKO      => 0,
                                                    DP        => 1,
                                                    DW        => DW
                                                  )
                                          port map( i_vld => apb_enable_r(0),
                                                    i_rdy => OPEN,
                                                    i_dat => apb_prdata,
                                                    o_vld => i_icb_rsp_valid,
                                                    o_rdy => i_icb_rsp_ready,  
                                                    o_dat => i_icb_rsp_rdata,
                                                    clk   => clk,
                                                    rst_n => rst_n
                                                  );
  i_icb_rsp_err <= '0';
  -- apb enable will be set if it is now not set and the new icb valid is coming
  -- And we only initiate the reqeust when the response buffer is empty, to make
  -- sure when the response back from APB we can alway be able to 
  apb_enable_set <= (not apb_enable_r(0)) and i_icb_cmd_valid and (not i_icb_rsp_valid);

  -- apb enable will be clear if it is now already set
  apb_enable_clr    <= apb_enable_r(0);
  apb_enable_ena    <= apb_enable_set or apb_enable_clr;
  apb_enable_nxt(0) <= apb_enable_set and (not apb_enable_clr);
  apb_enable_dfflr: entity work.sirv_gnrl_dfflr(impl_better) 
                    generic map(1)
                       port map(apb_enable_ena, apb_enable_nxt, apb_enable_r, clk, rst_n);

  i_icb_cmd_ready <= apb_enable_r(0) and (not i_icb_rsp_valid);

  apb_paddr  <= i_icb_cmd_addr;
  apb_pwrite <= (not i_icb_cmd_read(0));
  apb_pselx  <= i_icb_cmd_valid;
  apb_penable<= apb_enable_r(0);
  apb_pwdata <= i_icb_cmd_wdata;
end impl;

-- ===========================================================================
--
-- Description:
--  The module to handle the simple-ICB bus to AHB-lite bus conversion 
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_icb2ahbl is 
  generic( 
           AW:             integer := 32;
           DW:             integer := 32 
  );
  port ( 
         icb_cmd_valid:      in  std_logic;
         icb_cmd_ready:     out  std_logic;
         icb_cmd_read:       in  std_logic;
         icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         icb_cmd_size:       in  std_logic_vector(1 downto 0);
         icb_cmd_lock:       in  std_logic;
         icb_cmd_excl:       in  std_logic;
         icb_cmd_burst:      in  std_logic_vector(1 downto 0);
         icb_cmd_beat:       in  std_logic_vector(1 downto 0);
                  
         icb_rsp_valid:     out  std_logic;
         icb_rsp_ready:      in  std_logic;
         icb_rsp_err:       out  std_logic;
         icb_rsp_excl_ok:   out  std_logic;
         icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
         
         ahbl_htrans:       out  std_logic_vector(1 downto 0);
         ahbl_hwrite:       out  std_logic;
         ahbl_haddr:        out  std_logic_vector(AW-1 downto 0);
         ahbl_hsize:        out  std_logic_vector(2 downto 0);  
         ahbl_hlock:        out  std_logic;   
         ahbl_hexcl:        out  std_logic;
         ahbl_hburst:       out  std_logic_vector(2 downto 0);                                    
         ahbl_hwdata:       out  std_logic_vector(DW-1 downto 0);
         ahbl_hprot:        out  std_logic_vector(3 downto 0);
         ahbl_hattri:       out  std_logic_vector(1 downto 0);
         ahbl_master:       out  std_logic_vector(1 downto 0);

         ahbl_hrdata:        in  std_logic_vector(DW-1 downto 0);
         ahbl_hresp:         in  std_logic_vector(1 downto 0);                        
         ahbl_hresp_exok:    in  std_logic;
         ahbl_hready:        in  std_logic;

         clk:                in  std_logic;
         rst_n:              in  std_logic        
  );
end sirv_gnrl_icb2ahbl;

architecture impl of sirv_gnrl_icb2ahbl is  
  constant FSM_W : integer:= 2;
  constant STA_AR: std_logic_vector(1 downto 0):= "00"; 
  constant STA_WD: std_logic_vector(1 downto 0):= "01";
  constant STA_RD: std_logic_vector(1 downto 0):= "10";

  signal ahbl_eff_trans: std_logic;
  signal to_wd_sta:      std_logic;
  signal to_rd_sta:      std_logic;
  signal to_ar_sta:      std_logic;
  signal ahbl_sta_is_ar: std_logic;

  signal ahbl_sta_r:     std_logic_vector(FSM_W-1 downto 0);
  signal ahbl_sta_nxt:   std_logic_vector(FSM_W-1 downto 0);

  signal ahbl_hwdata_r:  std_logic_vector(DW-1 downto 0);
  signal ahbl_hwdata_ena:std_logic;
begin
  ahbl_eff_trans <= ahbl_hready and ahbl_htrans(1);
  icb_cmd_ready  <= ahbl_hready;
  ahbl_htrans(1) <= icb_cmd_valid;
  ahbl_htrans(0) <= '0';

  -- FSM to check the AHB state
  to_wd_sta <= ahbl_eff_trans and ahbl_hwrite;
  to_rd_sta <= ahbl_eff_trans and (not ahbl_hwrite);
  to_ar_sta <= ahbl_hready    and (not ahbl_htrans(1));
  ahbl_sta_is_ar <= (ahbl_sta_r ?= STA_AR);

  -- FSM Next state comb logics
  ahbl_sta_nxt <= (    ((FSM_W-1 downto 0 => to_ar_sta) and (STA_AR)) 
                   or  ((FSM_W-1 downto 0 => to_wd_sta) and (STA_WD))
                   or  ((FSM_W-1 downto 0 => to_rd_sta) and (STA_RD))
                  ) when ahbl_hready = '1' else
                  ahbl_sta_r;

  -- FSM sequential logics
  ahbl_sta_dffr: entity work.sirv_gnrl_dffr(impl_better) 
                 generic map(FSM_W)
                    port map(ahbl_sta_nxt, ahbl_sta_r, clk, rst_n);
  
  ahbl_hwdata_ena <= to_wd_sta;
  ahbl_hwdata_dfflr: entity work.sirv_gnrl_dfflr(impl_better) 
                     generic map(DW)
                        port map(ahbl_hwdata_ena, icb_cmd_wdata, ahbl_hwdata_r, clk, rst_n);

  -- AHB control signal generation
  ahbl_hwrite <= not icb_cmd_read;    
  ahbl_haddr  <= icb_cmd_addr;    
  ahbl_hsize  <= ('0', icb_cmd_size);    
  ahbl_hexcl  <= icb_cmd_excl;    
  ahbl_hwdata <= ahbl_hwdata_r;

  ahbl_hprot  <= "0000";
  ahbl_hattri <= "00";
  ahbl_hlock  <= '0';
  ahbl_master <= "00";
  ahbl_hburst <= "000";

  icb_rsp_valid     <= ahbl_hready and (not ahbl_sta_is_ar);  
  icb_rsp_rdata     <= ahbl_hrdata;   
  icb_rsp_err       <= ahbl_hresp(0);
  icb_rsp_excl_ok   <= ahbl_hresp_exok;
end impl;



















-- ===========================================================================
--
-- Description:
--  Verilog module for the AXI bus pipeline stage
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_axi_buffer is 
  generic( CHNL_FIFO_DP:        integer := 2;  
           CHNL_FIFO_CUT_READY: integer := 2;
           AW:                  integer := 32;           
           DW:                  integer := 32
  );
  port ( 
        i_axi_arvalid:        in  std_logic;
        i_axi_arready:       out  std_logic;       
        i_axi_araddr:         in  std_logic_vector(AW-1 downto 0);
        i_axi_arcache:        in  std_logic_vector(3 downto 0);
        i_axi_arprot:         in  std_logic_vector(2 downto 0);
        i_axi_arlock:         in  std_logic_vector(1 downto 0); 
        i_axi_arburst:        in  std_logic_vector(1 downto 0);
        i_axi_arlen:          in  std_logic_vector(3 downto 0);
        i_axi_arsize:         in  std_logic_vector(2 downto 0);

        i_axi_awvalid:        in  std_logic;
        i_axi_awready:       out  std_logic;       
        i_axi_awaddr:         in  std_logic_vector(AW-1 downto 0);
        i_axi_awcache:        in  std_logic_vector(3 downto 0);
        i_axi_awprot:         in  std_logic_vector(2 downto 0);
        i_axi_awlock:         in  std_logic_vector(1 downto 0); 
        i_axi_awburst:        in  std_logic_vector(1 downto 0);
        i_axi_awlen:          in  std_logic_vector(3 downto 0);
        i_axi_awsize:         in  std_logic_vector(2 downto 0);

        i_axi_rvalid:        out std_logic;
        i_axi_rready:         in std_logic;
        i_axi_rdata:         out std_logic_vector(DW-1 downto 0);
        i_axi_rresp:         out std_logic_vector(1 downto 0);
        i_axi_rlast:         out std_logic;
 
        i_axi_wvalid:         in std_logic;
        i_axi_wready:        out std_logic;
        i_axi_wdata:          in std_logic_vector(DW-1 downto 0);
        i_axi_wstrb:          in std_logic_vector((DW/8)-1 downto 0);
        i_axi_wlast:          in std_logic;
              
        i_axi_bvalid:        out std_logic;
        i_axi_bready:         in std_logic;
        i_axi_bresp:         out std_logic_vector(1 downto 0);

        o_axi_arvalid:       out  std_logic;
        o_axi_arready:        in  std_logic;       
        o_axi_araddr:        out  std_logic_vector(AW-1 downto 0);
        o_axi_arcache:       out  std_logic_vector(3 downto 0);
        o_axi_arprot:        out  std_logic_vector(2 downto 0);
        o_axi_arlock:        out  std_logic_vector(1 downto 0); 
        o_axi_arburst:       out  std_logic_vector(1 downto 0);
        o_axi_arlen:         out  std_logic_vector(3 downto 0);
        o_axi_arsize:        out  std_logic_vector(2 downto 0);

        o_axi_awvalid:       out  std_logic;
        o_axi_awready:        in  std_logic;       
        o_axi_awaddr:        out  std_logic_vector(AW-1 downto 0);
        o_axi_awcache:       out  std_logic_vector(3 downto 0);
        o_axi_awprot:        out  std_logic_vector(2 downto 0);
        o_axi_awlock:        out  std_logic_vector(1 downto 0); 
        o_axi_awburst:       out  std_logic_vector(1 downto 0);
        o_axi_awlen:         out  std_logic_vector(3 downto 0);
        o_axi_awsize:        out  std_logic_vector(2 downto 0);

        o_axi_rvalid:         in  std_logic;
        o_axi_rready:        out  std_logic;
        o_axi_rdata:          in  std_logic_vector(DW-1 downto 0);
        o_axi_rresp:          in  std_logic_vector(1 downto 0);
        o_axi_rlast:          in  std_logic; 
        
        o_axi_wvalid:        out  std_logic; 
        o_axi_wready:         in  std_logic;         
        o_axi_wdata:         out  std_logic_vector(DW-1 downto 0);
        o_axi_wstrb:         out  std_logic_vector((DW/8)-1 downto 0);
        o_axi_wlast:         out  std_logic; 

        o_axi_bvalid:         in  std_logic;
        o_axi_bready:        out  std_logic;
        o_axi_bresp:          in  std_logic_vector(1 downto 0); 
        
        clk:                  in  std_logic;
        rst_n:                in  std_logic        
  );
end sirv_gnrl_axi_buffer;

architecture impl of sirv_gnrl_axi_buffer is 
  constant AR_CHNL_W: integer:= 4+3+2+4+3+2+AW;
  constant AW_CHNL_W: integer:= AR_CHNL_W;
  constant W_CHNL_W:  integer:= DW+(DW/8)+1;
  constant R_CHNL_W:  integer:= DW+2+1;
  constant B_CHNL_W:  integer:= 2;

  signal i_axi_ar_chnl: std_logic_vector(AR_CHNL_W-1 downto 0);
  signal o_axi_ar_chnl: std_logic_vector(AR_CHNL_W-1 downto 0);
  signal i_axi_aw_chnl: std_logic_vector(AW_CHNL_W-1 downto 0);
  signal o_axi_aw_chnl: std_logic_vector(AW_CHNL_W-1 downto 0);
  signal i_axi_w_chnl:  std_logic_vector(W_CHNL_W-1 downto 0);
  signal o_axi_w_chnl:  std_logic_vector(W_CHNL_W-1 downto 0);
  signal o_axi_r_chnl:  std_logic_vector(R_CHNL_W-1 downto 0);
  signal i_axi_r_chnl:  std_logic_vector(R_CHNL_W-1 downto 0);
  signal o_axi_b_chnl:  std_logic_vector(B_CHNL_W-1 downto 0);
  signal i_axi_b_chnl:  std_logic_vector(B_CHNL_W-1 downto 0);

  component sirv_gnrl_fifo is
    generic(CUT_READY: integer;
            MSKO:      integer; -- Mask out the data with valid or not
            DP:        integer; -- FIFO depth
            DW:        integer  -- FIFO width
    );
    port( i_vld:  in std_logic;                          ----------
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
  i_axi_ar_chnl<= (
                   i_axi_araddr,
                   i_axi_arcache,
                   i_axi_arprot ,
                   i_axi_arlock ,
                   i_axi_arburst,
                   i_axi_arlen  ,
                   i_axi_arsize  
                  );
  (
    o_axi_araddr,
    o_axi_arcache,
    o_axi_arprot ,
    o_axi_arlock ,
    o_axi_arburst,
    o_axi_arlen  ,
    o_axi_arsize   
  ) <= o_axi_ar_chnl;
  o_axi_ar_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CHNL_FIFO_CUT_READY,
                                                       MSKO      => 0,
                                                       DP        => CHNL_FIFO_DP,
                                                       DW        => AR_CHNL_W
                                                     )
                                             port map( i_rdy => i_axi_arready,
                                                       i_vld => i_axi_arvalid,
                                                       i_dat => i_axi_ar_chnl,
                                                       o_rdy => o_axi_arready,
                                                       o_vld => o_axi_arvalid,  
                                                       o_dat => o_axi_ar_chnl,
                                                       clk   => clk,
                                                       rst_n => rst_n
                                                     );
                                               
  i_axi_aw_chnl<= (i_axi_awaddr,
                   i_axi_awcache,
                   i_axi_awprot ,
                   i_axi_awlock ,
                   i_axi_awburst,
                   i_axi_awlen  ,
                   i_axi_awsize  
                  );
  (o_axi_awaddr,
   o_axi_awcache,
   o_axi_awprot ,
   o_axi_awlock ,
   o_axi_awburst,
   o_axi_awlen  ,
   o_axi_awsize  
  )<= o_axi_aw_chnl;
  o_axi_aw_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CHNL_FIFO_CUT_READY,
                                                       MSKO      => 0,
                                                       DP        => CHNL_FIFO_DP,
                                                       DW        => AW_CHNL_W
                                                     )
                                             port map( i_rdy => i_axi_awready,
                                                       i_vld => i_axi_awvalid,
                                                       i_dat => i_axi_aw_chnl,
                                                       o_rdy => o_axi_awready,
                                                       o_vld => o_axi_awvalid,  
                                                       o_dat => o_axi_aw_chnl,
                                                       clk   => clk,
                                                       rst_n => rst_n
                                                     );
  
  i_axi_w_chnl <= (
                  i_axi_wdata,
                  i_axi_wstrb,
                  i_axi_wlast
                  );
  (
  o_axi_wdata,
  o_axi_wstrb,
  o_axi_wlast
  ) <= o_axi_w_chnl;
  o_axi_wdata_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CHNL_FIFO_CUT_READY,
                                                          MSKO      => 0,
                                                          DP        => CHNL_FIFO_DP,
                                                          DW        => W_CHNL_W
                                                        )
                                                port map( i_rdy => i_axi_wready,
                                                          i_vld => i_axi_wvalid,
                                                          i_dat => i_axi_w_chnl,
                                                          o_rdy => o_axi_wready,
                                                          o_vld => o_axi_wvalid,  
                                                          o_dat => o_axi_w_chnl,
                                                          clk   => clk,
                                                          rst_n => rst_n
                                                        );
  
  o_axi_r_chnl <= (
                  o_axi_rdata,
                  o_axi_rresp,
                  o_axi_rlast
                  );
  (
  i_axi_rdata,
  i_axi_rresp,
  i_axi_rlast
  ) <= i_axi_r_chnl;
  o_axi_rdata_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CHNL_FIFO_CUT_READY,
                                                          MSKO      => 0,
                                                          DP        => CHNL_FIFO_DP,
                                                          DW        => R_CHNL_W
                                                        )
                                                port map( i_rdy => o_axi_rready,
                                                          i_vld => o_axi_rvalid,
                                                          i_dat => o_axi_r_chnl,
                                                          o_rdy => i_axi_rready,
                                                          o_vld => i_axi_rvalid,  
                                                          o_dat => i_axi_r_chnl,
                                                          clk   => clk,
                                                          rst_n => rst_n
                                                        );
  o_axi_b_chnl <= o_axi_bresp;
  i_axi_bresp <= i_axi_b_chnl;
  o_axi_bresp_fifo: component sirv_gnrl_fifo generic map( CUT_READY => CHNL_FIFO_CUT_READY,
                                                          MSKO      => 0,
                                                          DP        => CHNL_FIFO_DP,
                                                          DW        => B_CHNL_W
                                                        )
                                                port map( i_rdy => o_axi_bready,
                                                          i_vld => o_axi_bvalid,
                                                          i_dat => o_axi_b_chnl,
                                                          o_rdy => i_axi_bready,
                                                          o_vld => i_axi_bvalid,  
                                                          o_dat => i_axi_b_chnl,
                                                          clk   => clk,
                                                          rst_n => rst_n
                                                        );
end impl;