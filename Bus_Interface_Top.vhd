----------------------------------------------------------------------------------
-- Company:  University of Arkansas (NCREPT)
-- Engineer: Chris Farnell
-- 
-- Create Date:			20Apr2023
-- Last Updated:		21Apr2023
-- Design Name: 		Bus Interface w/ UART & PWM & SPI  (Buck-UG)
-- Module Name: 		BusInterface_UARK-Buck-UG- Behavioral
-- Project Name: 		BusInterface_UARK-Buck-UG
-- Target Devices: 		LCMXO3D-9400HC-6BG256C (MachXO3D_BreakoutBrd)
-- Tool versions: 		Lattice Diamond_x64 Build  3.12.0.240.2
-- Description: 
-- This Project was developed to demonstrate a system-level design which incorperates shared registers and communications.
-- You may use various Serial Interface programs to communicate with this including the old version of X-CTU (Version 5.2.8.6), 
-- Termite, HypterTerminal, or the Custom LabVIEW Interface created for this project (LabVIEW-CommEx_Bus_Interface_PWM_v1.0a_16Apr2021).
-- A key to remember is that you will need to create packets in Hex-Mode not the standard ASCII-Mode.
-- Four individual on-board LEDs will be controlled via a simple PWM interface.
-- Each PWM will have its duty cycle set via system registers which may be modified via the serial interface.
-- A Testbench for this project was created and demostrates base functionality.
--
---- PinOut:
-- Signal			CPLD_Pin	Description
-- LED_1			H11			LED1			(Output)	[Onboard LED]
-- LED_2			J13			LED2			(Output)	[Onboard LED]	
-- LED_3			J11			LED3			(Output)	[Onboard LED]
-- LED_4			L12			LED4			(Output)	[Onboard LED]
-- LED_5			K11			LED5			(Output)	[Onboard LED]
-- LED_6			L13			LED6			(Output)	[Onboard LED]
-- LED_7			N15			LED7			(Output)	[Onboard LED]
-- LED_8			P16			LED8			(Output)	[Onboard LED]
-- PWM_Test_Out		N14			PWM Test		(Output)	
-- SCI_TX			C11			Serial-TX		(Output)	[USB Serial Port on Breakout Board]
-- SCI_RX			A11			Serial-RX		(Input)		[USB Serial Port on Breakout Board]
-- ADC_SCLK 		E6
-- ADC_DIN 			C5
-- ADC_CSn 			C4
-- ADC_DOUT			D6
-- DSP_G1			C12
-- DSP_G2			E11

