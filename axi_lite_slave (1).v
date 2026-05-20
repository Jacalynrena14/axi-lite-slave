// ============================================================
// AXI-lite Slave Interface with Register Bank
// Author  : Jacalyn Rena Karri
// Date    : May 2026
// ============================================================

module axi_lite_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,   // 8-bit address for proper out-of-range testing
    parameter NUM_REGS   = 4
)(
    input  wire                       ACLK,
    input  wire                       ARESETN,

    // Write Address Channel
    input  wire [ADDR_WIDTH-1:0]      AWADDR,
    input  wire                       AWVALID,
    output reg                        AWREADY,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]      WDATA,
    input  wire [(DATA_WIDTH/8)-1:0]  WSTRB,
    input  wire                       WVALID,
    output reg                        WREADY,

    // Write Response Channel
    output reg  [1:0]                 BRESP,
    output reg                        BVALID,
    input  wire                       BREADY,

    // Read Address Channel
    input  wire [ADDR_WIDTH-1:0]      ARADDR,
    input  wire                       ARVALID,
    output reg                        ARREADY,

    // Read Data Channel
    output reg  [DATA_WIDTH-1:0]      RDATA,
    output reg  [1:0]                 RRESP,
    output reg                        RVALID,
    input  wire                       RREADY
);

    // --------------------------------------------------------
    // Register Bank: 4 x 32-bit registers
    // reg_bank[0] -> 0x00
    // reg_bank[1] -> 0x04
    // reg_bank[2] -> 0x08
    // reg_bank[3] -> 0x0C
    // --------------------------------------------------------
    reg [DATA_WIDTH-1:0] reg_bank [0:NUM_REGS-1];

    reg [ADDR_WIDTH-1:0] aw_addr_latch;
    reg                  aw_addr_captured;

    integer i;

    // --------------------------------------------------------
    // BUG FIX 1:
    // Use "effective write address" wire
    // When AW and W handshakes happen simultaneously on same
    // clock edge, aw_addr_captured hasn't updated yet (<=)
    // So we directly use AWADDR when AW handshake is live
    // --------------------------------------------------------
    wire aw_handshake = AWVALID & AWREADY;

    wire [ADDR_WIDTH-1:0] eff_wr_addr;
    assign eff_wr_addr = aw_handshake ? AWADDR : aw_addr_latch;

    wire [1:0] eff_wr_idx = eff_wr_addr[3:2]; // bits[3:2] = divide by 4
    wire       eff_wr_ok  = (eff_wr_idx < NUM_REGS);

    wire [1:0] rd_reg_idx = ARADDR[3:2];
    // BUG FIX 2:
    // With 8-bit address, check if address is beyond register map (>= 0x10)
    wire       rd_addr_ok = (ARADDR[ADDR_WIDTH-1:4] == 0) &&
                            (rd_reg_idx < NUM_REGS);

    // ========================================================
    // WRITE ADDRESS CHANNEL (AW)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            AWREADY          <= 1'b1;
            aw_addr_latch    <= 0;
            aw_addr_captured <= 1'b0;
        end else begin
            if (AWVALID && AWREADY) begin
                aw_addr_latch    <= AWADDR;
                aw_addr_captured <= 1'b1;
                AWREADY          <= 1'b0;
            end else if (BVALID && BREADY) begin
                aw_addr_captured <= 1'b0;
                AWREADY          <= 1'b1;
            end
        end
    end

    // ========================================================
    // WRITE DATA CHANNEL (W)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            WREADY <= 1'b1;
        end else begin
            if (WVALID && WREADY) begin
                WREADY <= 1'b0;
            end else if (BVALID && BREADY) begin
                WREADY <= 1'b1;
            end
        end
    end

    // ========================================================
    // REGISTER WRITE LOGIC
    // Condition: W handshake + (address captured OR AW happening now)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                reg_bank[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            if (WVALID && WREADY &&
               (aw_addr_captured || aw_handshake) &&
                eff_wr_ok) begin
                if (WSTRB[0]) reg_bank[eff_wr_idx][ 7: 0] <= WDATA[ 7: 0];
                if (WSTRB[1]) reg_bank[eff_wr_idx][15: 8] <= WDATA[15: 8];
                if (WSTRB[2]) reg_bank[eff_wr_idx][23:16] <= WDATA[23:16];
                if (WSTRB[3]) reg_bank[eff_wr_idx][31:24] <= WDATA[31:24];
            end
        end
    end

    // ========================================================
    // WRITE RESPONSE CHANNEL (B)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            BVALID <= 1'b0;
            BRESP  <= 2'b00;
        end else begin
            if (WVALID && WREADY) begin
                BVALID <= 1'b1;
                BRESP  <= eff_wr_ok ? 2'b00 : 2'b10;
            end else if (BVALID && BREADY) begin
                BVALID <= 1'b0;
            end
        end
    end

    // ========================================================
    // READ ADDRESS CHANNEL (AR)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            ARREADY <= 1'b1;
        end else begin
            if (ARVALID && ARREADY) begin
                ARREADY <= 1'b0;
            end else if (RVALID && RREADY) begin
                ARREADY <= 1'b1;
            end
        end
    end

    // ========================================================
    // READ DATA CHANNEL (R)
    // ========================================================
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            RVALID <= 1'b0;
            RDATA  <= {DATA_WIDTH{1'b0}};
            RRESP  <= 2'b00;
        end else begin
            if (ARVALID && ARREADY) begin
                RVALID <= 1'b1;
                RRESP  <= rd_addr_ok ? 2'b00       : 2'b10;
                RDATA  <= rd_addr_ok ? reg_bank[rd_reg_idx]
                                     : 32'hDEAD_BEEF;
            end else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

endmodule
