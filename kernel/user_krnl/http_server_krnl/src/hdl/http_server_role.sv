// Copyright (c) 2023 Intellectual Highway. All rights reserved.
`timescale 1ns / 1ps
`default_nettype none

`include "network_types.svh"
`include "network_intf.svh"

module http_server_role 
  #( 
  parameter integer  C_S_AXI_CONTROL_DATA_WIDTH = 32,
  parameter integer  C_S_AXI_CONTROL_ADDR_WIDTH = 12,
  parameter integer  C_M_AXI_GMEM_ADDR_WIDTH = 64,
  parameter integer  C_M_AXI_GMEM_DATA_WIDTH = 512
)
(
    input wire      ap_clk,
    input wire      ap_rst_n,

    // AXI4-Lite slave interface
    input  wire                                    s_axi_control_awvalid,
    output wire                                    s_axi_control_awready,
    input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_awaddr ,
    input  wire                                    s_axi_control_wvalid ,
    output wire                                    s_axi_control_wready ,
    input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_wdata  ,
    input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb  ,
    input  wire                                    s_axi_control_arvalid,
    output wire                                    s_axi_control_arready,
    input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_araddr ,
    output wire                                    s_axi_control_rvalid ,
    input  wire                                    s_axi_control_rready ,
    output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_rdata  ,
    output wire [2-1:0]                            s_axi_control_rresp  ,
    output wire                                    s_axi_control_bvalid ,
    input  wire                                    s_axi_control_bready ,
    output wire [2-1:0]                            s_axi_control_bresp  ,

    /* NETWORK  - TCP/IP INTERFACE */
    //Network TCP/IP
    output  wire                                   m_axis_tcp_listen_port_tvalid ,
    input wire                                     m_axis_tcp_listen_port_tready ,
    output  wire [16-1:0]                          m_axis_tcp_listen_port_tdata  ,

    input wire                                     s_axis_tcp_port_status_tvalid ,
    output  wire                                   s_axis_tcp_port_status_tready ,
    input wire [8-1:0]                             s_axis_tcp_port_status_tdata  ,

    output  wire                                   m_axis_tcp_open_connection_tvalid ,
    input wire                                     m_axis_tcp_open_connection_tready ,
    output  wire [48-1:0]                          m_axis_tcp_open_connection_tdata  ,

    input wire                                     s_axis_tcp_open_status_tvalid ,
    output  wire                                   s_axis_tcp_open_status_tready ,
    input wire [128-1:0]                            s_axis_tcp_open_status_tdata  ,

    output  wire                                   m_axis_tcp_close_connection_tvalid ,
    input wire                                     m_axis_tcp_close_connection_tready ,
    output  wire [16-1:0]                          m_axis_tcp_close_connection_tdata  ,

    input wire                                     s_axis_tcp_notification_tvalid ,
    output  wire                                   s_axis_tcp_notification_tready ,
    input wire [88-1:0]                            s_axis_tcp_notification_tdata  ,

    output  wire                                   m_axis_tcp_read_pkg_tvalid ,
    input wire                                     m_axis_tcp_read_pkg_tready ,
    output  wire [32-1:0]                          m_axis_tcp_read_pkg_tdata  ,

    input wire                                     s_axis_tcp_rx_meta_tvalid ,
    output  wire                                   s_axis_tcp_rx_meta_tready ,
    input wire [16-1:0]                            s_axis_tcp_rx_meta_tdata  ,

    input wire                                     s_axis_tcp_rx_data_tvalid ,
    output  wire                                   s_axis_tcp_rx_data_tready ,
    input wire [NETWORK_STACK_WIDTH-1:0]           s_axis_tcp_rx_data_tdata  ,
    input wire [NETWORK_STACK_WIDTH/8-1:0]         s_axis_tcp_rx_data_tkeep  ,
    input wire                                     s_axis_tcp_rx_data_tlast  ,

    output  wire                                   m_axis_tcp_tx_meta_tvalid ,
    input wire                                     m_axis_tcp_tx_meta_tready ,
    output  wire [32-1:0]                          m_axis_tcp_tx_meta_tdata  ,

    output  wire                                   m_axis_tcp_tx_data_tvalid ,
    input wire                                     m_axis_tcp_tx_data_tready ,
    output  wire [NETWORK_STACK_WIDTH-1:0]         m_axis_tcp_tx_data_tdata  ,
    output  wire [NETWORK_STACK_WIDTH/8-1:0]       m_axis_tcp_tx_data_tkeep  ,
    output  wire                                   m_axis_tcp_tx_data_tlast  ,

    input wire                                     s_axis_tcp_tx_status_tvalid ,
    output  wire                                   s_axis_tcp_tx_status_tready ,
    input wire [64-1:0]                            s_axis_tcp_tx_status_tdata  ,
    
    // global memory
    output wire                                 m_axi_gmem_AWVALID,
    input  wire                                 m_axi_gmem_AWREADY,
    output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem_AWADDR,
    output wire [7:0]                           m_axi_gmem_AWLEN,
    output wire [2:0]                           m_axi_gmem_AWSIZE,
    output wire [1:0]                           m_axi_gmem_AWBURST,
    output wire [1:0]                           m_axi_gmem_AWLOCK,
    output wire [3:0]                           m_axi_gmem_AWCACHE,
    output wire [2:0]                           m_axi_gmem_AWPROT,
    output wire [3:0]                           m_axi_gmem_AWQOS,
    output wire [3:0]                           m_axi_gmem_AWREGION,
    output wire                                 m_axi_gmem_WVALID,
    input  wire                                 m_axi_gmem_WREADY,
    output wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]   m_axi_gmem_WDATA,
    output wire [C_M_AXI_GMEM_DATA_WIDTH/8-1:0] m_axi_gmem_WSTRB,
    output wire                                 m_axi_gmem_WLAST,
    output wire                                 m_axi_gmem_ARVALID,
    input  wire                                 m_axi_gmem_ARREADY,
    output wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0]   m_axi_gmem_ARADDR,
    output wire [7:0]                           m_axi_gmem_ARLEN,
    output wire [2:0]                           m_axi_gmem_ARSIZE,
    output wire [1:0]                           m_axi_gmem_ARBURST,
    output wire [1:0]                           m_axi_gmem_ARLOCK,
    output wire [3:0]                           m_axi_gmem_ARCACHE,
    output wire [2:0]                           m_axi_gmem_ARPROT,
    output wire [3:0]                           m_axi_gmem_ARQOS,
    output wire [3:0]                           m_axi_gmem_ARREGION,
    input  wire                                 m_axi_gmem_RVALID,
    output wire                                 m_axi_gmem_RREADY,
    input  wire [C_M_AXI_GMEM_DATA_WIDTH-1:0]   m_axi_gmem_RDATA,
    input  wire                                 m_axi_gmem_RLAST,
    input  wire [1:0]                           m_axi_gmem_RRESP,
    input  wire                                 m_axi_gmem_BVALID,
    output wire                                 m_axi_gmem_BREADY,
    input  wire [1:0]                           m_axi_gmem_BRESP
);

