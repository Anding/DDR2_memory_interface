--------------------------------------------------------------
--	Simple testbench for DDR2 controller
--------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_textio.all;
USE std.textio.all;
USE WORK.all;
LIBRARY STD;
USE STD.TEXTIO.ALL;

entity test_fpga_top is
end test_fpga_top;

architecture behavioral of test_fpga_top is

signal clk	: std_logic;
signal nrst : std_logic;
signal led : std_logic_vector(1 downto 0);

signal SDRAM_A 	: std_logic_vector(13 downto 0);
signal SDRAM_BA 	: std_logic_vector(2 downto 0);
signal SDRAM_CLK      : std_logic;  
signal SDRAM_nCLK     : std_logic;
signal SDRAM_DQ       : std_logic_vector(15 downto 0);   
signal SDRAM_DM       : std_logic_vector(1 downto 0);   
signal SDRAM_DQS      : std_logic_vector(1 downto 0);
signal SDRAM_nDQS     : std_logic_vector(1 downto 0); 
signal SDRAM_nRDQS    : std_logic_vector(1 downto 0);
signal SDRAM_UDQM    : std_logic;
signal SDRAM_LDQM    : std_logic;
signal SDRAM_nCAS     : std_logic;
signal SDRAM_nCS      : std_logic;
signal SDRAM_nRAS     : std_logic;
signal SDRAM_nWE      : std_logic; 

signal SDRAM_CKE      : std_logic;      
signal SDRAM_ODT      : std_logic;


component fpga_top is port(
	clk : in std_logic;
	nrst : in std_logic;
	led : out std_logic_vector(1 downto 0);
	sevenseg : out STD_LOGIC_VECTOR (6 downto 0);
	anode : out STD_LOGIC_VECTOR (7 downto 0);	
	SDRAM_A : out std_logic_vector(13 downto 0);
	SDRAM_BA : out std_logic_vector(2 downto 0);
	SDRAM_CKE      : out std_logic;
	SDRAM_CK      : out std_logic;
	SDRAM_nCK		: out std_logic;
	SDRAM_DQ       : inout std_logic_vector(15 downto 0);     
	SDRAM_DQS	   : inout std_logic_vector(1 downto 0);
	--SDRAM_nDQS	   : inout std_logic_vector(1 downto 0);
	SDRAM_LDQM    : out std_logic;
	SDRAM_UDQM    : out std_logic;
	SDRAM_nCAS     : out std_logic;
	SDRAM_nCS      : out std_logic;
	SDRAM_nRAS     : out std_logic;
	SDRAM_nWE      : out std_logic;
	SDRAM_ODT      : out std_logic);
	
end component;

component ddr2 is port (
    ck : in std_logic;
    ck_n : in std_logic;
    cke : in std_logic;
    cs_n : in std_logic;
    ras_n : in std_logic;
    cas_n : in std_logic;
    we_n : in std_logic;
    dm_rdqs : inout std_logic_vector(1 downto 0);
    ba : in std_logic_vector(2 downto 0);
    addr : in std_logic_vector(13 downto 0);
    dq : inout std_logic_vector(15 downto 0);
    dqs : inout std_logic_vector(1 downto 0);
    dqs_n : inout std_logic_vector(1 downto 0);
    rdqs_n : inout std_logic_vector(1 downto 0);
    odt : in std_logic
);
end component;

BEGIN


------------------------------------------------------------------------
--	all test pass
------------------------------------------------------------------------
stop_test_pass_gen:PROCESS
BEGIN

      WAIT FOR 10 ns;
      
      if (led = "11") then
	      ASSERT false REPORT "test passed" severity warning;
	  elsif (led = "01") then
	      ASSERT false REPORT "test failed" severity failure;
	  end if;

END PROCESS;

------------------------------------------------------------------------
--	clk
------------------------------------------------------------------------
clk_gen:PROCESS
   BEGIN
      clk <= '0';
      WAIT FOR 5000 ps;
      clk <= '1';
      WAIT FOR 5000 ps;
   END PROCESS;

------------------------------------------------------------------------
--	nrst
------------------------------------------------------------------------
reset_gen:PROCESS
   BEGIN
      nrst <= '1';
      WAIT FOR 600 ns;
      nrst <= '1' ;

      WAIT FOR 10100 ns;
      ASSERT false REPORT "test done" severity warning;
   END PROCESS;

------------------------------------------------------------------------
--	FPGA
------------------------------------------------------------------------
UUT : fpga_top port map (
   	clk => clk,
  	nrst => nrst, 
	led		=> led,

	SDRAM_A        => SDRAM_A,
	SDRAM_BA       => SDRAM_BA,
	SDRAM_CKE       => SDRAM_CKE,
	SDRAM_CK      => SDRAM_CLK,
	SDRAM_nCK	=> SDRAM_nCLK,
	SDRAM_DQ       => SDRAM_DQ,
	SDRAM_DQS	 => SDRAM_DQS,
	--SDRAM_nDQS	   => SDRAM_nDQS,
	SDRAM_LDQM    => SDRAM_LDQM,
	SDRAM_UDQM    => SDRAM_UDQM,
	SDRAM_nCAS     => SDRAM_nCAS,
	SDRAM_nCS      => SDRAM_nCS,
	SDRAM_nRAS     => SDRAM_nRAS,
	SDRAM_nWE      => SDRAM_nWE,
	SDRAM_ODT	=> SDRAM_ODT);
                 
------------------------------------------------------------------------
--	Memory
------------------------------------------------------------------------ 
SDRAM_DM(0) <= SDRAM_LDQM;
SDRAM_DM(1) <= SDRAM_UDQM; 
--SDRAM_ODT <= '0';     

SDRAM_nDQS <= "ZZ";

sdramddr2 : ddr2 port map (
        ck => SDRAM_CLK, 
        ck_n => SDRAM_nCLK, 
        cke => SDRAM_CKE, 
        cs_n => SDRAM_nCS, 
        ras_n => SDRAM_nRAS, 
        cas_n => SDRAM_nCAS, 
        we_n => SDRAM_nWE, 
        dm_rdqs => SDRAM_DM, 
        ba => SDRAM_BA, 
        addr => SDRAM_A, 
        dq => SDRAM_DQ, 
        dqs => SDRAM_DQS,
        dqs_n => SDRAM_nDQS,
        rdqs_n => SDRAM_nRDQS,
        odt => SDRAM_ODT
    );      
    
end behavioral;


