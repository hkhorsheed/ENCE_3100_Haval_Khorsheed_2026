# NN Number Recognition on the DE10-Lite

You draw a digit on the PC. The PC sends the image to the FPGA over UART, 30 times each second. A neural network on the FPGA recognizes the digit and shows it on HEX0. The PC also shows what PyTorch and the FPGA calculated.

You need:
- a DE10-Lite board with its USB cable
- a USB-serial adapter set to **3.3 V** and 3 jumper wires
- Quartus Prime Lite (the version used in class) with the MAX 10 device support
- Miniconda

## 0. Extract the zip file

1. Right-click `NN_Number_Recognition_student.zip` and select **Extract All**. Do not work inside the zip file: Quartus and Python cannot use files there.
2. Extract it to a short path with no spaces, for example `C:\FPGA\NN_Number_Recognition_student`.

Do not use a OneDrive folder (for example "Documents" or "Desktop" when OneDrive is on). OneDrive can lock files while Quartus compiles.

## 1. Install the Python environment

1. Install Miniconda: <https://www.anaconda.com/docs/getting-started/miniconda/install>. On that page, select **Windows** and the graphical installer, and use the default settings.
2. Open **Anaconda Prompt** (Windows Start menu).
3. Go to this folder and create the environment. The download is about 300 MB.
   ```
   cd C:\FPGA\NN_Number_Recognition_student
   conda env create -f environment.yml
   ```
   Use the folder where you extracted the zip file.
4. Activate the environment. Do this each time you open a new Anaconda Prompt.
   ```
   conda activate nn_fpga
   ```

## 2. Compile and program the FPGA

1. In Quartus, open `quartus\nn_number_recognition.qpf`.
2. Click **Processing → Start Compilation**. This takes a few minutes.
3. Click **Tools → Programmer**. Select `output_files\nn_number_recognition.sof`, then click **Start**.
4. HEX0 shows `-`. This means "no weights yet". This is correct.

Keep the `verilog` and `quartus` folders side by side. The project finds the Verilog files at `..\verilog`.

## 3. Connect the USB-serial adapter

| Adapter | DE10-Lite |
|---|---|
| TX | `GPIO[35]` (pin AA2) |
| RX | `GPIO[33]` (pin Y3) |
| GND | GND |

Set the adapter to 3.3 V. Do not connect its 5 V or VCC pin.

## 4. Run the GUI

```
cd python
python gui.py
```

1. Select the COM port of your adapter. Keep the baud rate at **921600** and the frame rate at **30 Hz**.
2. Click **Connect**. The GUI uploads the weights. The board shows `427b` for 3 seconds, and the GUI shows "Ready".
3. Draw a digit with the left mouse button. Erase with the right button.

The window shows three results:

| Row | Where it is calculated |
|---|---|
| PyTorch float | On the PC, with floating-point numbers |
| Integer model | On the PC, with the same integer arithmetic as the FPGA |
| FPGA | On the board. A ✓ means that it is exactly the same as the integer model. |

Try this: switch **Center** off, and draw a small digit in a corner. See what happens to the result, and think about why.

## Board display

| Display | Meaning |
|---|---|
| `-` | No weights, or an empty canvas |
| `P` + LED bar | Weight upload in progress |
| `427b` | Upload OK (the weight checksum) |
| `Err 3` | Upload failed (1 = wrong model, 2 = wrong length, 3 = wrong checksum, 4 = timeout) |
| digit | The digit that the FPGA recognized. `LEDR[0]` flashes for each result. |

`KEY[0]` resets the FPGA. After a reset, click **Disconnect** and **Connect** again.

## If it does not work

| Problem | What to do |
|---|---|
| "No identify from the FPGA" | Check the COM port, TX/RX (they cross), and GND. Push `KEY[0]`. |
| No COM port in the list | Install the driver of your adapter, then click **Refresh**. |
| `conda` is not found | Use **Anaconda Prompt**, not the normal Command Prompt. |
| `ModuleNotFoundError` | Run `conda activate nn_fpga` first. |
| ✗ in the FPGA row | Push `KEY[0]`, then click **Disconnect** and **Connect**. |

## Files

| Folder | Content |
|---|---|
| `python/` | The GUI, the UART protocol, the image preprocessing, and the PyTorch model with its integer copy |
| `python/checkpoints/` | Trained PyTorch weights (float) |
| `generated/` | The int8 weights that the GUI sends to the FPGA (25,496 bytes) |
| `verilog/` | The FPGA design: NN core, UART, protocol, 7-segment display |
| `quartus/` | The Quartus project for the DE10-Lite |
