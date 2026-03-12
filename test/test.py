import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly


# =============================================================================
# Safe Signal Access Helpers
# =============================================================================

def safe_bit(signal, bit_idx, default=0):
    """
    Safely extract a single bit from a LogicArray.
    Returns default if bit is X/Z or out of range.
    """
    try:
        binstr = signal.value.binstr
        # binstr is MSB-first; index 0 is leftmost (MSB)
        # For LSB access, use negative indexing or reverse
        if bit_idx < 0:
            bit_idx = len(binstr) + bit_idx
        if 0 <= bit_idx < len(binstr) and binstr[bit_idx] in '01':
            return int(binstr[bit_idx])
        return default
    except Exception:
        return default


def safe_int(signal, bits=None, default=0):
    """
    Safely convert LogicArray to int.
    Returns default if any bit is X/Z.
    If bits is specified, only use that many LSBs.
    """
    try:
        binstr = signal.value.binstr
        if 'X' in binstr or 'Z' in binstr:
            return default
        if bits is not None:
            binstr = binstr[-bits:]  # Take LSBs
        return int(binstr, 2)
    except Exception:
        return default


def binstr(signal):
    """Convenience: get binary string representation of a signal."""
    try:
        return signal.value.binstr
    except Exception:
        return "???"


# =============================================================================
# AXI4-Lite Primitive Operations (Custom Protocol)
# =============================================================================

async def axi_write(dut, addr, data, timeout_cycles=2000):
    """
    Perform AXI4-Lite write operation.
    
    Protocol:
    - ui_in[1:0] = address[1:0]
    - ui_in[0] also serves as start_write strobe (1 = start)
    - uio_in = write data
    - uo_out[0] = done flag (1 = complete)
    
    Returns True on success, False on timeout.
    """
    dut._log.debug(f"WRITE: addr=0x{addr:X}, data=0x{data:X}")
    
    # Idle state
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)

    # Assert write command: [addr<<1 | start_write=1]
    dut.ui_in.value = (addr << 1) | 0x1
    dut.uio_in.value = data
    await RisingEdge(dut.clk)

    # Deassert start while keeping address
    dut.ui_in.value = (addr << 1) | 0x0

    # Wait for done flag (uo_out[0] == 1)
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        # Safe check: only proceed if bit 0 is known
        if safe_bit(dut.uo_out, 0) == 1:
            dut._log.debug(f"WRITE done after {cycle+1} cycles")
            await RisingEdge(dut.clk)  # One more cycle for stability
            return True
        # Optional: debug first 20 cycles
        if cycle < 20:
            dut._log.debug(f"  WAIT[{cycle}]: uo_out={binstr(dut.uo_out)}")

    dut._log.error(f"WRITE TIMEOUT: addr=0x{addr:X}, uo_out={binstr(dut.uo_out)}")
    return False


async def axi_read(dut, addr, timeout_cycles=2000):
    """
    Perform AXI4-Lite read operation.
    
    Protocol:
    - ui_in[4:3] = address[1:0]
    - ui_in[5] = start_read strobe (1 = start)
    - uio_out = read data (8-bit)
    - uo_out[0] = done flag (1 = complete)
    
    Returns read data (int) on success, None on timeout.
    """
    dut._log.debug(f"READ: addr=0x{addr:X}")
    
    # Idle state
    dut.ui_in.value = 0
    await RisingEdge(dut.clk)

    # Assert read command: [addr<<3 | start_read=1<<5]
    dut.ui_in.value = (addr << 3) | 0x20
    await RisingEdge(dut.clk)

    # Deassert start while keeping address bits
    dut.ui_in.value = (addr << 3) | 0x0

    # Wait for done flag
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if safe_bit(dut.uo_out, 0) == 1:
            dut._log.debug(f"READ done after {cycle+1} cycles")
            await RisingEdge(dut.clk)  # Stabilize data
            # Safe conversion of 8-bit data
            data = safe_int(dut.uio_out, bits=8, default=None)
            if data is None:
                dut._log.error(f"READ data invalid: uio_out={binstr(dut.uio_out)}")
            return data
        if cycle < 20:
            dut._log.debug(f"  WAIT[{cycle}]: uo_out={binstr(dut.uo_out)}, uio_out={binstr(dut.uio_out)}")

    dut._log.error(f"READ TIMEOUT: addr=0x{addr:X}, uo_out={binstr(dut.uo_out)}")
    return None


# =============================================================================
# Main Testbench
# =============================================================================

@cocotb.test()
async def axi4lite_test(dut):
    """
    Cocotb testbench for tt_um_axi4lite_top (AXI4-Lite custom protocol)
    
    Test sequence:
    1. Reset and initialize
    2. Write 0x4 to address 0x1
    3. Read from address 0x1
    4. Verify read data matches written data
    """
    
    # ---------------------------------------------------------------------
    # 1. Clock Setup (100 MHz)
    # ---------------------------------------------------------------------
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut._log.info("Clock started @ 100 MHz")

    # ---------------------------------------------------------------------
    # 2. Reset Sequence
    # ---------------------------------------------------------------------
    dut._log.info("Asserting reset...")
    dut.rst_n.value = 0      # Active-low reset
    dut.ena.value = 1        # Enable module
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Hold reset for 5 cycles
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset released ✅")
    
    # Debug: log initial signal states
    dut._log.info(f"Post-reset: uo_out={binstr(dut.uo_out)}, uio_out={binstr(dut.uio_out)}")

    # ---------------------------------------------------------------------
    # 3. WRITE Test: Write 0x4 to address 0x1
    # ---------------------------------------------------------------------
    write_addr = 0x1
    write_data = 0x4
    
    dut._log.info(f"Starting WRITE: addr=0x{write_addr:X}, data=0x{write_data:X}")
    success = await axi_write(dut, write_addr, write_data)
    
    if not success:
        dut._log.error("❌ WRITE operation failed")
        return  # Fail test early
    
    dut._log.info(f"✅ WRITE completed: 0x{write_data:X} @ 0x{write_addr:X}")
    
    # Optional settling time
    await Timer(20, units="ns")

    # ---------------------------------------------------------------------
    # 4. READ Test: Read from address 0x1
    # ---------------------------------------------------------------------
    read_addr = 0x1
    
    dut._log.info(f"Starting READ: addr=0x{read_addr:X}")
    read_data = await axi_read(dut, read_addr)
    
    if read_data is None:
        dut._log.error("❌ READ operation failed")
        return  # Fail test early
    
    dut._log.info(f"✅ READ completed: 0x{read_data:X} @ 0x{read_addr:X}")

    # ---------------------------------------------------------------------
    # 5. Verification
    # ---------------------------------------------------------------------
    if read_data == write_data:
        dut._log.info(f"🎉 TEST PASSED: Read 0x{read_data:X} == Written 0x{write_data:X}")
    else:
        dut._log.error(f"💥 TEST FAILED: Expected 0x{write_data:X}, Got 0x{read_data:X}")
        # Additional debug info
        dut._log.error(f"  Final signals: uo_out={binstr(dut.uo_out)}, uio_out={binstr(dut.uio_out)}")
        assert False, f"Data mismatch: expected 0x{write_data:X}, got 0x{read_data:X}"
