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
--   The Commit module to commit instructions or flush pipeline
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_commit is 
  port ( 
         commit_mret:      out std_logic;
         commit_trap:      out std_logic;     
         core_wfi:         out std_logic;
         nonflush_cmt_ena: out std_logic;
         excp_active:      out std_logic;

         amo_wait:          in std_logic;

         wfi_halt_ifu_req: out std_logic;
         wfi_halt_exu_req: out std_logic;
         wfi_halt_ifu_ack:  in std_logic;
  	     wfi_halt_exu_ack:  in std_logic;

  	     dbg_irq_r:         in std_logic;
         lcl_irq_r:         in std_logic_vector(E203_LIRQ_NUM-1 downto 0);
         ext_irq_r:         in std_logic;
         sft_irq_r:         in std_logic;
         tmr_irq_r:         in std_logic;
         evt_r:             in std_logic_vector(E203_EVT_NUM-1 downto 0);

         status_mie_r:      in std_logic;
         mtie_r:            in std_logic;
         msie_r:            in std_logic;
         meie_r:            in std_logic;
         
  	     alu_cmt_i_valid:    in std_logic; -- Handshake valid
  	     alu_cmt_i_ready:   out std_logic; -- Handshake ready
         alu_cmt_i_pc:       in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     alu_cmt_i_instr:    in std_logic_vector(E203_INSTR_SIZE-1 downto 0); 
         alu_cmt_i_pc_vld:   in std_logic;
  	     alu_cmt_i_imm:      in std_logic_vector(E203_XLEN-1 downto 0);
  	     alu_cmt_i_rv32:     in std_logic;
  	     
  	     -- The Branch Commit
  	     alu_cmt_i_bjp:         in std_logic;
  	     alu_cmt_i_wfi:         in std_logic;
  	     alu_cmt_i_fencei:      in std_logic;
  	     alu_cmt_i_mret:        in std_logic;
  	     alu_cmt_i_dret:        in std_logic;
  	     alu_cmt_i_ecall:       in std_logic;
  	     alu_cmt_i_ebreak:      in std_logic;
  	     alu_cmt_i_ifu_misalgn: in std_logic;
  	     alu_cmt_i_ifu_buserr:  in std_logic;
  	     alu_cmt_i_ifu_ilegl:   in std_logic;
  	     alu_cmt_i_bjp_prdt:    in std_logic; -- The predicted ture/false  
  	     alu_cmt_i_bjp_rslv:    in std_logic; -- The resolved ture/false
  	     
         -- The AGU Exception
         alu_cmt_i_misalgn:     in std_logic; -- The misalign exception generated
  	     alu_cmt_i_ld:          in std_logic;
  	     alu_cmt_i_stamo:       in std_logic;
  	     alu_cmt_i_buserr:      in std_logic; -- The bus-error exception generated
  	     alu_cmt_i_badaddr:     in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  
         cmt_badaddr:          out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         cmt_badaddr_ena:      out std_logic;
         cmt_epc:              out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_epc_ena:          out std_logic;
         cmt_cause:            out std_logic_vector(E203_XLEN-1 downto 0);
         cmt_cause_ena:        out std_logic;
         cmt_instret_ena:      out std_logic;
         cmt_status_ena:       out std_logic;
         
         cmt_dpc:              out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_dpc_ena:          out std_logic;
         cmt_dcause:           out std_logic_vector(3-1 downto 0);
         cmt_dcause_ena:       out std_logic;
         cmt_mret_ena:         out std_logic;

         csr_epc_r:             in std_logic_vector(E203_PC_SIZE-1 downto 0);
         csr_dpc_r:             in std_logic_vector(E203_PC_SIZE-1 downto 0);
         csr_mtvec_r:           in std_logic_vector(E203_XLEN-1 downto 0);
         
         dbg_mode:              in std_logic; 
         dbg_halt_r:            in std_logic; 
         dbg_step_r:            in std_logic; 
         dbg_ebreakm_r:         in std_logic; 
         
         oitf_empty:            in std_logic; 
         
         u_mode:                in std_logic; 
         s_mode:                in std_logic; 
         h_mode:                in std_logic; 
         m_mode:                in std_logic; 
         
         longp_excp_i_ready:   out std_logic;
         longp_excp_i_valid:    in std_logic; 
         longp_excp_i_ld:       in std_logic; 
         longp_excp_i_st:       in std_logic; 
         longp_excp_i_buserr:   in std_logic; -- The load/store bus-error exception generated
         longp_excp_i_badaddr:  in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         longp_excp_i_insterr:  in std_logic;
         longp_excp_i_pc:       in std_logic_vector(E203_PC_SIZE-1 downto 0);

         -- The Flush interface to IFU
         --
         --   To save the gatecount, when we need to flush pipeline with new PC, 
         --     we want to reuse the adder in IFU, so we will not pass flush-PC
         --     to IFU, instead, we pass the flush-pc-adder-op1/op2 to IFU
         --     and IFU will just use its adder to caculate the flush-pc-adder-result
         flush_pulse:          out std_logic;
         -- To cut the combinational loop, we need this flush_req from non-alu source to flush ALU pipeline (e.g., MUL-div statemachine)
         flush_req:            out std_logic;

         pipe_flush_ack:        in std_logic;
  	     pipe_flush_req:       out std_logic;
         pipe_flush_add_op1:   out std_logic_vector(E203_PC_SIZE-1 downto 0);
         pipe_flush_add_op2:   out std_logic_vector(E203_PC_SIZE-1 downto 0);
        `if E203_TIMING_BOOST = "TRUE" then
         pipe_flush_pc:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
        `end if

         clk:                          in std_logic;  
         rst_n:                        in std_logic  
  	   );
