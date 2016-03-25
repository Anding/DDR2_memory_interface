#set projectPath D:/EDAptix/projects/rampup/rampup_nexys4ddr_sdram_standalone/vivado/rampup_nexys4ddr_sdram_standalone/
#source $projectPath/report_io_timing.tcl > $projectPath/report_io_timing.rep

set_output_delay -clock [get_clocks clk] 6 [get_ports SDRAM_CK]
report_timing -to [get_port SDRAM_CK]  

set_output_delay -clock [get_clocks clk] 6 [get_ports SDRAM_DQ[*]]
report_timing -to [get_port SDRAM_DQ[*]]
                                       
set_output_delay -clock [get_clocks clk] 6 [get_ports SDRAM_DQS*]
report_timing -to [get_port SDRAM_DQS*]
                                       
set_output_delay -clock [get_clocks clk] 6 [get_ports SDRAM_nCAS]
report_timing -to [get_port SDRAM_nCAS]