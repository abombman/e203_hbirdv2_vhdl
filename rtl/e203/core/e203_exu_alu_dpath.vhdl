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
--  This module to implement the datapath of ALU 
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_alu_dpath is 
  port ( -- ALU request the datapath 
  	     alu_req_alu:      in std_logic;  
  	     alu_req_alu_add:  in std_logic;  
         alu_req_alu_sub:  in std_logic;
         alu_req_alu_xor:  in std_logic;  
         alu_req_alu_sll:  in std_logic;
         alu_req_alu_srl:  in std_logic;  
         alu_req_alu_sra:  in std_logic;
         alu_req_alu_or:   in std_logic;  
         alu_req_alu_and:  in std_logic;
         alu_req_alu_slt:  in std_logic;  
         alu_req_alu_sltu: in std_logic;
         alu_req_alu_lui:  in std_logic;     
  	     alu_req_alu_op1:  in std_logic_vector(E203_XLEN-1 downto 0);
         alu_req_alu_op2:  in std_logic_vector(E203_XLEN-1 downto 0);
         alu_req_alu_res: out std_logic_vector(E203_XLEN-1 downto 0);
          
         -- BJP request the datapath
         bjp_req_alu:          in std_logic;
         bjp_req_alu_op1:      in std_logic_vector(E203_XLEN-1 downto 0);
         bjp_req_alu_op2:      in std_logic_vector(E203_XLEN-1 downto 0);
         bjp_req_alu_cmp_eq:   in std_logic;  
         bjp_req_alu_cmp_ne:   in std_logic;
         bjp_req_alu_cmp_lt:   in std_logic;  
         bjp_req_alu_cmp_gt:   in std_logic;
         bjp_req_alu_cmp_ltu:  in std_logic;  
         bjp_req_alu_cmp_gtu:  in std_logic;
         bjp_req_alu_add:      in std_logic;  
         bjp_req_alu_cmp_res: out std_logic; 
         bjp_req_alu_add_res: out std_logic_vector(E203_XLEN-1 downto 0);

         -- AGU request the datapath
         agu_req_alu:          in std_logic;
         agu_req_alu_op1:      in std_logic_vector(E203_XLEN-1 downto 0);
         agu_req_alu_op2:      in std_logic_vector(E203_XLEN-1 downto 0);
         agu_req_alu_swap:     in std_logic;  
         agu_req_alu_add:      in std_logic;
         agu_req_alu_and:      in std_logic;  
         agu_req_alu_or:       in std_logic;
         agu_req_alu_xor:      in std_logic;  
         agu_req_alu_max:      in std_logic;
         agu_req_alu_min:      in std_logic;  
         agu_req_alu_maxu:     in std_logic; 
         agu_req_alu_minu:     in std_logic;
         agu_req_alu_res:     out std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_0_ena:        in std_logic;
         agu_sbf_0_nxt:        in std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_0_r:         out std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_1_ena:        in std_logic;
         agu_sbf_1_nxt:        in std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_1_r:         out std_logic_vector(E203_XLEN-1 downto 0);

  	    `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  	     -- MULDIV request the datapath
         muldiv_req_alu:       in std_logic;
         muldiv_req_alu_op1:   in std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
         muldiv_req_alu_op2:   in std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);  
         muldiv_req_alu_add:   in std_logic;
         muldiv_req_alu_sub:   in std_logic;
         muldiv_req_alu_res:  out std_logic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);  
         muldiv_sbf_0_ena:     in std_logic;
         muldiv_sbf_0_nxt:     in std_logic_vector(33-1 downto 0);
         muldiv_sbf_0_r:      out std_logic_vector(33-1 downto 0);
         muldiv_sbf_1_ena:     in std_logic;
         muldiv_sbf_1_nxt:     in std_logic_vector(33-1 downto 0);
         muldiv_sbf_1_r:      out std_logic_vector(33-1 downto 0);
        `end if

         clk:               in std_logic;  
         rst_n:             in std_logic  
  	   );
end e203_exu_alu_dpath;