wire startServer;
wire [63:0] fileList;
wire [63:0] fileData;
wire [31:0] fileNum;
wire [15:0] serverPort;

assign m_axis_tcp_open_connection_tvalid = 1'b0;
assign s_axis_tcp_open_status_tready = 1'b1;

http_server_ip http_server (
   .m_axis_close_connection_TVALID(m_axis_tcp_close_connection_tvalid),      // output wire m_axis_close_connection_TVALID
   .m_axis_close_connection_TREADY(m_axis_tcp_close_connection_tready),      // input wire m_axis_close_connection_TREADY
   .m_axis_close_connection_TDATA(m_axis_tcp_close_connection_tdata),        // output wire [15 : 0] m_axis_close_connection_TDATA
   .m_axis_listen_port_TVALID(m_axis_tcp_listen_port_tvalid),                // output wire m_axis_listen_port_TVALID
   .m_axis_listen_port_TREADY(m_axis_tcp_listen_port_tready),                // input wire m_axis_listen_port_TREADY
   .m_axis_listen_port_TDATA(m_axis_tcp_listen_port_tdata),                  // output wire [15 : 0] m_axis_listen_port_TDATA
   .m_axis_read_package_TVALID(m_axis_tcp_read_pkg_tvalid),              // output wire m_axis_read_package_TVALID
   .m_axis_read_package_TREADY(m_axis_tcp_read_pkg_tready),              // input wire m_axis_read_package_TREADY
   .m_axis_read_package_TDATA(m_axis_tcp_read_pkg_tdata),                // output wire [31 : 0] m_axis_read_package_TDATA
   .m_axis_tx_data_TVALID(m_axis_tcp_tx_data_tvalid),                        // output wire m_axis_tx_data_TVALID
   .m_axis_tx_data_TREADY(m_axis_tcp_tx_data_tready),                        // input wire m_axis_tx_data_TREADY
   .m_axis_tx_data_TDATA(m_axis_tcp_tx_data_tdata),                          // output wire [63 : 0] m_axis_tx_data_TDATA
   .m_axis_tx_data_TKEEP(m_axis_tcp_tx_data_tkeep),                          // output wire [7 : 0] m_axis_tx_data_TKEEP
   .m_axis_tx_data_TLAST(m_axis_tcp_tx_data_tlast),                          // output wire [0 : 0] m_axis_tx_data_TLAST
   .m_axis_tx_metadata_TVALID(m_axis_tcp_tx_meta_tvalid),                // output wire m_axis_tx_metadata_TVALID
   .m_axis_tx_metadata_TREADY(m_axis_tcp_tx_meta_tready),                // input wire m_axis_tx_metadata_TREADY
   .m_axis_tx_metadata_TDATA(m_axis_tcp_tx_meta_tdata),                  // output wire [15 : 0] m_axis_tx_metadata_TDATA
   .s_axis_listen_port_status_TVALID(s_axis_tcp_port_status_tvalid),  // input wire s_axis_listen_port_status_TVALID
   .s_axis_listen_port_status_TREADY(s_axis_tcp_port_status_tready),  // output wire s_axis_listen_port_status_TREADY
   .s_axis_listen_port_status_TDATA(s_axis_tcp_port_status_tdata),    // input wire [7 : 0] s_axis_listen_port_status_TDATA
   .s_axis_notifications_TVALID(s_axis_tcp_notification_tvalid),            // input wire s_axis_notifications_TVALID
   .s_axis_notifications_TREADY(s_axis_tcp_notification_tready),            // output wire s_axis_notifications_TREADY
   .s_axis_notifications_TDATA(s_axis_tcp_notification_tdata),              // input wire [87 : 0] s_axis_notifications_TDATA
   .s_axis_rx_data_TVALID(s_axis_tcp_rx_data_tvalid),                        // input wire s_axis_rx_data_TVALID
   .s_axis_rx_data_TREADY(s_axis_tcp_rx_data_tready),                        // output wire s_axis_rx_data_TREADY
   .s_axis_rx_data_TDATA(s_axis_tcp_rx_data_tdata),                          // input wire [63 : 0] s_axis_rx_data_TDATA
   .s_axis_rx_data_TKEEP(s_axis_tcp_rx_data_tkeep),                          // input wire [7 : 0] s_axis_rx_data_TKEEP
   .s_axis_rx_data_TLAST(s_axis_tcp_rx_data_tlast),                          // input wire [0 : 0] s_axis_rx_data_TLAST
   .s_axis_rx_metadata_TVALID(s_axis_tcp_rx_meta_tvalid),                // input wire s_axis_rx_metadata_TVALID
   .s_axis_rx_metadata_TREADY(s_axis_tcp_rx_meta_tready),                // output wire s_axis_rx_metadata_TREADY
   .s_axis_rx_metadata_TDATA(s_axis_tcp_rx_meta_tdata),                  // input wire [15 : 0] s_axis_rx_metadata_TDATA
   .s_axis_tx_status_TVALID(s_axis_tcp_tx_status_tvalid),                    // input wire s_axis_tx_status_TVALID
   .s_axis_tx_status_TREADY(s_axis_tcp_tx_status_tready),                    // output wire s_axis_tx_status_TREADY
   .s_axis_tx_status_TDATA(s_axis_tcp_tx_status_tdata),                      // input wire [23 : 0] s_axis_tx_status_TDATA

   .m_axi_gmem_AWVALID (m_axi_gmem_AWVALID ),
   .m_axi_gmem_AWREADY (m_axi_gmem_AWREADY ),
   .m_axi_gmem_AWADDR  (m_axi_gmem_AWADDR  ),
   .m_axi_gmem_AWLEN   (m_axi_gmem_AWLEN   ),
   .m_axi_gmem_AWSIZE  (m_axi_gmem_AWSIZE  ),
   .m_axi_gmem_AWBURST (m_axi_gmem_AWBURST ),
   .m_axi_gmem_AWLOCK  (m_axi_gmem_AWLOCK  ),
   .m_axi_gmem_AWCACHE (m_axi_gmem_AWCACHE ),
   .m_axi_gmem_AWPROT  (m_axi_gmem_AWPROT  ),
   .m_axi_gmem_AWQOS   (m_axi_gmem_AWQOS   ),
   .m_axi_gmem_AWREGION(m_axi_gmem_AWREGION),
   .m_axi_gmem_WVALID  (m_axi_gmem_WVALID  ),
   .m_axi_gmem_WREADY  (m_axi_gmem_WREADY  ),
   .m_axi_gmem_WDATA   (m_axi_gmem_WDATA   ),
   .m_axi_gmem_WSTRB   (m_axi_gmem_WSTRB   ),
   .m_axi_gmem_WLAST   (m_axi_gmem_WLAST   ),
   .m_axi_gmem_ARVALID (m_axi_gmem_ARVALID ),
   .m_axi_gmem_ARREADY (m_axi_gmem_ARREADY ),
   .m_axi_gmem_ARADDR  (m_axi_gmem_ARADDR  ),
   .m_axi_gmem_ARLEN   (m_axi_gmem_ARLEN   ),
   .m_axi_gmem_ARSIZE  (m_axi_gmem_ARSIZE  ),
   .m_axi_gmem_ARBURST (m_axi_gmem_ARBURST ),
   .m_axi_gmem_ARLOCK  (m_axi_gmem_ARLOCK  ),
   .m_axi_gmem_ARCACHE (m_axi_gmem_ARCACHE ),
   .m_axi_gmem_ARPROT  (m_axi_gmem_ARPROT  ),
   .m_axi_gmem_ARQOS   (m_axi_gmem_ARQOS   ),
   .m_axi_gmem_ARREGION(m_axi_gmem_ARREGION),
   .m_axi_gmem_RVALID  (m_axi_gmem_RVALID  ),
   .m_axi_gmem_RREADY  (m_axi_gmem_RREADY  ),
   .m_axi_gmem_RDATA   (m_axi_gmem_RDATA   ),
   .m_axi_gmem_RLAST   (m_axi_gmem_RLAST   ),
   .m_axi_gmem_RRESP   (m_axi_gmem_RRESP   ),
   .m_axi_gmem_BVALID  (m_axi_gmem_BVALID  ),
   .m_axi_gmem_BREADY  (m_axi_gmem_BREADY  ),
   .m_axi_gmem_BRESP   (m_axi_gmem_BRESP   ),

   .startServer(startServer),
   .fileList   (fileList   ),
   .fileData   (fileData   ),
   .fileNum    (fileNum    ),
   .serverPort (serverPort ),
   
   .ap_clk(ap_clk),                                                          // input wire aclk
   .ap_rst_n(ap_rst_n)                                                    // input wire aresetn
 );

