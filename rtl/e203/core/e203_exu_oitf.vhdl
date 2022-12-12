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
--   The OITF (Oustanding Instructions Track FIFO) to hold all the non-ALU long
--   pipeline instruction's status and information
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_oitf is 
  port ( 
  	     dis_ready: out std_logic;

  	     dis_ena:   in std_logic;
  	     ret_ena:   in std_logic;

  	     dis_ptr:   out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         ret_ptr:   out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         
         ret_rdidx: out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ret_rdwen: out std_logic;
         ret_rdfpu: out std_logic;
         ret_pc:    out std_logic_vector(E203_PC_SIZE-1 downto 0);

         disp_i_rs1en:  in std_logic;  
         disp_i_rs2en:  in std_logic;  
         disp_i_rs3en:  in std_logic;  
         disp_i_rdwen:  in std_logic;
         disp_i_rs1fpu: in std_logic;
         disp_i_rs2fpu: in std_logic;
         disp_i_rs3fpu: in std_logic;
         disp_i_rdfpu:  in std_logic;
         disp_i_rs1idx: in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         disp_i_rs2idx: in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);  
         disp_i_rs3idx: in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);    
         disp_i_rdidx:  in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
         disp_i_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0); 
          
         oitfrd_match_disprs1: out std_logic;
         oitfrd_match_disprs2: out std_logic;
         oitfrd_match_disprs3: out std_logic;
         oitfrd_match_disprd:  out std_logic;
       
         oitf_empty:           out std_logic;   
         clk:                   in std_logic;  
         rst_n:                 in std_logic  
  );
end e203_exu_oitf;
  
