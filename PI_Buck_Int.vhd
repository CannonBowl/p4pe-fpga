library IEEE;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

library work;
use work.Bus_Interface_Common.all;

entity PI_Buck is
	port ( clk: in std_logic;
			rst: in std_logic;
			Data : inout std_logic_vector(15 downto 0);
			Addr : out std_logic_vector(15 downto 0);
			Xrqst : out std_logic;
			XDat : in std_logic;
			YDat : out std_logic;
			BusRqst : out std_logic;
			BusCtrl : in std_logic
		);
end PI_Buck;

architecture Behaviorial of PI_Buck is
	type state_type is (s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17);
	signal CS_Bus, NS_Bus : state_type;

	-- Declare Std_Counter
	component Std_Counter is
		generic (
			Width : integer
		);
		port (INC, rst, clk : in std_logic;
			Count : out std_logic_vector(Width-1 downto 0)
		);
	end component;

	-- Declare Bus Interface
	component Bus_Int is
		port (
			clk : in std_logic;
			rst : in std_logic;
			DataIn : in std_logic_vector(15 downto 0);
			DataOut : out std_logic_vector(15 downto 0);
			AddrIn : in std_logic_vector(15 downto 0);
			WE : in std_logic;
			RE : in std_logic;
			Busy : out std_logic;
			Data : inout std_logic_vector(15 downto 0);
			Addr : out std_logic_vector(15 downto 0);
			Xrqst : out std_logic;
			XDat : in std_logic;
			YDat : out std_logic;
			BusRqst : out std_logic;
			BusCtrl : in std_logic
		);
	end component;
	
	---- Signals

	---- Constants
	-- Max Command Values
	constant Cmd_Max : std_logic_vector(15 downto 0) := x"0F00";
	constant Cmd_Min : std_logic_vector(15 downto 0) := x"0000";

	-- PI Shift Values
	constant P_Shift : integer := 1;
	constant I_Shift : integer := 1;

	-- Declare Signals for Bus Interface
	signal Bus_Int1_WE, Bus_Int1_RE, Bus_Int1_Busy : std_logic := '0';
	signal Bus_Int1_DataIn, Bus_Int1_DataOut, Bus_Int1_AddrIn : std_logic_vector(15 downto 0) := (others => '0');
	signal Bus_Cnt_rst, Bus_Cnt_INC : std_logic := '0';
	signal Bus_Cnt_Out : std_logic_vector(15 downto 0) := (others => '0');
	signal Delay_Cnt_rst, Delay_Cnt_INC : std_logic := '0';
	signal Delay_Cnt_Out : std_logic_vector(7 downto 0) := (others => '0');

	-- Signals for Registers
	signal Cmd_In, Cmd_In_reg_o : std_logic_vector(15 downto 0) := (others => '0');
	signal Mea_In, Mea_In_reg_o : std_logic_vector(15 downto 0) := (others => '0');
	signal Cmd_Out, Cmd_Temp : std_logic_vector(15 downto 0) := (others => '0');
	signal LD_Cmd_In, LD_Mea_In, LD_Cmd_Out : std_logic := '0';

	-- Signals for Internal PI Variables
	signal Err, Err_reg_o : signed(31 downto 0) := (others => '0');
	signal Err_S_Temp, Err_S_reg_o : std_logic := '0';
	signal Acc_S_Temp, Acc_S_reg_o : std_logic := '0';
	signal P_Temp, P_reg_o : signed(31 downto 0) := (others => '0');
	signal Acc_Temp, Acc_reg_o : signed(31 downto 0) := (others => '0');
	signal I_Temp, I_reg_o : signed(31 downto 0) := (others => '0');
	signal LD_Err, LD_Err_S, LD_P, LD_Acc, LD_Acc_S, LD_I : std_logic := '0';
 
	signal Acc_Temp_17b, Acc_Temp_17b_reg_o : signed(31 downto 0) := (others => '0');
	signal LD_Acc_Temp_17b : std_logic := '0';
	signal Cmd_Temp_17b, Cmd_Temp_17b_reg_o : signed(31 downto 0) := (others => '0');
	signal LD_Cmd_Temp_17b : std_logic := '0';
	signal Cmd_Temp_s, Cmd_Out_s : std_logic := '0';
	signal LD_Cmd_Temp_s : std_logic := '0';