/*
 * Role Controller
 */

// AXI4-Lite slave interface
user_krnl_control_s_axi #(
  .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
)
inst_control_s_axi (
  .ACLK                   ( ap_clk                 ),
  .ARESET                 ( ~ap_rst_n              ),
  .ACLK_EN                ( 1'b1                   ),
  .AWVALID                ( s_axi_control_awvalid  ), 
  .AWREADY                ( s_axi_control_awready  ),
  .AWADDR                 ( s_axi_control_awaddr   ),
  .WVALID                 ( s_axi_control_wvalid   ),
  .WREADY                 ( s_axi_control_wready   ),
  .WDATA                  ( s_axi_control_wdata    ),
  .WSTRB                  ( s_axi_control_wstrb    ),
  .ARVALID                ( s_axi_control_arvalid  ),
  .ARREADY                ( s_axi_control_arready  ),
  .ARADDR                 ( s_axi_control_araddr   ),
  .RVALID                 ( s_axi_control_rvalid   ),
  .RREADY                 ( s_axi_control_rready   ),
  .RDATA                  ( s_axi_control_rdata    ),
  .RRESP                  ( s_axi_control_rresp    ),
  .BVALID                 ( s_axi_control_bvalid   ),
  .BREADY                 ( s_axi_control_bready   ),
  .BRESP                  ( s_axi_control_bresp    ),
  .startServer            (startServer),
  .fileList               (fileList   ),
  .fileData               (fileData   ),
  .fileNum                (fileNum    ),
  .serverPort             (serverPort )
);


endmodule
`default_nettype wire
