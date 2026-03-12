import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def axi_write(dut, addr, data):
"""
Perform AXI4-Lite write: set ui_in and uio_in, wait for done safely
"""

```
dut.ui_in.value = 0
dut.uio_in.value = 0
await RisingEdge(dut.clk)

dut.ui_in.value = (addr << 1) | 0x1
dut.uio_in.value = data
await RisingEdge(dut.clk)
```

# Deassert start_write
dut.ui_in.value = (addr << 1)

# Wait for done
max_cycles = 2000
for _ in range(max_cycles):

    val_logic = dut.uo_out.value

    if val_logic.is_resolvable:
        val = int(val_logic) & 0x1
    else:
        val = 0

    if val:
        return True

    await RisingEdge(dut.clk)

dut._log.error("Timeout waiting for DONE in write ❌")
return False
```

async def axi_read(dut, addr):
"""
Perform AXI4-Lite read
"""
dut.ui_in.value = 0
await RisingEdge(dut.clk)

```
# Setup read
dut.ui_in.value = (addr << 3) | 0x20
await RisingEdge(dut.clk)

# Deassert start_read
dut.ui_in.value = (addr << 3)

# Wait for done
max_cycles = 2000
for _ in range(max_cycles):

    val_logic = dut.uo_out.value
    val = int(val_logic) & 0x1 if val_logic.is_resolvable else 0

    if val:
        break

    await RisingEdge(dut.clk)
else:
    dut._log.error("Timeout waiting for DONE in read ❌")
    return None

await RisingEdge(dut.clk)
return int(dut.uio_out.value) & 0xFF
```

@cocotb.test()
async def axi4lite_test(dut):

```
# Clock
cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

# RESET
dut.rst_n.value = 0
dut.ena.value = 1
dut.ui_in.value = 0
dut.uio_in.value = 0

for _ in range(5):
    await RisingEdge(dut.clk)

dut.rst_n.value = 1
await RisingEdge(dut.clk)

dut._log.info("Reset released")

# WRITE
write_addr = 0x1
write_data = 0x4

ok = await axi_write(dut, write_addr, write_data)
if not ok:
    return

dut._log.info(f"WRITE DONE Addr={write_addr} Data={write_data}")

await Timer(20, units="ns")

# READ
read_addr = 0x1
read_data = await axi_read(dut, read_addr)

if read_data is None:
    return

dut._log.info(f"READ DONE Addr={read_addr} Data={read_data}")

# CHECK
if read_data == write_data:
    dut._log.info("TEST PASSED")
else:
    dut._log.error(f"TEST FAILED Expected {write_data} Got {read_data}")
```