--
---- Register and Memory Map Information:
-- This section describes the Memory Map used in this project.
-- This design contains a SPRAM Module which is 16 bits wide and 1024 entries deep.
-- Register addresses are from X"0000" to X"03FF".
-- All registers are 16-bits wide.
-- The SPRAM Module is located in the Bus_Master portion of the code.
-- This RAM Module may be accessed externally using Serial Port interface.
-- Reserved for future use.
-- X"0300" - X"03FF"
--
-- LED Configuration Values-
-- Range is X"0100" - X"010A"
--
-- SPI ADC Measurement Values-
-- Range is X"0200" - X"020A"
--
-- Register Map is found as constants in Bus_Interface_Common and shared with all submodules of this program.
--
---- Serial Settings
-- Baud: 			9600
-- Flow Control: 	None
-- Data Bits:		8
-- Parity: 			None
-- Stop Bits:		1
--
-- 
--
---- Serial Communications:
-- In the project we will construct packets to facilitate serial communication between the device and a computer. 
-- Using packets we can implement operational commands and check sums which allow for easily implementing a user GUI. 
-- You may use various Serial Interface programs to communicate with this including the old version of X-CTU (Version 5.2.8.6), 
-- Termite, HypterTerminal, or the Custom LabVIEW Interface created for this project (LabVIEW-CommEx_Bus_Interface_PWM_v1.0a_16Apr2021)
-- A key to remember is that you will need to create packets in Hex-Mode not the standard ASCII-Mode.
-- All packets will begin with a Start Delimiter (0x7E) and end with a CheckSum. 
-- The CheckSum is calculated by adding up all the bytes of the packet between the packet length and the checksum then 
-- subtracting the sum from 0xFF. 
-- We will implement two types of packets for our use. 
-- Register Write Command Packet (Used to update registers internal to the CPLD)
-- Register Read Command Packet (Used to read registers internal to the CPLD)
--
---Serial Write Packet (OP_ID = 0x0A)
-- The Register Write Command Packet is used to update registers internal to the CPLD. 
-- The following example breaks down a write request packet. 
-- The packet below writes 7 16-bit registers starting at register 0x0100; Values listed below. 
-- PWM_Enable     => 0x0001 (1=Enable; 0=Disable) 
-- LED_BlinkFreq  => 0xBFFF [75%]   (BFFF/FFFF) (%) 
-- LED_OnTime     => 0x6000 [50%]   (6000/BFFF) (%) 
-- LED1_Intensity => 0x2000 [12.5%] (2000/FFFF) (%)
-- LED2_Intensity => 0x4000 [25%]   (4000/FFFF) (%)
-- LED3_Intensity => 0x8000 [50%]   (8000/FFFF) (%)
-- LED4_Intensity => 0xFFFF [100%]  (FFFF/FFFF) (%)
--
-- Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address   |Register Data (16bit x Register_Cnt) | ChkSum
-- 0x7E           | 0x12    |0x0A |0x07          |0x0100          |0x0001BFFF6000200040008000FFFF       | 0xF0
-- 0x7E120A0701000001BFFF6000200040008000FFFFF0 results in all LEDs being set to the above parameters.
-- 0x7E120A0701000001BFFF60000000000000000000CE results in all LED Intensities being set to 0%. 
--
--- Serial Read Packet (OP_ID = 0x0F)
-- The Register Read Command Packet is used to read registers internal to the CPLD. 
-- The following example breaks down a read request packet. 
-- The packet below reads 16 16-bit registers starting at register 0x0100. 
--  Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address | ChkSum
--  0x7E           | 0x04    |0x0F |0x10          |0x0100        | 0xDF
-- 0x7E040F100100DF 
--
-- The above command results in a write command being sent from the CPLD which contains data from 16 16-bit registers starting at address 0x0100. 
-- An example response from the CPLD is shown below: 
-- 0x7E240A1001000001BFFF6000200040008000FFFF000000000000000000000000000000000000E7 
--  Start Delimiter| Pkt Len |Op ID| Register_Cnt |Start Address |Register Data (16bit x Register_Cnt)                               | ChkSum
--  0x7E           | 0x24    |0x0A |0x10          |0x0100        |0x0001BFFF6000200040008000FFFF000000000000000000000000000000000000 | 0xE7
-- 
--
--
--
--
-- Revisions:--
--
-- Revision 1.00a -
-- Updated for GitLab.
--
-- Revision 0.01 - 
-- File Created; Basic\Classical Operation Implemented
-- Created from BusInterface_UART_PWM_SPI
--
--
-- Additional Comments: 
-- 
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use ieee.numeric_std.all;

--LIBRARY lattice;
--USE lattice.components.all;


library machxo3d;
use machxo3d.all;


library work;
use work.Bus_Interface_Common.all;



entity Bus_Interface_Top is
    Port (
				---- RS232 Communication
				SCI_RX : in  STD_LOGIC;		-- Serial In for User Control
				SCI_TX : inout  STD_LOGIC;		-- Serial Out for User Control (Updated to "inout" so can read for LED Status)
				---- Board LEDs
				LED_1 : out  STD_LOGIC;		-- Board LED 
				LED_2 : out  STD_LOGIC;		-- Board LED 
				LED_3 : out  STD_LOGIC;		-- Board LED 
				LED_4 : out  STD_LOGIC;		-- Board LED 
				LED_5 : out  STD_LOGIC;		-- Board LED 
				LED_6 : out  STD_LOGIC;		-- Board LED 
				LED_7 : out  STD_LOGIC;		-- Board LED 
				LED_8 : out  STD_LOGIC;		-- Board LED 
				PWM_Test_Out : out  STD_LOGIC;	-- PWM Test Pin
				ADC_SCLK : INOUT  std_logic;
				ADC_DIN : INOUT  std_logic;
				ADC_CSn : OUT  std_logic;
				ADC_DOUT : IN  std_logic;
				DSP_G1 : out STD_LOGIC;		-- Gate Signal (Buck Control)
				DSP_G2 : out STD_LOGIC			-- Gate Signal (Keep Low)
				);
end Bus_Interface_Top;

