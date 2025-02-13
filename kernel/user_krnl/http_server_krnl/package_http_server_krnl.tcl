# /*******************************************************************************
# (c) Copyright 2019 Xilinx, Inc. All rights reserved.
# This file contains confidential and proprietary information 
# of Xilinx, Inc. and is protected under U.S. and
# international copyright and other intellectual property 
# laws.
# 
# DISCLAIMER
# This disclaimer is not a license and does not grant any 
# rights to the materials distributed herewith. Except as 
# otherwise provided in a valid license issued to you by 
# Xilinx, and to the maximum extent permitted by applicable
# law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
# WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES 
# AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING 
# BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
# INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and 
# (2) Xilinx shall not be liable (whether in contract or tort, 
# including negligence, or under any other theory of 
# liability) for any loss or damage of any kind or nature 
# related to, arising under or in connection with these 
# materials, including for any direct, or any indirect, 
# special, incidental, or consequential loss or damage 
# (including loss of data, profits, goodwill, or any type of 
# loss or damage suffered as a result of any action brought 
# by a third party) even if such damage or loss was 
# reasonably foreseeable or Xilinx had been advised of the 
# possibility of the same.
# 
# CRITICAL APPLICATIONS
# Xilinx products are not designed or intended to be fail-
# safe, or for use in any application requiring fail-safe
# performance, such as life-support or safety devices or 
# systems, Class III medical devices, nuclear facilities, 
# applications related to the deployment of airbags, or any 
# other applications that could lead to death, personal 
# injury, or severe property or environmental damage 
# (individually and collectively, "Critical 
# Applications"). Customer assumes the sole risk and 
# liability of any use of Xilinx products in Critical 
# Applications, subject only to applicable laws and 
# regulations governing limitations on product liability.
# 
# THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS 
# PART OF THIS FILE AT ALL TIMES.
# 
# *******************************************************************************/
set path_to_hdl "./kernel/user_krnl/http_server_krnl/src"
set path_to_packaged "./packaged_kernel_${suffix}"
set path_to_tmp_project "./tmp_kernel_pack_${suffix}"
set path_to_common "./kernel/common"

set words [split $device "_"]
set board [lindex $words 1]

if {[string compare -nocase $board "u280"] == 0} {
    set projPart "xcu280-fsvh2892-2L-e"
} elseif {[string compare -nocase $board "u250"] == 0} {
    set projPart "xcu250-figd2104-2L-e"
} elseif {[string compare -nocase $board "u50"] == 0} {
    set projPart "xcu50-fsvh2104-2-e"
} elseif {[string compare -nocase $board "u55c"] == 0} {
    set projPart "xcu55c-fsvh2892-2L-e"
} else {
    puts "Unknown board $board"
    exit 
}

set projName kernel_pack
create_project -force $projName $path_to_tmp_project -part $projPart

