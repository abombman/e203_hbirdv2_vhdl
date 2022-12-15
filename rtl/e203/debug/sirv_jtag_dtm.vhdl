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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_jtag_dtm is 
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
end sirv_jtag_dtm;

architecture impl of sirv_jtag_dtm is 
  
  -- Number of cycles which must remain in IDLE
  -- The software should handle even if the
  -- answer is actually higher than this, or
  -- the software may choose to ignore it entirely
  -- and just check for busy.
  constant IR_BITS:          integer:= 5;
  constant DEBUG_VERSION:    integer:= 0;

  -- JTAG State Machine
  constant TEST_LOGIC_RESET: std_ulogic_vector(3 downto 0):= X"0";
  constant RUN_TEST_IDLE   : std_ulogic_vector(3 downto 0):= X"1";
  constant SELECT_DR       : std_ulogic_vector(3 downto 0):= X"2";
  constant CAPTURE_DR      : std_ulogic_vector(3 downto 0):= X"3";
  constant SHIFT_DR        : std_ulogic_vector(3 downto 0):= X"4";
  constant EXIT1_DR        : std_ulogic_vector(3 downto 0):= X"5";
  constant PAUSE_DR        : std_ulogic_vector(3 downto 0):= X"6";
  constant EXIT2_DR        : std_ulogic_vector(3 downto 0):= X"7";
  constant UPDATE_DR       : std_ulogic_vector(3 downto 0):= X"8";
  constant SELECT_IR       : std_ulogic_vector(3 downto 0):= X"9";
  constant CAPTURE_IR      : std_ulogic_vector(3 downto 0):= X"A";
  constant SHIFT_IR        : std_ulogic_vector(3 downto 0):= X"B";
  constant EXIT1_IR        : std_ulogic_vector(3 downto 0):= X"C";
  constant PAUSE_IR        : std_ulogic_vector(3 downto 0):= X"D";
  constant EXIT2_IR        : std_ulogic_vector(3 downto 0):= X"E";
  constant UPDATE_IR       : std_ulogic_vector(3 downto 0):= X"F";
  
  -- RISCV DTM Registers (see RISC-V Debug Specification)
  -- All others are treated as 'BYPASS'.
  constant REG_BYPASS      : std_ulogic_vector(4 downto 0):= "11111";
  constant REG_IDCODE      : std_ulogic_vector(4 downto 0):= "00001";
  constant REG_DEBUG_ACCESS: std_ulogic_vector(4 downto 0):= "10001";
  constant REG_DTM_INFO    : std_ulogic_vector(4 downto 0):= "10000";

  constant DBUS_REG_BITS : integer:= DEBUG_OP_BITS + DEBUG_ADDR_BITS + DEBUG_DATA_BITS;  -- 41
  constant DBUS_REQ_BITS : integer:= DEBUG_OP_BITS + DEBUG_ADDR_BITS + DEBUG_DATA_BITS;  -- 41
  constant DBUS_RESP_BITS: integer:= DEBUG_OP_BITS + DEBUG_DATA_BITS;                    -- 36

  constant SHIFT_REG_BITS: integer:=DBUS_REG_BITS;
  
  signal i_dtm_req_valid: std_ulogic;
  signal i_dtm_req_ready: std_ulogic;
  signal i_dtm_req_bits:  std_ulogic_vector(DBUS_REQ_BITS-1 downto 0);
  
  signal i_dtm_resp_valid: std_ulogic;
  signal i_dtm_resp_ready: std_ulogic;
  signal i_dtm_resp_bits:  std_ulogic_vector(DBUS_RESP_BITS-1 downto 0);

  signal irReg:            std_ulogic_vector(IR_BITS-1 downto 0);
  
  signal idcode:           std_ulogic_vector(31 downto 0);
  signal dtminfo:          std_ulogic_vector(31 downto 0);
  signal dbusReg:          std_ulogic_vector(DBUS_REG_BITS-1 downto 0);
  signal dbusValidReg:     std_ulogic;
  
  signal jtagStateReg:     std_ulogic_vector(3 downto 0);
  
  signal shiftReg:         std_ulogic_vector(SHIFT_REG_BITS-1 downto 0);

  signal doDbusWriteReg:   std_ulogic;
  signal doDbusReadReg:    std_ulogic;

  signal busyReg:              std_ulogic;
  signal stickyBusyReg:        std_ulogic;
  signal stickyNonzeroRespReg: std_ulogic;

  signal skipOpReg:        std_ulogic; -- Skip op because we're busy.
  signal downgradeOpReg:   std_ulogic; -- Downgrade op because prev. op failed.
  
  signal busy:             std_ulogic;
  signal nonzeroResp:      std_ulogic;

  signal busyResponse:     std_ulogic_vector(SHIFT_REG_BITS-1 downto 0);
  signal nonbusyResponse:  std_ulogic_vector(SHIFT_REG_BITS-1 downto 0);

  constant debugAddrBits:  std_ulogic_vector(3 downto 0):= std_logic_vector(to_unsigned(DEBUG_ADDR_BITS, 4));
  constant debugVersion:   std_ulogic_vector(3 downto 0):= std_logic_vector(to_unsigned(DEBUG_VERSION, 4));
  signal dbusStatus:       std_ulogic_vector(1 downto 0);
  signal dbusIdleCycles:   std_ulogic_vector(2 downto 0);
  signal dbusReset:        std_ulogic;
  signal dtm_resp_ornot:   std_ulogic;

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

