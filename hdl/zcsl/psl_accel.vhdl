-- $Id$
-- $URL$
-- $Source:  $

-- *!***************************************************************************
-- *! Copyright 2014 International Business Machines
-- *! 
-- *! Licensed under the Apache License, Version 2.0 (the "License");
-- *! you may not use this file except in compliance with the License.
-- *! You may obtain a copy of the License at
-- *! 
-- *!     http://www.apache.org/licenses/LICENSE-2.0
-- *! 
-- *! Unless required by applicable law or agreed to in writing, software
-- *! distributed under the License is distributed on an "AS IS" BASIS,
-- *! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- *! See the License for the specific language governing permissions and
-- *! limitations under the License.
-- *!
-- *!***************************************************************************
-- *! FILENAME    : psl_accel.vhdl
-- *! DESCRIPTION : 
-- *! GENERATOR   : c2v
-- *! SOURCE FILE : psl_accel.c
-- *!***************************************************************************



library ieee, work;
use ieee.std_logic_1164.all;
use work.std_ulogic_function_support.all;
use work.std_ulogic_support.all;
use work.std_ulogic_unsigned.all;

ENTITY psl_accel IS
  PORT(
       -- Accelerator Command Interface
       ah_cvalid: out std_ulogic;                                            -- A valid command is present
       ah_ctag: out std_ulogic_vector(0 to 7);                               -- request id
       ah_com: out std_ulogic_vector(0 to 12);                               -- command PSL will execute
       ah_cpad: out std_ulogic_vector(0 to 2);                               -- prefetch attributes
       ah_cabt: out std_ulogic_vector(0 to 2);                               -- abort if translation intr is generated
       ah_cea: out std_ulogic_vector(0 to 63);                               -- Effective byte address for command
       ah_cch: out std_ulogic_vector(0 to 15);                               -- Context Handle
       ah_csize: out std_ulogic_vector(0 to 11);                             -- Number of bytes
       ha_croom: in std_ulogic_vector(0 to 7);                               -- Commands PSL is prepared to accept
       
       -- command parity
       ah_ctagpar: out std_ulogic;
       ah_compar: out std_ulogic;
       ah_ceapar: out std_ulogic;
       
       -- Accelerator Buffer Interfaces
       ha_brvalid: in std_ulogic;                                            -- A read transfer is present
       ha_brtag: in std_ulogic_vector(0 to 7);                               -- Accelerator generated ID for read
       ha_brad: in std_ulogic_vector(0 to 5);                                -- half line index of read data
       ah_brlat: out std_ulogic_vector(0 to 3);                              -- Read data ready latency
       ah_brdata: out std_ulogic_vector(0 to 511);                           -- Read data
       ah_brpar: out std_ulogic_vector(0 to 7);                              -- Read data parity
       ha_bwvalid: in std_ulogic;                                            -- A write data transfer is present
       ha_bwtag: in std_ulogic_vector(0 to 7);                               -- Accelerator ID of the write
       ha_bwad: in std_ulogic_vector(0 to 5);                                -- half line index of write data
       ha_bwdata: in std_ulogic_vector(0 to 511);                            -- Write data
       ha_bwpar: in std_ulogic_vector(0 to 7);                               -- Write data parity
       
       -- buffer tag parity
       ha_brtagpar: in std_ulogic;
       ha_bwtagpar: in std_ulogic;
       
       -- PSL Response Interface
       ha_rvalid: in std_ulogic;                                             --A response is present
       ha_rtag: in std_ulogic_vector(0 to 7);                                --Accelerator generated request ID
       ha_response: in std_ulogic_vector(0 to 7);                            --response code
       ha_rcredits: in std_ulogic_vector(0 to 8);                            --twos compliment number of credits
       ha_rcachestate: in std_ulogic_vector(0 to 1);                         --Resultant Cache State
       ha_rcachepos: in std_ulogic_vector(0 to 12);                          --Cache location id
       ha_rtagpar: in std_ulogic;
       
       -- MMIO Interface
       ha_mmval: in std_ulogic;                                              -- A valid MMIO is present
       ha_mmrnw: in std_ulogic;                                              -- 1 = read, 0 = write
       ha_mmdw: in std_ulogic;                                               -- 1 = doubleword, 0 = word
       ha_mmad: in std_ulogic_vector(0 to 23);                               -- mmio address
       ha_mmdata: in std_ulogic_vector(0 to 63);                             -- Write data
       ha_mmcfg: in std_ulogic;                                              -- mmio is to afu descriptor space
       ah_mmack: out std_ulogic;                                             -- Write is complete or Read is valid pulse
       ah_mmdata: out std_ulogic_vector(0 to 63);                            -- Read data
       
       -- mmio parity
       ha_mmadpar: in std_ulogic;
       ha_mmdatapar: in std_ulogic;
       ah_mmdatapar: out std_ulogic;
       
       -- Accelerator Control Interface
       ha_jval: in std_ulogic;                                               -- A valid job control command is present
       ha_jcom: in std_ulogic_vector(0 to 7);                                -- Job control command opcode
       ha_jea: in std_ulogic_vector(0 to 63);                                -- Save/Restore address
       ah_jrunning: out std_ulogic;                                          -- Accelerator is running level
       ah_jdone: out std_ulogic;                                             -- Accelerator is finished pulse
       ah_jcack: out std_ulogic;                                             -- Accelerator is with context llcmd pulse
       ah_jerror: out std_ulogic_vector(0 to 63);                            -- Accelerator error code. 0 = success
       ah_tbreq: out std_ulogic;                                             -- Timebase request pulse
       ah_jyield: out std_ulogic;                                            -- Accelerator wants to stop
       ha_jeapar: in std_ulogic;
       ha_jcompar: in std_ulogic;
       ah_paren: out std_ulogic;
       
       -- SFP+ Phy 0 Interface
       as_sfp0_phy_mgmt_clk_reset: out std_ulogic;
       as_sfp0_phy_mgmt_address: out std_ulogic_vector(0 to 8);
       as_sfp0_phy_mgmt_read: out std_ulogic;
       sa_sfp0_phy_mgmt_readdata: in std_ulogic_vector(0 to 31);
       sa_sfp0_phy_mgmt_waitrequest: in std_ulogic;
       as_sfp0_phy_mgmt_write: out std_ulogic;
       as_sfp0_phy_mgmt_writedata: out std_ulogic_vector(0 to 31);
       sa_sfp0_tx_ready: in std_ulogic;
       sa_sfp0_rx_ready: in std_ulogic;
       as_sfp0_tx_forceelecidle: out std_ulogic;
       sa_sfp0_pll_locked: in std_ulogic;
       sa_sfp0_rx_is_lockedtoref: in std_ulogic;
       sa_sfp0_rx_is_lockedtodata: in std_ulogic;
       sa_sfp0_rx_signaldetect: in std_ulogic;
       as_sfp0_tx_coreclk: out std_ulogic;
       sa_sfp0_tx_clk: in std_ulogic;
       sa_sfp0_rx_clk: in std_ulogic;
       as_sfp0_tx_parallel_data: out std_ulogic_vector(0 to 39);
       sa_sfp0_rx_parallel_data: in std_ulogic_vector(0 to 39);
       
       -- SFP+ 0 Sideband Signals
       sa_sfp0_tx_fault: in std_ulogic;
       sa_sfp0_mod_abs: in std_ulogic;
       sa_sfp0_rx_los: in std_ulogic;
       as_sfp0_tx_disable: out std_ulogic;
       as_sfp0_rs0: out std_ulogic;
       as_sfp0_rs1: out std_ulogic;
       as_sfp0_scl: out std_ulogic;
       as_sfp0_en: out std_ulogic;
       sa_sfp0_sda: in std_ulogic;
       as_sfp0_sda: out std_ulogic;
       as_sfp0_sda_oe: out std_ulogic;
       
       -- SFP+ Phy 1 Interface
       as_sfp1_phy_mgmt_clk_reset: out std_ulogic;
       as_sfp1_phy_mgmt_address: out std_ulogic_vector(0 to 8);
       as_sfp1_phy_mgmt_read: out std_ulogic;
       sa_sfp1_phy_mgmt_readdata: in std_ulogic_vector(0 to 31);
       sa_sfp1_phy_mgmt_waitrequest: in std_ulogic;
       as_sfp1_phy_mgmt_write: out std_ulogic;
       as_sfp1_phy_mgmt_writedata: out std_ulogic_vector(0 to 31);
       sa_sfp1_tx_ready: in std_ulogic;
       sa_sfp1_rx_ready: in std_ulogic;
       as_sfp1_tx_forceelecidle: out std_ulogic;
       sa_sfp1_pll_locked: in std_ulogic;
       sa_sfp1_rx_is_lockedtoref: in std_ulogic;
       sa_sfp1_rx_is_lockedtodata: in std_ulogic;
       sa_sfp1_rx_signaldetect: in std_ulogic;
       as_sfp1_tx_coreclk: out std_ulogic;
       sa_sfp1_tx_clk: in std_ulogic;
       sa_sfp1_rx_clk: in std_ulogic;
       as_sfp1_tx_parallel_data: out std_ulogic_vector(0 to 39);
       sa_sfp1_rx_parallel_data: in std_ulogic_vector(0 to 39);
       
       -- SFP+ 1 Sideband Signals
       sa_sfp1_tx_fault: in std_ulogic;
       sa_sfp1_mod_abs: in std_ulogic;
       sa_sfp1_rx_los: in std_ulogic;
       as_sfp1_tx_disable: out std_ulogic;
       as_sfp1_rs0: out std_ulogic;
       as_sfp1_rs1: out std_ulogic;
       as_sfp1_scl: out std_ulogic;
       as_sfp1_en: out std_ulogic;
       sa_sfp1_sda: in std_ulogic;
       as_sfp1_sda: out std_ulogic;
       as_sfp1_sda_oe: out std_ulogic;
       
       -- SFP+ Reference Clock Select
       as_refclk_sfp_fs: out std_ulogic;
       as_refclk_sfp_fs_en: out std_ulogic;
       
       -- SFP+ LED
       as_red_led: out std_ulogic_vector(0 to 3);
       as_green_led: out std_ulogic_vector(0 to 3);
       ha_pclock: in std_ulogic);

