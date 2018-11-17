-- ********************************************************************************
-- cabac_enc_ coder for HEVC h.265       
-- 01/03/2017                 
-- Norwegian University of Science and Technology              
-- Lars Erik Songe Paulsen             
-- ********************************************************************************

-- ********************************************************************************
-- TODO LIST:    
-- ********************************************************************************
-- BinCountInNALUnits            
-- bitsOutstanding overflow
-- Replace ctxIdxTableInitials with calculation     
-- Proper memory interfacing for tables
-- ********************************************************************************

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.std_logic_arith.ALL;
use     ieee.numeric_std.all;
use     ieee.std_logic_unsigned.all;
use     ieee.std_logic_misc.all;

library std;
use     std.textio.all;

library work;
use     work.cabac_enc_pkg.all;

entity cabac_enc is

    port    
    (
    Clk       : in  std_logic;
    Input     : in  std_logic_vector(InputW-1 downto 0);
    InputLen  : in  std_logic_vector(InputWLen-1 downto 0);
    ctxIdx    : in  std_logic_vector(6 downto 0);
    SliceQPY  : in  std_logic_vector(5 downto 0);
    initType  : in  std_logic_vector(1 downto 0);
    Resetn    : in  std_logic;
    Start     : in  std_logic;
    Output    : out std_logic_vector(OutputW-1 downto 0); 
    OutputLen : out std_logic_vector(OutputWLen-1 downto 0);
    BypassI   : in  std_logic;
    BypassO   : out  std_logic;
    TermI     : in  std_logic;
    TermO     : out std_logic;
    Finished  : out std_logic
    );

end cabac_enc;

architecture struct of cabac_enc is

    -- ---------------------------------------------------------------------------
    -- Type declarations
    -- ---------------------------------------------------------------------------

    -- States
        type cabac_enc_StateType is(
                    r_Input, 
                    init_ctxTbl,
                    r_ctx,                    
                    enc_bin_r,        
                    enc_bin_b,
                    RenormE,
                    PutBit,
                    w_ctx,
                    enc_Term,
                    w_finished
                );

    -- ---------------------------------------------------------------------------
    -- Signal declarations
    -- ---------------------------------------------------------------------------

    -- ---------------------------------------------------------------------------
    -- Signal declarations
    -- ---------------------------------------------------------------------------
    signal cabac_enc_State                 : cabac_enc_StateType;
    signal currCtx                      : std_logic_vector(6 downto 0);
    signal initTbl                      : integer range 0 to ctxIdxRange-1;    

    -- Tables
    signal rangeTabLPS         : rangeTabLps_t :=  InitrangeTabLps("..\tables\rangeTabLPS.txt");
    signal transIdxLPS         : transIdx_t    :=  InittransIdx   ("..\tables\transIdxLPS.txt");
    signal transIdxMPS         : transIdx_t    :=  InittransIdx   ("..\tables\transIdxMPS.txt");
    signal ctxIdxTableInitials : ctxTblInit_t  :=  InitctxTbl     ("..\tables\ctxIdxTableInitials.txt");
    signal ctxIdxTable         : ctxTbl_t;