end e203_exu_commit;

architecture impl of e203_exu_commit is 
  signal alu_brchmis_flush_ack:     std_ulogic;
  signal alu_brchmis_flush_req:     std_ulogic;
  signal alu_brchmis_flush_add_op1: std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal alu_brchmis_flush_add_op2: std_ulogic_vector(E203_PC_SIZE-1 downto 0);
 `if E203_TIMING_BOOST = "TRUE" then
  signal alu_brchmis_flush_pc:      std_ulogic_vector(E203_PC_SIZE-1 downto 0);
 `end if
  signal alu_brchmis_cmt_i_ready:   std_ulogic;
  signal cmt_dret_ena:                 std_ulogic;
  signal nonalu_excpirq_flush_req_raw: std_ulogic;

  signal excpirq_flush_ack:     std_ulogic;
  signal excpirq_flush_req:     std_ulogic;
  signal excpirq_flush_add_op1: std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal excpirq_flush_add_op2: std_ulogic_vector(E203_PC_SIZE-1 downto 0);
 `if E203_TIMING_BOOST = "TRUE" then
  signal excpirq_flush_pc:      std_ulogic_vector(E203_PC_SIZE-1 downto 0);
 `end if
  signal excpirq_cause:         std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_excp_cmt_i_ready:  std_ulogic;
  signal cmt_ena:               std_ulogic;
  
  component e203_exu_branchslv is 
    port ( -- The BJP condition final result need to be resolved at ALU
    	   cmt_i_valid:    in std_logic; -- Handshake valid
    	   cmt_i_ready:   out std_logic; -- Handshake ready
           cmt_i_rv32:     in std_logic;
    	   cmt_i_dret:     in std_logic; -- The dret instruction
    	   cmt_i_mret:     in std_logic; -- The ret instruction
    	   cmt_i_fencei:   in std_logic; -- The fencei instruction
    	   cmt_i_bjp:      in std_logic;  
    	   cmt_i_bjp_prdt: in std_logic; -- The predicted ture/false  
    	   cmt_i_bjp_rslv: in std_logic; -- The resolved ture/false
    	   cmt_i_pc:       in std_logic_vector(E203_PC_SIZE-1 downto 0);
    	   cmt_i_imm:      in std_logic_vector(E203_XLEN-1 downto 0); -- The resolved ture/false
  
    	   csr_epc_r:      in std_logic_vector(E203_PC_SIZE-1 downto 0);
           csr_dpc_r:      in std_logic_vector(E203_PC_SIZE-1 downto 0);
           
           nonalu_excpirq_flush_req_raw: in std_logic; 
           brchmis_flush_ack:            in std_logic; 
           brchmis_flush_req:           out std_logic;
           brchmis_flush_add_op1:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
           brchmis_flush_add_op2:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
          `if E203_TIMING_BOOST = "TRUE" then
           brchmis_flush_pc:            out std_logic_vector(E203_PC_SIZE-1 downto 0);
          `end if
  
           cmt_mret_ena:                out std_logic;
           cmt_dret_ena:                out std_logic;
           cmt_fencei_ena:              out std_logic;
           
           clk:                          in std_logic;  
           rst_n:                        in std_logic  
    );
  end component;
  component e203_exu_excp is 
    port ( 
           commit_trap:      out std_logic;
           core_wfi:         out std_logic;     
           wfi_halt_ifu_req: out std_logic;
           wfi_halt_exu_req: out std_logic;
           wfi_halt_ifu_ack:  in std_logic;
           wfi_halt_exu_ack:  in std_logic;
  
           amo_wait:          in std_logic;
  
           alu_excp_i_ready: out std_logic;
           alu_excp_i_valid:  in std_logic;
           alu_excp_i_ld:     in std_logic;
           alu_excp_i_stamo:  in std_logic;
           alu_excp_i_misalgn: in std_logic;
           alu_excp_i_buserr:  in std_logic;
           alu_excp_i_ecall:   in std_logic;
           alu_excp_i_ebreak:  in std_logic;
           alu_excp_i_wfi:     in std_logic;
           alu_excp_i_ifu_misalgn: in std_logic;
           alu_excp_i_ifu_buserr:  in std_logic;
           alu_excp_i_ifu_ilegl:   in std_logic;
           alu_excp_i_badaddr:     in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
           alu_excp_i_pc:          in std_logic_vector(E203_PC_SIZE-1 downto 0);
           alu_excp_i_instr:       in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
           alu_excp_i_pc_vld:      in std_logic;
  
           longp_excp_i_ready:    out std_logic;
           longp_excp_i_valid:     in std_logic;
           longp_excp_i_ld:        in std_logic;
           longp_excp_i_st:        in std_logic; -- 1: load, 0: store
           longp_excp_i_buserr:    in std_logic; -- The load/store bus-error exception generated
           longp_excp_i_insterr:   in std_logic;
           longp_excp_i_badaddr:   in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
           longp_excp_i_pc:        in std_logic_vector(E203_PC_SIZE-1 downto 0);
  
           excpirq_flush_ack:             in std_logic;
           excpirq_flush_req:            out std_logic;
           nonalu_excpirq_flush_req_raw: out std_logic;
           excpirq_flush_add_op1:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
           excpirq_flush_add_op2:        out std_logic_vector(E203_PC_SIZE-1 downto 0);     
          `if E203_TIMING_BOOST = "TRUE" then
           excpirq_flush_pc:             out std_logic_vector(E203_PC_SIZE-1 downto 0);
          `end if
  
           csr_mtvec_r:                   in std_logic_vector(E203_XLEN-1 downto 0);
           cmt_dret_ena:                  in std_logic;
           cmt_ena:                       in std_logic;
           
           cmt_badaddr:                  out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
           cmt_epc:                      out std_logic_vector(E203_PC_SIZE-1 downto 0);
           cmt_cause:                    out std_logic_vector(E203_XLEN-1 downto 0);
           cmt_badaddr_ena:              out std_logic;
           cmt_epc_ena:                  out std_logic;
           cmt_cause_ena:                out std_logic;
           cmt_status_ena:               out std_logic;
           
           cmt_dpc:                      out std_logic_vector(E203_PC_SIZE-1 downto 0);
           cmt_dpc_ena:                  out std_logic;
           cmt_dcause:                   out std_logic_vector(3-1 downto 0);
           cmt_dcause_ena:               out std_logic;
           
           dbg_irq_r:                     in std_logic;
           lcl_irq_r:                     in std_logic_vector(E203_LIRQ_NUM-1 downto 0);
           ext_irq_r:                     in std_logic;
           sft_irq_r:                     in std_logic;
           tmr_irq_r:                     in std_logic;
  
           status_mie_r:                  in std_logic;
           mtie_r:                        in std_logic;
           msie_r:                        in std_logic;
           meie_r:                        in std_logic;
           
           dbg_mode:                      in std_logic;
           dbg_halt_r:                    in std_logic;
           dbg_step_r:                    in std_logic;
           dbg_ebreakm_r:                 in std_logic;
  
           oitf_empty:                    in std_logic;
           
           u_mode:                        in std_logic; 
           s_mode:                        in std_logic; 
           h_mode:                        in std_logic; 
           m_mode:                        in std_logic; 
           
           excp_active:                  out std_logic;
           
           clk:                           in std_logic;  
           rst_n:                         in std_logic  
         );
  end component;
