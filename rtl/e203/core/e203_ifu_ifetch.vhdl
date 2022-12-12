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
--  The Lite-BPU module to handle very simple branch predication at IFU 
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_ifu_ifetch is 
  port ( 
  	     inspect_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     pc_rtvec:          in std_logic_vector(E203_PC_SIZE-1 downto 0);

  	     -- Fetch Interface to memory system, internal protocol
         --    * IFetch REQ channel
  	     ifu_req_valid:    out std_logic;  -- Handshake valid
  	     ifu_req_ready:     in std_logic;  -- Handshake ready

  	     -- Note: the req-addr can be unaligned with the length indicated
         --       by req_len signal.
         --       The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --       will handle the unalign cases and split-and-merge works
  	     ifu_req_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);  -- Fetch PC
  	     ifu_req_seq:      out std_logic;  -- This request is a sequential instruction fetch
  	     ifu_req_seq_rv32: out std_logic;  -- This request is incremented 32bits fetch
         ifu_req_last_pc:  out std_logic_vector(E203_PC_SIZE-1 downto 0);  -- The last accessed
                                                                           -- PC address (i.e., pc_r)
  	     --  * IFetch RSP channel
  	     ifu_rsp_valid:     in std_logic;  -- Response valid
  	     ifu_rsp_ready:    out std_logic;  -- Response ready
  	     ifu_rsp_err:       in std_logic;  -- Response error
         -- Note: the RSP channel always return a valid instruction
         --   fetched from the fetching start PC address.
         --   The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --   will handle the unalign cases and split-and-merge works
         --input  ifu_rsp_replay,
         ifu_rsp_instr:     in std_logic_vector(E203_INSTR_SIZE-1 downto 0);

         -- The IR stage to EXU interface
         ifu_o_ir:         out std_logic_vector(E203_INSTR_SIZE-1 downto 0); -- The instruction register
         ifu_o_pc:         out std_logic_vector(E203_PC_SIZE-1 downto 0);    -- The PC register along with
         ifu_o_pc_vld:     out std_logic;
         ifu_o_rs1idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_rs2idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_prdt_taken: out std_logic;  -- The Bxx is predicted as taken
         ifu_o_misalgn:    out std_logic;  -- The fetch misalign 
         ifu_o_buserr:     out std_logic;  -- The fetch bus error
         ifu_o_muldiv_b2b: out std_logic;  -- The mul/div back2back case
         ifu_o_valid:      out std_logic;  -- Handshake signals with EXU stage
         ifu_o_ready:       in std_logic;

         pipe_flush_ack:   out std_logic;
         pipe_flush_req:    in std_logic;
         pipe_flush_add_op1:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         pipe_flush_add_op2:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `if E203_TIMING_BOOST = "TRUE" then
         pipe_flush_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `end if

         -- The halt request come from other commit stage
         --   If the ifu_halt_req is asserting, then IFU will stop fetching new 
         --     instructions and after the oustanding transactions are completed,
         --     asserting the ifu_halt_ack as the response.
         --   The IFU will resume fetching only after the ifu_halt_req is deasserted
         ifu_halt_req:      in std_logic;
  	     ifu_halt_ack:     out std_logic;

  	     oitf_empty:        in std_logic;
  	     rf2ifu_x1:         in std_logic_vector(E203_XLEN-1 downto 0);
         rf2ifu_rs1:        in std_logic_vector(E203_XLEN-1 downto 0);
  	     dec2ifu_rs1en:     in std_logic;
         dec2ifu_rden:      in std_logic;
         dec2ifu_rdidx:     in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec2ifu_mulhsu:    in std_logic;
         dec2ifu_div:       in std_logic;
  	     dec2ifu_rem:       in std_logic;
  	     dec2ifu_divu:      in std_logic;
  	     dec2ifu_remu:      in std_logic;

         clk:               in std_logic;
         rst_n:             in std_logic
  );
end e203_ifu_ifetch;