begin

    ---- ---------------------------------------------------------------------------
    ---- Debugger  process
    ---- ---------------------------------------------------------------------------
    --Debugger : process(Resetn)
    --begin
    --if rising_edge(Resetn) then
    --    for i in 0 to 63 loop
    --        report "index: "                & integer'image(i)                               &
    --            "   rangeTabLPS: "          & integer'image(conv_integer(rangeTabLPS(i)(0))) & 
    --            "   "                       & integer'image(conv_integer(rangeTabLPS(i)(1))) &
    --            "   "                       & integer'image(conv_integer(rangeTabLPS(i)(2))) &
    --            "   "                       & integer'image(conv_integer(rangeTabLPS(i)(3))) &
    --            "   transIdxLPS: "          & integer'image(conv_integer(transIdxLPS(i)))    &
    --            "   transIdxMPS: "          & integer'image(conv_integer(transIdxMPS(i)));
    --    end loop;
    --    for i in 0 to 17939 loop
    --        report "index: "                & integer'image(i)                               &
    --            "   ctxIdxTableInitials: "  & integer'image(conv_integer(ctxIdxTableInitials(i)));
    --    end loop;
    --end if;
    --end process;

    -- ---------------------------------------------------------------------------
    -- ctxIdxTable interfacing process
    -- ---------------------------------------------------------------------------
    ctxIdxTableLookups : process(Clk)
    begin
        if rising_edge(Clk) then
            case cabac_enc_State is
                when init_ctxTbl => -- TODO verify full table is loaded
                    -- Read context table inital values with the correct offset
                    ctxIdxTable(initTbl) 
                        <= ctxIdxTableInitials((conv_integer(SliceQPY)*(ctxIdxRange*3))
                            +(conv_integer(initType)*ctxIdxRange)+initTbl);
                when r_ctx =>
                    -- Store current context in working register
                    -- TODO: Figure out why this needs to in cabac_enc_ Process.
                when w_ctx =>
                    -- Update context from working register
                    ctxIdxTable(conv_integer(ctxIdx)) <= currCtx;
                when others =>
            end case;
        end if;
    end process;

    -- ---------------------------------------------------------------------------
    -- cabac_enc coding main process
    -- ---------------------------------------------------------------------------
    cabac_enc : process(Clk, Input, initType, SliceQPY, BypassI, Resetn, Start, ctxIdx, TermI)
    
    -- ---------------------------------------------------------------------------
    -- Variable declarations
    -- ---------------------------------------------------------------------------

    -- Encoding vals
    variable ivlLow : std_logic_vector(10 downto 0);
    variable ivlCurrRange : std_logic_vector(8 downto 0);
    variable ivlLpsRange : std_logic_vector(7 downto 0);
    variable qRangeIdx : std_logic_VECTOR(0 to 1);

    -- binVals
    variable bins : std_logic_vector(InputW-1 downto 0);
    variable binValI : integer range 0 to InputW-1;    
    variable binsLen : std_logic_vector(InputWLen-1 downto 0);

    -- PutBit variables
    variable PutBitVal : std_logic;
    variable PutBitI : integer range OutputW-1 downto 0;
    variable bitsOutstanding : integer range 0 to OutputW-1; 
    variable firstBitFlag : std_logic;

    variable Flushed : std_logic_vector(1 downto 0);

    variable InitFlag : std_logic;

    begin
        if Resetn = '0' then
            currCtx                <= (others => '0');
            Output                       <= (others => '0');
            OutputLen                    <= (others => '0');
            cabac_enc_State                 <= r_Input;
            Finished                     <= '1';
            TermO                        <= '0';
            BypassO                      <= '0';
            InitFlag                     := '0';
            Flushed                      := "00";
            initTbl                      <= 0;
            ivlLow                       := (others => '0');--0
            ivlCurrRange                 := "111111110"; --510
            firstBitFlag                 := '1';
            bitsOutstanding              := 0;
            qRangeIdx                    := (others => '0');
            PutBitI                  := 0;
        elsif rising_edge(Clk) then
            case cabac_enc_State is
                when r_Input =>
                    if (Start = '1') then
                        if (InitFlag = '0') then
                            cabac_enc_State <= init_ctxTbl;
                        elsif (TermI = '1') then
                            cabac_enc_State <= enc_Term;    
                        else
                            if (BypassI = '1') then
                                cabac_enc_State <= enc_bin_b;
                            else
                                cabac_enc_State <= r_ctx;
                            end if;
                        end if;
                        BypassO     <= BypassI;
                        bins        := Input;
                        binsLen     := InputLen;
                        Finished    <= '0';
                        binValI     := InputW-1;
                    end if;
                when init_ctxTbl =>
                    if (initTbl = (ctxIdxRange-1)) then 
                        if(BypassI = '1') then
                            cabac_enc_State <= enc_bin_b;
                        else
                            cabac_enc_State <= r_ctx;
                        end if;
                        InitFlag := '1';
                    else
                        initTbl <= initTbl + 1;
                    end if;  
                when r_ctx =>  
                    cabac_enc_State <= enc_bin_r;
                    currCtx      <= ctxIdxTable(conv_integer(ctxIdx));
                when enc_bin_b =>
                    if (binValI>=(InputW-conv_integer(binsLen))) then
                        ivlLow := ivlLow(9 downto 0) & "0";
                        if (bins(binValI) /= '0') then
                            ivlLow := ivlLow + ivlCurrRange;
                        end if;
                        if (ivlLow>=1024) then
                            PutBitVal       := '1';
                            cabac_enc_State <= PutBit;
                            ivlLow       := ivlLow - 1024;
                        elsif (ivlLow<512) then
                            PutBitVal    := '0';
                            cabac_enc_State <= PutBit;
                        else
                            ivlLow          := ivlLow - 512;
                            bitsOutstanding := bitsOutstanding + 1;
                        end if;
                        binValI := binValI - 1;
                    else
                        OutputLen    <= std_logic_vector(to_unsigned(PutBitI,OutputWLen));
                        cabac_enc_State <= w_ctx;                                
                    end if;
                when enc_bin_r =>
                    if (binValI>=(InputW-conv_integer(binsLen))) then
                        qRangeIdx    := ivlCurrRange(7 downto 6);
                        ivlLpsRange  := rangeTabLPS(conv_integer(currCtx(5 downto 0)))(conv_integer(qRangeIdx));
                        ivlCurrRange := ivlCurrRange - ivlLpsRange;
                        if(bins(binValI) /= currCtx(6)) then
                            ivlLow       := ivlLow + ivlCurrRange;
                            ivlCurrRange := "0" & ivlLpsRange;
                            if(currCtx(5 downto 0) = "000000") then
                                currCtx(6) <= not currCtx(6);
                            end if;
                            currCtx(5 downto 0) <= transIdxLPS(conv_integer(currCtx(5 downto 0)));
                        else
                            currCtx(5 downto 0) <= transIdxMPS(conv_integer(currCtx(5 downto 0)));
                        end if;
                        binValI  := binValI - 1;
                        cabac_enc_State <= RenormE;
                    else
                        OutputLen <= std_logic_vector(to_unsigned(PutBitI,OutputWLen));
                        cabac_enc_State <= w_ctx;
                    end if;
                when RenormE =>
                    if (ivlCurrRange < 256) then
                        if (ivlLow < 256) then
                            PutBitVal       := '0';
                            cabac_enc_State <= PutBit;
                        elsif(ivlLow >= 512) then
                            ivlLow       := ivlLow - 512;
                            PutBitVal    := '1';
                            cabac_enc_State <= PutBit;
                        else
                            ivlLow := ivlLow - 256;
                            bitsOutstanding := bitsOutstanding + 1;
                            ivlCurrRange    := ivlCurrRange(7 downto 0) & "0";
                            ivlLow          := ivlLow(9 downto 0) & "0";
                        end if;
                    else
                        if (Flushed = "11") then
                            OutputLen    <= std_logic_vector(to_unsigned(PutBitI,OutputWLen));
                            cabac_enc_State <= w_finished;
                        elsif (Flushed = "01") then
                            Flushed      := "10";
                            PutBitVal    := ivlLow(9);
                            cabac_enc_State <= PutBit;
                        else                        
                            cabac_enc_State <= enc_bin_r;
                        end if;
                    end if;
                when PutBit =>
                    if (firstBitFlag /= '0') then 
                        firstBitFlag := '0';
                    else
                        Output((OutputW-1)-PutBitI) <= PutBitVal;
                        PutBitI                     := PutBitI + 1;
                    end if;
                    PutBit_loop : for i in 0 to PutBitLoopLen-1 loop -- TODO: Potential overflow here if bitsOutstanding > PutBitLoopLen
                        if (bitsOutstanding > 0) then
                            Output((OutputW-1)-PutBitI) <= not PutBitVal;
                            bitsOutstanding             := bitsOutstanding - 1;
                            PutBitI                     := PutBitI + 1;
                        else
                            if(Flushed = "10") then
                                Output((OutputW-1)-PutBitI downto (OutputW-1)-PutBitI-1) <= ivlLow(8) & '1';
                                OutputLen    <= std_logic_vector(to_unsigned(PutBitI+2,OutputWLen));
                                cabac_enc_State <= w_finished;   
                            elsif(BypassI = '1') then
                                cabac_enc_State <= enc_bin_b;
                            else
                                ivlCurrRange := ivlCurrRange(7 downto 0) & "0";
                                ivlLow       := ivlLow(9 downto 0) & "0";
                                cabac_enc_State <= RenormE;
                            end if;
                            exit PutBit_loop;
                        end if;
                    end loop;
                when w_ctx => 
                    cabac_enc_State <= r_Input;
                    PutBitI  := 0;
                    Finished     <= '1';
                when enc_Term =>
                    ivlCurrRange := ivlCurrRange - 2;
                    if (bins(binValI) /= '0') then
                        ivlLow       := ivlLow + ivlCurrRange;
                        ivlCurrRange := "000000010"; --2
                        Flushed      := "01";
                        cabac_enc_State <= RenormE;
                    else                    
                        Flushed      := "11";
                        cabac_enc_State <= RenormE;
                    end if;
                when others =>
                    cabac_enc_State <= w_finished;
                    Finished     <= '1';
                    TermO        <= '1';
            end case;
        end if;
    end process;
end struct;