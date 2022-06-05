# S/PDIF to I2S on iCE40UP5K
Convert S/PDIF to I2S. Toy project without extensive testing.
```
Top.v
                                +------------+
 TOSLINK   +---------+  S/PDIF  | UPduino v3 |
---------> | PLR-135 | -------->|23        47| LRCLK       +-----------+
           +---------+          |          26| BCLK -----> | MAX98357A | ---> Speaker
                                |          27| DATA        +-----------+
                                +------------+
```

Use about 3mA for gateware when running at 38.4MHz

### TODO
- Add reset to clkdiv25, i2s_tx, spdif_decode
- Generate global reset
