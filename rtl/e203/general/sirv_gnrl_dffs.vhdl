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
--  All of the general DFF and Latch modules
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------


-- ===========================================================================
--
-- Description:
--  module sirv_gnrl DFF with Load-enable and Reset Async?
--  Default reset value is 1
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_dfflrs is
    generic( DW: integer := 32 );
    port( 
    	  lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
end sirv_gnrl_dfflrs;

architecture impl_better of sirv_gnrl_dfflrs is         -- Preset Asynchronous
  signal qout_r : std_ulogic_vector( DW-1 downto 0 );
  signal d_load : std_ulogic_vector( DW-1 downto 0 );
begin
  d_load <= dnxt when lden = '1' else
            qout_r;
  Dff: process(clk, rst_n) begin                        -- Preset ASynchronous
    if rst_n = '0' then
      qout_r <= (others=> '1');
    elsif rising_edge(clk) then     
      qout_r <= d_load;                                 
    end if;
  end process;
  qout <= qout_r;
end impl_better;

--architecture full_asynchronous of sirv_gnrl_dfflrs is         -- Full Asynchronous
--  signal qout_r : std_ulogic_vector( DW-1 downto 0 );
--  signal d_load : std_ulogic_vector( DW-1 downto 0 );
--begin
--  C_E: process(lden) begin
--    if lden = '1' then
--      d_load <= dnxt;
--    else
--      d_load <= qout_r;
--    end if;
--  end process;
--  Dff: process(clk, rst_n, lden) begin                        -- Full ASynchronous
--    if rst_n = '0' then
--      qout_r <= (others=> '1');
--    elsif rising_edge(clk) then     
--      qout_r <= d_load;                                 
--    end if;
--  end process;
--  O_E: process(lden) begin
--    if lden = '1' then
--      qout <= qout_r;
--    else
--      qout <= (others => 'Z');
--    end if;
--  end process;
--end full_asynchronous;

-- architecture impl_r_sync1 of sirv_gnrl_dfflrs is        -- Full Synchronous
-- begin
--   Dff: process (clk) begin                              -- Full Synchronous
--     if rising_edge(clk) then 
--       if rst_n = '0' then
--         qout <= (others=> '1');
--       elsif lden = '1' then   
--         qout <= dnxt; 
--       end if;
--     end if;
--   end process;
-- end impl_r_sync1;

-- architecture impl_r_sync2 of sirv_gnrl_dfflrs is        -- Set Synchronous
--   signal din_r  : std_ulogic_vector( DW-1 downto 0 );
--   signal dload  : std_ulogic_vector( DW-1 downto 0 );
--   signal qout_r : std_ulogic_vector( DW-1 downto 0 );
--   
-- begin
--   din_r<= (others=> '1') when rst_n = '0' else
--           dnxt;
--   dload<= din_r when lden = '1' else
--           qout_r;
--   
--   Dff: process (clk) begin                              -- Set Synchronous
--     if rising_edge(clk) then   
--       qout_r<= dload;
--     end if;
--   end process;
-- 
--   qout<= qout_r;
-- end impl_r_sync2;
-- 
-- architecture impl_wrong of sirv_gnrl_dfflrs is          -- Preset Asynchronous
--   signal d_load : std_ulogic_vector( DW-1 downto 0 );
--   signal qout_r : std_ulogic_vector( DW-1 downto 0 );
-- begin
--   d_load<= dnxt when lden = '1' else
--           qout_r;
-- 
--   Dff: process(clk) begin 
--     if rising_edge(clk) then 
--       qout_r<= d_load;
--     end if;
--   end process;
-- 
--   qout<= (others=> '1') when rst_n = '0' else            -- can't reset qout_r, also can't reset the circuit.
--          qout_r;
-- end impl_wrong;

-- ===========================================================================
--
-- Description:
--  module sirv_gnrl DFF with Load-enable and Reset
--  Default reset value is 0
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_dfflr is
    generic( DW: integer := 32 );
    port( 
    	    lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
end sirv_gnrl_dfflr;

architecture impl_better of sirv_gnrl_dfflr is         -- Clear Asynchronous
  signal d_load : std_ulogic_vector( DW-1 downto 0 );
  signal qout_r : std_ulogic_vector( DW-1 downto 0 );
begin
  d_load <= dnxt when lden = '1' else
            qout_r;
  process(clk, rst_n) begin                            -- Clear ASynchronous
    if rst_n = '0' then
      qout_r <= (others=> '0');
    elsif rising_edge(clk) then                                    
      qout_r <= d_load;
    end if;
  end process;
  qout <= qout_r;
end impl_better;

-- architecture impl_wrong of sirv_gnrl_dfflr is          -- Clear Asynchronous
--   signal d_load : std_ulogic_vector( DW-1 downto 0 );
--   signal qout_r : std_ulogic_vector( DW-1 downto 0 );
-- begin
--   d_load<= dnxt when lden = '1' else
--           qout_r;
--   process(clk) begin 
--     if rising_edge(clk) then
--       qout_r<= d_load;
--     end if;
--   end process;
--   qout<= (others=> '0') when rst_n = '0' else 
--          qout_r;
-- end impl_wrong;

-- ===========================================================================
--
-- Description:
--  module sirv_gnrl DFF with Load-enable, no reset 
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_dffl is
    generic( DW: integer := 32 );
    port( 	  
    	    lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
end sirv_gnrl_dffl;

architecture impl of sirv_gnrl_dffl is
  signal d_load : std_ulogic_vector( DW-1 downto 0 );
  signal qout_r : std_ulogic_vector( DW-1 downto 0 );
begin
  d_load <= dnxt when lden = '1' else
            qout_r;
  process(clk) begin
    if rising_edge(clk) then    
      qout_r <= d_load;     
    end if;
  end process;
  qout <= qout_r;
end impl;

-- ===========================================================================
--
-- Description:
--  module sirv_gnrl DFF with Reset, no load-enable
--  Default reset value is 1
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_dffrs is
    generic( DW: integer := 32 );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic  
    );
end sirv_gnrl_dffrs;

architecture impl_better of sirv_gnrl_dffrs is
begin
  process(clk, rst_n) begin                                -- Preset ASynchronous
    if rst_n = '0' then
      qout <= (others=> '1');
    elsif rising_edge(clk) then
      qout <= dnxt;
    end if;
  end process;
end impl_better;

-- architecture impl_r_sync of sirv_gnrl_dffrs is  
-- begin
--   process(clk) begin                                    -- Set Synchronous
--     if rising_edge(clk) then 
--       if rst_n = '0' then
--         qout <= (others=> '1');
--       else
--         qout <= dnxt;
--       end if;
--     end if;
--   end process;
-- end impl_r_sync;

-- architecture impl_wrong of sirv_gnrl_dffrs is           -- Preset Asynchronous
--   signal qout_r : std_ulogic_vector( DW-1 downto 0 );
-- begin
--   process(clk) begin 
--     if rising_edge(clk) then    
--         qout_r<= dnxt; 
--     end if;
--   end process;
--   qout<= (others=> '1') when rst_n = '0' else 
--          qout_r;
-- end impl_wrong;

-- ===========================================================================
--
-- Description:
--  module sirv_gnrl DFF with Reset, no load-enable
--  Default reset value is 0
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_dffr is
    generic( DW: integer := 32 );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
end sirv_gnrl_dffr;

architecture impl_better of sirv_gnrl_dffr is
begin
  process(clk, rst_n) begin                             -- Clear ASynchronous
    if rst_n = '0' then
      qout <= (others=> '0');
    elsif rising_edge(clk) then
      qout <= dnxt;
    end if;
  end process;
end impl_better;

-- architecture impl_r_sync of sirv_gnrl_dffr is
-- begin
--   process(clk) begin                                    -- Reset Synchronous
--     if rising_edge(clk) then
--       if rst_n = '0' then
--         qout<= (others=> '0');
--       else 
--         qout<= dnxt;
--       end if;
--     end if;
--   end process;   
-- end impl_r_sync;
 
-- architecture impl_wrong of sirv_gnrl_dffr is            -- clear Asynchronous
--   signal qout_r : std_ulogic_vector( DW-1 downto 0 );
-- begin
--   process(clk) begin 
--     if rising_edge(clk) then    
--         qout_r<= dnxt;   
--     end if;
--   end process;
--   qout<= (others=> '0') when rst_n = '0' else 
--          qout_r;
-- end impl_wrong;

-- ===========================================================================
--
-- Description:
--  module for general latch 
--
-- ===========================================================================
library ieee;
use ieee.std_logic_1164.all;

entity sirv_gnrl_ltch is
    generic( DW: integer := 32 );
    port( 
          lden:  in std_logic;   	  
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 )
    );
end sirv_gnrl_ltch;

architecture impl of sirv_gnrl_ltch is
  signal qout_r : std_ulogic_vector( DW-1 downto 0 );
begin
  process (all) begin
    if lden = '1' then
      qout_r <= dnxt;
    end if; 
  end process;
  qout <= qout_r;
end impl;

-- pragma translate_off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sirv_gnrl_dffr is
end tb_sirv_gnrl_dffr;

architecture impl of tb_sirv_gnrl_dffr is
  signal clock:  std_ulogic;
  signal resetn: std_ulogic:= '1';
  signal din:    std_ulogic_vector(7 downto 0);
  signal qout:   std_ulogic_vector(7 downto 0);
  component sirv_gnrl_dffr is
    generic( DW: integer );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
begin
  DUT: component sirv_gnrl_dffr generic map(8)
                                   port map(din, qout, clock, resetn);
  process begin
    clock <= '1';
    wait for 10 ns;
    clock <= '0';
    wait for 10 ns;
  end process;
  
  process begin
    wait for 5 ns;
    for i in 0 to 255 loop
      din <= to_slv(std_ulogic_vector(to_unsigned(i, 8)));
      wait for 20 ns;
    end loop;
  end process;
  
  process begin
    resetn <= '1';
    wait for 95 ns;
    
    resetn <= '0';
    wait for 100 ns;
    
    resetn <= '1';
    wait for 10000 ns;
    std.env.stop(0);
  end process;
end impl;
-- pragma translate_on
