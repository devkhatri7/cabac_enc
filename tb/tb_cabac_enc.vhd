-- ********************************************************************************
-- cabac_enc coder Testbench for HEVC h.265	      
-- 01/03/2017			      
-- Norwegian University of Science and Technology              
-- Lars Erik Songe Paulsen             
-- ********************************************************************************


library std;
use std.textio.all;
use std.env.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library ieee;
use ieee.std_logic_textio.all;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.cabac_enc_pkg.all;


entity tb_cabac_enc is

end tb_cabac_enc;

architecture struct of tb_cabac_enc is 

  constant C_SCOPE      : string  := C_TB_SCOPE_DEFAULT;  -- From adaptations pkg: 'TB seq.'

	-- ---------------------------------------------------------------------------
	-- Signal declarations
	-- ---------------------------------------------------------------------------
	
	signal clk		 : std_logic;
	signal Input	 : std_logic_vector(InputW-1 downto 0);
    signal InputLen  : std_logic_vector(InputWLen-1 downto 0);
	signal ctxIdx	 : std_logic_vector(6 downto 0);
    signal SliceQPY  : std_logic_vector(5 downto 0);
    signal initType  : std_logic_vector(1 downto 0);
	signal Resetn	 : std_logic;
	signal Start   	 : std_logic;
	signal Output    : std_logic_vector(OutputW-1 downto 0);
	signal OutputLen : std_logic_vector(OutputWLen-1 downto 0);
    signal BypassI   : std_logic;
    signal BypassO   : std_logic;
    signal TermI     : std_logic;
    signal TermO     : std_logic;
    signal Finished  : std_logic;

	-- ---------------------------------------------------------------------------
	-- Test input
	-- ---------------------------------------------------------------------------

    -- Include TestFile.txt in Vivado simulation sources.
	file TestFile : TEXT open read_mode is "..\..\HEVC_CABAC_Verification_Tool\HEVC_CABAC_Verification_Tool\bin\Debug\TestFile.txt";
    -- Target output
    file TestFileOut : TEXT open write_mode is "..\..\HEVC_CABAC_Verification_Tool\HEVC_CABAC_Verification_Tool\bin\Debug\DecoderInput.txt";
	
	-- ---------------------------------------------------------------------------
	-- Functions
	-- ---------------------------------------------------------------------------

    impure function FormatOutput
       (Output : std_logic_vector;
        from   : integer; 
        length  : integer; 
        Bypass : std_logic) 
        return std_logic is 
        variable temp       : string(1 to length) := (others => 'X'); 
        variable tempindex  : integer range 1 to 1024 := 1;
        variable targetline : line;
    begin 
        for i in from downto from-length+1 loop 
            case Output(i) is 
                when '0' => temp(tempindex)    := '0'; 
                            tempindex          := tempindex + 1;
                when '1' => temp(tempindex)    := '1'; 
                            tempindex          := tempindex + 1; 
                when others => temp(tempindex) := 'X'; 
            end case; 
        end loop;
        write(targetline, temp, left, length);
        writeline(TestFileOut, targetline);  
        if(tempindex-1 = length) then
            return '1'; 
        else 
            return '0';
        end if;
    end function FormatOutput;

    procedure FormatInput
       (signal BypassFlag : out std_logic;
        signal InputData : out std_logic_vector(InputW-1 downto 0);
        signal InputDataLen : out std_logic_vector(InputWLen-1 downto 0)) is
        variable fileline : line;
        variable tempindex  : integer range InputW-1 downto 0 := InputW-1;
        variable Inputset : integer := 0;
    begin 
        readline(TestFile, fileline); 
        for j in fileline'range loop
            if (Inputset = 0) then
                if (fileline(j) = ',') then
                    Inputset := 1; 
                elsif (fileline(j) = '1') then
                    Bypassflag <= '1'; 
                else
                    Bypassflag <= '0';
                end if;
            else
                if (fileline(j) = '1') then
                    InputData(tempindex) <= '1';
                    tempindex            := tempindex - 1; 
                else
                    InputData(tempindex) <= '0';
                    tempindex            := tempindex - 1; 
                end if;
            end if;
        end loop;
            InputDataLen <= std_logic_vector(to_unsigned(InputW-1-tempindex,InputWLen));
    end FormatInput;

	-- ---------------------------------------------------------------------------
	-- DUT component
	-- ---------------------------------------------------------------------------

	component cabac_enc is
		port 
		(
        clk       : in std_logic;
        Input     : in std_logic_vector(InputW-1 downto 0);
        InputLen  : in std_logic_vector(InputWLen-1 downto 0);
        ctxIdx 	  : in std_logic_vector(6 downto 0);
        SliceQPY  : in std_logic_vector(5 downto 0);
        initType  : in std_logic_vector(1 downto 0);
        Resetn	  : in std_logic;
        Start	  : in std_logic;
        Output    : out std_logic_vector(OutputW-1 downto 0); 
        OutputLen : out std_logic_vector(OutputWLen-1 downto 0); 
        BypassI   : in std_logic;
        BypassO   : out  std_logic;
        TermI     : in std_logic;
        TermO     : out std_logic;
        Finished  : out std_logic
        );
	end component cabac_enc;

	