END psl_accel;



ARCHITECTURE psl_accel OF psl_accel IS


COMPONENT zcsl_top
  PORT(
       -- Accelerator Command Interface
       ah_cvalid: out std_ulogic;                                            -- A valid command is present
       ah_ctag: out std_ulogic_vector(0 to 7);                               -- request id
       ah_com: out std_ulogic_vector(0 to 12);                               -- command PSL will execute
--       ah_cpad: out std_ulogic_vector(0 to 2);                               -- prefetch attributes
       ah_cabt: out std_ulogic_vector(0 to 2);                               -- abort if translation intr is generated
       ah_cea: out std_ulogic_vector(0 to 63);                               -- Effective byte address for command
       ah_cch: out std_ulogic_vector(0 to 15);                               -- Context Handle
       ah_csize: out std_ulogic_vector(0 to 11);                             -- Number of bytes
       ha_croom: in std_ulogic_vector(0 to 7);                               -- Commands PSL is prepared to accept

       -- command parity
       ah_ctagpar: out std_ulogic;
       ah_compar: out std_ulogic;
       ah_ceapar: out std_ulogic;

       -- Accelerator Buffer Interfaces
       ha_brvalid: in std_ulogic;                                            -- A read transfer is present
       ha_brtag: in std_ulogic_vector(0 to 7);                               -- Accelerator generated ID for read
       ha_brad: in std_ulogic_vector(0 to 5);                                -- half line index of read data
       ah_brlat: out std_ulogic_vector(0 to 3);                              -- Read data ready latency
       ah_brdata: out std_ulogic_vector(0 to 511);                           -- Read data
       ah_brpar: out std_ulogic_vector(0 to 7);                              -- Read data parity
       ha_bwvalid: in std_ulogic;                                            -- A write data transfer is present
       ha_bwtag: in std_ulogic_vector(0 to 7);                               -- Accelerator ID of the write
       ha_bwad: in std_ulogic_vector(0 to 5);                                -- half line index of write data
       ha_bwdata: in std_ulogic_vector(0 to 511);                            -- Write data
       ha_bwpar: in std_ulogic_vector(0 to 7);                               -- Write data parity

       -- buffer tag parity
       ha_brtagpar: in std_ulogic;
       ha_bwtagpar: in std_ulogic;

       -- PSL Response Interface
       ha_rvalid: in std_ulogic;                                             --A response is present
       ha_rtag: in std_ulogic_vector(0 to 7);                                --Accelerator generated request ID
       ha_response: in std_ulogic_vector(0 to 7);                            --response code
       ha_rcredits: in std_ulogic_vector(0 to 8);                            --twos compliment number of credits
       ha_rcachestate: in std_ulogic_vector(0 to 1);                         --Resultant Cache State
       ha_rcachepos: in std_ulogic_vector(0 to 12);                          --Cache location id
       ha_rtagpar: in std_ulogic;

       -- MMIO Interface
       ha_mmval: in std_ulogic;                                              -- A valid MMIO is present
       ha_mmrnw: in std_ulogic;                                              -- 1 = read, 0 = write
       ha_mmdw: in std_ulogic;                                               -- 1 = doubleword, 0 = word
       ha_mmad: in std_ulogic_vector(0 to 23);                               -- mmio address
       ha_mmdata: in std_ulogic_vector(0 to 63);                             -- Write data
       ha_mmcfg: in std_ulogic;                                              -- mmio is to afu descriptor space
       ah_mmack: out std_ulogic;                                             -- Write is complete or Read is valid pulse
       ah_mmdata: out std_ulogic_vector(0 to 63);                            -- Read data

       -- mmio parity
       ha_mmadpar: in std_ulogic;
       ha_mmdatapar: in std_ulogic;
       ah_mmdatapar: out std_ulogic;

       -- Accelerator Control Interface
       ha_jval: in std_ulogic;                                               -- A valid job control command is present
       ha_jcom: in std_ulogic_vector(0 to 7);                                -- Job control command opcode
       ha_jea: in std_ulogic_vector(0 to 63);                                -- Save/Restore address
       ah_jrunning: out std_ulogic;                                          -- Accelerator is running level
       ah_jdone: out std_ulogic;                                             -- Accelerator is finished pulse
       ah_jcack: out std_ulogic;                                             -- Accelerator is with context llcmd pulse
       ah_jerror: out std_ulogic_vector(0 to 63);                            -- Accelerator error code. 0 = success
--       ah_tbreq: out std_ulogic;                                             -- Timebase request pulse
       ah_jyield: out std_ulogic;                                            -- Accelerator wants to stop
--       ha_lop           : IN  std_ulogic_vector(0 to 4);                    -- LPC / Internal Cache Operation Code when haX_jcom specifies LPC or SNOOP
--       ha_loppar        : IN  std_ulogic;                                   -- Odd parity for haX_lop
--       ha_lsize         : IN  std_ulogic_vector(0 to 6);                    -- Size (in bytes) and/or Secondary Operation code for LPC operations
--       ha_ltag          : IN  std_ulogic_vector(0 to 11);                   -- LPC Tag/ Internal Cache Tag, used for subsequent operation in response to this command.
--       ha_ltagpar       : IN  std_ulogic;                                   -- Odd parity for hax_ltag
       ha_jeapar: in std_ulogic;
       ha_jcompar: in std_ulogic;
       ah_paren: out std_ulogic;
--       ha_refclk: in std_ulogic;
       ha_pclock: in std_ulogic);
