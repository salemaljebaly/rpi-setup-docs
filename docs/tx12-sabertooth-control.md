# TX12 RC Control for Sabertooth via Cube Orange+

This guide explains the control path for using a **Radiomaster TX12** to drive **two 12V motors** through a **Cube Orange+** and a **Sabertooth HS Hybrid**.

It is written for the setup already discussed in this repo:

- Raspberry Pi provides MAVLink networking and QGroundControl access
- Cube Orange+ is the flight controller
- Radiomaster TX12 provides manual RC input
- Sabertooth receives PWM-style control on `S1` and `S2`

## Important Architecture Note

For **live joystick driving**, the normal signal path is:

```text
TX12 transmitter
  -> RC receiver
  -> Cube Orange+ RC input
  -> Cube PWM outputs
  -> Sabertooth S1 / S2
  -> Motors
```

The Raspberry Pi and `mavlink-router` are **not** the main path for TX12 stick movement.

Their role is:

```text
Cube Orange+ <-> Raspberry Pi <-> mavlink-router <-> QGroundControl / scripts
```

Use the Pi path for:

- telemetry
- QGroundControl access
- Python or MAVLink automation
- checking live outputs and parameters

Do **not** rely on the Pi to forward normal RC stick motion unless you intentionally build a separate MAVLink control bridge.

## Assumptions

This guide assumes:

- the Sabertooth is being driven in **RC/PWM input mode**
- `S1` is motor channel 1 input
- `S2` is motor channel 2 input
- the Sabertooth `0V` terminal is connected to Cube signal ground
- only **signal + ground** are connected from Cube to Sabertooth
- the Sabertooth `5V` terminal is left unused

If your Sabertooth is configured for packetized serial, analog, or another input mode, this guide does not apply directly.

## Wiring Summary

Typical signal wiring for the current setup:

```text
Cube output GND   -> Sabertooth 0V
Cube output SIG1  -> Sabertooth S1
Cube output SIG2  -> Sabertooth S2
```

Notes:

- The red 5V servo wire is usually **not needed** for this setup.
- The Sabertooth already has its own power from the 12V motor supply.
- A multimeter on a PWM signal will show a **small average voltage** such as `0.17V` to `0.8V`. That is normal for PWM and does not mean the signal is weak.

## What Must Be Working First

Before testing motor motion from the TX12, confirm all of these:

1. `mavlink-router` is running on the Pi and QGroundControl can see the Cube.
2. The TX12 receiver is connected to the Cube and RC input is visible in QGroundControl.
3. Radio calibration in QGroundControl has been completed.
4. The Cube safety setting has already been adjusted for bench testing.
5. The vehicle can arm successfully without the `non-zero throttle` error.

From prior troubleshooting in this repo, two things were already important:

- `BRD_SAFETYOPTION = 0`
- the TX12 receiver must be connected so the Cube sees valid RC input

## Recommended Control Model

For a two-motor ground vehicle, think of the sticks as:

- `up/down` = throttle
- `left/right` = steering

The Cube should then mix those inputs into two motor outputs:

- one output for the left motor controller input
- one output for the right motor controller input

In practice, that means:

- one Cube output drives Sabertooth `S1`
- one Cube output drives Sabertooth `S2`

## Bench Test Procedure

Remove load from the drivetrain if possible before testing.

### 1. Verify RC input in QGroundControl

Open **QGroundControl -> Vehicle Setup -> Radio**.

Move the TX12 sticks and confirm:

- throttle changes when you move the drive stick up/down
- steering changes when you move the stick left/right
- the bars reach their minimum, center, and maximum cleanly

If arming says `non-zero throttle`, recalibrate the radio first.

### 2. Verify output is reaching the Sabertooth

When you move the sticks:

- the Cube output PWM should change
- the Sabertooth should see a valid signal on `S1` / `S2`

If you use a multimeter on signal-to-ground, a low average voltage is expected because PWM is pulsed.

### 3. Arm the vehicle

The Cube will often block throttle-related outputs until armed.

If the vehicle is disarmed:

- RC input may look correct in QGroundControl
- but the outputs to the Sabertooth may remain fixed or inactive

### 4. Test one direction at a time

Test in this order:

1. Neutral sticks: both motors stopped
2. Forward stick: both motors drive forward
3. Reverse stick: both motors drive reverse
4. Right steering: left/right motor speeds split correctly
5. Left steering: left/right motor speeds split correctly

## If the TX12 Moves in QGC but Motors Do Not Move

Check these in order:

1. The vehicle is still disarmed.
2. RC calibration was incomplete or throttle minimum is wrong.
3. The Sabertooth is not in the expected RC/PWM mode.
4. `S1` and `S2` are not connected to the actual active Cube outputs.
5. Ground between Cube and Sabertooth is missing.
6. The motor power side of the Sabertooth is powered, but the output side is not enabled as expected.

## What MAVLink Is Good For Here

MAVLink through the Pi is useful for:

- reading RC and servo output values
- changing parameters from QGroundControl
- testing outputs from software
- building autonomous control later

This is a different mode from direct RC driving.

## Identifying The Real RC Channel At The Cube

When QGroundControl is reading the Radiomaster over USB, the channel labels on the transmitter or QGC joystick page may not match the final `RC_CHANNELS` values that arrive at the Cube.

For output mapping, the **Cube-side MAVLink view is the source of truth**.

This repo includes a helper script:

👉 **[scripts/monitor_rc_channels.py](../scripts/monitor_rc_channels.py)**

### Why this matters

If you want an output to follow a specific stick axis, do not guess from the transmitter screen alone.

Instead:

1. Watch `RC_CHANNELS` on the Cube.
2. Move one stick axis.
3. See which `RCx` changes.
4. Assign the matching pass-through function.

### Copy to the Pi

From this repo on your computer:

```bash
scp scripts/monitor_rc_channels.py lab2@192.168.0.127:/home/lab2/
```

### Run on the Pi

```bash
ssh lab2@192.168.0.127
python3 /home/lab2/monitor_rc_channels.py --channels 4
```

Example output:

```text
Connecting to tcp:127.0.0.1:5760...
Watching RC_CHANNELS. Move one stick at a time. Press Ctrl+C to stop.
(1467, 1433, 1100, 1496)
```

### How to interpret it

Move one stick axis at a time and watch which channel changes:

- `RC1` changed -> use `SERVOx_FUNCTION = 51`
- `RC2` changed -> use `SERVOx_FUNCTION = 52`
- `RC3` changed -> use `SERVOx_FUNCTION = 53`
- `RC4` changed -> use `SERVOx_FUNCTION = 54`

Example:

- if right stick up/down changes `RC3`
- and you want `MAIN OUT 5` to follow it
- set `SERVO5_FUNCTION = 53`

## Why RC5 To RC8 May Stay At Zero

In the current USB joystick path:

```text
TX12 -> USB -> QGroundControl -> MAVLink -> Cube
```

it is normal for only the first four RC-style channels to reach the Cube.

That means:

- `RC1` to `RC4` change when you move the main sticks
- `RC5` to `RC8` may stay `0`
- buttons or switches may still appear to work inside QGroundControl without becoming Cube RC channels

This is a limitation of the current joystick-to-QGC control path, not a problem with the Cube.

### If you need RC5 to RC8

The normal way to get more RC channels is to add a real radio receiver connected directly to the Cube:

```text
TX12 -> receiver -> Cube RC input
```

That gives the Cube proper RC input for:

- extra channels like `RC5` to `RC8`
- switches
- better failsafe behavior
- a more standard radio control path

For your current setup:

- `TX12 -> USB -> QGC` is fine for basic 4-channel control
- `TX12 -> receiver -> Cube` is the better design if you need more channels

## Two Supported Ways to Drive the Motors

### Method 1: Direct RC driving

Use this when the operator is holding the TX12.

Path:

```text
TX12 -> receiver -> Cube -> Sabertooth -> motors
```

This is the correct method for manual joystick driving.

### Method 2: Software or QGC driving

Use this when you want Python or a ground station to command motion.

Path:

```text
QGroundControl or Python -> MAVLink -> Cube -> Sabertooth -> motors
```

This is the correct method for scripted or assisted control.

## Recommendation for This Project

For your current goal, use:

- **TX12 for manual movement**
- **Raspberry Pi + MAVLink for monitoring, setup, and later automation**

That keeps the control path simple and avoids adding the Pi into the live RC loop.
