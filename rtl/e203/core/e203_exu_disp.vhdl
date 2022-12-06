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
--   The Dispatch module to dispatch instructions to different functional units
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_disp is 
  port ( wfi_halt_exu_req:  in std_logic;
  	     wfi_halt_exu_ack: out std_logic;

  	     oitf_empty:        in std_logic;
  	     amo_wait:          in std_logic;

  	     -- The operands and decode info from dispatch
         disp_i_valid:      in std_logic;  -- Handshake valid
         disp_i_ready:     out std_logic;  -- Handshake ready 
       
         -- The operand 1/2 read-enable signals and indexes
         disp_i_rs1x0:      in std_logic;  
         disp_i_rs2x0:      in std_logic;  
         disp_i_rs1en:      in std_logic;  
         disp_i_rs2en:      in std_logic;  
         disp_i_rs1idx:     in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_i_rs2idx:     in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_i_rs1:        in std_logic_vector(E203_XLEN-1 downto 0);
         disp_i_rs2:        in std_logic_vector(E203_XLEN-1 downto 0);
         disp_i_rdwen:      in std_logic; 
         disp_i_rdidx:      in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);    
         disp_i_info:       in std_logic_vector(E203_DECINFO_WIDTH-1 downto 0);   
         disp_i_imm:        in std_logic_vector(E203_XLEN-1 downto 0);    
         disp_i_pc:         in std_logic_vector(E203_PC_SIZE-1 downto 0); 
         disp_i_misalgn:    in std_logic;
         disp_i_buserr:     in std_logic;
         disp_i_ilegl:      in std_logic;
       
         -- Dispatch to ALU
         disp_o_alu_valid: out std_logic; 
         disp_o_alu_ready:  in std_logic;
       
         disp_o_alu_longpipe: in std_logic;
       
         disp_o_alu_rs1:     out std_logic_vector(E203_XLEN-1 downto 0);
         disp_o_alu_rs2:     out std_logic_vector(E203_XLEN-1 downto 0);
         disp_o_alu_rdwen:   out std_logic;
         disp_o_alu_rdidx:   out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);  
         disp_o_alu_info:    out std_logic_vector(E203_DECINFO_WIDTH-1 downto 0);  
         disp_o_alu_imm:     out std_logic_vector(E203_XLEN-1 downto 0);      
         disp_o_alu_pc:      out std_logic_vector(E203_PC_SIZE-1 downto 0);   
         disp_o_alu_itag:    out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         disp_o_alu_misalgn: out std_logic;
         disp_o_alu_buserr:  out std_logic;
         disp_o_alu_ilegl:   out std_logic;
       
         -- Dispatch to OITF
         oitfrd_match_disprs1: in std_logic;
         oitfrd_match_disprs2: in std_logic;
         oitfrd_match_disprs3: in std_logic;
         oitfrd_match_disprd:  in std_logic;
         disp_oitf_ptr:        in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
       
         disp_oitf_ena:       out std_logic;
         disp_oitf_ready:      in std_logic;
       
         disp_oitf_rs1fpu:    out std_logic;
         disp_oitf_rs2fpu:    out std_logic;
         disp_oitf_rs3fpu:    out std_logic;
         disp_oitf_rdfpu:     out std_logic;
       
         disp_oitf_rs1en:     out std_logic;
         disp_oitf_rs2en:     out std_logic;
         disp_oitf_rs3en:     out std_logic;
         disp_oitf_rdwen:     out std_logic;
       
         disp_oitf_rs1idx:    out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_oitf_rs2idx:    out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_oitf_rs3idx:    out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_oitf_rdidx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
       
         disp_oitf_pc:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
            
         clk:                  in std_logic;  
         rst_n:                in std_logic  
  );
end e203_exu_disp;

