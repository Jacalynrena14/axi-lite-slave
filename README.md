# AXI-lite Slave Interface — Verilog HDL

A fully compliant **AXI4-lite Slave** implementation in Verilog HDL, featuring a 4-register bank with complete handshake logic across all five AXI channels.

---

## Overview

AXI4-lite is a lightweight subset of ARM's AMBA AXI4 protocol designed for **single-beat register access** — ideal for control and status register (CSR) interfaces in SoC designs. This implementation provides a clean, parameterizable slave core ready for SoC integration.

---

## Features

- All **5 AXI-lite channels** implemented: AW, W, B, AR, R
- **Valid-Ready handshake** on every channel — fully AXI4-lite compliant
- **4 × 32-bit register bank** (word-aligned, parameterizable)
- **Byte-enable writes** via WSTRB — individual byte update support
- **BRESP / RRESP** error signaling — OKAY (2'b00) and SLVERR (2'b10)
- **Active-LOW synchronous reset** (ARESETN)
- Clean, commented RTL suitable for synthesis and simulation

---

## Block Diagram

```
          Master
            |
   +--------+--------+
   |    AXI-lite     |
   |   Slave Core    |
   |  +-----------+  |
   |  | reg_bank  |  |
   |  | [0] 0x00  |  |
   |  | [1] 0x04  |  |
   |  | [2] 0x08  |  |
   |  | [3] 0x0C  |  |
   |  +-----------+  |
   +-----------------+
```

---

## AXI-lite Channel Summary

| Channel | Signals | Direction | Purpose |
|---------|---------|-----------|---------|
| **AW** | AWADDR, AWVALID, AWREADY | Master → Slave | Write address |
| **W**  | WDATA, WSTRB, WVALID, WREADY | Master → Slave | Write data |
| **B**  | BRESP, BVALID, BREADY | Slave → Master | Write response |
| **AR** | ARADDR, ARVALID, ARREADY | Master → Slave | Read address |
| **R**  | RDATA, RRESP, RVALID, RREADY | Slave → Master | Read data |

---

## Register Map

| Register | Address | Description |
|----------|---------|-------------|
| REG0 | 0x00 | General purpose register 0 |
| REG1 | 0x04 | General purpose register 1 |
| REG2 | 0x08 | General purpose register 2 |
| REG3 | 0x0C | General purpose register 3 |

---

## Handshake Protocol

A transaction completes **only when both VALID and READY are HIGH** on the same rising clock edge. Neither side is required to wait for the other before asserting its signal.

```
        _____       _____
VALID  |     |_____|
        ___________
READY |             |___
              ^
        Transaction captured here
```

---

## Write Transaction Sequence

1. Master asserts **AWVALID** with AWADDR
2. Slave asserts **AWREADY** → address latched
3. Master asserts **WVALID** with WDATA and WSTRB
4. Slave asserts **WREADY** → data written to register bank
5. Slave asserts **BVALID** with BRESP = 2'b00 (OKAY)
6. Master asserts **BREADY** → transaction complete

---

## Read Transaction Sequence

1. Master asserts **ARVALID** with ARADDR
2. Slave asserts **ARREADY** → address captured
3. Slave asserts **RVALID** with RDATA and RRESP = 2'b00 (OKAY)
4. Master asserts **RREADY** → transaction complete

---

## File Structure

```
axi-lite-slave/
├── axi_lite_slave.v       # RTL design — AXI-lite slave core
├── tb_axi_lite_slave.v    # Testbench with 10 test cases
└── README.md              # This file
```

---

## Simulation

### Using Icarus Verilog (free)

```bash
# Install Icarus Verilog
sudo apt install iverilog gtkwave     # Linux
brew install icarus-verilog gtkwave   # Mac

# Compile
iverilog -o axi_sim axi_lite_slave.v tb_axi_lite_slave.v

# Run simulation
vvp axi_sim

# View waveforms
gtkwave axi_lite_tb.vcd
```

### Using Vivado (Xilinx)

1. Create new project → Add `axi_lite_slave.v` as design source
2. Add `tb_axi_lite_slave.v` as simulation source
3. Run Simulation → Run Behavioral Simulation
4. View waveforms in Vivado simulator

---

## Testbench Coverage

| Test | Description | Expected Result |
|------|-------------|-----------------|
| 1–4  | Write to all 4 registers | BRESP = OKAY |
| 5–8  | Read back all 4 registers | Data matches written values |
| 9    | Byte-enable partial write (WSTRB=0011) | Only lower 2 bytes updated |
| 10   | Out-of-range address read | RRESP = SLVERR |

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| DATA_WIDTH | 32 | Data bus width (bits) |
| ADDR_WIDTH | 4 | Address bus width (bits) |
| NUM_REGS | 4 | Number of registers in bank |

---

## Author

**Jacalyn Rena Karri**  
B.Tech Electronics and Communication Engineering  
VITAP University, Amaravati — 2026  
GitHub: [github.com/Jacalynrena14](https://github.com/Jacalynrena14)
