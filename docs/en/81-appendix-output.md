# Appendix: Solution Output

<!-- Appendix: feeding the MRTKLIB solution to an external consumer.

     Structure rationale:
       - File      : zero setup (the /workspace volume is already mounted rw)
       - TCP Server: the OS-independent primary route; needs a published port
       - Serial    : Windows(WSL) / Linux only. Docker Desktop for Mac has no
                     serial/--device passthrough (see scripts/macos/README.md)
       - NTRIP / TCP Client: outbound, so no port publishing is needed

     Settled:
       - The published TCP port is 2101 (common.ps1 $OutPort), matching the
         UI's tcpsvr placeholder. Port conflicts are covered by
         90-troubleshooting.md#sec-troubleshooting-port-in-use.
       - run-container.ps1 passes only the SBF node, pinned to /dev/ttyACM0 in
         the container. The receiver's CON node stays in WSL, unused.

     Sources for the less obvious claims here (read off the code, not guessed):
       - tcpsvr always binds INADDR_ANY: gentcp() in MRTKLIB
         src/stream/mrtk_stream.c leaves sin_addr zeroed for type==0, so an
         address in the path is parsed and then ignored. Restricting the
         audience has to happen at the docker publish, on the host side.
       - The output slot's "NTRIP Client" acts as an NTRIP *server*: the UI
         writes type="ntrip", and rtkrcv's OSTOPT list has no ntripcli, so
         str2enum() substring-matches "5:ntripsvr" (apps/rtkrcv/rtkrcv.c).
       - ::S= takes hours as a float: sscanf(p+2,"S=%lf") in openfile().
       - The mrtk process inherits the server's cwd, /app (Dockerfile WORKDIR),
         so a relative output path is NOT written to the mounted volume.

     TODO(open decision):
       - Serial: attaching additional USB devices is not implemented yet
         (an opt-in VID:PID list was proposed). Until then this chapter
         documents the manual usbipd + one-line script edit procedure.

     CAUTION for the macOS / Linux implementations:
       "The UI's Path is always ttyACM0" is now asserted OS-independently in
       10-concepts.md, 50-using-ui.md and 90-troubleshooting.md. When
       scripts/macos/lib and the Linux equivalent are written, they MUST
       reproduce the same `--device <detected>:/dev/ttyACM0` renaming, or
       those three statements become wrong.
-->

## Overview {#sec-output-overview}

MRTKLIB's positioning solution can be output externally in various forms for use elsewhere.
This chapter explains how to configure each output method.

Output is configured in `Output 1 (Solution)` under `Output & Log Streams` in the UI.
If you want to configure multiple outputs, click the `+` on the right side of `Output & Log Streams` to add more output configurations.

![](../assets/img/mrtklib-output.png)