architecture impl of e203_exu_disp is 
  signal disp_i_info_grp: std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0);
  signal disp_csr:        std_logic;
  signal disp_alu_longp_prdt: std_logic;
  signal disp_alu_longp_real: std_logic;
  signal disp_fence_fencei:   std_logic;
  signal disp_i_valid_pos:    std_logic;
  signal disp_i_ready_pos:    std_logic;
  
  signal raw_dep:             std_logic;
  signal waw_dep:             std_logic;
  signal dep:                 std_logic;
  signal disp_condition:      std_logic;

  signal disp_by_csr:         std_logic;
  signal disp_by_fence:       std_logic;
  signal disp_by_longp:       std_logic;

  signal disp_i_rs1_msked:    std_logic_vector(E203_XLEN-1 downto 0);
  signal disp_i_rs2_msked:    std_logic_vector(E203_XLEN-1 downto 0);
  
 `if E203_HAS_FPU = "FALSE" then
  constant disp_i_fpu:        std_logic:= '0';
  constant disp_i_fpu_rs1en:  std_logic:= '0';
  constant disp_i_fpu_rs2en:  std_logic:= '0';
  constant disp_i_fpu_rs3en:  std_logic:= '0';
  constant disp_i_fpu_rdwen:  std_logic:= '0';
  constant disp_i_fpu_rs1idx: std_logic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  constant disp_i_fpu_rs2idx: std_logic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  constant disp_i_fpu_rs3idx: std_logic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  constant disp_i_fpu_rdidx:  std_logic_vector(E203_RFIDX_WIDTH-1 downto 0):= (others => '0');
  constant disp_i_fpu_rs1fpu: std_logic:= '0';
  constant disp_i_fpu_rs2fpu: std_logic:= '0';
  constant disp_i_fpu_rs3fpu: std_logic:= '0';
  constant disp_i_fpu_rdfpu:  std_logic:= '0';
 `end if