END COMPONENT zcsl_top;




begin

 IAFU : zcsl_top
    PORT MAP (
          ha_pclock        =>    ha_pclock                              -- Primary clock, rising edge active
--       , ha_refclk         =>    ha_refclk                              -- Reference clock for an internal PLL
-- Accelerator Control Interface
       , ha_jval          =>    ha_jval                                -- A valid job control command is present
       , ha_jcom         =>    ha_jcom                                -- Job control command opcode
       , ha_jea           =>    ha_jea                                 -- Save/Restore address
       , ah_jrunning      =>    ah_jrunning                            -- Accelerator is running
       , ah_jdone         =>    ah_jdone                               -- Accelerator is finished
       , ah_jerror        =>    ah_jerror                              -- Accelerator error code. 0 = success
       , ah_jyield        =>    ah_jyield                              -- Single cycle request for STOP command
--       , ha_lop           =>    (OTHERS => '0')                        -- LPC / Internal Cache Operation Code when haX_jcom specifies LPC or SNOOP
--       , ha_loppar        =>    '0'                                    -- Odd parity for haX_lop
--       , ha_lsize         =>    (OTHERS => '0')                        -- Size (in bytes) and/or Secondary Operation code for LPC operations
--       , ha_ltag          =>    (OTHERS => '0')                        -- LPC Tag/ Internal Cache Tag, used for subsequent operation in response to this command.
--       , ha_ltagpar       =>    '0'                                    -- Odd parity for hax_ltag
--       , ah_tbreq         =>    ah_tbreq                               -- Single cycle request for TimeBase command
       , ah_jcack         =>    ah_jcack                               -- llcmd acknowledge pulse
       , ha_jcompar       =>    ha_jcompar
       , ha_jeapar        =>    ha_jeapar
       , ah_paren         =>    ah_paren
-- Accelerator MMIO Interface
       , ha_mmval         =>    ha_mmval                               -- A valid MMIO is present
       , ha_mmrnw        =>    ha_mmrnw                               -- 1 = read, 0 = write
       , ha_mmdw          =>    ha_mmdw                                -- 1 = 64 bits, 0 = 32 bits operation
       , ha_mmad          =>    ha_mmad                                -- Save/Restore address
       , ha_mmdata        =>    ha_mmdata                              -- Write data
       , ha_mmcfg         =>    ha_mmcfg                               -- MMIO is afu descriptor space
       , ah_mmack         =>    ah_mmack                               -- Write is complete or Read data is valid
       , ah_mmdata        =>    ah_mmdata                              -- Read Data
       , ha_mmadpar       =>    ha_mmadpar
       , ha_mmdatapar     =>    ha_mmdatapar
       , ah_mmdatapar     =>    ah_mmdatapar
-- Accelerator Command Interface
       , ah_cvalid        =>    ah_cvalid                              -- A valid command is present on the interface
       , ah_ctag          =>    ah_ctag                                -- Accelerator ID for the request
       , ah_com           =>    ah_com                                 -- Which command -PSL will execute
--       , ah_cpad          =>    ah_cpad                                -- hints for page mode memory
       , ah_cabt          =>    ah_cabt                                -- PSL Address Translation Ordering directive
       , ah_cea           =>    ah_cea                                 -- Effective byte address for command
       , ah_csize         =>    ah_csize                               -- Number of bytes for partial line commands
       , ah_cch           =>    ah_cch                                 -- Context handle in afu driven context mode
       , ha_croom         =>    ha_croom                               -- Number of commands PSL is prepared to accept (initial credit)
       , ah_ctagpar       =>    ah_ctagpar
       , ah_compar        =>    ah_compar
       , ah_ceapar        =>    ah_ceapar
-- PSL Response Interface
       , ha_rvalid        =>    ha_rvalid                              -- A valid response is present
       , ha_rtag          =>    ha_rtag                                -- Accelerator generated ID for the request.
       , ha_response      =>    ha_response                            -- Response code
       , ha_rcredits      =>    ha_rcredits                            -- Twos compliment number of credits
       , ha_rcachestate   =>    ha_rcachestate                  -- noDD1: What state was granted for afu cache entry
       , ha_rcachepos     =>    ha_rcachepos                    -- noDD1: PSL generated cache position indicator
       , ha_rtagpar       =>    ha_rtagpar
-- Accelerator Buffer Interface
       , ha_brvalid       =>    ha_brvalid                             -- A valid read data transfer is present on the interface
       , ha_brtag         =>    ha_brtag                               -- Accelerator generated ID for the read request.
       , ha_brad          =>    ha_brad                                -- Half line index of read data within the transaction
       , ah_brlat         =>    ah_brlat                               -- Read data latency, 0000=1 clock anter brvalid, 0001=2 clocks, etc.
       , ah_brdata        =>    ah_brdata                              -- Read data
       , ah_brpar         =>    ah_brpar                               -- Read parity
       , ha_bwvalid       =>    ha_bwvalid                             -- A valid write data transfer is present on the interface
       , ha_bwtag         =>    ha_bwtag                               -- Accelerator generated ID for the write request.
       , ha_bwad          =>    ha_bwad                                -- Half line index of write data within the transaction
       , ha_bwdata        =>    ha_bwdata                              -- Write data
       , ha_bwpar         =>    ha_bwpar                               -- Write parity
       , ha_brtagpar      =>    ha_brtagpar
       , ha_bwtagpar      =>    ha_bwtagpar
       );
       
