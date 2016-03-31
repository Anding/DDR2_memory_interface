-- DDR2 memory interface
-- Andrew Read, March 2016
-- This project is based on a working DDR2 interface very kindly donated by a friend

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_arith.all;
USE IEEE.std_logic_textio.all;

-- DQS not used in READ Cycles.
-- ODT disabled.


entity SDRAM_CTRL is 
port (
	CLK   : in  std_logic;  
	CLK_90 : in std_logic;								-- 100MHz clock 90 degree phase shift 
    nrst : in  std_logic;
        
	wrrd_ba_add : in std_logic_vector(2 downto 0);   -- bank address	
	wrrd_ras_add : in std_logic_vector(12 downto 0);  -- row address
	wrrd_cas_add : in std_logic_vector(8 downto 0);  -- column address
	
	wr_we : in std_logic;
	wr_add : in std_logic_vector(25 downto 0);  -- not used
	wr_dat : in std_logic_vector(31 downto 0);
	wr_ack : out std_logic;

	rd_re : in std_logic;
	rd_add : in std_logic_vector(25 downto 0);  -- not used
	rd_dat : out std_logic_vector(31 downto 0);
	rd_ack : out std_logic;   
	rd_valid : out std_logic;

	SDRAM_A : out std_logic_vector(13 downto 0);
	SDRAM_BA : out std_logic_vector(2 downto 0);
	SDRAM_CKE      : out std_logic;
	SDRAM_CK       : out std_logic;
	SDRAM_nCK	   : out std_logic;
	SDRAM_DQ       : inout std_logic_vector(15 downto 0);    
	SDRAM_DQS	   : out std_logic_vector(1 downto 0);
	--SDRAM_nDQS	   : inout std_logic_vector(1 downto 0);
	SDRAM_DM    : out std_logic_vector(1 downto 0);
	SDRAM_nCAS     : out std_logic;
	SDRAM_nCS      : out std_logic;
	SDRAM_nRAS     : out std_logic;
	SDRAM_nWE      : out std_logic);

end SDRAM_CTRL;


architecture Struct of SDRAM_CTRL is      

component SDRAM_PHYIO is 
port (
	CLK   : in  std_logic;
	CLK_90 : in std_logic;								-- 100MHz clock 90 degree phase shift
    nrst : in  std_logic; 

	wrrd_ba_add : in std_logic_vector(2 downto 0);
	wrrd_ras_add : in std_logic_vector(12 downto 0);
	wrrd_cas_add : in std_logic_vector(8 downto 0);
	
	wr_we : in std_logic;
	wr_add : in std_logic_vector(25 downto 0);
	wr_dat : in std_logic_vector(31 downto 0);
	wr_ack : out std_logic;

	rd_re : in std_logic;
	rd_add : in std_logic_vector(25 downto 0);
	rd_dat : out std_logic_vector(31 downto 0);
	rd_ack : out std_logic;
	rd_valid : out std_logic;        
	
	refresh : in std_logic;

	SDRAM_A : out std_logic_vector(13 downto 0);
	SDRAM_BA : out std_logic_vector(2 downto 0);
	SDRAM_CKE      : out std_logic;
	SDRAM_CK       : out std_logic;
	SDRAM_nCK	   : out std_logic;
	SDRAM_DQ       : inout std_logic_vector(15 downto 0); 
	SDRAM_DQS	   : out std_logic_vector(1 downto 0);
	--SDRAM_nDQS	   : inout std_logic_vector(1 downto 0);
	SDRAM_DM    : out std_logic_vector(1 downto 0);
	SDRAM_nCAS     : out std_logic;
	SDRAM_nCS      : out std_logic;
	SDRAM_nRAS     : out std_logic;
	SDRAM_nWE      : out std_logic);

end component;     
                                                
signal refresh_time_cnt : integer range 0 to 6400000;  
signal refresh : std_logic;

begin  
 
-----------------------------------------------------
--	Refresh Mechanism
-----------------------------------------------------

refresh_gen : process (CLK, nrst)
begin
if (nrst='0') then
   refresh_time_cnt <= 0;
   refresh <= '0';
elsif (CLK'event and CLK='0') then
	if (refresh = '0') then
		if (refresh_time_cnt = 640000) then -- should work 10-times slower         
			refresh <= '1';
			refresh_time_cnt <= 0;
		else
			refresh_time_cnt <= refresh_time_cnt + 1;
		end if;
	else
		if (refresh_time_cnt = 8200) then             
			refresh <= '0';
			refresh_time_cnt <= 0;
		else
			refresh_time_cnt <= refresh_time_cnt + 1;
		end if;
	end if;
end if;
end process;                  

-----------------------------------------------------
--	SDRAM_CTRL
-----------------------------------------------------
SDRAM_PHYIOi : SDRAM_PHYIO 
port map (
	CLK   => CLK,
	CLK_90 => CLK_90,
    nrst => nrst,  

	wrrd_ba_add => wrrd_ba_add,
	wrrd_ras_add => wrrd_ras_add,
	wrrd_cas_add => wrrd_cas_add,
	
	wr_we => wr_we,
	wr_add => wr_add,
	wr_dat => wr_dat,
	wr_ack => wr_ack, 
	
	rd_re => rd_re,
	rd_add => rd_add,
	rd_dat => rd_dat,
	rd_ack => rd_ack,  
	rd_valid => rd_valid,  
	
	refresh => refresh,

	SDRAM_A 		=> SDRAM_A,
	SDRAM_BA 		=> SDRAM_BA,
	SDRAM_CKE      	=> SDRAM_CKE,
	SDRAM_CK        => SDRAM_CK,
	SDRAM_nCK	    => SDRAM_nCK,
	SDRAM_DQ       	=> SDRAM_DQ,
	SDRAM_DQS	    => SDRAM_DQS,
	--SDRAM_nDQS	    => SDRAM_nDQS,
	SDRAM_DM    	=> SDRAM_DM,
	SDRAM_nCAS     	=> SDRAM_nCAS,
	SDRAM_nCS      	=> SDRAM_nCS,
	SDRAM_nRAS     	=> SDRAM_nRAS,
	SDRAM_nWE      	=> SDRAM_nWE);


end Struct;
