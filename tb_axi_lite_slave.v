// ============================================================
// Testbench: AXI-lite Slave
// Author  : Jacalyn Rena Karri
// ============================================================
`timescale 1ns/1ps

module tb_axi_lite_slave;

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 8;   // Updated to 8-bit
    parameter CLK_PERIOD = 10;

    reg                       ACLK;
    reg                       ARESETN;

    reg  [ADDR_WIDTH-1:0]     AWADDR;
    reg                       AWVALID;
    wire                      AWREADY;

    reg  [DATA_WIDTH-1:0]     WDATA;
    reg  [(DATA_WIDTH/8)-1:0] WSTRB;
    reg                       WVALID;
    wire                      WREADY;

    wire [1:0]                BRESP;
    wire                      BVALID;
    reg                       BREADY;

    reg  [ADDR_WIDTH-1:0]     ARADDR;
    reg                       ARVALID;
    wire                      ARREADY;

    wire [DATA_WIDTH-1:0]     RDATA;
    wire [1:0]                RRESP;
    wire                      RVALID;
    reg                       RREADY;

    axi_lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .NUM_REGS  (4)
    ) dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA),   .WSTRB(WSTRB),
        .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP),   .BVALID(BVALID),  .BREADY(BREADY),
        .ARADDR(ARADDR), .ARVALID(ARVALID),.ARREADY(ARREADY),
        .RDATA(RDATA),   .RRESP(RRESP),
        .RVALID(RVALID), .RREADY(RREADY)
    );

    initial ACLK = 0;
    always #(CLK_PERIOD/2) ACLK = ~ACLK;

    integer pass_count = 0;
    integer fail_count = 0;

    // --------------------------------------------------------
    // TASK: Write
    // --------------------------------------------------------
    task axi_write;
        input [ADDR_WIDTH-1:0]     addr;
        input [DATA_WIDTH-1:0]     data;
        input [(DATA_WIDTH/8)-1:0] strb;
        begin
            @(posedge ACLK); #1;
            AWADDR  = addr;  AWVALID = 1;
            WDATA   = data;  WSTRB   = strb; WVALID = 1;
            BREADY  = 1;

            wait(AWREADY); @(posedge ACLK); #1; AWVALID = 0;
            wait(WREADY);  @(posedge ACLK); #1; WVALID  = 0;
            wait(BVALID);  @(posedge ACLK); #1; BREADY  = 0;

            $display("[WRITE] Addr=0x%02h | Data=0x%08h | WSTRB=%04b | BRESP=%02b (%s)",
                addr, data, strb, BRESP,
                (BRESP==2'b00)?"OKAY":"SLVERR");
        end
    endtask

    // --------------------------------------------------------
    // TASK: Read
    // --------------------------------------------------------
    task axi_read;
        input  [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] rdata_out;
        output [1:0]            rresp_out;
        begin
            @(posedge ACLK); #1;
            ARADDR  = addr; ARVALID = 1;
            RREADY  = 1;

            wait(ARREADY); @(posedge ACLK); #1; ARVALID = 0;
            wait(RVALID);
            rdata_out = RDATA;
            rresp_out = RRESP;
            @(posedge ACLK); #1; RREADY = 0;

            $display("[READ]  Addr=0x%02h | Data=0x%08h | RRESP=%02b (%s)",
                addr, RDATA, RRESP,
                (RRESP==2'b00)?"OKAY":"SLVERR");
        end
    endtask

    // --------------------------------------------------------
    // TASK: Check
    // --------------------------------------------------------
    task check;
        input [DATA_WIDTH-1:0] actual;
        input [DATA_WIDTH-1:0] expected;
        input integer          test_num;
        begin
            if (actual === expected) begin
                $display("  >> TEST %0d PASS: Got 0x%08h", test_num, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  >> TEST %0d FAIL: Expected 0x%08h Got 0x%08h",
                    test_num, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [DATA_WIDTH-1:0] rd_data;
    reg [1:0]            rd_resp;

    initial begin
        $dumpfile("axi_lite_tb.vcd");
        $dumpvars(0, tb_axi_lite_slave);

        ARESETN=0; AWVALID=0; WVALID=0;
        BREADY=0;  ARVALID=0; RREADY=0;
        AWADDR=0;  WDATA=0;   WSTRB=4'hF;
        ARADDR=0;

        repeat(3) @(posedge ACLK);
        ARESETN = 1;
        repeat(2) @(posedge ACLK);

        $display("");
        $display("========================================");
        $display("  AXI-lite Slave Testbench");
        $display("========================================");

        // --- Write all 4 registers ---
        $display("\n--- TEST 1-4: Write Transactions ---");
        axi_write(8'h00, 32'hDEAD_BEEF, 4'hF);
        axi_write(8'h04, 32'hCAFE_BABE, 4'hF);
        axi_write(8'h08, 32'h1234_5678, 4'hF);
        axi_write(8'h0C, 32'hABCD_EF01, 4'hF);
        repeat(3) @(posedge ACLK);

        // --- Read back all 4 registers ---
        $display("\n--- TEST 5-8: Read-back Verification ---");
        axi_read(8'h00, rd_data, rd_resp); check(rd_data, 32'hDEAD_BEEF, 5);
        axi_read(8'h04, rd_data, rd_resp); check(rd_data, 32'hCAFE_BABE, 6);
        axi_read(8'h08, rd_data, rd_resp); check(rd_data, 32'h1234_5678, 7);
        axi_read(8'h0C, rd_data, rd_resp); check(rd_data, 32'hABCD_EF01, 8);

        // --- Byte enable write ---
        $display("\n--- TEST 9: Byte-Enable Write (WSTRB=0011) ---");
        axi_write(8'h00, 32'hFFFF_1111, 4'b0011);
        axi_read (8'h00, rd_data, rd_resp);
        check(rd_data, 32'hDEAD_1111, 9);

        // --- Out of range address ---
        $display("\n--- TEST 10: Out-of-Range Read (Expect SLVERR) ---");
        axi_read(8'hFF, rd_data, rd_resp);
        if (rd_resp == 2'b10) begin
            $display("  >> TEST 10 PASS: Got SLVERR");
            pass_count = pass_count + 1;
        end else begin
            $display("  >> TEST 10 FAIL: Expected SLVERR got %02b", rd_resp);
            fail_count = fail_count + 1;
        end

        repeat(5) @(posedge ACLK);
        $display("");
        $display("========================================");
        $display("  RESULTS: %0d PASS | %0d FAIL", pass_count, fail_count);
        $display("========================================");
        $finish;
    end

    initial begin #50000; $display("WATCHDOG TIMEOUT"); $finish; end

endmodule