add_files -norecurse [glob $path_to_hdl/hdl/*.v $path_to_hdl/hdl/*.sv $path_to_hdl/hdl/*.svh ]
add_files -norecurse [glob $path_to_common/types/*.v $path_to_common/types/*.sv $path_to_common/types/*.svh ]

set_property top user_krnl [current_fileset]
update_compile_order -fileset sources_1

set __ip_list [get_property ip_repo_paths [current_project]]

lappend __ip_list ./build/fpga-network-stack/iprepo
set_property ip_repo_paths $__ip_list [current_project]
update_ip_catalog

create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name axis_data_fifo_512
set_property -dict [list CONFIG.TDATA_NUM_BYTES {64} CONFIG.HAS_TLAST {1} CONFIG.Component_Name {axis_data_fifo_512}] [get_ips axis_data_fifo_512]


create_ip -name http_server -vendor i-highway.com -library hls -version 1.0 -module_name http_server_ip 

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
ipx::package_project -root_dir $path_to_packaged -vendor xilinx.com -library RTLKernel -taxonomy /KernelIP -import_files -set_current false
ipx::unload_core $path_to_packaged/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $path_to_packaged $path_to_packaged/component.xml
set_property core_revision 1 [ipx::current_core]
foreach up [ipx::get_user_parameters] {
    ipx::remove_user_parameter [get_property NAME $up] [ipx::current_core]
}
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::add_bus_interface ap_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]
set_property physical_name ap_clk [ipx::get_port_maps CLK -of_objects [ipx::get_bus_interfaces ap_clk -of_objects [ipx::current_core]]]

#ipx::add_bus_interface ap_clk_2 [ipx::current_core]
#set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 [ipx::get_bus_interfaces ap_clk_2 -of_objects [ipx::current_core]]
#set_property bus_type_vlnv xilinx.com:signal:clock:1.0 [ipx::get_bus_interfaces ap_clk_2 -of_objects [ipx::current_core]]
#ipx::add_port_map CLK2 [ipx::get_bus_interfaces ap_clk_2 -of_objects [ipx::current_core]]
#set_property physical_name ap_clk_2 [ipx::get_port_maps CLK2 -of_objects [ipx::get_bus_interfaces ap_clk_2 -of_objects [ipx::current_core]]]
#ipx::infer_bus_interface ap_rst_n_2 xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]

# Specify the freq_hz parameter 
#set clkbif      [::ipx::get_bus_interfaces -of [ipx::current_core] "ap_clk"]
#set clkbifparam [::ipx::add_bus_parameter -quiet "FREQ_HZ" $clkbif]
# Set desired frequency                   
#set_property value 250000000 $clkbifparam
# set value_resolve_type 'user' if the frequency can vary. 
#set_property value_resolve_type user $clkbifparam
# set value_resolve_type 'immediate' if the frequency cannot change. 
#set_property value_resolve_type immediate $clkbifparam

# Specify the freq_hz parameter 
#set clkbif      [::ipx::get_bus_interfaces -of [ipx::current_core] "ap_clk_2"]
#set clkbifparam [::ipx::add_bus_parameter -quiet "FREQ_HZ" $clkbif]
# Set desired frequency                   
#set_property value 250000000 $clkbifparam
# set value_resolve_type 'user' if the frequency can vary. 
# set_property value_resolve_type user $clkbifparam
# set value_resolve_type 'immediate' if the frequency cannot change. 
#set_property value_resolve_type immediate $clkbifparam

ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif m_axi_gmem -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_udp_rx [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_udp_rx -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_udp_rx -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_udp_rx -clock ap_clk [ipx::current_core]
ipx::add_bus_interface m_axis_udp_tx [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_udp_tx -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_udp_tx -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_udp_tx -clock ap_clk [ipx::current_core]
ipx::add_bus_interface s_axis_udp_rx_meta [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_udp_rx_meta -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_udp_rx_meta -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_udp_rx_meta -clock ap_clk [ipx::current_core]
ipx::add_bus_interface m_axis_udp_tx_meta [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_udp_tx_meta -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_udp_tx_meta -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_udp_tx_meta -clock ap_clk [ipx::current_core]

#TCP/IP interfaces
ipx::add_bus_interface m_axis_tcp_listen_port [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_listen_port -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_listen_port -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_listen_port -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_port_status [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_port_status -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_port_status -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_port_status -clock ap_clk [ipx::current_core]

ipx::add_bus_interface m_axis_tcp_open_connection [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_open_connection -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_open_connection -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_open_connection -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_open_status [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_open_status -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_open_status -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_open_status -clock ap_clk [ipx::current_core]

ipx::add_bus_interface m_axis_tcp_close_connection [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_close_connection -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_close_connection -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_close_connection -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_notification [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_notification -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_notification -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_notification -clock ap_clk [ipx::current_core]

ipx::add_bus_interface m_axis_tcp_read_pkg [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_read_pkg -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_read_pkg -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_read_pkg -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_rx_meta [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_rx_meta -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_rx_meta -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_rx_meta -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_rx_data [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_rx_data -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_rx_data -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_rx_data -clock ap_clk [ipx::current_core]

ipx::add_bus_interface m_axis_tcp_tx_meta [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_tx_meta -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_tx_meta -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_tx_meta -clock ap_clk [ipx::current_core]

ipx::add_bus_interface m_axis_tcp_tx_data [ipx::current_core]
set_property interface_mode master [ipx::get_bus_interfaces m_axis_tcp_tx_data -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces m_axis_tcp_tx_data -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif m_axis_tcp_tx_data -clock ap_clk [ipx::current_core]

ipx::add_bus_interface s_axis_tcp_tx_status [ipx::current_core]
set_property interface_mode slave [ipx::get_bus_interfaces s_axis_tcp_tx_status -of_objects [ipx::current_core]]
set_property abstraction_type_vlnv xilinx.com:interface:axis_rtl:1.0 [ipx::get_bus_interfaces s_axis_tcp_tx_status -of_objects [ipx::current_core]]
ipx::associate_bus_interfaces -busif s_axis_tcp_tx_status -clock ap_clk [ipx::current_core]

puts "TEMPORARY: Not packaging reference clock as diff clock due to post-System Linker validate error"
#for {set clk 0} {$clk < 1} {incr clk} {
#   ipx::add_bus_interface gt_refclk${clk} [ipx::current_core]
#   set_property interface_mode slave [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]
#   set_property abstraction_type_vlnv xilinx.com:interface:diff_clock_rtl:1.0 [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]
#   set_property bus_type_vlnv xilinx.com:interface:diff_clock:1.0 [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]
#   ipx::add_port_map CLK_N [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]
#   set_property physical_name gt_refclk${clk}_n [ipx::get_port_maps CLK_N -of_objects [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]]
#   ipx::add_port_map CLK_P [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]
#   set_property physical_name gt_refclk${clk}_p [ipx::get_port_maps CLK_P -of_objects [ipx::get_bus_interfaces gt_refclk${clk} -of_objects [ipx::current_core]]]
#}

set_property xpm_libraries {XPM_CDC XPM_MEMORY XPM_FIFO} [ipx::current_core]
set_property supported_families { } [ipx::current_core]
set_property auto_family_support_level level_2 [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project -delete