architecture impl of e203_ifu_ifetch is 
  signal ifu_req_hsked:    std_ulogic;
  signal ifu_rsp_hsked:    std_ulogic;
  signal ifu_ir_o_hsked:   std_ulogic;
  signal pipe_flush_hsked: std_ulogic;
  signal reset_flag_r:     std_ulogic;
  
  signal reset_req_set:    std_ulogic;
  signal reset_req_clr:    std_ulogic;
  signal reset_req_ena:    std_ulogic;
  signal reset_req_nxt:    std_ulogic;
  signal reset_req_r:      std_ulogic;
  signal ifu_reset_req:    std_ulogic;

  signal halt_ack_set:     std_ulogic;
  signal halt_ack_clr:     std_ulogic;
  signal halt_ack_ena:     std_ulogic;
  signal halt_ack_r:       std_ulogic;
  signal halt_ack_nxt:     std_ulogic;
  signal ifu_no_outs:      std_ulogic;

  signal dly_flush_set:       std_ulogic;
  signal dly_flush_clr:       std_ulogic;
  signal dly_flush_ena:       std_ulogic;
  signal dly_flush_nxt:       std_ulogic;
  signal dly_flush_r:         std_ulogic;
  signal dly_pipe_flush_req:  std_ulogic;
  signal pipe_flush_req_real: std_ulogic;

  signal ir_valid_set:        std_ulogic;
  signal ir_valid_clr:        std_ulogic;
  signal ir_valid_ena:        std_ulogic;
  signal ir_valid_r:          std_ulogic;
  signal ir_valid_nxt:        std_ulogic;

  signal ir_pc_vld_set:       std_ulogic;
  signal ir_pc_vld_clr:       std_ulogic;
  signal ir_pc_vld_ena:       std_ulogic;
  signal ir_pc_vld_r:         std_ulogic;
  signal ir_pc_vld_nxt:       std_ulogic;

  signal ifu_rsp_need_replay: std_ulogic;
  signal pc_newpend_r:        std_ulogic;
  signal ifu_ir_i_ready:      std_ulogic;

  signal ifu_ir_nxt:          std_ulogic_vector(E203_INSTR_SIZE-1 downto 0);
  signal ifu_err_nxt:         std_ulogic;
  signal ifu_err_r:           std_ulogic;
  signal prdt_taken:          std_ulogic;
  signal ifu_prdt_taken_r:    std_ulogic;
  signal ifu_muldiv_b2b_nxt:  std_ulogic;
  signal ifu_muldiv_b2b_r:    std_ulogic;

  signal ifu_ir_r:            std_ulogic_vector(E203_INSTR_SIZE-1 downto 0); -- The instruction register
  signal minidec_rv32:        std_ulogic;
  signal ir_hi_ena:           std_ulogic;
  signal ir_lo_ena:           std_ulogic;
  signal minidec_rs1en:       std_ulogic;
  signal minidec_rs2en:       std_ulogic;
  signal minidec_rs1idx:      std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal minidec_rs2idx:      std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  
  `if E203_HAS_FPU = "FALSE" then
  constant minidec_fpu:         std_ulogic:= '0';
  constant minidec_fpu_rs1en:   std_ulogic:= '0';
  constant minidec_fpu_rs2en:   std_ulogic:= '0';
  constant minidec_fpu_rs3en:   std_ulogic:= '0';
  constant minidec_fpu_rs1fpu:  std_ulogic:= '0';
  constant minidec_fpu_rs2fpu:  std_ulogic:= '0';
  constant minidec_fpu_rs3fpu:  std_ulogic:= '0';
  constant minidec_fpu_rs1idx:  std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  constant minidec_fpu_rs2idx:  std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  `end if

  signal bpu2rf_rs1_ena:        std_ulogic;
  signal ir_rs1idx_r:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal ir_rs2idx_r:           std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal ir_rs1idx_ena:         std_ulogic;
  signal ir_rs2idx_ena:         std_ulogic;
  signal ir_rs1idx_nxt:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal ir_rs2idx_nxt:         std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  
  signal pc_r:                  std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal ifu_pc_nxt:            std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal ifu_pc_r:              std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  

  signal ir_empty:                std_ulogic;
  signal ir_rs1en:                std_ulogic;
  signal ir_rden:                 std_ulogic;
  signal ir_rdidx:                std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal minidec_jalr_rs1idx:     std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal minidec_jalr_rs1idx_cp:  std_ulogic;
  signal jalr_rs1idx_cam_irrdidx: std_ulogic;

  signal minidec_mul:             std_ulogic;
  signal minidec_div:             std_ulogic;
  signal minidec_rem:             std_ulogic;
  signal minidec_divu:            std_ulogic;
  signal minidec_remu:            std_ulogic;

  signal ir_rs1idx_cp:            std_ulogic;
  signal ir_rs2idx_cp:            std_ulogic;
  signal ir_rdidx1_cp:            std_ulogic;
  signal ir_rdidx2_cp:            std_ulogic;

  signal minidec_bjp:             std_ulogic;
  signal minidec_jal:             std_ulogic;
  signal minidec_jalr:            std_ulogic;
  signal minidec_bxx:             std_ulogic;
  signal minidec_bjp_imm:         std_ulogic_vector(E203_XLEN-1 downto 0);

  signal bpu_wait:                std_ulogic;
  signal prdt_pc_add_op1:         std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal prdt_pc_add_op2:         std_ulogic_vector(E203_PC_SIZE-1 downto 0);

  signal pc_incr_ofst:            std_ulogic_vector(2 downto 0);
  signal pc_nxt_pre:              std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal pc_nxt:                  std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal bjp_req:                 std_ulogic;
  signal ifetch_replay_req:       std_ulogic;
  signal pc_add_op1:              std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal pc_add_op2:              std_ulogic_vector(E203_PC_SIZE-1 downto 0);

  signal ifu_new_req:             std_ulogic;
  signal ifu_req_valid_pre:       std_ulogic;
  signal out_flag_clr:            std_ulogic;
  signal out_flag_r:              std_ulogic;
  signal new_req_condi:           std_ulogic;

  signal ifu_rsp2ir_ready:        std_ulogic;

  signal pc_ena:                  std_ulogic;

  signal out_flag_set:            std_ulogic;
  signal out_flag_ena:            std_ulogic;
  signal out_flag_nxt:            std_ulogic;

  signal pc_newpend_set:          std_ulogic;
  signal pc_newpend_clr:          std_ulogic;
  signal pc_newpend_ena:          std_ulogic;
  signal pc_newpend_nxt:          std_ulogic;
  

  component sirv_gnrl_dffrs is
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

  component e203_ifu_minidec is 
    port(
        --------------------------------------------------------------
        -- The IR stage to Decoder
        --------------------------------------------------------------
        instr:            in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
    
        --------------------------------------------------------------
        -- The Decoded Info-Bus
        --------------------------------------------------------------
        dec_rs1en:       out std_logic;
        dec_rs2en:       out std_logic;
        dec_rs1idx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
        dec_rs2idx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        
        dec_mulhsu:      out std_logic;
        dec_mul:         out std_logic;
        dec_div:         out std_logic;
        dec_rem:         out std_logic;
        dec_divu:        out std_logic;
        dec_remu:        out std_logic;
  
        dec_rv32:        out std_logic;
        dec_bjp:         out std_logic;
        dec_jal:         out std_logic;
        dec_jalr:        out std_logic;
        dec_bxx:         out std_logic;
        dec_jalr_rs1idx: out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
        dec_bjp_imm:     out std_logic_vector(E203_XLEN-1 downto 0)
  
    );
  end component;
  component e203_ifu_litebpu is 
    port ( 
    	   -- Current PC
    	   pc:              in std_logic_vector(E203_PC_SIZE-1 downto 0);

    	   -- The mini-decoded info
    	   dec_jal:         in std_logic;
    	   dec_jalr:        in std_logic;
    	   dec_bxx:         in std_logic;
           dec_bjp_imm:     in std_logic_vector(E203_XLEN-1 downto 0);
           dec_jalr_rs1idx: in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
           
           -- The IR index and OITF status to be used for checking dependency
           oitf_empty:              in std_logic;
    	   ir_empty:                in std_logic;
    	   ir_rs1en:                in std_logic;
    	   jalr_rs1idx_cam_irrdidx: in std_logic;

    	   -- The add op to next-pc adder
    	   bpu_wait:        out std_logic;
    	   prdt_taken:      out std_logic;
    	   prdt_pc_add_op1: out std_logic_vector(E203_PC_SIZE-1 downto 0);
    	   prdt_pc_add_op2: out std_logic_vector(E203_PC_SIZE-1 downto 0);

    	   dec_i_valid:      in std_logic;

    	   -- The RS1 to read regfile
    	   bpu2rf_rs1_ena:  out std_logic;
    	   ir_valid_clr:     in std_logic;
    	   rf2bpu_x1:        in std_logic_vector(E203_XLEN-1 downto 0);
           rf2bpu_rs1:       in std_logic_vector(E203_XLEN-1 downto 0);
           
           clk:              in std_logic;
           rst_n:            in std_logic
    );
  end component;
