# pins.tcl - Pinlagen der Variante plus_hw21x_cyclone_iv_v7_1 (Cyclone-IV-Board v7.1, EP4CE22F17C8).
# Am 06.11.2026 aus variants\plus_hw21x_cyclone_iv_v7\pins.tcl abgeleitet. Header-Belegung
# wie v7; geaendert sind nur die Baelle, die beim EP4CE22 Takteingaenge sind:
#
#   Board v7.1 (Schaltplan EP4CE6_dev_board_v7_1_SCH.PDF, Piggyback-Doku 12.7):
#     disp_segments[10] R8 -> P8    disp_segments[11] T8 -> N8
#     disp_segments[12] R9 -> P9    disp_segments[13] T9 -> N9
#     U4_PA[2]          B8 -> C8    Sound             C8 -> E8
#     U4_PA[0]          B9 -> C9    LED_SDcard        C9 -> E9
#
#   DRAHTBRUECKEN (nur GottFA80): die Schalter-Strobes U4_PB[7]/U4_PB[5] sind Ausgaenge,
#   liegen auf v7 aber auf A8/A9 - beim EP4CE22 reine Takteingaenge, die das Board v7.1
#   bewusst am Header gelassen hat. Deshalb auf zwei freie I/Os (Bank 5) verlegt:
#     U4_PB[7]  A8 (P3-16) -> N14 (P2-8)   Bruecke P2-8 <-> P3-16
#     U4_PB[5]  A9 (P3-14) -> R16 (P2-3)   Bruecke P2-3 <-> P3-14
#   A8/A9 bleiben unzugewiesen (RESERVE_ALL_UNUSED_PINS: tri-state Eingang), die Bruecke
#   stoert sie nicht. P2-3 und P2-8 muessen auf dem PLuS-Mainboard frei sein.
#   Headerpins aus der Netzliste EP4CE6_dev_board_v7_0.NET. Reserve: L14 (P2-9).
#
# Die drei FA-Pins liegen nicht am Stecker, sondern am ESP auf X7 (wie v7).
# NICHT HARDWAREGETESTET.
set_location_assignment PIN_E1 -to clk_50
set_location_assignment PIN_T3 -to disp_segments[1]
set_location_assignment PIN_R4 -to disp_segments[2]
set_location_assignment PIN_T4 -to disp_segments[3]
set_location_assignment PIN_R5 -to disp_segments[4]
set_location_assignment PIN_T6 -to disp_segments[5]
set_location_assignment PIN_T5 -to disp_segments[6]
set_location_assignment PIN_R6 -to disp_segments[7]
set_location_assignment PIN_R7 -to disp_segments[8]
set_location_assignment PIN_T7 -to disp_segments[9]
set_location_assignment PIN_P8 -to disp_segments[10]
set_location_assignment PIN_N8 -to disp_segments[11]
set_location_assignment PIN_P9 -to disp_segments[12]
set_location_assignment PIN_N9 -to disp_segments[13]
set_location_assignment PIN_R10 -to disp_segments[14]
set_location_assignment PIN_T10 -to disp_segments[15]
set_location_assignment PIN_R11 -to disp_segments[16]
set_location_assignment PIN_T11 -to disp_segments[17]
set_location_assignment PIN_R12 -to disp_segments[18]
set_location_assignment PIN_T12 -to disp_segments[19]
set_location_assignment PIN_R13 -to disp_segments[20]
set_location_assignment PIN_T13 -to disp_segments[21]
set_location_assignment PIN_R14 -to disp_segments[22]
set_location_assignment PIN_T14 -to disp_segments[23]
set_location_assignment PIN_T15 -to disp_segments[24]
set_location_assignment PIN_P15 -to U5_PA[0]
set_location_assignment PIN_P16 -to U5_PA[1]
set_location_assignment PIN_N15 -to U5_PA[2]
set_location_assignment PIN_N16 -to U5_PA[3]
set_location_assignment PIN_L16 -to U6_PB[2]
set_location_assignment PIN_L15 -to U6_PB[1]
set_location_assignment PIN_G15 -to U6_PB[3]
set_location_assignment PIN_F16 -to U6_PB[4]
set_location_assignment PIN_F15 -to U6_PB[5]
set_location_assignment PIN_E10 -to U6_PB[6]
set_location_assignment PIN_E11 -to U6_PB[7]
set_location_assignment PIN_D16 -to U6_PA[3]
set_location_assignment PIN_D15 -to U6_PA[1]
set_location_assignment PIN_C16 -to U6_PA[2]
set_location_assignment PIN_C15 -to U6_PA[0]
set_location_assignment PIN_B16 -to U6_PA[6]
set_location_assignment PIN_A4 -to U4_PA[7]
set_location_assignment PIN_B6 -to U4_PA[6]
set_location_assignment PIN_A5 -to U4_PA[5]
set_location_assignment PIN_B7 -to U4_PA[4]
set_location_assignment PIN_A6 -to U4_PA[3]
set_location_assignment PIN_C8 -to U4_PA[2]
set_location_assignment PIN_A7 -to U4_PA[1]
set_location_assignment PIN_C9 -to U4_PA[0]
set_location_assignment PIN_B13 -to U4_PB[0]
set_location_assignment PIN_A11 -to U4_PB[1]
set_location_assignment PIN_B12 -to U4_PB[2]
set_location_assignment PIN_A10 -to U4_PB[3]
set_location_assignment PIN_B11 -to U4_PB[4]
set_location_assignment PIN_R16 -to U4_PB[5]
set_location_assignment PIN_B10 -to U4_PB[6]
set_location_assignment PIN_N14 -to U4_PB[7]
set_location_assignment PIN_R1 -to CLK
set_location_assignment PIN_P1 -to CS_EEprom
set_location_assignment PIN_K1 -to CS_SDcard
set_location_assignment PIN_C6 -to LED_Int
set_location_assignment PIN_E9 -to LED_SDcard
set_location_assignment PIN_P2 -to MISO
set_location_assignment PIN_L2 -to MOSI
set_location_assignment PIN_G16 -to U5_PA_7
set_location_assignment PIN_A12 -to U5_PB_7
set_location_assignment PIN_B14 -to U6_PA[7]
set_location_assignment PIN_A13 -to U6_PA[5]
set_location_assignment PIN_A14 -to U6_PA[4]
set_location_assignment PIN_A15 -to U6_PB[0]
set_location_assignment PIN_B4 -to reset_sw
set_location_assignment PIN_B1 -to DIP_Return[0]
set_location_assignment PIN_D1 -to DIP_Return[2]
set_location_assignment PIN_C3 -to DIP_Return[1]
set_location_assignment PIN_K16 -to DIP_Return[3]
set_location_assignment PIN_B5 -to DIP_Strobe[0]
set_location_assignment PIN_N2 -to DIP_Strobe[1]
set_location_assignment PIN_J15 -to myTest
set_location_assignment PIN_D9 -to LED_ON
set_location_assignment PIN_N1 -to DIP_Strobe[2]
set_location_assignment PIN_L1 -to DIP_Strobe[3]
set_location_assignment PIN_D8 -to Audio_RX
set_location_assignment PIN_E8 -to Sound
set_location_assignment PIN_C2 -to Debug[0]
set_location_assignment PIN_R3 -to FA_RXD
set_location_assignment PIN_T2 -to FA_TXD
set_location_assignment PIN_N3 -to FA_CTRL_REQ
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to FA_CTRL_REQ