architecture impl of e203_exu_alu_dpath is 
  signal mux_op1: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal mux_op2: std_ulogic_vector(E203_XLEN-1 downto 0);

  signal misc_op1: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal misc_op2: std_ulogic_vector(E203_XLEN-1 downto 0);

  signal shifter_op1: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal shifter_op2: std_ulogic_vector(E203_XLEN-1 downto 0);

  signal op_max:      std_ulogic;
  signal op_min:      std_ulogic;
  signal op_maxu:     std_ulogic;
  signal op_minu:     std_ulogic;

  signal op_add:      std_ulogic;
  signal op_sub:      std_ulogic;
  signal op_addsub:   std_ulogic;

  signal op_or:       std_ulogic;
  signal op_xor:      std_ulogic;
  signal op_and:      std_ulogic;
  
  signal op_sll:      std_ulogic;
  signal op_srl:      std_ulogic;
  signal op_sra:      std_ulogic;
  
  signal op_slt:      std_ulogic;
  signal op_sltu:     std_ulogic;
  signal op_mvop2:    std_ulogic;

  signal op_cmp_eq:   std_ulogic;
  signal op_cmp_ne:   std_ulogic;
  signal op_cmp_lt:   std_ulogic;
  signal op_cmp_gt:   std_ulogic;
  signal op_cmp_ltu:  std_ulogic;
  signal op_cmp_gtu:  std_ulogic;

  signal cmp_res:     std_ulogic;

  signal sbf_0_ena:   std_ulogic;
  signal sbf_0_nxt:   std_ulogic_vector(32 downto 0);
  signal sbf_0_r:     std_ulogic_vector(32 downto 0);

  signal sbf_1_ena:   std_ulogic;
  signal sbf_1_nxt:   std_ulogic_vector(32 downto 0);
  signal sbf_1_r:     std_ulogic_vector(32 downto 0);

  signal shifter_in1: std_ulogic_vector(E203_XLEN-1 downto 0);
  signal shifter_in2: std_ulogic_vector(5-1 downto 0);
  signal shifter_res: std_ulogic_vector(E203_XLEN-1 downto 0);

  signal op_shift:    std_ulogic;

  signal sll_res:     std_ulogic_vector(E203_XLEN-1 downto 0);
  signal srl_res:     std_ulogic_vector(E203_XLEN-1 downto 0);

  signal eff_mask:    std_ulogic_vector(E203_XLEN-1 downto 0);
  signal sra_res:     std_ulogic_vector(E203_XLEN-1 downto 0);

  signal op_unsigned: std_ulogic;
  
  signal misc_adder_op1: std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal misc_adder_op2: std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);

  signal adder_op1:      std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal adder_op2:      std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
    
  signal adder_cin:      std_ulogic;
  signal adder_in1:      std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal adder_in2:      std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  signal adder_res:      std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);

  signal adder_add:      std_ulogic;
  signal adder_sub:      std_ulogic;

  signal adder_addsub:   std_ulogic;

  signal xorer_in1:      std_ulogic_vector(E203_XLEN-1 downto 0);
  signal xorer_in2:      std_ulogic_vector(E203_XLEN-1 downto 0);

  signal xorer_op:       std_ulogic;

  signal xorer_res:      std_ulogic_vector(E203_XLEN-1 downto 0);
  signal orer_res:       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal ander_res:      std_ulogic_vector(E203_XLEN-1 downto 0);

  signal neq:            std_ulogic;
  signal cmp_res_ne:     std_ulogic;  
  signal cmp_res_eq:     std_ulogic;  
  signal cmp_res_lt:     std_ulogic;
  signal cmp_res_ltu:    std_ulogic;
  signal op1_gt_op2:     std_ulogic;
  signal cmp_res_gt:     std_ulogic;
  signal cmp_res_gtu:    std_ulogic;

  signal mvop2_res:      std_ulogic_vector(E203_XLEN-1 downto 0);  
  signal op_slttu:       std_ulogic;
  
  signal slttu_cmp_lt:   std_ulogic; 
  signal slttu_res:      std_ulogic_vector(E203_XLEN-1 downto 0);

  signal maxmin_sel_op1: std_ulogic; 
  signal maxmin_res:     std_ulogic_vector(E203_XLEN-1 downto 0);
  
  signal alu_dpath_res:  std_ulogic_vector(E203_XLEN-1 downto 0);

  constant DPATH_MUX_WIDTH: integer:= (E203_XLEN*2)+21;
  
  signal reverse_op1:    std_ulogic_vector(E203_XLEN-1 downto 0);
  signal add_or_sub_op2: std_ulogic_vector(E203_ALU_ADDER_WIDTH-1 downto 0);
  
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
  `if E203_XLEN_IS_32 = "TRUE" then
      -- This is the correct config since E200 is 32bits core
  `else
      `error "There must be something wrong, our core must be 32bits wide !!!"
  `end if

  misc_op1 <= mux_op1(E203_XLEN-1 downto 0);
  misc_op2 <= mux_op2(E203_XLEN-1 downto 0);

  -- Only the regular ALU use shifter
  shifter_op1 <= alu_req_alu_op1(E203_XLEN-1 downto 0);
  shifter_op2 <= alu_req_alu_op2(E203_XLEN-1 downto 0);

  op_addsub <= op_add or op_sub; 

  -- Impelment the Left-Shifter
  -- The Left-Shifter will be used to handle the shift op
  op_shift <= op_sra or op_sll or op_srl; 
 
  -- Make sure to use logic-gating to gateoff the ?
  --   In order to save area and just use one left-shifter, we
  --   convert the right-shift op into left-shift operation
  reverse_op1 <= ( shifter_op1(00), shifter_op1(01), shifter_op1(02), shifter_op1(03), 
                   shifter_op1(04), shifter_op1(05), shifter_op1(06), shifter_op1(07), 
                   shifter_op1(08), shifter_op1(09), shifter_op1(10), shifter_op1(11), 
                   shifter_op1(12), shifter_op1(13), shifter_op1(14), shifter_op1(15), 
                   shifter_op1(16), shifter_op1(17), shifter_op1(18), shifter_op1(19), 
                   shifter_op1(20), shifter_op1(21), shifter_op1(22), shifter_op1(23), 
                   shifter_op1(24), shifter_op1(25), shifter_op1(26), shifter_op1(27), 
                   shifter_op1(28), shifter_op1(29), shifter_op1(30), shifter_op1(31)
 	             ) when (op_sra or op_srl) = '1' else shifter_op1;

  shifter_in1 <= (E203_XLEN-1 downto 0 => op_shift) and reverse_op1;
  shifter_in2 <= (4 downto 0 => op_shift) and shifter_op2(4 downto 0);

  shifter_res <= (shifter_in1 sll to_integer(u_unsigned(shifter_in2))); -- shift <<

  sll_res <= shifter_res;
  srl_res <= (
              shifter_res(00), shifter_res(01), shifter_res(02), shifter_res(03),
              shifter_res(04), shifter_res(05), shifter_res(06), shifter_res(07),
              shifter_res(08), shifter_res(09), shifter_res(10), shifter_res(11),
              shifter_res(12), shifter_res(13), shifter_res(14), shifter_res(15),
              shifter_res(16), shifter_res(17), shifter_res(18), shifter_res(19),
              shifter_res(20), shifter_res(21), shifter_res(22), shifter_res(23),
              shifter_res(24), shifter_res(25), shifter_res(26), shifter_res(27),
              shifter_res(28), shifter_res(29), shifter_res(30), shifter_res(31));
  
  eff_mask <= (not (E203_XLEN-1 downto 0 => '0')) srl to_integer(u_unsigned(shifter_in2));
  sra_res  <= (srl_res and eff_mask) or ((32-1 downto 0 => shifter_op1(31)) and (not eff_mask));

  -- Impelment the Adder
  -- The Adder will be reused to handle the add/sub/compare op

  -- Only the MULDIV request ALU-adder with 35bits operand with sign extended already, 
  -- all other unit request ALU-adder with 32bits opereand without sign extended
  --   For non-MULDIV operands
  op_unsigned <= op_sltu or op_cmp_ltu or op_cmp_gtu or op_maxu or op_minu;
  misc_adder_op1 <=
      ((E203_ALU_ADDER_WIDTH-E203_XLEN-1 downto 0 => ((not op_unsigned) and misc_op1(E203_XLEN-1))) & misc_op1);
  misc_adder_op2 <=
      ((E203_ALU_ADDER_WIDTH-E203_XLEN-1 downto 0 => ((not op_unsigned) and misc_op2(E203_XLEN-1))) & misc_op2);


  adder_op1 <= -- signed number
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
     muldiv_req_alu_op1 when muldiv_req_alu = '1' else
 `end if
     misc_adder_op1;
  adder_op2 <= -- signed number
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
     muldiv_req_alu_op2 when muldiv_req_alu = '1' else
 `end if
     misc_adder_op2;

  adder_add <=
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
     muldiv_req_alu_add when muldiv_req_alu = '1' else
 `end if
      op_add; 
  adder_sub <=
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
     muldiv_req_alu_sub when muldiv_req_alu = '1' else 
 `end if
     (
     -- The original sub instruction
     (op_sub)    or 
     -- The compare lt or gt instruction
     (op_cmp_lt  or op_cmp_gt  or 
      op_cmp_ltu or op_cmp_gtu or
      op_max     or op_maxu    or
      op_min     or op_minu    or
      op_slt     or op_sltu 
     ));

  adder_addsub   <= adder_add or adder_sub; 
  
  add_or_sub_op2 <= (not adder_op2) when adder_sub = '1' else adder_op2;
  -- Make sure to use logic-gating to gateoff the ?
  adder_in1 <= (E203_ALU_ADDER_WIDTH-1 downto 0 => adder_addsub) and (adder_op1);
  adder_in2 <= (E203_ALU_ADDER_WIDTH-1 downto 0 => adder_addsub) and (add_or_sub_op2);
  adder_cin <= adder_addsub and adder_sub;  -- cin is not represent carry_in but add or sub operation, if sub then in2 = not(op2) + 1
  adder_res <= std_ulogic_vector(u_signed(adder_in1) + u_signed(adder_in2) + adder_cin);

  -- Impelment the XOR-er
  -- The XOR-er will be reused to handle the XOR and compare op

  xorer_op <= op_xor
           -- The compare eq or ne instruction
              or (op_cmp_eq or op_cmp_ne); 

  -- Make sure to use logic-gating to gateoff the 
  xorer_in1 <= (E203_XLEN-1 downto 0 => xorer_op) and misc_op1;
  xorer_in2 <= (E203_XLEN-1 downto 0 => xorer_op) and misc_op2;

  xorer_res <= xorer_in1 xor xorer_in2;
  -- The OR and AND is too light-weight, so no need to gate off
  orer_res  <= misc_op1 or misc_op2; 
  ander_res <= misc_op1 and misc_op2; 

  -- Generate the CMP operation result
  -- It is Non-Equal if the XOR result have any bit non-zero
  neq <= (or xorer_res); 
  cmp_res_ne <= (op_cmp_ne and neq);
  -- It is Equal if it is not Non-Equal
  cmp_res_eq <= op_cmp_eq and (not neq);
  -- It is Less-Than if the adder result is negative
  cmp_res_lt <= op_cmp_lt  and adder_res(E203_XLEN);
  cmp_res_ltu<= op_cmp_ltu and adder_res(E203_XLEN);
  -- It is Greater-Than if the adder result is postive
  op1_gt_op2 <= (not adder_res(E203_XLEN));
  cmp_res_gt <= op_cmp_gt  and op1_gt_op2;
  cmp_res_gtu<= op_cmp_gtu and op1_gt_op2;

  cmp_res <= cmp_res_eq 
          or cmp_res_ne 
          or cmp_res_lt 
          or cmp_res_gt  
          or cmp_res_ltu 
          or cmp_res_gtu; 

  -- Generate the mvop2 result
  --   Just directly use op2 since the op2 will be the immediate
  mvop2_res <= misc_op2;

  -- Generate the SLT and SLTU result
  --   Just directly use op2 since the op2 will be the immediate
  op_slttu <= (op_slt or op_sltu);
  -- The SLT and SLTU is reusing the adder to do the comparasion
  -- It is Less-Than if the adder result is negative
  slttu_cmp_lt <= op_slttu and adder_res(E203_XLEN);
  slttu_res <= (E203_XLEN-1 downto 0 => '1') when slttu_cmp_lt = '1' else
               (E203_XLEN-1 downto 0 => '0');

  -- Generate the Max/Min result
  maxmin_sel_op1 <=  ((op_max or op_maxu) and      op1_gt_op2) 
                 or  ((op_min or op_minu) and (not op1_gt_op2));

  maxmin_res <= misc_op1 when maxmin_sel_op1 = '1' else
                misc_op2;  

  
  -- Generate the final result
  alu_dpath_res <= 
                   ((E203_XLEN-1 downto 0 => (op_or    )) and orer_res )
                or ((E203_XLEN-1 downto 0 => (op_and   )) and ander_res)
                or ((E203_XLEN-1 downto 0 => (op_xor   )) and xorer_res)
                or ((E203_XLEN-1 downto 0 => (op_addsub)) and adder_res(E203_XLEN-1 downto 0))
                or ((E203_XLEN-1 downto 0 => (op_srl   )) and srl_res  )
                or ((E203_XLEN-1 downto 0 => (op_sll   )) and sll_res  )
                or ((E203_XLEN-1 downto 0 => (op_sra   )) and sra_res  )
                or ((E203_XLEN-1 downto 0 => (op_mvop2 )) and mvop2_res)
                or ((E203_XLEN-1 downto 0 => (op_slttu )) and slttu_res)
                or ((E203_XLEN-1 downto 0 => (op_max or op_maxu or op_min or op_minu)) and maxmin_res)
                   ;

  -- Implement the SBF: Shared Buffers
  sbf_0_dffl: component sirv_gnrl_dffl generic map(33) port map(sbf_0_ena, sbf_0_nxt, sbf_0_r, clk);
  sbf_1_dffl: component sirv_gnrl_dffl generic map(33) port map(sbf_1_ena, sbf_1_nxt, sbf_1_r, clk);

  --  The ALU-Datapath Mux for the requestors 
  (
     mux_op1
   , mux_op2
   , op_max  
   , op_min  
   , op_maxu 
   , op_minu 
   , op_add
   , op_sub
   , op_or
   , op_xor
   , op_and
   , op_sll
   , op_srl
   , op_sra
   , op_slt
   , op_sltu
   , op_mvop2
   , op_cmp_eq 
   , op_cmp_ne 
   , op_cmp_lt 
   , op_cmp_gt 
   , op_cmp_ltu
   , op_cmp_gtu
  )
   <= 
   ((DPATH_MUX_WIDTH-1 downto 0 => alu_req_alu) and (
      alu_req_alu_op1
    & alu_req_alu_op2
    & '0'
    & '0'
    & '0'
    & '0'
    & alu_req_alu_add
    & alu_req_alu_sub
    & alu_req_alu_or
    & alu_req_alu_xor
    & alu_req_alu_and
    & alu_req_alu_sll
    & alu_req_alu_srl
    & alu_req_alu_sra
    & alu_req_alu_slt
    & alu_req_alu_sltu
    & alu_req_alu_lui  -- LUI just move-Op2 operation
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
   ))
   or 
   ((DPATH_MUX_WIDTH-1 downto 0 => bjp_req_alu) and (
      bjp_req_alu_op1
    & bjp_req_alu_op2
    & '0'
    & '0'
    & '0'
    & '0'
    & bjp_req_alu_add
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & bjp_req_alu_cmp_eq 
    & bjp_req_alu_cmp_ne 
    & bjp_req_alu_cmp_lt 
    & bjp_req_alu_cmp_gt 
    & bjp_req_alu_cmp_ltu
    & bjp_req_alu_cmp_gtu
   ))
   or
   ((DPATH_MUX_WIDTH-1 downto 0 => agu_req_alu) and (
      agu_req_alu_op1
    & agu_req_alu_op2
    & agu_req_alu_max  
    & agu_req_alu_min  
    & agu_req_alu_maxu 
    & agu_req_alu_minu 
    & agu_req_alu_add
    & '0'
    & agu_req_alu_or
    & agu_req_alu_xor
    & agu_req_alu_and
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & agu_req_alu_swap -- SWAP just move-Op2 operation
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
    & '0'
   ));
  
  alu_req_alu_res     <= alu_dpath_res(E203_XLEN-1 downto 0);
  agu_req_alu_res     <= alu_dpath_res(E203_XLEN-1 downto 0);
  bjp_req_alu_add_res <= alu_dpath_res(E203_XLEN-1 downto 0);
  bjp_req_alu_cmp_res <= cmp_res;
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_req_alu_res  <= adder_res;
 `end if

  sbf_0_ena <= 
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_sbf_0_ena when muldiv_req_alu = '1' else
 `end if
  agu_sbf_0_ena;
  sbf_1_ena <= 
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_sbf_1_ena when muldiv_req_alu = '1' else
 `end if
  agu_sbf_1_ena;

  sbf_0_nxt <= 
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_sbf_0_nxt when muldiv_req_alu = '1' else
 `end if
  ('0' & agu_sbf_0_nxt);
  sbf_1_nxt <= 
 `if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
  muldiv_sbf_1_nxt when muldiv_req_alu = '1' else
 `end if
  ('0' & agu_sbf_1_nxt);

 agu_sbf_0_r <= sbf_0_r(E203_XLEN-1 downto 0);
 agu_sbf_1_r <= sbf_1_r(E203_XLEN-1 downto 0);

`if E203_SUPPORT_SHARE_MULDIV = "TRUE" then
 muldiv_sbf_0_r <= sbf_0_r;
 muldiv_sbf_1_r <= sbf_1_r;
`end if
end impl;