| Output method | Main use | Supported OS | Prerequisite |
| --- | --- | --- | --- |
| [File](#sec-output-file) | Save as a log for later analysis | Windows / macOS / Linux | None |
| [TCP/IP Server](#sec-output-tcpsvr) | Receive in real time from another app or device | Windows / macOS / Linux | None |
| [Serial (USB)](#sec-output-serial) | Stream in real time to an external device | Windows / Linux only | Required (manual) |
| [NTRIP / TCP Client](#sec-output-client) | Send to an external server | Windows / macOS / Linux | None |

!!! danger "Important"

    This chapter covers output of the **positioning result (solution)**.
    The current `mrtklib-docker-ui` cannot save the raw data (SBF) arriving from the receiver as-is in parallel with real-time positioning.
    Support for saving raw data is being considered for the near future.

## Selecting the output method {#sec-output-type}

Click `Type` to select the output method from the dropdown.

![](../assets/img/mrtklib-output-type.png)

Once you select `Type`, you can enter `Path` and `Format`.
The `Path` format differs by output method, so refer to the sections below.
You can also view the list of `Path` formats from the `?` icon to the right of the `Output & Log Streams` heading.

## Selecting the output format {#sec-output-format}

For `Format`, select `NMEA`.
The positioning solution is output as NMEA sentences (such as `$GPGGA`), which most applications can interpret as-is.

## File output {#sec-output-file}

To output to a file, set `Type` and `Path` as follows.

| Item | Setting |
| --- | --- |
| **Type**    | `File` |
| **Path**    | `/workspace/G5P6%n%H.nmea::S=1` |
| **Format**  | `NMEA` |

`/workspace` is mounted from the host's `{path to mrtklib-quickstart}/mrtklib-quickstart-data/workspace`.
In the example filename `G5P6%n%H.nmea`, `G5P6` is the receiver name, `%n` is the day of year, and `%H` is the hour code (a=0, b=1, ..., x=23).

!!! danger "Important"

    Always specify `Path` as an **absolute path** starting with `/workspace/`.
    A relative path (e.g., `workspace/out.nmea`) is written to a different location inside the container, so it **will not be visible from the host, and will be lost when the container is stopped or removed**.

### Time specifiers {#sec-output-file-keyword}

In addition to `%n` and `%H`, the following specifiers are available.

| Specifier | Meaning |
| --- | --- |
| `%Y` | Year (yyyy) |
| `%y` | Year (yy) |
| `%m` | Month (mm) |
| `%d` | Day of Month (dd) |
| `%n` | Day of Year (ddd) |
| `%W` | GPS Week No. (wwww) |
| `%D` | Day of Week |
| `%h` | Hour (00-23) |
| `%M` | Minute (00-59) |
| `%S` | Second (00-59) |
| `%H` | Hour code (a,b,...,x) |

### File splitting {#sec-output-file-swap}

The `::S=` appended to the end of the path specifies the interval at which the file is split, **in hours**.

| Setting | Behavior |
| --- | --- |
| `::S=1` | Switch to a new file every hour |
| `::S=24` | Switch every 24 hours |
| `::S=0.5` | Switch every 30 minutes |
| Not specified | Keep writing to a single file without splitting |

When using splitting, be sure to include a time specifier in the file name.
If you don't, each switch will overwrite the file of the same name.

## TCP/IP Server output {#sec-output-tcpsvr}

Run MRTKLIB as a TCP server, and connect from another application or device to receive the positioning solution.

| Item | Setting |
| --- | --- |
| **Type**    | `TCP Server` |
| **Path**    | `:2101` |
| **Format**  | `NMEA` |

For `Path`, write the port number after `:`.

!!! danger "Important"

    The number you specify here **must match the port published by the startup script**. If you specify a different number, you won't be able to connect from outside.
    Only `$OutPort` in `scripts\windows\lib\common.ps1` (default `2101`) is published. If you want to change it, see [Change the port in use](90-troubleshooting.md#sec-troubleshooting-port-change).

### Verifying the connection {#sec-output-tcpsvr-verify}

To verify from the same PC, run the following command in PowerShell.
If `TcpTestSucceeded : True` is displayed, the port is reachable.

```powershell
Test-NetConnection localhost -Port 2101
```

!!! note "Note"

    This command only checks whether the port is reachable. To confirm that the positioning solution is actually flowing, verify that the connecting application can receive NMEA sentences.

To connect from another device, specify the IP address of the PC running MRTKLIB instead of `localhost`. You can check the IP address with the following command.

```powershell
ipconfig
```

### Note on the scope of exposure {#sec-output-tcpsvr-security}

!!! warning "Warning"

    By default, this port is published on `0.0.0.0` (all network interfaces), so **any device on the same LAN can connect**.
    MRTKLIB's TCP Server has no authentication feature.
    Please be careful when using it on an untrusted network, such as shared Wi-Fi.

Writing an address in `Path` does not change the scope of exposure.
MRTKLIB's TCP Server always listens on all interfaces, regardless of what is written in the path.
If you want to restrict it to the same PC only, rewrite the publish setting in `scripts\windows\lib\run-container.ps1` as follows.

```powershell
'-p', "127.0.0.1:${OutPort}:${OutPort}"
```

## Serial (USB) output {#sec-output-serial}

Stream the positioning solution to an external device via a USB serial converter or similar.

!!! warning "Warning"

    Serial output is available **only on Windows (via WSL) and Linux**.
    Docker Desktop for Mac does not support serial device passthrough, so it is not available on macOS.
    On macOS, use [TCP/IP Server output](#sec-output-tcpsvr) instead.

!!! danger "Important"

    Because the target devices vary widely, this is **outside the scope of automatic configuration**.
    The steps below are manual.
    Also, the device passed to the container can only be specified at startup.
    **Be sure to connect the output device before running `start.bat`**.
    If you connect it after the container has started, it will not be recognized.

### Attaching the output device {#sec-output-serial-attach}

Just like the receiver, the output device also needs to be attached to WSL.

Connect the output device via USB, then, in an administrator PowerShell ([Run PowerShell as administrator](20-install-windows.md#sec-win-wsl2-powershell)), list the connected USB devices.

```powershell
usbipd list
```

Check the `BUSID` of the output device, then share it and attach it to WSL. Replace `X-Y` with the `BUSID` you checked.

```powershell
usbipd bind --busid X-Y
usbipd attach --wsl --busid X-Y
```

Check the device name on the WSL side.

```powershell
wsl ls /dev/ttyUSB* /dev/ttyACM*
```

Common USB serial converters such as FTDI, CP210x, and CH340 appear as something like `/dev/ttyUSB0`.
Use the name you confirmed here in the next step and in the UI configuration.

### Adding the device to the container {#sec-output-serial-device}

`start.bat` passes only the single port carrying the receiver's SBF to the container.
To pass the output device as well, edit the following line in `scripts\windows\lib\run-container.ps1`.

```powershell
$deviceArgs = @('--device', "${sbfDevice}:${ContainerDevice}",
                '--device', '/dev/ttyUSB0:/dev/ttyUSB0')
```

Replace `/dev/ttyUSB0` with the name you confirmed in the previous step.

After editing, run `stop.bat`, then run `start.bat` again. The container is recreated, and the added device is passed through.

!!! note "Note"

    If the output device is a CDC-ACM device such as an Arduino (one that appears as `/dev/ttyACM*`), the SBF port detection process in `start.bat` reads from that port for about 3 seconds at startup.
    Be careful with devices that have side effects when read from.

### UI configuration {#sec-output-serial-config}

| Item | Setting |
| --- | --- |
| **Type**    | `Serial` |
| **Path**    | `ttyUSB0:115200` |
| **Format**  | `NMEA` |

Specify `Path` in the format `device name:baud rate`. The leading `/dev/` is not needed.
Set the baud rate to match the configuration on the output device side.

!!! note "Note"

    `ttyACM0` is the port used for the receiver input (Rover). Do not specify it as an output destination.

### Detaching at shutdown {#sec-output-serial-detach}

`stop.bat` only detaches the receiver (mosaic-G5).
The output device you added remains attached to WSL, and stays invisible from Windows.

After running `stop.bat`, manually detach it in an administrator PowerShell.

```powershell
usbipd detach --busid X-Y
```

## NTRIP / TCP Client output {#sec-output-client}

Send the positioning solution to an external server.
Since MRTKLIB initiates the outbound connection, no port publishing is needed.

### NTRIP {#sec-output-client-ntrip}

Send the positioning solution to an NTRIP caster.

| Item | Setting |
| --- | --- |
| **Type**    | `NTRIP Client` |
| **Path**    | `[:passwd@]addr[:port]/mountpoint` |
| **Format**  | `NMEA` |

!!! danger "Important"

    The `Type` shown is `NTRIP Client`, but **when configured as an output, it acts as an NTRIP server (the side that sends to the caster)**.
    Because of this, `Path` uses the format above, which differs from the NTRIP client format used on the input side (`user:passwd@...`).
    Do not specify a username — specify only the password and mount point.

Example: `:mypassword@rtk2go.com:2101/MYMOUNT`

### TCP Client {#sec-output-client-tcp}

Connect to any TCP server to send the positioning solution.

| Item | Setting |
| --- | --- |
| **Type**    | `TCP Client` |
| **Path**    | `addr[:port]` |
| **Format**  | `NMEA` |

Example: `192.168.1.100:2101`

## If it doesn't work

- [Troubleshooting](90-troubleshooting.md)