architecture Behavioral of Bus_Interface_Top is	

	 -- Declare Internal Oscillator
	COMPONENT OSCJ
	GENERIC (NOM_FREQ: string := "8.31");
	PORT ( STDBY :IN std_logic;
		OSC :OUT std_logic;
		SEDSTDBY :OUT std_logic
		);
	END COMPONENT; 
	
	-- Declare PLL
    COMPONENT PLL_Clk
	PORT(
		ClkI: in  std_logic; 
		ClkOP: out std_logic;
		Lock: out std_logic
		);
    END COMPONENT;

	-- Declare Bus_Master
    COMPONENT Bus_Master
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         Data : INOUT  std_logic_vector(15 downto 0);
         Addr : IN  std_logic_vector(15 downto 0);
         Xrqst : IN  std_logic;
         XDat : OUT  std_logic;
         YDat : IN  std_logic;
         BusRqst : IN  std_logic_vector(9 downto 0);
         BusCtrl : OUT  std_logic_vector(9 downto 0)
        );
    END COMPONENT;
	  
	 -- Declare RS232_Usr_Int
	 COMPONENT RS232_Usr_Int
	 	Generic (
		Baud 		: integer;		-- Baud Rate
		clk_in 		: integer		-- Input Clk
		);
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         rs232_rcv : IN  std_logic;
         rs232_xmt : OUT  std_logic;
         Data : INOUT  std_logic_vector(15 downto 0);
         Addr : OUT  std_logic_vector(15 downto 0);
         Xrqst : OUT  std_logic;
         XDat : IN  std_logic;
         YDat : OUT  std_logic;
         BusRqst : OUT  std_logic;
         BusCtrl : IN  std_logic
        );
    END COMPONENT;
	
	-- Declare LED_Ctrl
	 COMPONENT LED_Ctrl is
    PORT ( 
			clk : in  STD_LOGIC;
			rst : in  STD_LOGIC;
			Data : INOUT  std_logic_vector(15 downto 0);
			Addr : OUT  std_logic_vector(15 downto 0);
			Xrqst : OUT  std_logic;
			XDat : IN  std_logic;
			YDat : OUT  std_logic;
			BusRqst : OUT  std_logic;
			BusCtrl : IN  std_logic;
			LED_En : out  STD_LOGIC;
			LED1_Out : out  STD_LOGIC;
			LED2_Out : out  STD_LOGIC;
			LED3_Out : out  STD_LOGIC;
			LED4_Out : out  STD_LOGIC;
			LED5_Out : out  STD_LOGIC;
			LED6_Out : out  STD_LOGIC;
			LED7_Out : out  STD_LOGIC;
			LED8_Out : out  STD_LOGIC
			);
    END COMPONENT;
	
	--Declare ADC_Int
	 COMPONENT ADC_Int is
    PORT ( 
			clk : in  STD_LOGIC;										
			rst : in  STD_LOGIC;										
			Data : INOUT  std_logic_vector(15 downto 0);
			Addr : OUT  std_logic_vector(15 downto 0);
			Xrqst : OUT  std_logic;
			XDat : IN  std_logic;
			YDat : OUT  std_logic;
			BusRqst : OUT  std_logic;
			BusCtrl : IN  std_logic;
			SPI_Sclk : inout  STD_LOGIC;								
			SPI_Din : inout  STD_LOGIC;							
			SPI_CSn : out  STD_LOGIC;												
			SPI_Dout : in  STD_LOGIC							
			);
    END COMPONENT;
	
	--Declare PI_Buck
	component PI_Buck is 
	port (
		clk: in std_logic;
		rst: in std_logic;
		Data : inout std_logic_vector(15 downto 0);
		Addr : out std_logic_vector(15 downto 0);
		Xrqst : out std_logic;
		XDat : in std_logic;
		YDat : out std_logic;
		BusRqst : out std_logic;
		BusCtrl : in std_logic
		);
	end component;
	
	
	-- Declare Std_Counter Component
	component Std_Counter is
	generic 
	(
		Width : integer		-- width of counter
	);
	port(INC,rst,clk: in std_logic;
		 Count: out STD_LOGIC_VECTOR(Width-1 downto 0));
	end component;
	 
	----Signals
	-- Declare Signals for Bus Interface
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy: STD_LOGIC:= '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn: STD_LOGIC_VECTOR(15 downto 0):= (others => '0');

	--  Inputs
	signal Addr : std_logic_vector(15 downto 0):= (others => '0');
	signal Xrqst : std_logic := '0';
	signal YDat : std_logic := '0';
	signal BusRqst : std_logic_vector(9 downto 0):= (others => '0');
	signal Data : std_logic_vector(15 downto 0):= (others => '0');
	signal XDat : std_logic := '0';
	signal BusCtrl : std_logic_vector(9 downto 0):= (others => '0');

	-- Internal Clock
	signal OSC_Stdby, OSC_Out, OSC_SEDSTDBY, clk: std_logic := '0';

	-- Reset
	signal PLL_Lock, System_rst: std_logic := '0';
	signal Reset_Cnt_INC, Reset_Cnt_rst: std_logic := '0';
	signal Reset_Cnt_out: std_logic_vector(7 downto 0):= (others => '0');
	
	-- Misc
	signal LED_En : std_logic := '0';
	-- For inverting LED Outputs
	signal LED_1n, LED_2n, LED_3n, LED_4n, LED_5n, LED_6n, LED_7n, LED_8n: STD_LOGIC:= '0';