-- SFP+ Phy 0 Interface
as_sfp0_phy_mgmt_clk_reset <= '0';
as_sfp0_phy_mgmt_address <= (others => '0') ;
as_sfp0_phy_mgmt_read <= '0' ;
as_sfp0_phy_mgmt_write <= '0' ;
as_sfp0_phy_mgmt_writedata <= (others => '0') ;
as_sfp0_tx_forceelecidle <= '0' ;
as_sfp0_tx_coreclk <= '0' ;
as_sfp0_tx_parallel_data <= (others => '0') ;
as_sfp0_tx_disable <= '0' ;
as_sfp0_rs0 <= '0' ;
as_sfp0_rs1 <= '0' ;
as_sfp0_scl <= '0' ;
as_sfp0_en <= '0' ;
as_sfp0_sda <= '0' ;
as_sfp0_sda_oe <= '0' ;

-- SFP+ Phy 1 Interface
as_sfp1_phy_mgmt_clk_reset <= '0' ;
as_sfp1_phy_mgmt_address <= (others => '0') ;
as_sfp1_phy_mgmt_read <= '0' ;
as_sfp1_phy_mgmt_write <= '0' ;
as_sfp1_phy_mgmt_writedata <= (others => '0') ;
as_sfp1_tx_forceelecidle <= '0' ;
as_sfp1_tx_coreclk <= '0' ;
as_sfp1_tx_parallel_data <= (others => '0') ;
as_sfp1_tx_disable <= '0' ;
as_sfp1_rs0 <= '0' ;
as_sfp1_rs1 <= '0' ;
as_sfp1_scl <= '0' ;
as_sfp1_en <= '0' ;
as_sfp1_sda <= '0' ;
as_sfp1_sda_oe <= '0' ;
as_refclk_sfp_fs <= '0' ;
as_refclk_sfp_fs_en <= '0' ;

as_red_led <= (others => '0') ;
as_green_led <= (others => '0') ;
    
END psl_accel;