begin
  -- Combo Logic
  idcode <= JTAG_VERSION & 16x"e200" & 11x"536" & '1';
  dbusIdleCycles <= DBUS_IDLE_CYCLES;
  dbusStatus <= (stickyNonzeroRespReg, (stickyNonzeroRespReg or stickyBusyReg));
  dbusReset <= shiftReg(16);
  
  dtminfo <= (15b"0",
              '0',    -- dbusreset goes here but is write-only
              "000", 
              dbusIdleCycles, 
              dbusStatus, 
              debugAddrBits, 
              debugVersion);
  -- busy, dtm_resp* is only valid during CAPTURE_DR,
  -- so these signals should only be used at that time.
  -- This assumes there is only one transaction in flight at a time.
  busy <= (busyReg and (not i_dtm_resp_valid)) or stickyBusyReg;
  
  -- This is needed especially for the first request.
  dtm_resp_ornot <= or(i_dtm_resp_bits(DEBUG_OP_BITS-1 downto 0)) when i_dtm_resp_valid = '1' else
  	                 '0';
  nonzeroResp <= dtm_resp_ornot or stickyNonzeroRespReg;

  -- Interface to DM.
  -- Note that this means i_dtm_resp_bits must only be used during CAPTURE_DR.
  i_dtm_resp_ready <= (jtagStateReg ?= CAPTURE_DR) and
                      (irReg        ?= REG_DEBUG_ACCESS) and
                       i_dtm_resp_valid;
  i_dtm_req_valid <= dbusValidReg;
  i_dtm_req_bits  <= dbusReg;

  busyResponse <= (DEBUG_ADDR_BITS+DEBUG_DATA_BITS-1 downto 0 => '0') & 
                  (DEBUG_OP_BITS-1 downto 0 => '1');  -- Generalizing 'busy' to 'all-1'
  nonbusyResponse <= (
                      dbusReg((DEBUG_DATA_BITS+DEBUG_OP_BITS+DEBUG_ADDR_BITS-1) downto (DEBUG_DATA_BITS+DEBUG_OP_BITS)), 
                      i_dtm_resp_bits(DEBUG_OP_BITS+DEBUG_DATA_BITS-1 downto DEBUG_OP_BITS), 
                      i_dtm_resp_bits(0+DEBUG_OP_BITS-1 downto 0)
                     ); 

  ----------------------------------------------------------
  -- Sequential Logic

  -- JTAG STATE MACHINE
  process(jtag_TCK, jtag_TRST) is
  begin
    if (jtag_TRST = '1') then
      jtagStateReg <= TEST_LOGIC_RESET;
    elsif rising_edge(jtag_TCK) then
      case jtagStateReg is 
        when TEST_LOGIC_RESET => jtagStateReg <= TEST_LOGIC_RESET when jtag_TMS = '1' else RUN_TEST_IDLE;
        when RUN_TEST_IDLE    => jtagStateReg <= SELECT_DR        when jtag_TMS = '1' else RUN_TEST_IDLE;
        when SELECT_DR        => jtagStateReg <= SELECT_IR        when jtag_TMS = '1' else CAPTURE_DR;
        when CAPTURE_DR       => jtagStateReg <= EXIT1_DR         when jtag_TMS = '1' else SHIFT_DR;
        when SHIFT_DR         => jtagStateReg <= EXIT1_DR         when jtag_TMS = '1' else SHIFT_DR;
        when EXIT1_DR         => jtagStateReg <= UPDATE_DR        when jtag_TMS = '1' else PAUSE_DR;
        when PAUSE_DR         => jtagStateReg <= EXIT2_DR         when jtag_TMS = '1' else PAUSE_DR;
        when EXIT2_DR         => jtagStateReg <= UPDATE_DR        when jtag_TMS = '1' else SHIFT_DR;
        when UPDATE_DR        => jtagStateReg <= SELECT_DR        when jtag_TMS = '1' else RUN_TEST_IDLE;
        when SELECT_IR        => jtagStateReg <= TEST_LOGIC_RESET when jtag_TMS = '1' else CAPTURE_IR;
        when CAPTURE_IR       => jtagStateReg <= EXIT1_IR         when jtag_TMS = '1' else SHIFT_IR;
        when SHIFT_IR         => jtagStateReg <= EXIT1_IR         when jtag_TMS = '1' else SHIFT_IR;
        when EXIT1_IR         => jtagStateReg <= UPDATE_IR        when jtag_TMS = '1' else PAUSE_IR;
        when PAUSE_IR         => jtagStateReg <= EXIT2_IR         when jtag_TMS = '1' else PAUSE_IR;
        when EXIT2_IR         => jtagStateReg <= UPDATE_IR        when jtag_TMS = '1' else SHIFT_IR;
        when UPDATE_IR        => jtagStateReg <= SELECT_DR        when jtag_TMS = '1' else RUN_TEST_IDLE;
		    when others           => NULL; -- jtagStateReg <= RUN_TEST_IDLE; maybe?
      end case;
    end if;
  end process; 
  
  -- SHIFT REG
  process(jtag_TCK) is
  begin  
    if rising_edge(jtag_TCK) then
      case jtagStateReg is 
        when CAPTURE_IR => shiftReg <= ((SHIFT_REG_BITS-2 downto 0 => '0'), '1'); -- JTAG spec only says must end with 'b01. 
        when SHIFT_IR   => shiftReg <= ((SHIFT_REG_BITS-IR_BITS-1 downto 0 => '0'), jtag_TDI, shiftReg(IR_BITS-1 downto 1));
        when CAPTURE_DR => case irReg is 
                             when REG_BYPASS       => shiftReg <=  (SHIFT_REG_BITS- 1 downto 0 => '0');
                             when REG_IDCODE       => shiftReg <= ((SHIFT_REG_BITS-33 downto 0 => '0'), idcode);
                             when REG_DTM_INFO     => shiftReg <= ((SHIFT_REG_BITS-33 downto 0 => '0'), dtminfo);
                             when REG_DEBUG_ACCESS => shiftReg <= busyResponse when busy = '1' else nonbusyResponse;
                             when others => -- BYPASS
                                    shiftReg <= (SHIFT_REG_BITS-1 downto 0 => '0');
                           end case;
        when SHIFT_DR   => case irReg is 
                             when REG_BYPASS       => shiftReg <= ((SHIFT_REG_BITS- 2 downto 0 => '0'), jtag_TDI);
                             when REG_IDCODE       => shiftReg <= ((SHIFT_REG_BITS-33 downto 0 => '0'), jtag_TDI, shiftReg(31 downto 1));
                             when REG_DTM_INFO     => shiftReg <= ((SHIFT_REG_BITS-33 downto 0 => '0'), jtag_TDI, shiftReg(31 downto 1));
                             when REG_DEBUG_ACCESS => shiftReg <= (jtag_TDI, shiftReg(SHIFT_REG_BITS-1 downto 1));
                             when others => -- BYPASS
                                    shiftReg <= ((SHIFT_REG_BITS-2 downto 0 => '0'), jtag_TDI);
                           end case;
        when others     => NULL;
      end case;
    end if;
  end process;

  -- IR 
  process (jtag_TCK, jtag_TRST) is begin
    if (jtag_TRST = '1') then
      irReg<= REG_IDCODE;
    elsif rising_edge(jtag_TCK) then
      if (jtagStateReg ?= TEST_LOGIC_RESET) = '1' then
        irReg<= REG_IDCODE;
      elsif (jtagStateReg ?= UPDATE_IR) = '1' then
        irReg<= shiftReg(IR_BITS-1 downto 0);
      end if;
    end if;
  end process;
  
  -- Busy. We become busy when we first try to send a request.
  -- We stop being busy when we accept a response.
  -- This means that busyReg will still be set when we check it,
  -- so the logic for checking busy looks ahead.
  process (jtag_TCK, jtag_TRST) is begin
    if (jtag_TRST = '1') then
      busyReg <= '0';
    elsif rising_edge(jtag_TCK) then
      if i_dtm_req_valid = '1' then  -- UPDATE_DR onwards
        busyReg <= '1';
      elsif (i_dtm_resp_valid and i_dtm_resp_ready) = '1' then -- only in CAPTURE_DR
        busyReg <= '0';
      end if;
    end if;
  end process;

  -- Downgrade/Skip. We make the decision to downgrade or skip
  -- during every CAPTURE_DR, and use the result in UPDATE_DR.
  process (jtag_TCK, jtag_TRST) is begin
    if (jtag_TRST = '1') then
      skipOpReg            <= '0';
      downgradeOpReg       <= '0';
      stickyBusyReg        <= '0';
      stickyNonzeroRespReg <= '0';
    elsif rising_edge(jtag_TCK) then
      if (irReg ?= REG_DEBUG_ACCESS) = '1' then
        case jtagStateReg is 
          when CAPTURE_DR=>
            skipOpReg            <= busy;
            downgradeOpReg       <= (not busy and nonzeroResp);
            stickyBusyReg        <= busy;
            stickyNonzeroRespReg <= nonzeroResp;
          when UPDATE_DR=>
            skipOpReg      <= '0';
            downgradeOpReg <= '0';
          when others=> NULL;
        end case;
      elsif (irReg ?= REG_DTM_INFO) = '1' then
        case jtagStateReg is 
          when UPDATE_DR=>
            stickyNonzeroRespReg <= '0';
            stickyBusyReg        <= '0';
          when others=> NULL;
        end case;
      end if;
    end if;
  end process;

  -- dbusReg, dbusValidReg.
  process (jtag_TCK, jtag_TRST) is begin
    if (jtag_TRST = '1') then
      dbusReg <= (DBUS_REG_BITS-1 downto 0 => '0');
      dbusValidReg <= '0';
    elsif rising_edge(jtag_TCK) then
      if (jtagStateReg ?= UPDATE_DR) = '1' then
        if (irReg ?= REG_DEBUG_ACCESS) = '1' then
          if skipOpReg = '1' then
            NULL; -- do nothing.
          elsif downgradeOpReg = '1' then
            dbusReg      <= (DBUS_REG_BITS-1 downto 0 => '0'); -- NOP has encoding 2'b00.
            dbusValidReg <= '1';
          else
            dbusReg      <= shiftReg(DBUS_REG_BITS-1 downto 0);
            dbusValidReg <= '1';    
          end if;
        end if;
      elsif i_dtm_req_ready = '1' then
        dbusValidReg <= '0';
      end if;
    end if;
  end process;

  -- TDO
  process (jtag_TCK, jtag_TRST) is begin
    if (jtag_TRST = '1') then
      jtag_TDO     <= '0';
      jtag_DRV_TDO <= '0';
    elsif rising_edge(jtag_TCK) then
      if (jtagStateReg ?= SHIFT_IR) = '1' then
        jtag_TDO     <= shiftReg(0);
        jtag_DRV_TDO <= '1';
      elsif (jtagStateReg ?= SHIFT_DR) = '1' then
        jtag_TDO     <= shiftReg(0);
        jtag_DRV_TDO <= '1';
      else
        jtag_TDO     <= '0';
        jtag_DRV_TDO <= '0';
      end if;
    end if;
  end process;

  u_jtag2debug_cdc_tx: component sirv_gnrl_cdc_tx generic map(DW=> 41, SYNC_DP=> ASYNC_FF_LEVELS)
                                                     port map( o_vld   => dtm_req_valid, 
                                                               o_rdy_a => dtm_req_ready, 
                                                               o_dat   => dtm_req_bits ,
                                                               i_vld   => i_dtm_req_valid, 
                                                               i_rdy   => i_dtm_req_ready, 
                                                               i_dat   => i_dtm_req_bits ,
   
                                                               clk     => jtag_TCK,
                                                               rst_n   => not jtag_TRST
                                                             );
  u_jtag2debug_cdc_rx: component sirv_gnrl_cdc_rx generic map(DW=> 36, SYNC_DP=> ASYNC_FF_LEVELS)
                                                     port map( i_vld_a => dtm_resp_valid, 
                                                               i_rdy   => dtm_resp_ready, 
                                                               i_dat   => dtm_resp_bits ,
                                                               o_vld   => i_dtm_resp_valid, 
                                                               o_rdy   => i_dtm_resp_ready, 
                                                               o_dat   => i_dtm_resp_bits ,
   
                                                               clk     => jtag_TCK,
                                                               rst_n   => not jtag_TRST
                                                             );
end impl;