begin
  u_e203_exu_branchslv: component e203_exu_branchslv port map(
    cmt_i_ready             => alu_brchmis_cmt_i_ready,
    cmt_i_valid             => alu_cmt_i_valid   ,  
    cmt_i_rv32              => alu_cmt_i_rv32    ,  
    cmt_i_bjp               => alu_cmt_i_bjp     ,  
    cmt_i_fencei            => alu_cmt_i_fencei  ,
    cmt_i_mret              => alu_cmt_i_mret    ,
    cmt_i_dret              => alu_cmt_i_dret    ,
    cmt_i_bjp_prdt          => alu_cmt_i_bjp_prdt,
    cmt_i_bjp_rslv          => alu_cmt_i_bjp_rslv,
    cmt_i_pc                => alu_cmt_i_pc      ,
    cmt_i_imm               => alu_cmt_i_imm     ,
                        
    cmt_mret_ena            => cmt_mret_ena      ,
    cmt_dret_ena            => cmt_dret_ena      ,
    cmt_fencei_ena          => OPEN              ,
    csr_epc_r               => csr_epc_r         ,
    csr_dpc_r               => csr_dpc_r         ,


    nonalu_excpirq_flush_req_raw => nonalu_excpirq_flush_req_raw,
    brchmis_flush_ack       => alu_brchmis_flush_ack    ,
    brchmis_flush_req       => alu_brchmis_flush_req    ,
    brchmis_flush_add_op1   => alu_brchmis_flush_add_op1,  
    brchmis_flush_add_op2   => alu_brchmis_flush_add_op2,  
   `if E203_TIMING_BOOST = "TRUE" then
    brchmis_flush_pc        => alu_brchmis_flush_pc,  
   `end if

    clk   => clk  ,
    rst_n => rst_n
  );

  u_e203_exu_excp: component e203_exu_excp port map(
    commit_trap           => commit_trap     ,
    core_wfi              => core_wfi        ,
    wfi_halt_ifu_req      => wfi_halt_ifu_req,
    wfi_halt_exu_req      => wfi_halt_exu_req,
    wfi_halt_ifu_ack      => wfi_halt_ifu_ack,
    wfi_halt_exu_ack      => wfi_halt_exu_ack,

    cmt_badaddr           => cmt_badaddr    , 
    cmt_badaddr_ena       => cmt_badaddr_ena,
    cmt_epc               => cmt_epc        ,
    cmt_epc_ena           => cmt_epc_ena    ,
    cmt_cause             => cmt_cause      ,
    cmt_cause_ena         => cmt_cause_ena  ,
    cmt_status_ena        => cmt_status_ena ,
                          
    cmt_dpc               => cmt_dpc        ,
    cmt_dpc_ena           => cmt_dpc_ena    ,
    cmt_dcause            => cmt_dcause     ,
    cmt_dcause_ena        => cmt_dcause_ena ,

    cmt_dret_ena          => cmt_dret_ena   ,
    cmt_ena               => cmt_ena        ,

    alu_excp_i_valid      => alu_cmt_i_valid  ,
    alu_excp_i_ready      => alu_excp_cmt_i_ready,
    alu_excp_i_misalgn    => alu_cmt_i_misalgn,
    alu_excp_i_ld         => alu_cmt_i_ld     ,
    alu_excp_i_stamo      => alu_cmt_i_stamo  ,
    alu_excp_i_buserr     => alu_cmt_i_buserr ,
    alu_excp_i_pc         => alu_cmt_i_pc     ,
    alu_excp_i_instr      => alu_cmt_i_instr  ,
    alu_excp_i_pc_vld     => alu_cmt_i_pc_vld ,
    alu_excp_i_badaddr    => alu_cmt_i_badaddr,
    alu_excp_i_ecall      => alu_cmt_i_ecall  ,
    alu_excp_i_ebreak     => alu_cmt_i_ebreak ,
    alu_excp_i_wfi        => alu_cmt_i_wfi    ,
    alu_excp_i_ifu_misalgn=> alu_cmt_i_ifu_misalgn,
    alu_excp_i_ifu_buserr => alu_cmt_i_ifu_buserr ,
    alu_excp_i_ifu_ilegl  => alu_cmt_i_ifu_ilegl  ,
                        
    longp_excp_i_ready    => longp_excp_i_ready  ,
    longp_excp_i_valid    => longp_excp_i_valid  ,
    longp_excp_i_ld       => longp_excp_i_ld     ,
    longp_excp_i_st       => longp_excp_i_st     ,
    longp_excp_i_buserr   => longp_excp_i_buserr ,
    longp_excp_i_badaddr  => longp_excp_i_badaddr,
    longp_excp_i_insterr  => longp_excp_i_insterr,
    longp_excp_i_pc       => longp_excp_i_pc     ,

    csr_mtvec_r           => csr_mtvec_r         ,

    dbg_irq_r             => dbg_irq_r,
    lcl_irq_r             => lcl_irq_r,
    ext_irq_r             => ext_irq_r,
    sft_irq_r             => sft_irq_r,
    tmr_irq_r             => tmr_irq_r,

    status_mie_r          => status_mie_r,
    mtie_r                => mtie_r      ,
    msie_r                => msie_r      ,
    meie_r                => meie_r      ,

    dbg_mode              => dbg_mode  ,
    dbg_halt_r            => dbg_halt_r,
    dbg_step_r            => dbg_step_r,
    dbg_ebreakm_r         => dbg_ebreakm_r,
    oitf_empty            => oitf_empty,

    u_mode                => u_mode,
    s_mode                => s_mode,
    h_mode                => h_mode,
    m_mode                => m_mode,

    excpirq_flush_ack        => excpirq_flush_ack    ,
    excpirq_flush_req        => excpirq_flush_req    ,
    nonalu_excpirq_flush_req_raw =>nonalu_excpirq_flush_req_raw,
    excpirq_flush_add_op1    => excpirq_flush_add_op1,  
    excpirq_flush_add_op2    => excpirq_flush_add_op2,  
   `if E203_TIMING_BOOST = "TRUE" then
    excpirq_flush_pc         =>excpirq_flush_pc,
   `end if

    excp_active => excp_active,
    amo_wait => amo_wait,

    clk   => clk,
    rst_n => rst_n
  );

  excpirq_flush_ack <= pipe_flush_ack;
  alu_brchmis_flush_ack <= pipe_flush_ack;

  pipe_flush_req <= excpirq_flush_req or alu_brchmis_flush_req;
     
  alu_cmt_i_ready <= alu_excp_cmt_i_ready and alu_brchmis_cmt_i_ready;

  pipe_flush_add_op1 <= excpirq_flush_add_op1 when excpirq_flush_req = '1' else alu_brchmis_flush_add_op1;  
  pipe_flush_add_op2 <= excpirq_flush_add_op2 when excpirq_flush_req = '1' else alu_brchmis_flush_add_op2;  
 `if E203_TIMING_BOOST = "TRUE" then
  pipe_flush_pc      <= excpirq_flush_pc when excpirq_flush_req = '1' else alu_brchmis_flush_pc;  
 `end if

  cmt_ena <= alu_cmt_i_valid and alu_cmt_i_ready;
  cmt_instret_ena <= cmt_ena and (not alu_brchmis_flush_req);

  -- Generate the signal as the real-commit enable (non-flush)
  nonflush_cmt_ena <= cmt_ena and (not pipe_flush_req);


  flush_pulse <= pipe_flush_ack and pipe_flush_req;
  flush_req   <= nonalu_excpirq_flush_req_raw;

  commit_mret <= cmt_mret_ena;

  --  `ifndef FPGA_SOURCE//{
  --  `ifndef DISABLE_SV_ASSERTION//{
  --  //synopsys translate_off
  --  
  --   `ifndef E203_HAS_LOCKSTEP//{
  --  CHECK_1HOT_FLUSH_HALT:
  --    assert property (@(posedge clk) disable iff (~rst_n)
  --                       ($onehot0({wfi_halt_ifu_req,pipe_flush_req}))
  --                    )
  --    else $fatal ("\n Error: Oops, detected non-onehot0 value for halt and flush req!!! This should never happen. \n");
  --   `endif//}
  --  
  --  //synopsys translate_on
  --  `endif//}
  --  `endif//}
end impl;