begin

	-- Instantiate Bus_Cnt
	Bus_Cnt : Std_Counter
		generic map (
			Width => 16
		)
		port map (
			INC => Bus_Cnt_INC,
			rst => Bus_Cnt_rst,
			clk => clk,
			Count => Bus_Cnt_Out
		);

	-- Instantiate Delay_Cnt
	Delay_Cnt : Std_Counter
		generic map (
			Width => 8
		)
		port map (
			INC => Delay_Cnt_INC,
			rst => Delay_Cnt_rst,
			clk => clk,
			Count => Delay_Cnt_Out
		);

	-- Instantiate Bus Interface
	Bus_Int1 : Bus_Int
		port map (
			clk => clk,
			rst => rst,
			DataIn => Bus_Int1_DataIn,
			DataOut => Bus_Int1_DataOut,
			AddrIn => Bus_Int1_AddrIn,
			WE => Bus_Int1_WE,
			RE => Bus_Int1_RE,
			Busy => Bus_Int1_Busy,
			Data => Data,
			Addr => Addr,
			Xrqst => Xrqst,
			XDat => XDat,
			YDat => YDat,
			BusRqst => BusRqst,
			BusCtrl => BusCtrl
		);

	---- Registers
	Reg_Proc : process
	begin
		wait until clk'event and clk = '1';
		if rst = '0' then
			Cmd_In_reg_o <= (others => '0');
			Mea_In_reg_o <= (others => '0');
			Cmd_Out <= (others => '0');
			Cmd_Out_s <= '0';
			Err_reg_o <= (others => '0');
			P_reg_o <= (others => '0');
			Acc_reg_o <= (others => '0');
			I_reg_o <= (others => '0');
			Err_S_reg_o <= '0';
			Acc_S_reg_o <= '0';
			Acc_Temp_17b_reg_o <= (others => '0');
			Cmd_Temp_17b_reg_o <= (others => '0');
		else
			if (LD_Cmd_In = '1') then Cmd_In_reg_o <= Bus_Int1_DataOut; end if;
			if (LD_Mea_In = '1') then Mea_In_reg_o <= Bus_Int1_DataOut; end if;
			if (LD_Cmd_Out = '1') then Cmd_Out <= Cmd_Temp; end if;
			if (LD_Cmd_Temp_s = '1') then Cmd_Out_s <= Cmd_Temp_s; end if;
			if (LD_Err = '1') then Err_reg_o <= Err; end if;
			if (LD_P = '1') then P_reg_o <= P_Temp; end if;
			if (LD_Acc = '1') then Acc_reg_o <= Acc_Temp; end if;
			if (LD_I = '1') then I_reg_o <= I_Temp; end if;
			if (LD_Err_S = '1') then Err_S_reg_o <= Err_S_Temp; end if;
			if (LD_Acc_S = '1') then Acc_S_reg_o <= Acc_S_Temp; end if;
			if (LD_Acc_Temp_17b = '1') then Acc_Temp_17b_reg_o <= Acc_Temp_17b; end if;
			if (LD_Cmd_Temp_17b = '1') then Cmd_Temp_17b_reg_o <= Cmd_Temp_17b; end if;
		end if;
	end process;

	-- End Registers
	
	---- Next State Logic for Bus Interface
	NSL_Bus : process(CS_Bus, Bus_Cnt_Out, Bus_Int1_Busy, Delay_Cnt_Out, Cmd_In_reg_o, Mea_In_reg_o, Err_reg_o, Err_S_reg_o, Acc_S_reg_o, Acc_Temp_17b_reg_o, Cmd_Temp_17b_reg_o, Acc_reg_o, P_reg_o, I_reg_o)
	begin
	
		-- Default States to Remove Latches
		NS_Bus <= s0;
		Bus_Int1_AddrIn <= (others => '0');
		Bus_Int1_DataIn <= (others => '0');
		Bus_Int1_WE <= '0';
		Bus_Int1_RE <= '0';
		Bus_Cnt_rst <= '1';
		Bus_Cnt_INC <= '0';
		Delay_Cnt_rst <= '1';
		Delay_Cnt_INC <= '0';

		-- PI Ctrl Specific
		LD_Cmd_In <= '0';
		LD_Mea_In <= '0';
		LD_Cmd_Out <= '0';
		LD_Err <= '0';
		Ld_P <= '0';
		LD_Acc <= '0';
		LD_I <= '0';
		Cmd_Temp <= (others => '0');
		Err <= (others => '0');
		Err_S_Temp <= '0';
		Acc_S_Temp <= '0';
		LD_Err_S <= '0';
		LD_Acc_S <= '0';
		Acc_Temp_17b <= (others => '0');
		LD_Acc_Temp_17b <= '0';
		Cmd_Temp_17b <= (others => '0');
		LD_Cmd_Temp_17b <= '0';
		Acc_Temp <= (others => '0');
		P_Temp <= (others => '0');
		I_Temp <= (others => '0');
		Cmd_Temp_s <= '0';
		LD_Cmd_Temp_s <= '0';

		case CS_Bus is
			when s0 => 
				Bus_Cnt_rst <= '0';
				Delay_Cnt_rst <= '0';
				NS_Bus <= s1;

			when s1 =>
				if(Delay_Cnt_Out < X"FF") then
					NS_Bus <= s1;
				else
					NS_Bus <= s2;
				end if;
				Delay_Cnt_INC <= '1';

			when s2 =>
				if(Bus_Cnt_Out < X"0FDE") then
					NS_Bus <= s2;
				else
					NS_Bus <= s3;
				end if;
				Bus_Cnt_INC <= '1';

			
			-- Read Command Data from Bus
			when s3 =>
				if(Bus_Int1_Busy = '1') then
					NS_Bus <= s3;
				else
					NS_Bus <= s4;
				end if;
				Bus_Cnt_rst <= '0';

			when s4 =>
				Bus_Int1_AddrIn <= Addr_ADC1;
				Bus_Int1_RE <= '1';
				NS_Bus <= s5;

			when s5 =>
				if(Bus_Int1_Busy = '1') then
					NS_Bus <= s5;
				else
					LD_Mea_In <= '1';
					NS_Bus <= s6;
				end if;

			when s6 => 
				Bus_Int1_AddrIn <= Addr_Buck_SP;
				Bus_Int1_RE <= '1';
				NS_Bus <= s7;

			when s7 =>
				if(Bus_Int1_Busy = '1') then
					NS_Bus <= s7;
				else
					LD_Cmd_In <= '1';
					NS_Bus <= s8;
				end if;

			-- PI Calculations
			when s8 => 
				Err <= resize((signed(Cmd_In_reg_o) - signed(Mea_In_reg_o)), 32);
				LD_Err <= '1';
				NS_Bus <= s9;

			when s9 =>
				-- Divide by 256 for the Integral Term
				I_Temp <= shift_right(Err_reg_o, 14);

				-- Divide by 16 for the Proportional Term
				P_Temp <= Err_reg_o;

				LD_I <= '1';
				LD_P <= '1';
				NS_Bus <= s10;

			when s10 =>
				Acc_Temp_17b <= Acc_reg_o + I_reg_o;
				LD_Acc_Temp_17b <= '1';
				NS_Bus <= s11;

			when s11 =>
				if(Acc_Temp_17b_reg_o > 65535) then
					Acc_Temp <= X"0000FFFF";
				elsif(Acc_Temp_17b_reg_o < 0) then
					Acc_Temp_17b <= X"00000000";
				else
					Acc_Temp <= Acc_Temp_17b_reg_o;
				end if;
				LD_Acc <= '1';
				NS_Bus <= s12;

			when s12 =>
				Cmd_Temp_17b <= Acc_reg_o + P_reg_o;
				LD_Cmd_Temp_17b <= '1';
				NS_Bus <= s13;

			when s13 => 
				if(Cmd_Temp_17b_reg_o > signed(Cmd_Max)) then
					Cmd_Temp <= Cmd_Max(15 downto 0);
				elsif(Cmd_Temp_17b_reg_o < signed(Cmd_Min)) then
					Cmd_Temp <= (others => '0');
				else
					Cmd_Temp <= std_logic_vector(Cmd_Temp_17b_reg_o(15 downto 0));
				end if;
				LD_Cmd_Out <= '1';
				NS_Bus <= s14;

			-- Write Command Data to Bus
			when s14 =>
				if(Bus_Int1_Busy = '1') then 
					NS_Bus <= s14;
				else
					NS_Bus <= s15;
				end if;

			when s15 => 
				Bus_Int1_AddrIn <= Addr_Buck_DC;
				Bus_Int1_DataIn <= Cmd_Out;
				Bus_Int1_WE <= '1';
				NS_Bus <= s16;

			when s16 =>
				if(Bus_Int1_Busy = '1') then
					NS_Bus <= s16;
				else
					NS_Bus <= s2;
				end if;

			when others => 
				NS_Bus <= s0;
		end case;
	end process;

	-- State Sync
	sync_States : process
	begin
		wait until clk'event and clk = '1';
		if(rst = '0') then
			CS_Bus <= s0;
		else
			CS_Bus <= NS_Bus;
		end if;
	end process;

end Behaviorial; 
			