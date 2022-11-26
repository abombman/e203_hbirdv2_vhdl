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

entity e203_ifu_litebpu is 
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
end e203_ifu_litebpu;

  -- BPU of E201 utilize very simple static branch prediction logics
  --   * JAL: The target address of JAL is calculated based on current PC value
  --          and offset, and JAL is unconditionally always jump
  --   * JALR with rs1 == x0: The target address of JALR is calculated based on
  --          x0+offset, and JALR is unconditionally always jump
  --   * JALR with rs1 = x1: The x1 register value is directly wired from regfile
  --          when the x1 have no dependency with ongoing instructions by checking
  --          two conditions:
  --            ** (1) The OTIF in EXU must be empty 
  --            ** (2) The instruction in IR have no x1 as destination register
  --          * If there is dependency, then hold up IFU until the dependency is cleared
  --   * JALR with rs1 != x0 or x1: The target address of JALR need to be resolved
  --          at EXU stage, hence have to be forced halted, wait the EXU to be
  --          empty and then read the regfile to grab the value of xN.
  --          This will exert 1 cycle performance lost for JALR instruction
  --   * Bxxx: Conditional branch is always predicted as taken if it is backward
  --          jump, and not-taken if it is forward jump. The target address of JAL
  --          is calculated based on current PC value and offset

    

architecture impl of e203_ifu_litebpu is 
  
  signal dec_jalr_rs1x0: std_logic;
  signal dec_jalr_rs1x1: std_logic;
  signal dec_jalr_rs1xn: std_logic;

  signal jalr_rs1x1_dep: std_logic;
  signal jalr_rs1xn_dep: std_logic;

  signal jalr_rs1xn_dep_ir_clr: std_logic;

  signal rs1xn_rdrf_r:   std_logic;
  signal rs1xn_rdrf_set: std_logic;
  signal rs1xn_rdrf_clr: std_logic;
  signal rs1xn_rdrf_ena: std_logic;
  signal rs1xn_rdrf_nxt: std_logic;
  
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
  -- The JAL and JALR is always jump, bxxx backward is predicted as taken
  prdt_taken <= (dec_jal or dec_jalr or (dec_bxx and dec_bjp_imm(E203_XLEN-1)));
  
  -- The JALR with rs1 == x1 have dependency or xN have dependency
  dec_jalr_rs1x0 <= (dec_jalr_rs1idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '0'));
  dec_jalr_rs1x1 <= (dec_jalr_rs1idx ?= (E203_RFIDX_WIDTH-1 downto 0 => '1'));
  dec_jalr_rs1xn <= (not dec_jalr_rs1x0) and (not dec_jalr_rs1x1);
  
  jalr_rs1x1_dep <= dec_i_valid and dec_jalr and dec_jalr_rs1x1 and ((not oitf_empty) or (jalr_rs1idx_cam_irrdidx));
  jalr_rs1xn_dep <= dec_i_valid and dec_jalr and dec_jalr_rs1xn and ((not oitf_empty) or (not ir_empty));

  -- If only depend to IR stage (OITF is empty), then if IR is under clearing, or
  -- it does not use RS1 index, then we can also treat it as non-dependency
  jalr_rs1xn_dep_ir_clr <= (jalr_rs1xn_dep and oitf_empty and (not ir_empty)) and (ir_valid_clr or (not ir_rs1en));

  rs1xn_rdrf_set <= (not rs1xn_rdrf_r) and dec_i_valid and dec_jalr and dec_jalr_rs1xn and ((not jalr_rs1xn_dep) or jalr_rs1xn_dep_ir_clr);
  rs1xn_rdrf_clr <= rs1xn_rdrf_r;
  rs1xn_rdrf_ena <= rs1xn_rdrf_set or      rs1xn_rdrf_clr;
  rs1xn_rdrf_nxt <= rs1xn_rdrf_set or (not rs1xn_rdrf_clr);
  rs1xn_rdrf_dfflrs: component sirv_gnrl_dfflr generic map (1)
                                                  port map (lden   => rs1xn_rdrf_ena,
                                                            dnxt(0)=> rs1xn_rdrf_nxt,
                                                            qout(0)=> rs1xn_rdrf_r,
                                                            clk    => clk,
                                                            rst_n  => rst_n
                                                           );
  
  bpu2rf_rs1_ena <= rs1xn_rdrf_set;

  bpu_wait <= jalr_rs1x1_dep or jalr_rs1xn_dep or rs1xn_rdrf_set;

  prdt_pc_add_op1 <= pc(E203_PC_SIZE-1 downto 0)        when (dec_bxx or dec_jal)          = '1' else
                     (E203_PC_SIZE-1 downto 0 => '0')   when (dec_jalr and dec_jalr_rs1x0) = '1' else
                     rf2bpu_x1(E203_PC_SIZE-1 downto 0) when (dec_jalr and dec_jalr_rs1x1) = '1' else
                     rf2bpu_rs1(E203_PC_SIZE-1 downto 0);
							
  prdt_pc_add_op2 <= dec_bjp_imm(E203_PC_SIZE-1 downto 0);
    
end impl;