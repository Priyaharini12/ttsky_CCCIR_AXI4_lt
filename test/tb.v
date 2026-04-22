//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2025 18:50:21
// Design Name: 
// Module Name: axi4lite_tb
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

module axi4lite_tb;

    //localparam ADDR_WIDTH = 2;
    //localparam DATA_WIDTH = 8;

    reg clk;
    reg rst_n;
    reg ena;

    // Inputs to top
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;

    // Outputs from top
    wire [7:0] uio_oe;
    wire [7:0] uio_out;
    wire [7:0] uo_out;

    // DUT
    tt_um_axi4lite_top dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .ena    (ena),
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .uio_oe (uio_oe),
        .uio_out(uio_out),
        .uo_out (uo_out)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // Test sequence
    initial begin
        rst_n  = 0;
        ena    = 1;
        ui_in  = 0;
        uio_in = 0;

        #20 rst_n = 1;

        // ---------------- WRITE ----------------
        #20;
        ui_in[0]   = 1;        // start_write
        ui_in[2:1] = 2'h1;     // write_addr
        uio_in     = 8'h4;     // write data
        #10 ui_in[0] = 0;      // deassert start_write
        wait(uo_out[0] == 1);  // wait for done
        $display("WRITE: Addr=0x%h Data=0x%h", ui_in[2:1], uio_in);

        // ---------------- READ ----------------
        #20;
        ui_in[5]   = 1;        // start_read
        ui_in[4:3] = 2'h1;     // read_addr
        #10 ui_in[5] = 0;      // deassert start_read
        wait(uo_out[0] == 1);  // wait for done
        $display("READ:  Addr=0x%h Data=0x%h", ui_in[4:3], uio_out);

        // ---------------- CHECK ----------------
        if (uio_out == 8'h4)
            $display("TEST PASSED ?");
        else
            $display("TEST FAILED ? (Expected 0x04, Got 0x%h)", uio_out);

        #100 $finish;
    end
    endmodule
