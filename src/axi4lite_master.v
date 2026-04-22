
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2025 18:49:04
// Design Name: 
// Module Name: axi4lite_master
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

module axi4lite_master
(
    input  wire                         m_axi_aclk,
    input  wire                         m_axi_aresetn,

    // Write address channel
    output reg  [1:0] m_axi_awaddr,
    output reg                           m_axi_awvalid,
    input  wire                          m_axi_awready,

    // Write data channel
    output reg  [7:0] m_axi_wdata,
    output reg  [8/8-1:0] m_axi_wstrb,
    output reg                           m_axi_wvalid,
    input  wire                          m_axi_wready,

    // Write response channel
    input  wire [1:0]                    m_axi_bresp,
    input  wire                          m_axi_bvalid,
    output reg                           m_axi_bready,

    // Read address channel
    output reg  [1:0] m_axi_araddr,
    output reg                           m_axi_arvalid,
    input  wire                          m_axi_arready,

    // Read data channel
    input  wire [7:0] m_axi_rdata,
    input  wire [1:0]                    m_axi_rresp,
    input  wire                          m_axi_rvalid,
    output reg                           m_axi_rready,

    output reg                           done,

    // User interface
    input  wire [1:0] write_addr,
    input  wire                          start_write,
    input  wire [7:0] uio_in,
    input  wire [1:0] read_addr,
    input  wire                          start_read,
    output  reg [7:0] read_data    
);

    // Master FSM states
    localparam IDLE        = 3'b000,
               WRITE_ADDR  = 3'b001,
               WRITE_DATA  = 3'b010,
               WRITE_RESP  = 3'b011,
               READ_ADDR   = 3'b100,
               READ_DATA   = 3'b101;

    reg [2:0] state, next_state;

    // FSM Sequential
    always @(posedge m_axi_aclk or negedge m_axi_aresetn) begin
        if (!m_axi_aresetn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM Combinational
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_write) next_state = WRITE_ADDR;
                else if (start_read) next_state = READ_ADDR;
            end
            WRITE_ADDR: if (m_axi_awready) next_state = WRITE_DATA;
            WRITE_DATA: if (m_axi_wready)  next_state = WRITE_RESP;
            WRITE_RESP: if (m_axi_bvalid)  next_state = IDLE;
            READ_ADDR:  if (m_axi_arready) next_state = READ_DATA;
            READ_DATA:  if (m_axi_rvalid)  next_state = IDLE;
        endcase
    end

    // FSM Outputs
    always @(posedge m_axi_aclk or negedge m_axi_aresetn) begin
        if (!m_axi_aresetn) begin
            m_axi_awaddr  <= 0;
            m_axi_awvalid <= 0;
            m_axi_wdata   <= 0;
            m_axi_wstrb   <= {8/8{1'b1}};
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
            m_axi_araddr  <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready  <= 0;
            read_data     <= 0;
            done          <= 0;
        end else begin
            m_axi_awvalid <= 0;
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready  <= 0;
            done          <= 0;

            case (state)
                WRITE_ADDR: begin
                    m_axi_awaddr  <= write_addr;
                    m_axi_awvalid <= 1'b1;
                end
                WRITE_DATA: begin
                    m_axi_wdata   <= uio_in;
                    m_axi_wvalid  <= 1'b1;
                    m_axi_wstrb   <= {8/8{1'b1}};
                end
                WRITE_RESP: begin
                    m_axi_bready  <= 1'b1;
                    if (m_axi_bvalid) done <= 1'b1;
                end
                READ_ADDR: begin
                    m_axi_araddr  <= read_addr;
                    m_axi_arvalid <= 1'b1;
                end
                READ_DATA: begin
                    m_axi_rready  <= 1'b1;
                    if (m_axi_rvalid) begin
                        read_data <= m_axi_rdata;
                        done      <= 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