begin
  disp_i_info_grp <= disp_i_info (E203_DECINFO_GRP'range);

  -- Based on current 2 pipe stage implementation, the 2nd stage need to have all instruction
  --   to be commited via ALU interface, so every instruction need to be dispatched to ALU,
  --   regardless it is long pipe or not, and inside ALU it will issue instructions to different
  --   other longpipes
  --wire disp_alu  = (disp_i_info_grp == `E203_DECINFO_GRP_ALU) 
  --               | (disp_i_info_grp == `E203_DECINFO_GRP_BJP) 
  --               | (disp_i_info_grp == `E203_DECINFO_GRP_CSR) 
  --              `ifdef E203_SUPPORT_SHARE_MULDIV //{
  --               | (disp_i_info_grp == `E203_DECINFO_GRP_MULDIV) 
  --              `endif//E203_SUPPORT_SHARE_MULDIV}
  --               | (disp_i_info_grp == `E203_DECINFO_GRP_AGU);
  disp_csr <= (disp_i_info_grp ?= E203_DECINFO_GRP_CSR);
  disp_alu_longp_prdt <= (disp_i_info_grp ?= E203_DECINFO_GRP_AGU);
  disp_alu_longp_real <= disp_o_alu_longpipe;

  -- Both fence and fencei need to make sure all outstanding instruction have been completed
  disp_fence_fencei   <= (disp_i_info_grp ?= E203_DECINFO_GRP_BJP) and 
                               ( disp_i_info(E203_DECINFO_BJP_FENCE'right) or disp_i_info(E203_DECINFO_BJP_FENCEI'right));   

  -- Since any instruction will need to be dispatched to ALU, we dont need the gate here
  --   wire   disp_i_ready_pos = disp_alu & disp_o_alu_ready;
  --   assign disp_o_alu_valid = disp_alu & disp_i_valid_pos; 
  disp_i_ready_pos <= disp_o_alu_ready;
  disp_o_alu_valid <= disp_i_valid_pos;  
  
  --////////////////////////////////////////////////////////////
  -- The Dispatch Scheme Introduction for two-pipeline stage
  --  #1: The instruction after dispatched must have already have operand fetched, so
  --      there is no any WAR dependency happened.
  --  #2: The ALU-instruction are dispatched and executed in-order inside ALU, so
  --      there is no any WAW dependency happened among ALU instructions.
  --      Note: LSU since its AGU is handled inside ALU, so it is treated as a ALU instruction
  --  #3: The non-ALU-instruction are all tracked by OITF, and must be write-back in-order, so 
  --      it is like ALU in-ordered. So there is no any WAW dependency happened among
  --      non-ALU instructions.
  --  Then what dependency will we have?
  --  * RAW: This is the real dependency
  --  * WAW: The WAW between ALU an non-ALU instructions
  --
  --  So #1, The dispatching ALU instruction can not proceed and must be stalled when
  --      ** RAW: The ALU reading operands have data dependency with OITF entries
  --         *** Note: since it is 2 pipeline stage, any last ALU instruction have already
  --             write-back into the regfile. So there is no chance for ALU instr to depend 
  --             on last ALU instructions as RAW. 
  --             Note: if it is 3 pipeline stages, then we also need to consider the ALU-to-ALU 
  --                   RAW dependency.
  --      ** WAW: The ALU writing result have no any data dependency with OITF entries
  --           Note: Since the ALU instruction handled by ALU may surpass non-ALU OITF instructions
  --                 so we must check this.
  --  And #2, The dispatching non-ALU instruction can not proceed and must be stalled when
  --      ** RAW: The non-ALU reading operands have data dependency with OITF entries
  --         *** Note: since it is 2 pipeline stage, any last ALU instruction have already
  --             write-back into the regfile. So there is no chance for non-ALU instr to depend 
  --             on last ALU instructions as RAW. 
  --             Note: if it is 3 pipeline stages, then we also need to consider the non-ALU-to-ALU 
  --                   RAW dependency.
  raw_dep <= ((oitfrd_match_disprs1) or (oitfrd_match_disprs2) or (oitfrd_match_disprs3)); 
  
  -- Only check the longp instructions (non-ALU) for WAW, here if we 
  --   use the precise version (disp_alu_longp_real), it will hurt timing very much, but
  --   if we use imprecise version of disp_alu_longp_prdt, it is kind of tricky and in 
  --   some corner case. For example, the AGU (treated as longp) will actually not dispatch
  --   to longp but just directly commited, then it become a normal ALU instruction, and should
  --   check the WAW dependency, but this only happened when it is AMO or unaligned-uop, so
  --   ideally we dont need to worry about it, because
  --     * We dont support AMO in 2 stage CPU here
  --     * We dont support Unalign load-store in 2 stage CPU here, which 
  --         will be triggered as exception, so will not really write-back
  --         into regfile
  --     * But it depends on some assumption, so it is still risky if in the future something changed.
  -- Nevertheless: using this condition only waiver the longpipe WAW case, that is, two
  --   longp instruction write-back same reg back2back. Is it possible or is it common? 
  --   after we checking the benmark result we found if we remove this complexity here 
  --   it just does not change any benchmark number, so just remove that condition out. Means
  --   all of the instructions will check waw_dep
  -- wire alu_waw_dep = (~disp_alu_longp_prdt) & (oitfrd_match_disprd & disp_i_rdwen); 
  waw_dep <= (oitfrd_match_disprd); 

  dep <= raw_dep or waw_dep;

  -- The WFI halt exu ack will be asserted when the OITF is empty
  --    and also there is no AMO oustanding uops 
  wfi_halt_exu_ack <= oitf_empty and (not amo_wait);
  
  disp_by_csr    <= oitf_empty when disp_csr = '1' else '1';
  disp_by_fence  <= oitf_empty when disp_fence_fencei = '1' else '1';
  disp_by_longp  <= disp_oitf_ready when disp_alu_longp_prdt = '1' else '1';
  disp_condition <= 
                 -- To be more conservtive, any accessing CSR instruction need to wait the oitf to be empty.
                 -- Theoretically speaking, it should also flush pipeline after the CSR have been updated
                 --  to make sure the subsequent instruction get correct CSR values, but in our 2-pipeline stage
                 --  implementation, CSR is updated after EXU stage, and subsequent are all executed at EXU stage,
                 --  no chance to got wrong CSR values, so we dont need to worry about this.
                 (disp_by_csr)
                 -- To handle the Fence: just stall dispatch until the OITF is empty
             and (disp_by_fence)
                 -- If it was a WFI instruction commited halt req, then it will stall the disaptch
             and (not wfi_halt_exu_req)   
                 -- No dependency
             and (not dep)   
               -- If dispatch to ALU as long pipeline, then must check
               --   the OITF is ready
               -- & ((disp_alu & disp_o_alu_longpipe) ? disp_oitf_ready : 1'b1);
               -- To cut the critical timing  path from longpipe signal
               -- we always assume the LSU will need oitf ready
             and (disp_by_longp);

  disp_i_valid_pos <= disp_condition and disp_i_valid; 
  disp_i_ready     <= disp_condition and disp_i_ready_pos; 
  
  disp_i_rs1_msked <= disp_i_rs1 and (E203_XLEN-1 downto 0 => (not disp_i_rs1x0));
  disp_i_rs2_msked <= disp_i_rs2 and (E203_XLEN-1 downto 0 => (not disp_i_rs2x0));
  -- Since we always dispatch any instructions into ALU, so we dont need to gate ops here
  --assign disp_o_alu_rs1   = {`E203_XLEN{disp_alu}} & disp_i_rs1_msked;
  --assign disp_o_alu_rs2   = {`E203_XLEN{disp_alu}} & disp_i_rs2_msked;
  --assign disp_o_alu_rdwen = disp_alu & disp_i_rdwen;
  --assign disp_o_alu_rdidx = {`E203_RFIDX_WIDTH{disp_alu}} & disp_i_rdidx;
  --assign disp_o_alu_info  = {`E203_DECINFO_WIDTH{disp_alu}} & disp_i_info;  
  disp_o_alu_rs1   <= disp_i_rs1_msked;
  disp_o_alu_rs2   <= disp_i_rs2_msked;
  disp_o_alu_rdwen <= disp_i_rdwen;
  disp_o_alu_rdidx <= disp_i_rdidx;
  disp_o_alu_info  <= disp_i_info;  
  
  -- Why we use precise version of disp_longp here, because
  --   only when it is really dispatched as long pipe then allocate the OITF
  disp_oitf_ena <= disp_o_alu_valid and disp_o_alu_ready and disp_alu_longp_real;

  disp_o_alu_imm    <= disp_i_imm;
  disp_o_alu_pc     <= disp_i_pc;
  disp_o_alu_itag   <= disp_oitf_ptr;
  disp_o_alu_misalgn<= disp_i_misalgn;
  disp_o_alu_buserr <= disp_i_buserr;
  disp_o_alu_ilegl  <= disp_i_ilegl;

  disp_oitf_rs1fpu <= (disp_i_fpu_rs1en and disp_i_fpu_rs1fpu) when disp_i_fpu = '1' else '0';
  disp_oitf_rs2fpu <= (disp_i_fpu_rs2en and disp_i_fpu_rs2fpu) when disp_i_fpu = '1' else '0';
  disp_oitf_rs3fpu <= (disp_i_fpu_rs3en and disp_i_fpu_rs3fpu) when disp_i_fpu = '1' else '0';
  disp_oitf_rdfpu  <= (disp_i_fpu_rdwen and disp_i_fpu_rdfpu ) when disp_i_fpu = '1' else '0';

  disp_oitf_rs1en  <= disp_i_fpu_rs1en when disp_i_fpu = '1' else disp_i_rs1en;
  disp_oitf_rs2en  <= disp_i_fpu_rs2en when disp_i_fpu = '1' else disp_i_rs2en;
  disp_oitf_rs3en  <= disp_i_fpu_rs3en when disp_i_fpu = '1' else '0';
  disp_oitf_rdwen  <= disp_i_fpu_rdwen when disp_i_fpu = '1' else disp_i_rdwen;

  disp_oitf_rs1idx <= disp_i_fpu_rs1idx when disp_i_fpu = '1' else disp_i_rs1idx;
  disp_oitf_rs2idx <= disp_i_fpu_rs2idx when disp_i_fpu = '1' else disp_i_rs2idx;
  disp_oitf_rs3idx <= disp_i_fpu_rs3idx when disp_i_fpu = '1' else (E203_RFIDX_WIDTH-1 downto 0 => '0');
  disp_oitf_rdidx  <= disp_i_fpu_rdidx  when disp_i_fpu = '1' else disp_i_rdidx;

  disp_oitf_pc  <= disp_i_pc;

end impl;