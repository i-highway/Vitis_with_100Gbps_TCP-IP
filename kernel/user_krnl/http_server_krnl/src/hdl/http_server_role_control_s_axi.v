`timescale 1ns/1ps
module user_krnl_control_s_axi
#(parameter
    C_S_AXI_ADDR_WIDTH = 5,
    C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                          ACLK,
    input  wire                          ARESET,
    input  wire                          ACLK_EN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  wire                          AWVALID,
    output wire                          AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  wire                          WVALID,
    output wire                          WREADY,
    output wire [1:0]                    BRESP,
    output wire                          BVALID,
    input  wire                          BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  wire                          ARVALID,
    output wire                          ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] RDATA,
    output wire [1:0]                    RRESP,
    output wire                          RVALID,
    input  wire                          RREADY,
    output wire                          startServer,
    output wire [63:0]                   fileList,
    output wire [63:0]                   fileData,
    output wire [31:0]                   fileNum,
    output wire [15:0]                   serverPort
);

//------------------------Parameter----------------------
localparam
    ADDR_START_SERVER         = 5'h00,
    ADDR_FILE_LIST_0          = 5'h04,
    ADDR_FILE_LIST_1          = 5'h08,
    ADDR_FILE_DATA_0          = 5'h0c,
    ADDR_FILE_DATA_1          = 5'h10,
    ADDR_FILE_NUM             = 5'h14,
    ADDR_SERVER_PORT          = 5'h18,
    WRIDLE                    = 2'd0,
    WRDATA                    = 2'd1,
    WRRESP                    = 2'd2,
    WRRESET                   = 2'd3,
    RDIDLE                    = 2'd0,
    RDDATA                    = 2'd1,
    RDRESET                   = 2'd2,
    ADDR_BITS         = 5;

//------------------------Local signal-------------------
    reg  [1:0]                    wstate = WRRESET;
    reg  [1:0]                    wnext;
    reg  [ADDR_BITS-1:0]          waddr;
    wire [31:0]                   wmask;
    wire                          aw_hs;
    wire                          w_hs;
    reg  [1:0]                    rstate = RDRESET;
    reg  [1:0]                    rnext;
    reg  [31:0]                   rdata;
    wire                          ar_hs;
    wire [ADDR_BITS-1:0]          raddr;
    // internal registers
    reg                           int_startServer = 1'b0;
    reg  [63:0]                   int_fileList = 'b0;
    reg  [63:0]                   int_fileData = 'b0;
    reg  [31:0]                   int_fileNum = 'b0;
    reg  [15:0]                   int_serverPort = 'b0;

//------------------------Instantiation------------------

//------------------------AXI write fsm------------------
assign AWREADY = (wstate == WRIDLE);
assign WREADY  = (wstate == WRDATA);
assign BRESP   = 2'b00;  // OKAY
assign BVALID  = (wstate == WRRESP);
assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
assign aw_hs   = AWVALID & AWREADY;
assign w_hs    = WVALID & WREADY;

// wstate
always @(posedge ACLK) begin
    if (ARESET)
        wstate <= WRRESET;
    else if (ACLK_EN)
        wstate <= wnext;
end

// wnext
always @(*) begin
    case (wstate)
        WRIDLE:
            if (AWVALID)
                wnext = WRDATA;
            else
                wnext = WRIDLE;
        WRDATA:
            if (WVALID)
                wnext = WRRESP;
            else
                wnext = WRDATA;
        WRRESP:
            if (BREADY)
                wnext = WRIDLE;
            else
                wnext = WRRESP;
        default:
            wnext = WRIDLE;
    endcase
end

// waddr
always @(posedge ACLK) begin
    if (ACLK_EN) begin
        if (aw_hs)
            waddr <= AWADDR[ADDR_BITS-1:0];
    end
end

//------------------------AXI read fsm-------------------
assign ARREADY = (rstate == RDIDLE);
assign RDATA   = rdata;
assign RRESP   = 2'b00;  // OKAY
assign RVALID  = (rstate == RDDATA);
assign ar_hs   = ARVALID & ARREADY;
assign raddr   = ARADDR[ADDR_BITS-1:0];

// rstate
always @(posedge ACLK) begin
    if (ARESET)
        rstate <= RDRESET;
    else if (ACLK_EN)
        rstate <= rnext;
end

// rnext
always @(*) begin
    case (rstate)
        RDIDLE:
            if (ARVALID)
                rnext = RDDATA;
            else
                rnext = RDIDLE;
        RDDATA:
            if (RREADY & RVALID)
                rnext = RDIDLE;
            else
                rnext = RDDATA;
        default:
            rnext = RDIDLE;
    endcase
end

// rdata
always @(posedge ACLK) begin
    if (ACLK_EN) begin
        if (ar_hs) begin
            rdata <= 1'b0;
            case (raddr)
                ADDR_START_SERVER: begin
                    rdata <= {31'b0, int_startServer};
                end
                ADDR_FILE_LIST_0: begin
                    rdata <= int_fileList[31:0];
                end
                ADDR_FILE_LIST_1: begin
                    rdata <= int_fileList[63:32];
                end
                ADDR_FILE_DATA_0: begin
                    rdata <= int_fileData[31:0];
                end
                ADDR_FILE_DATA_1: begin
                    rdata <= int_fileData[63:32];
                end
                ADDR_FILE_NUM: begin
                    rdata <= int_fileNum[31:0];
                end
                ADDR_SERVER_PORT: begin
                    rdata <= {16'b0, int_serverPort[15:0]};
                end
            endcase
        end
    end
end


//------------------------Register logic-----------------
assign startServer   = int_startServer;
assign fileList      = int_fileList;
assign fileData      = int_fileData;
assign fileNum       = int_fileNum;
assign serverPort    = int_serverPort;

// int_startServer
always @(posedge ACLK) begin
    if (ARESET)
        int_startServer <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_START_SERVER)
            int_startServer <= WDATA[0];
    end
end

// int_fileList[31:0]
always @(posedge ACLK) begin
    if (ARESET)
        int_fileList[31:0] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_FILE_LIST_0)
            int_fileList[31:0] <= (WDATA[31:0] & wmask) | (int_fileList[31:0] & ~wmask);
    end
end

// int_fileList[63:32]
always @(posedge ACLK) begin
    if (ARESET)
        int_fileList[63:32] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_FILE_LIST_1)
            int_fileList[63:32] <= (WDATA[31:0] & wmask) | (int_fileList[63:32] & ~wmask);
    end
end

// int_fileData[31:0]
always @(posedge ACLK) begin
    if (ARESET)
        int_fileData[31:0] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_FILE_DATA_0)
            int_fileData[31:0] <= (WDATA[31:0] & wmask) | (int_fileData[31:0] & ~wmask);
    end
end

// int_fileData[63:32]
always @(posedge ACLK) begin
    if (ARESET)
        int_fileData[63:32] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_FILE_DATA_1)
            int_fileData[63:32] <= (WDATA[31:0] & wmask) | (int_fileData[63:32] & ~wmask);
    end
end

// int_fileNum[31:0]
always @(posedge ACLK) begin
    if (ARESET)
        int_fileNum[31:0] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_FILE_NUM)
            int_fileNum[31:0] <= (WDATA[31:0] & wmask) | (int_fileNum[31:0] & ~wmask);
    end
end

// int_serverPort[15:0]
always @(posedge ACLK) begin
    if (ARESET)
        int_serverPort[15:0] <= 0;
    else if (ACLK_EN) begin
        if (w_hs && waddr == ADDR_SERVER_PORT)
            int_serverPort[15:0] <= (WDATA[15:0] & wmask[15:0]) | (int_serverPort[15:0] & ~wmask[15:0]);
    end
end


//------------------------Memory logic-------------------

endmodule