begin

	-- Instantiate Internal Oscillator
	Int_OSC: OSCJ PORT MAP (
				STDBY => OSC_Stdby,
				OSC => OSC_Out,
				SEDSTDBY => OSC_SEDSTDBY
			);
			
			
	-- Instantiate PLL
	PLL_1: PLL_Clk PORT MAP (
				ClkI => OSC_Out,
				ClkOP => clk,
				Lock =>Pll_Lock
			);
			
			
	-- Instantiate Bus_Master
	BM: Bus_Master PORT MAP (
          clk => clk,
          rst => System_rst,
          Data => Data,
          Addr => Addr,
          Xrqst => Xrqst,
          XDat => XDat,
          YDat => YDat,
          BusRqst => BusRqst,
          BusCtrl => BusCtrl
        );
		
		
	-- Instantiate RS232_Usr_Int
	RS232_Usr: RS232_Usr_Int 
	Generic Map
	 (
		Baud 	=> 9600,	-- Baud Rate
		Clk_In => Clk_Freq	--	Input Clk
	 )
	PORT MAP (
         clk => clk,
         rst => System_rst,
         rs232_rcv => SCI_RX,
         rs232_xmt => SCI_TX,
         Data => Data,
         Addr => Addr,
         Xrqst => Xrqst,
         XDat => XDat,
         YDat => YDat,
         BusRqst => BusRqst(3),
         BusCtrl => BusCtrl(3)
       );		  
	   
	-- Instantiate LED_Ctrl
	LED_Ctrl1: LED_Ctrl PORT MAP (
				clk => clk,
				rst => System_rst,
				Data => Data,
				Addr => Addr,
				Xrqst => Xrqst,
				XDat => XDat,
				YDat => YDat,
				BusRqst => BusRqst(0),
				BusCtrl => BusCtrl(0),
				LED_En => LED_En,
				LED1_Out => LED_1n,
				LED2_Out => LED_2n,
				LED3_Out => LED_3n,
				LED4_Out => LED_4n,
				LED5_Out => LED_5n,
				LED6_Out => LED_6n,
				LED7_Out => LED_7n,
				LED8_Out => LED_8n
			);	
			
	--Instantiate ADC_Int
	ADC_Int1: ADC_Int PORT MAP (
				clk => clk,
				rst => System_rst,
				SPI_Sclk => ADC_SCLK,
				SPI_Din => ADC_DIN,
				SPI_CSn => ADC_CSn,
				SPI_Dout => ADC_DOUT,
				Data => Data,
				Addr => Addr,
				Xrqst => Xrqst,
				XDat => XDat,
				YDat => YDat,
				BusRqst => BusRqst(1),
				BusCtrl => BusCtrl(1)
			);
			
	-- Instantiate PI_Buck
	PI_Buck1: PI_Buck port map (
		clk => clk,
		rst => System_rst,
		Data => Data,
		Addr => Addr,
		Xrqst => Xrqst,
		XDat => XDat,
		YDat => YDat,
		BusRqst => BusRqst(2),
		BusCtrl => BusCtrl(2)
	); 
			
	-- Instantiate Reset_Cnt_8
	Reset_Cnt: Std_Counter
	generic map
	(
		Width => 8
	)
	port map( 
		clk => OSC_Out,
		rst=> Reset_Cnt_rst,
		INC=> Reset_Cnt_INC,
		Count=> Reset_Cnt_Out
	);
	
	

	--  Oscillator
	OSC_Stdby <= '0';
	
	
	-- Tie unused ports to '0'	  
	BusRqst(9 downto 4) <= (others => '0');
	--DSP_G1 <= '0';
	DSP_G2 <= '0';
	

	-- Reset Block1
	Reset_Blk1: process
	begin
			wait until OSC_Out'event and OSC_Out = '1';
				if(PLL_Lock ='0') then
					Reset_Cnt_rst <= '0'; -- Active Low
				else
					Reset_Cnt_rst <= '1';
				end if;
	end process;

	-- Reset Block
	Reset_Blk: process
	begin
			wait until OSC_Out'event and OSC_Out = '1';
				if(Reset_Cnt_out < X"7F") then
					System_rst <= '0'; -- Active Low
					Reset_Cnt_Inc <='1';
				else
					System_rst <= '1';
					Reset_Cnt_Inc <='0';
				end if;
	end process;

	-- LED Invert due to Active Low Configuration on Dev Board
	LED_Invert: process(LED_1n, LED_2n, LED_3n, LED_4n, LED_5n, LED_6n, LED_7n, LED_8n, SCI_RX, SCI_TX)
	begin
	
		LED_8 <= not(SCI_TX);		-- Used to show Serial Comms
		LED_7 <= not(SCI_RX);		-- Used to show Serial Comms
		LED_6 <= not(LED_6n);
		LED_5 <= not(LED_5n);
		LED_4 <= not(LED_4n);
		LED_3 <= not(LED_3n);
		LED_2 <= not(LED_2n);
		LED_1 <= not(LED_1n);
		PWM_Test_Out <= LED_1n;
		DSP_G1 <= LED_1n;
		
	end process;
	
end Behavioral;