# FIR Filter: MAC vs Shift/Add

This project designs, simulates, and compares a 50th-order FIR filter using two Verilog hardware architectures:

- **MAC-based FIR**: direct multiply-and-accumulate implementation, mapped to FPGA DSP resources during synthesis.
- **Shift/Add FIR**: multiplier-less implementation that replaces coefficient multiplication with shifts and additions.

The goal is to compare functional behavior, timing, power, and FPGA resource utilization for the same filter coefficients and test signals.

## Filter Specification

| Item | Value |
| --- | --- |
| Filter type | Low-pass FIR |
| Filter order | 50 |
| Number of taps | 51 |
| Sampling frequency / HDL test clock | 44.1 kHz |
| Clock period used in testbench | 22,675.73696 ns |
| Input data width | 16-bit signed |
| Coefficient width | 16-bit signed fixed-point |
| Output data width | 32-bit signed in main RTL modules |
| Coefficient set | Symmetric, 51 coefficients, generated in MATLAB and quantized to 16-bit fixed-point |
| Target FPGA used for reports | Xilinx Artix-7 XC7A100T |

The coefficient set is symmetric, so the FIR filter has linear phase. The quantized coefficient sum is `32765`, close to Q15 unity gain.

From the current 16-bit coefficient response at `Fs = 44.1 kHz`:

- Pass-band examples: `550 Hz`, `820 Hz`, and `2.1 kHz` are passed with very small attenuation.
- Around `3 kHz`, attenuation is about `-2.15 dB`.
- Approximate `-3 dB` cutoff is around `3.14 kHz`.
- Around `4.3 kHz`, attenuation is about `-20 dB`.
- From about `5 kHz` upward, attenuation is roughly `-60 dB` or lower for the measured coefficient response.

## Test Signals

The Verilog testbench uses a `44.1 kHz` clock and applies four multi-frequency stimulus cases:

| Case | Input signal | Purpose |
| --- | --- | --- |
| 1 | `550 Hz + 3 kHz` | Low and mid-frequency behavior |
| 2 | `820 Hz + 4.3 kHz` | Mid-band / transition behavior |
| 3 | `2.1 kHz + 10.8 kHz` | Pass-band plus stop-band rejection |
| 4 | `13 kHz + 70 kHz` | High-frequency rejection stress case |

The stimulus is implemented in `Codes/FIR Testbench/fir_filter_tasks.v` and driven by `Codes/FIR Testbench/fir_filter_tb.v`.

## Architectures

### MAC-Based FIR

File: `Codes/FIR Modules/fir_filter.v`

- Stores 51 input samples in a delay-line buffer.
- Stores 51 fixed-point tap coefficients.
- Computes one product per tap using direct multiplication.
- Accumulates all tap products into the output.
- Supports runtime tap update through `i_tap_wr_en`, `i_tap_wr_addr`, and `i_tap_wr_data` when filtering is disabled.

This version is logic-efficient but uses DSP blocks for multiplication.

### Shift/Add FIR

File: `Codes/FIR Modules/fir_filter_shift.v`

- Uses the same delay-line and coefficient structure.
- Replaces multiplication with bit-level shift-and-add operations.
- Handles negative coefficients by negating the coefficient magnitude and subtracting shifted sample terms.
- Avoids DSP usage, but uses many more LUTs and routing resources.

This version is useful when DSP slices must be reserved for other modules, but it has much higher LUT utilization.

## Tools

- **Verilog HDL**: RTL implementation and testbench.
- **MATLAB**: FIR coefficient generation, signal generation, and reference checking.
- **Simulink**: optional model-level and HDL co-simulation verification.
- **Xilinx Vivado / XSIM**: RTL simulation, synthesis, timing analysis, power estimate, and resource utilization reports.

## Workflow

1. Design the FIR filter in MATLAB using a low-pass specification for an audio-rate sample clock (`Fs = 44.1 kHz`).
2. Generate floating-point FIR coefficients and inspect the frequency response with MATLAB tools such as `fvtool`.
3. Quantize coefficients to 16-bit fixed-point values.
4. Implement the filter in Verilog using both architectures:
   - `fir_filter.v` for MAC-based implementation.
   - `fir_filter_shift.v` for Shift/Add implementation.
5. Create and run the Verilog testbench in Vivado XSIM.
6. Compare filtered waveform behavior across the four test cases.
7. Optionally verify against MATLAB/Simulink reference outputs.
8. Synthesize both designs for Artix-7 and compare timing, power, LUT/register/DSP usage.

## Reproducing The Simulation

In Vivado:

1. Create a new RTL project.
2. Use an Artix-7 target matching the report setup, such as `XC7A100T`.
3. Add RTL sources from `Codes/FIR Modules/`.
4. Add simulation sources from `Codes/FIR Testbench/`.
5. Set `fir_filter_tb` as the simulation top.
6. Run behavioral simulation with XSIM.

For Shift/Add simulation, instantiate the Shift/Add module in the testbench instead of the MAC module.

## Reported Results

### Timing

The design clock is very slow for FPGA logic because it is tied to the audio sample rate (`44.1 kHz`). Both architectures meet timing comfortably.

| Metric | MAC FIR | Shift/Add FIR |
| --- | ---: | ---: |
| Worst Negative Slack (WNS) | 22,658.408 ns | 22,641.400 ns |
| Total Negative Slack (TNS) | 0.000 ns | 0.000 ns |
| Worst Hold Slack (WHS) | 0.131 ns | 0.055 ns |
| Total Hold Slack (THS) | 0.000 ns | 0.000 ns |

### Power

| Metric | MAC FIR | Shift/Add FIR |
| --- | ---: | ---: |
| Total on-chip power | 0.091 W | 0.091 W |
| Dynamic power | < 0.001 W | < 0.001 W |
| Static power | 0.091 W | 0.091 W |
| DSP power share | 37% | 0% |

Static power dominates because the clock frequency is only `44.1 kHz`.

### Resource Utilization

| Resource | MAC FIR | Shift/Add FIR |
| --- | ---: | ---: |
| Slice LUTs | 861 / 63,400 (1.35%) | 39,888 / 63,400 (63%) |
| Slice registers | 1,670 / 126,800 (1.3%) | 1,664 / 126,800 (1.3%) |
| Slices | 595 / 15,850 (3.7%) | 10,888 / 15,850 (68.7%) |
| DSPs | 51 / 240 (21.25%) | 0 / 240 (0%) |
| IOB | 74 | 74 |
| BUFGCTRL | 1 | 1 |

Summary:

- MAC FIR is much more LUT-efficient, but consumes 51 DSP blocks.
- Shift/Add FIR uses no DSP blocks, but consumes far more LUTs and slices.
- At `44.1 kHz`, both designs meet timing and have nearly identical total estimated power.

## Repository Structure

- `Codes/FIR Modules/` - RTL implementations.
- `Codes/FIR Testbench/` - Vivado simulation testbench and waveform-generation tasks.
- `Codes/MATLAB:Simulink/` - MATLAB/Simulink-related HDL and test assets.
- `Designs/` - Block diagrams.
- `Docs/` - Project report and presentation deck.
- `Demos/` - Demo notes. Large video files are kept locally and ignored by Git.
- `Refs/` - Reference papers and supporting documents.

## Notes

- Large `.mp4` demo files are intentionally ignored to keep the repository lightweight.
- The project is currently simulation/synthesis focused. Hardware deployment on a physical FPGA board is listed as future work in the report.