begin
  ifu_req_hsked    <= (ifu_req_valid and ifu_req_ready) ;
  ifu_rsp_hsked    <= (ifu_rsp_valid and ifu_rsp_ready) ;
  ifu_ir_o_hsked   <= (ifu_o_valid and ifu_o_ready) ;
  pipe_flush_hsked <= pipe_flush_req and pipe_flush_ack;
  -- The rst_flag is the synced version of rst_n
  --    * rst_n is asserted 
  -- The rst_flag will be clear when
  --    * rst_n is de-asserted 
  reset_flag_dffrs: component sirv_gnrl_dffrs generic map (1)
                                                 port map (
                                                           dnxt(0)=> '0',
                                                           qout(0)=> reset_flag_r,
                                                           clk    => clk,
                                                           rst_n  => rst_n
                                                 	      );

  -- The reset_req valid is set when 
  --    * Currently reset_flag is asserting
  -- The reset_req valid is clear when 
  --    * Currently reset_req is asserting
  --    * Currently the flush can be accepted by IFU
  reset_req_set <= (not reset_req_r) and reset_flag_r;
  reset_req_clr <= reset_req_r and ifu_req_hsked;
  reset_req_ena <= reset_req_set or reset_req_clr;
  reset_req_nxt <= reset_req_set or (not reset_req_clr);
  reset_req_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => reset_req_ena,
                                                          dnxt(0)=> reset_req_nxt,
                                                          qout(0)=> reset_req_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  ifu_reset_req <= reset_req_r;

  -- The halt_ack will be set when
  --    * Currently halt_req is asserting
  --    * Currently halt_ack is not asserting
  --    * Currently the ifetch REQ channel is ready, means
  --        there is no oustanding transactions
  halt_ack_set <= ifu_halt_req and (not halt_ack_r) and ifu_no_outs;
  -- The halt_ack_r valid is cleared when 
  --    * Currently halt_ack is asserting
  --    * Currently halt_req is de-asserting
  halt_ack_clr <= halt_ack_r and (not ifu_halt_req);
  halt_ack_ena <= halt_ack_set or halt_ack_clr;
  halt_ack_nxt <= halt_ack_set or (not halt_ack_clr);
  halt_ack_dfflr: component sirv_gnrl_dfflr generic map (1)
                                               port map (lden   => halt_ack_ena,
                                                         dnxt(0)=> halt_ack_nxt,
                                                         qout(0)=> halt_ack_r,
                                                         clk    => clk,
                                                         rst_n  => rst_n
                                                        );
  ifu_halt_ack <= halt_ack_r;

  -- The flush ack signal generation
  --
  --   Ideally the flush is acked when the ifetch interface is ready
  --     or there is rsponse valid 
  --   But to cut the comb loop between EXU and IFU, we always accept
  --     the flush, when it is not really acknowledged, we use a 
  --     delayed flush indication to remember this flush
  --   Note: Even if there is a delayed flush pending there, we
  --     still can accept new flush request
  pipe_flush_ack <= '1';
  
  -- The dly_flush will be set when
  --    * There is a flush requst is coming, but the ifu
  --        is not ready to accept new fetch request
  dly_flush_set <= pipe_flush_req and (not ifu_req_hsked);

  -- The dly_flush_r valid is cleared when 
  --    * The delayed flush is issued
  dly_flush_clr <= dly_flush_r and ifu_req_hsked;
  dly_flush_ena <= dly_flush_set or dly_flush_clr;
  dly_flush_nxt <= dly_flush_set or (not dly_flush_clr);
  dly_flush_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => dly_flush_ena,
                                                          dnxt(0)=> dly_flush_nxt,
                                                          qout(0)=> dly_flush_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  dly_pipe_flush_req  <= dly_flush_r;
  pipe_flush_req_real <= pipe_flush_req or dly_pipe_flush_req;

  -- The IR register to be used in EXU for decoding
  -- The ir valid is set when there is new instruction fetched *and* 
  --   no flush happening 
  ir_valid_set  <= ifu_rsp_hsked and (not pipe_flush_req_real) and (not ifu_rsp_need_replay);
  ir_pc_vld_set <= pc_newpend_r and ifu_ir_i_ready and (not pipe_flush_req_real) and (not ifu_rsp_need_replay);
     
  -- The ir valid is cleared when it is accepted by EXU stage *or*
  --   the flush happening 
  ir_valid_clr  <= ifu_ir_o_hsked or (pipe_flush_hsked and ir_valid_r);
  ir_pc_vld_clr <= ir_valid_clr;
  ir_valid_ena  <= ir_valid_set   or ir_valid_clr;
  ir_valid_nxt  <= ir_valid_set   or (not ir_valid_clr);
  ir_pc_vld_ena <= ir_pc_vld_set  or ir_pc_vld_clr;
  ir_pc_vld_nxt <= ir_pc_vld_set  or (not ir_pc_vld_clr);
  ir_valid_dfflr:  component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ir_valid_ena,
                                                          dnxt(0)=> ir_valid_nxt,
                                                          qout(0)=> ir_valid_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  ir_pc_vld_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ir_pc_vld_ena,
                                                          dnxt(0)=> ir_pc_vld_nxt,
                                                          qout(0)=> ir_pc_vld_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );

  -- IFU-IR loaded with the returned instruction from the IFetch RSP channel
  ifu_ir_nxt  <= ifu_rsp_instr;
  -- IFU-PC loaded with the current PC
  ifu_err_nxt <= ifu_rsp_err;
  -- IFU-IR and IFU-PC as the datapath register, only loaded and toggle when the valid reg is set
  ifu_err_dfflr: component sirv_gnrl_dfflr  generic map (1)
                                               port map (lden   => ir_valid_set,
                                                         dnxt(0)=> ifu_err_nxt,
                                                         qout(0)=> ifu_err_r,
                                                         clk    => clk,
                                                         rst_n  => rst_n
                                                        );
  ifu_prdt_taken_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                     port map (lden   => ir_valid_set,
                                                               dnxt(0)=> prdt_taken,
                                                               qout(0)=> ifu_prdt_taken_r,
                                                               clk    => clk,
                                                               rst_n  => rst_n
                                                              );
  ir_muldiv_b2b_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                    port map (lden   => ir_valid_set,
                                                              dnxt(0)=> ifu_muldiv_b2b_nxt,
                                                              qout(0)=> ifu_muldiv_b2b_r,
                                                              clk    => clk,
                                                              rst_n  => rst_n
                                                             );

  -- To save power the H-16bits only loaded when it is 32bits length instru
  ir_hi_ena <= ir_valid_set and minidec_rv32;
  ir_lo_ena <= ir_valid_set;
  ifu_hi_ir_dfflr: component sirv_gnrl_dfflr generic map (E203_INSTR_SIZE/2)
                                                port map (lden   => ir_hi_ena,
                                                          dnxt   => ifu_ir_nxt(31 downto 16),
                                                          qout   => ifu_ir_r(31 downto 16),
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  ifu_lo_ir_dfflr: component sirv_gnrl_dfflr generic map (E203_INSTR_SIZE/2)
                                                port map (lden   => ir_lo_ena,
                                                          dnxt   => ifu_ir_nxt(15 downto 0),
                                                          qout   => ifu_ir_r(15 downto 0),
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  
  -- FPU: if it is FPU instruction. we still need to put it into the IR register, but we need to mask off the non-integer regfile index to save power
  ir_rs1idx_ena <= (minidec_fpu and ir_valid_set and minidec_fpu_rs1en and (not minidec_fpu_rs1fpu)) or ((not minidec_fpu) and ir_valid_set and minidec_rs1en) or bpu2rf_rs1_ena;
  ir_rs2idx_ena <= (minidec_fpu and ir_valid_set and minidec_fpu_rs2en and (not minidec_fpu_rs2fpu)) or ((not minidec_fpu) and ir_valid_set and minidec_rs2en);
  ir_rs1idx_nxt <= minidec_fpu_rs1idx when minidec_fpu = '1' else minidec_rs1idx;
  ir_rs2idx_nxt <= minidec_fpu_rs2idx when minidec_fpu = '1' else minidec_rs2idx;
  ir_rs1idx_dfflr: component sirv_gnrl_dfflr generic map (E203_RFIDX_WIDTH)
                                                port map (lden   => ir_rs1idx_ena,
                                                          dnxt   => ir_rs1idx_nxt,
                                                          qout   => ir_rs1idx_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  ir_rs2idx_dfflr: component sirv_gnrl_dfflr generic map (E203_RFIDX_WIDTH)
                                                port map (lden   => ir_rs2idx_ena,
                                                          dnxt   => ir_rs2idx_nxt,
                                                          qout   => ir_rs2idx_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  
  ifu_pc_nxt <= pc_r;
  ifu_pc_dfflr: component sirv_gnrl_dfflr generic map (E203_PC_SIZE)
                                             port map (lden   => ir_pc_vld_set,
                                                       dnxt   => ifu_pc_nxt,
                                                       qout   => ifu_pc_r,
                                                       clk    => clk,
                                                       rst_n  => rst_n
                                                      );
  ifu_o_ir  <= ifu_ir_r;
  ifu_o_pc  <= ifu_pc_r;
  
  -- Instruction fetch misaligned exceptions are not possible on machines that support extensions
  -- with 16-bit aligned instructions, such as the compressed instruction set extension, C.
  ifu_o_misalgn    <= '0';  -- Never happen in RV32C configuration 
  ifu_o_buserr     <= ifu_err_r;
  ifu_o_rs1idx     <= ir_rs1idx_r;
  ifu_o_rs2idx     <= ir_rs2idx_r;
  ifu_o_prdt_taken <= ifu_prdt_taken_r;
  ifu_o_muldiv_b2b <= ifu_muldiv_b2b_r;

  ifu_o_valid      <= ir_valid_r;
  ifu_o_pc_vld     <= ir_pc_vld_r;

  -- The IFU-IR stage will be ready when it is empty or under-clearing
  ifu_ir_i_ready   <= (not ir_valid_r) or ir_valid_clr;

  -- JALR instruction dependency check
  ir_empty <= not ir_valid_r;
  ir_rs1en <= dec2ifu_rs1en;
  ir_rden  <= dec2ifu_rden;
  ir_rdidx <= dec2ifu_rdidx;
  minidec_jalr_rs1idx_cp <= '1' when (minidec_jalr_rs1idx ?= ir_rdidx) = '1' else
  	                        '0';
  jalr_rs1idx_cam_irrdidx <= ir_rden and minidec_jalr_rs1idx_cp and ir_valid_r;

  -- MULDIV BACK2BACK Fusing
  -- To detect the sequence of MULH[[S]U] rdh, rs1, rs2;    MUL rdl, rs1, rs2
  -- To detect the sequence of     DIV[U] rdq, rs1, rs2; REM[U] rdr, rs1, rs2 
  ir_rs1idx_cp <= '1' when (ir_rs1idx_r ?= ir_rs1idx_nxt) = '1' else
  	              '0';
  ir_rs2idx_cp <= '1' when (ir_rs2idx_r ?= ir_rs2idx_nxt) = '1' else
  	              '0';
  ir_rdidx1_cp <= '1' when (ir_rs1idx_r ?= ir_rdidx) = '1' else
  	              '0';
  ir_rdidx2_cp <= '1' when (ir_rs2idx_r ?= ir_rdidx) = '1' else
  	              '0';           
  ifu_muldiv_b2b_nxt <= 
                       (
                           -- For multiplicaiton, only the MUL instruction following
                           --    MULH/MULHU/MULSU can be treated as back2back
                            ( minidec_mul  and dec2ifu_mulhsu)
                           -- For divider and reminder instructions, only the following cases
                           --    can be treated as back2back
                           --      * DIV--REM
                           --      * REM--DIV
                           --      * DIVU--REMU
                           --      * REMU--DIVU
                         or ( minidec_div  and dec2ifu_rem)
                         or ( minidec_rem  and dec2ifu_div)
                         or ( minidec_divu and dec2ifu_remu)
                         or ( minidec_remu and dec2ifu_divu)
                       )
                       -- The last rs1 and rs2 indexes are same as this instruction
                       and ir_rs1idx_cp
                       and ir_rs2idx_cp
                       -- The last rs1 and rs2 indexes are not same as last RD index
                       and (not ir_rdidx1_cp)
                       and (not ir_rdidx2_cp)
                       ;

  -- Next PC generation
  -- The mini-decoder to check instruciton length and branch type
  u_e203_ifu_minidec: component e203_ifu_minidec
                       port map ( instr           => ifu_ir_nxt         ,
    
                                  dec_rs1en       => minidec_rs1en      ,
                                  dec_rs2en       => minidec_rs2en      ,
                                  dec_rs1idx      => minidec_rs1idx     ,
                                  dec_rs2idx      => minidec_rs2idx     ,
                                
                                  dec_rv32        => minidec_rv32       ,
                                  dec_bjp         => minidec_bjp        ,
                                  dec_jal         => minidec_jal        ,
                                  dec_jalr        => minidec_jalr       ,
                                  dec_bxx         => minidec_bxx        ,
                                
                                  dec_mulhsu      => OPEN               ,
                                  dec_mul         => minidec_mul        ,
                                  dec_div         => minidec_div        ,
                                  dec_rem         => minidec_rem        ,
                                  dec_divu        => minidec_divu       ,
                                  dec_remu        => minidec_remu       ,
                            
                                  dec_jalr_rs1idx => minidec_jalr_rs1idx,
                                  dec_bjp_imm     => minidec_bjp_imm    

                       	        );
  
  u_e203_ifu_litebpu: component e203_ifu_litebpu
                       port map ( pc                      => pc_r,
                        
                                  dec_jal                 => minidec_jal ,
                                  dec_jalr                => minidec_jalr,
                                  dec_bxx                 => minidec_bxx ,
                                  dec_bjp_imm             => minidec_bjp_imm,
                                  dec_jalr_rs1idx         => minidec_jalr_rs1idx,
                              
                                  dec_i_valid             => ifu_rsp_valid,
                                  ir_valid_clr            => ir_valid_clr ,
                                
                                  oitf_empty              => oitf_empty,
                                  ir_empty                => ir_empty  ,
                                  ir_rs1en                => ir_rs1en  ,
                             
                                  jalr_rs1idx_cam_irrdidx => jalr_rs1idx_cam_irrdidx,
                                
                                  bpu_wait                => bpu_wait       ,  
                                  prdt_taken              => prdt_taken     ,  
                                  prdt_pc_add_op1         => prdt_pc_add_op1,  
                                  prdt_pc_add_op2         => prdt_pc_add_op2,
                              
                                  bpu2rf_rs1_ena          => bpu2rf_rs1_ena ,
                                  rf2bpu_x1               => rf2ifu_x1      ,
                                  rf2bpu_rs1              => rf2ifu_rs1     ,
                              
                                  clk                     => clk,
                                  rst_n                   => rst_n 
                       	        );

  -- If the instruciton is 32bits length, increament 4, otherwise 2
  pc_incr_ofst <= 3d"4" when minidec_rv32 = '1' else 3d"2";
  bjp_req <= minidec_bjp and prdt_taken;
  
  pc_add_op1 <=
  `if E203_TIMING_BOOST = "FALSE" then
    pipe_flush_add_op1 when pipe_flush_req     = '1' else
    pc_r               when dly_pipe_flush_req = '1' else
  `end if
    pc_r               when ifetch_replay_req  = '1' else
    prdt_pc_add_op1    when bjp_req            = '1' else
    pc_rtvec           when ifu_reset_req      = '1' else
    pc_r;
  
  pc_add_op2 <=
  `if E203_TIMING_BOOST = "FALSE" then
    pipe_flush_add_op2               when pipe_flush_req     = '1' else
    (E203_PC_SIZE-1 downto 0 => '0') when dly_pipe_flush_req = '1' else
  `end if
    (E203_PC_SIZE-1 downto 0 => '0') when ifetch_replay_req  = '1' else
    prdt_pc_add_op2                  when bjp_req            = '1' else
    (E203_PC_SIZE-1 downto 0 => '0') when ifu_reset_req      = '1' else
    (E203_PC_SIZE-1 downto 3 => '0', 2 downto 0 => pc_incr_ofst);

  ifu_req_seq <= (not pipe_flush_req_real) and (not ifu_reset_req) and (not ifetch_replay_req) and (not bjp_req);
  ifu_req_seq_rv32 <= minidec_rv32;
  ifu_req_last_pc <= pc_r;

  pc_nxt_pre <= std_logic_vector(u_signed(pc_add_op1) + u_signed(pc_add_op2));
  
  `if E203_TIMING_BOOST = "FALSE" then
  pc_nxt <= (pc_nxt_pre(E203_PC_SIZE-1 downto 1),'0');  
  `end if
  `if E203_TIMING_BOOST = "TRUE" then
  pc_nxt <= (pipe_flush_pc(E203_PC_SIZE-1 downto 1),'0') when pipe_flush_req     = '1' else
  	        (         pc_r(E203_PC_SIZE-1 downto 1),'0') when dly_pipe_flush_req = '1' else
  	        (   pc_nxt_pre(E203_PC_SIZE-1 downto 1),'0');  
  `end if
  
  -- The Ifetch issue new ifetch request when
  --   * If it is a bjp insturction, and it does not need to wait, and it is not a replay-set cycle
  --   * and there is no halt_request
  ifu_new_req <= (not bpu_wait) and (not ifu_halt_req) and (not reset_flag_r) and (not ifu_rsp_need_replay);

  -- The fetch request valid is triggering when
  --      * New ifetch request
  --      * or The flush-request is pending
  ifu_req_valid_pre <= ifu_new_req or ifu_reset_req or pipe_flush_req_real or ifetch_replay_req;
  
  -- The new request ready condition is:
  --   * No outstanding reqeusts
  --   * Or if there is outstanding, but it is reponse valid back
  new_req_condi <= (not out_flag_r) or out_flag_clr;
  ifu_no_outs   <= (not out_flag_r) or ifu_rsp_valid;

  -- Here we use the rsp_valid rather than the out_flag_clr (ifu_rsp_hsked) because
  --   as long as the rsp_valid is asserting then means last request have returned the
  --   response back, in WFI case, we cannot expect it to be handshaked (otherwise deadlock)
  ifu_req_valid <= ifu_req_valid_pre and new_req_condi;

  ifu_rsp2ir_ready <= '1' when pipe_flush_req_real = '1' else
                      (ifu_ir_i_ready and ifu_req_ready and (not bpu_wait));

  -- Response channel only ready when:
  --   * IR is ready to accept new instructions
  ifu_rsp_ready <= ifu_rsp2ir_ready;

  -- The PC will need to be updated when ifu req channel handshaked or a flush is incoming
  pc_ena <= ifu_req_hsked or pipe_flush_hsked;
  pc_dfflr: component sirv_gnrl_dfflr generic map (E203_PC_SIZE)
                                         port map (lden   => pc_ena,
                                                   dnxt   => pc_nxt,
                                                   qout   => pc_r,
                                                   clk    => clk,
                                                   rst_n  => rst_n 
                                         	      );
  
  inspect_pc <= pc_r;

  -- The out_flag will be set if there is a new request handshaked
  out_flag_set <= ifu_req_hsked;
  out_flag_ena <= out_flag_set or out_flag_clr;
  -- If meanwhile set and clear, then set preempt
  out_flag_nxt <= out_flag_set or (not out_flag_clr);
  out_flag_dfflr: component sirv_gnrl_dfflr generic map (1)
                                               port map (lden   => out_flag_ena,
                                                         dnxt(0)=> out_flag_nxt,
                                                         qout(0)=> out_flag_r,
                                                         clk    => clk,
                                                         rst_n  => rst_n 
                                               	        );

  -- The pc_newpend will be set if there is a new PC loaded
  pc_newpend_set <= pc_ena;
  -- The pc_newpend will be cleared if have already loaded into the IR-PC stage
  pc_newpend_clr <= ir_pc_vld_set;
  pc_newpend_ena <= pc_newpend_set or pc_newpend_clr;
  -- If meanwhile set and clear, then set preempt
  pc_newpend_nxt <= pc_newpend_set or (not pc_newpend_clr);
  pc_newpend_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                 port map (lden   => pc_newpend_ena,
                                                           dnxt(0)=> pc_newpend_nxt,
                                                           qout(0)=> pc_newpend_r,
                                                           clk    => clk,
                                                           rst_n  => rst_n 
                                                 	      );
  ifu_rsp_need_replay <= '0';
  ifetch_replay_req   <= '0';
  
end impl;