architecture impl of e203_exu_oitf is 
  signal vld_set: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal vld_clr: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal vld_ena: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal vld_nxt: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal vld_r:   std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal rdwen_r: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal rdfpu_r: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  
  type rdidx_type is array(E203_OITF_DEPTH-1 downto 0) of std_ulogic_vector(E203_RFIDX_WIDTH-1 downto 0);
  signal rdidx_r: rdidx_type;
  type pc_type is array(E203_OITF_DEPTH-1 downto 0) of std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal pc_r: pc_type;
  
  signal alc_ptr_ena: std_ulogic;
  signal ret_ptr_ena: std_ulogic;
  signal oitf_full:   std_ulogic;

  signal alc_ptr_r: std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);
  signal ret_ptr_r: std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);

  signal rd_match_rs1idx: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal rd_match_rs2idx: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal rd_match_rs3idx: std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);
  signal rd_match_rdidx:  std_ulogic_vector(E203_OITF_DEPTH-1 downto 0);

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
  depth_gt1: if E203_OITF_DEPTH > 1 generate
    signal alc_ptr_flg_r:   std_ulogic;
    signal alc_ptr_flg_nxt: std_ulogic;
    signal alc_ptr_flg_ena: std_ulogic;
    signal alc_ptr_nxt:     std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);

    signal ret_ptr_flg_r:   std_ulogic;
    signal ret_ptr_flg_nxt: std_ulogic;
    signal ret_ptr_flg_ena: std_ulogic;
    signal ret_ptr_nxt:     std_ulogic_vector(E203_ITAG_WIDTH-1 downto 0);
  begin
    alc_ptr_flg_nxt <= not alc_ptr_flg_r;
    alc_ptr_flg_ena <= (alc_ptr_r ?= std_logic_vector(to_unsigned((E203_OITF_DEPTH-1), E203_ITAG_WIDTH))) and alc_ptr_ena;
    alc_ptr_flg_dfflrs: component sirv_gnrl_dfflr generic map (1)
                                                     port map (lden    => alc_ptr_flg_ena,
                                                               dnxt(0) => alc_ptr_flg_nxt,
                                                               qout(0) => alc_ptr_flg_r,
                                                               clk     => clk,
                                                               rst_n   => rst_n
                                                     	      );
    alc_ptr_nxt <= (E203_ITAG_WIDTH-1 downto 0 => '0') when alc_ptr_flg_ena = '1' else 
                   std_logic_vector((u_unsigned(alc_ptr_r) + '1'));
    alc_ptr_dfflrs: component sirv_gnrl_dfflr generic map (E203_ITAG_WIDTH)
                                                 port map (alc_ptr_ena, alc_ptr_nxt, alc_ptr_r, clk, rst_n);

    ret_ptr_flg_nxt <= not ret_ptr_flg_r;
    ret_ptr_flg_ena <= (ret_ptr_r ?= std_logic_vector(to_unsigned((E203_OITF_DEPTH-1), E203_ITAG_WIDTH))) and ret_ptr_ena;
    ret_ptr_flg_dfflrs: component sirv_gnrl_dfflr generic map (1)
                                                     port map (lden    => ret_ptr_flg_ena,
                                                               dnxt(0) => ret_ptr_flg_nxt,
                                                               qout(0) => ret_ptr_flg_r,
                                                               clk     => clk,
                                                               rst_n   => rst_n
                                                     	      );
    ret_ptr_nxt <= (E203_ITAG_WIDTH-1 downto 0 => '0') when ret_ptr_flg_ena = '1' else 
                   std_logic_vector((u_unsigned(ret_ptr_r) + '1'));
    ret_ptr_dfflrs: component sirv_gnrl_dfflr generic map (E203_ITAG_WIDTH)
                                                 port map (ret_ptr_ena, ret_ptr_nxt, ret_ptr_r, clk, rst_n);
    
    oitf_empty <= (ret_ptr_r ?= alc_ptr_r) and      (ret_ptr_flg_r ?= alc_ptr_flg_r);
    oitf_full  <= (ret_ptr_r ?= alc_ptr_r) and (not (ret_ptr_flg_r ?= alc_ptr_flg_r));
  end generate;
  depth_eq1: if E203_OITF_DEPTH = 1 generate
    alc_ptr_r  <= (others => '0');
    ret_ptr_r  <= (others => '0');
    oitf_empty <= not vld_r(0);
    oitf_full  <= vld_r(0);
  end generate;

  ret_ptr <= ret_ptr_r;
  dis_ptr <= alc_ptr_r;

  -- If the OITF is not full, or it is under retiring, then it is ready to accept new dispatch
  -- assign dis_ready = (~oitf_full) | ret_ena;
  -- To cut down the loop between ALU write-back valid --> oitf_ret_ena --> oitf_ready ---> dispatch_ready --- > alu_i_valid
  --   we exclude the ret_ena from the ready signal
  dis_ready <= (not oitf_full);

  oitf_entries: for i in 0 to E203_OITF_DEPTH-1 generate
    signal alcptr_is_i: std_ulogic;
    signal retptr_is_i: std_ulogic; 
  begin
    alcptr_is_i<= '1' when (to_integer(u_unsigned(alc_ptr_r)) = i) else '0';
    retptr_is_i<= '1' when (to_integer(u_unsigned(ret_ptr_r)) = i) else '0';  
    vld_set(i) <= alc_ptr_ena and alcptr_is_i;
    vld_clr(i) <= ret_ptr_ena and retptr_is_i;
    vld_ena(i) <= vld_set(i) or      vld_clr(i);
    vld_nxt(i) <= vld_set(i) or (not vld_clr(i));

    vld_dfflrs: component sirv_gnrl_dfflr generic map (1)
                                             port map (lden    => vld_ena(i),
                                                       dnxt(0) => vld_nxt(i),
                                                       qout(0) => vld_r(i),
                                                       clk     => clk,
                                                       rst_n   => rst_n
                                             	      );
    -- Payload only set, no need to clear
    rdidx_dfflrs: component sirv_gnrl_dffl generic map (E203_RFIDX_WIDTH)
                                              port map (vld_set(i), disp_i_rdidx, rdidx_r(i), clk);
    pc_dfflrs:    component sirv_gnrl_dffl generic map (E203_PC_SIZE)
                                              port map (vld_set(i), disp_i_pc   , pc_r(i)   , clk);
    rdwen_dfflrs: component sirv_gnrl_dffl generic map (1)
                                              port map (lden    => vld_set(i),
                                                        dnxt(0) => disp_i_rdwen,
                                                        qout(0) => rdwen_r(i),
                                                        clk     => clk
                                              	       );
    rdfpu_dfflrs: component sirv_gnrl_dffl generic map (1)
                                              port map (lden    => vld_set(i),
                                                        dnxt(0) => disp_i_rdfpu,
                                                        qout(0) => rdfpu_r(i),
                                                        clk     => clk
                                              	       );
    rd_match_rs1idx(i) <= vld_r(i) and rdwen_r(i) and disp_i_rs1en and (rdfpu_r(i) ?= disp_i_rs1fpu) and (rdidx_r(i) ?= disp_i_rs1idx);
    rd_match_rs2idx(i) <= vld_r(i) and rdwen_r(i) and disp_i_rs2en and (rdfpu_r(i) ?= disp_i_rs2fpu) and (rdidx_r(i) ?= disp_i_rs2idx);
    rd_match_rs3idx(i) <= vld_r(i) and rdwen_r(i) and disp_i_rs3en and (rdfpu_r(i) ?= disp_i_rs3fpu) and (rdidx_r(i) ?= disp_i_rs3idx);
    rd_match_rdidx (i) <= vld_r(i) and rdwen_r(i) and disp_i_rdwen and (rdfpu_r(i) ?= disp_i_rdfpu ) and (rdidx_r(i) ?= disp_i_rdidx );                                          
  end generate;

  oitfrd_match_disprs1 <= or(rd_match_rs1idx);
  oitfrd_match_disprs2 <= or(rd_match_rs2idx);
  oitfrd_match_disprs3 <= or(rd_match_rs3idx);
  oitfrd_match_disprd  <= or(rd_match_rdidx );

  ret_rdidx <= rdidx_r(to_integer(u_unsigned(ret_ptr)));
  ret_pc    <= pc_r   (to_integer(u_unsigned(ret_ptr)));
  ret_rdwen <= rdwen_r(to_integer(u_unsigned(ret_ptr)));
  ret_rdfpu <= rdfpu_r(to_integer(u_unsigned(ret_ptr)));

end impl;