
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2025 18:48:19
// Design Name: 
// Module Name: tt_um_axi4lite_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tt_um_axi4lite_top
(
    input  wire                        clk,
    input  wire                        rst_n ,
    input  wire                        ena,

    // Control interface to Master
    input  wire [7:0]       ui_in,
    //input  wire                        start_write,
    //input  wire [ADDR_WIDTH-1:0]       write_addr,
    input  wire [7:0]       uio_in,
    //input  wire                        start_read,
    //input  wire [ADDR_WIDTH-1:0]       read_addr,
    output wire [7:0]       uio_oe,
    output wire [7:0]       uio_out,
    output wire [7:0]       uo_out

    
);
     wire                        start_write;
    wire [1:0]       write_addr;
     wire                        start_read;
     wire [1:0]       read_addr;
     wire                        done;
     assign start_write=ui_in[0];
     assign write_addr=ui_in[2:1];
     assign read_addr=ui_in[4:3];
     assign start_read=ui_in[5];
     reg [7:0] uo_out_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        uo_out_reg <= 8'b0;
    else begin
        uo_out_reg[0] <= done;
        uo_out_reg[7:1] <= 7'b0;
    end
end

assign uo_out = uo_out_reg;

     
    // Expose AXI signals for simulation visibility
     wire [1:0] awaddr;
     wire                  awvalid;
     wire                  awready;
     wire [7:0] wdata;
    wire [8/8-1:0] wstrb;
     wire                  wvalid;
     wire                  wready;
     wire [1:0]            bresp;
     wire                  bvalid;
     wire                  bready;
     wire [1:0] araddr;
     wire                  arvalid;
     wire                  arready;
     wire [7:0] rdata;
     wire [1:0]            rresp;
     wire                  rvalid;
     wire                  rready;
 
    // Master instance
    axi4lite_master master_inst (
        .m_axi_aclk    (clk),
        .m_axi_aresetn (rst_n ),

        .m_axi_awaddr  (awaddr),
        .m_axi_awvalid (awvalid),
        .m_axi_awready (awready),

        .m_axi_wdata   (wdata),
        .m_axi_wstrb   (wstrb),
        .m_axi_wvalid  (wvalid),
        .m_axi_wready  (wready),

        .m_axi_bresp   (bresp),
        .m_axi_bvalid  (bvalid),
        .m_axi_bready  (bready),

        .m_axi_araddr  (araddr),
        .m_axi_arvalid (arvalid),
        .m_axi_arready (arready),

        .m_axi_rdata   (rdata),
        .m_axi_rresp   (rresp),
        .m_axi_rvalid  (rvalid),
        .m_axi_rready  (rready),

        // User interface
        .start_write   (start_write),
        .write_addr    (write_addr),
        .uio_in   (uio_in),
        .start_read    (start_read),
        .read_addr     (read_addr),
        .read_data     (uio_out),
        .done          (done)
    );

    // Slave instance
    axi4lite_slave slave_inst (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n ),

        .s_axi_awaddr  (awaddr),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),

        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),

        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),

        .s_axi_araddr  (araddr),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),

        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready)
    );
assign uio_oe = 8'hFF;
endmodule