begin

	-- ---------------------------------------------------------------------------
	-- DUT port map
	-- ---------------------------------------------------------------------------
	cabac_enc_inst : cabac_enc
		port map
		(
		clk      				=> clk,
		Input 			        => Input,
        InputLen            => InputLen,
		ctxIdx			    => ctxIdx,
        SliceQPY                => SliceQPY,
        initType                => initType,
		Resetn				    => Resetn,
		Start			=> Start,
		Output		            => Output,
		OutputLen	        => OutputLen,
        BypassI                  => BypassI,
        BypassO                  => BypassO,
        TermI             => TermI,
        TermO              => TermO,
        Finished                => Finished
		);

	clkGen : process
	begin
		clk <= '1';
		wait for 5 ns;
		clk <= '0';
		wait for 5 ns;
	end process;

	TestGen : process
		
	-- ---------------------------------------------------------------------------
	-- Variable declarations
	-- ---------------------------------------------------------------------------

    --The status of the arithmetic decoding engine is represented by the variables codIRange and codIOffset. In the
    --initialization procedure of the arithmetic decoding process, codIRange is set equal to 510 and codIOffset is set equal to
    --the value returned from read_bits( 9 ) interpreted as a 9 bit binary representation of an unsigned integer with most
    --significant bit written first.

	variable TestString : string(InputW downto 1);
    variable TestStringWL : string(InputWLen downto 1);    
    variable TestStringBypassI : string(1 downto 1);

	variable TestLine : line;

    variable TestStringOut : string(InputW+2 downto 1);
    variable TestStringBypassO : string(InputW downto 1);
    variable TestLineOut : line;

    variable codIOffset : integer range 0 to 1023 := 0;
    variable codIRange : integer range 0 to 511 := 510;
    variable codIRangeVector : std_logic_vector(8 downto 0);

    variable successparse : std_logic;


	begin

    log(ID_LOG_HDR, "Start Simulation --- tb_cabac_enc ---", C_SCOPE);

        --file_open(TestFileOut, "TestFileOut.txt", write_mode);
        Input <= (others => '0');
        InputLen <= (others => '0');
        BypassI <= '0';
        initType <= "10";
        SliceQPY <= "000010";
        ctxIdx <= "0000010";
        -- offset: 2*345+2*115+2-1 = 921
        TermI <= '0';

        FormatInput(BypassI, Input, InputLen); 

        Resetn <= '0';
        wait for 5 ns;
        Resetn <= '1';        
        Start <= '1';
        wait for 10 ns;
        Start <= '0';

        wait until Finished = '1';

        if(conv_integer(OutputLen) /= 0) then
            if(conv_integer(OutputLen) /= 0) then                
                assert (FormatOutput(Output, OutputW-1, conv_integer(OutputLen), BypassO) = '1') 
                    report "Fatal error writing to file";
            end if;
        end if;

		while not endfile(TestFile) loop

            log(ID_SEQUENCER_SUB, "Sending input", C_SCOPE);
            FormatInput(BypassI, Input, InputLen); 

            wait for 5 ns;
            Start <= '1';
            wait for 10 ns;
            Start <= '0';


            wait until Finished = '1';
            
            log(ID_SEQUENCER_SUB, "Storing output", C_SCOPE);
            if(conv_integer(OutputLen) /= 0) then                
                assert (FormatOutput(Output, OutputW-1, conv_integer(OutputLen), BypassO) = '1') 
                    report "Fatal error writing to file";
            end if;

        end loop;
        Input <= (InputW-1 => '1', others => '0');--0
        InputLen <= "000001"; -- Crude TermI
        BypassI <= '0'; -- BypassI = 0 for TermI
        TermI <= '1';

        wait for 5 ns;
        Start <= '1';
        wait for 10 ns;
        Start <= '0';
        wait until Finished = '1';

        if(conv_integer(OutputLen) /= 0) then                
                assert (FormatOutput(Output, OutputW-1, conv_integer(OutputLen), BypassO) = '1') 
                report "Fatal error writing to file";
        end if;

        file_close(TestFileOut);
        file_close(TestFile);
        stop(0);
		--finish(0);
	end process;
	
end struct;

