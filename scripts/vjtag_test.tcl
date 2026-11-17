# vjtag_test.tcl - Stufe 1 von "FA-Control ueber Virtual JTAG" (17.11.2026)
#
# Prueft den Testknoten lib_common\vjtag_probe.vhd (Variante smd_hw11_cyclone_iv_v4_vj) vom PC
# aus, ueber USB-Blaster an P5. Zwei Teile:
#   A  ueber die Quartus-Befehle device_virtual_*  -> prueft das Design
#   B  roh ueber device_ir_shift/device_dr_shift, genau so, wie es der ESP32 spaeter tun muss
#      (USER1/USER0, HUB_INFO/NODE_INFO lesen, Knoten adressieren) -> prueft das Hub-Protokoll
#
# Aufruf (FPGA mit SYS80.sof bzw. .jic der Variante konfiguriert):
#   C:\intelFPGA_lite\22.1std\quartus\bin64\quartus_stp.exe -t scripts\vjtag_test.tcl
#
# Erwartet: ID = 4746383x ("GF8" & BOARD_ID, v4 -> 47463833), Echo = geschriebener Wert,
# HUB_INFO-Hersteller 0x06E, ein Knoten mit ID 0x08. Konzept: ESP32-C3_EVALUIERUNG.md Abschnitt 15.

set IR_USER0 12      ;# 0x00C
set IR_USER1 14      ;# 0x00E
set VIR_SCRATCH 1
set VIR_ID      2

proc hex2int {h} { return [expr "0x$h"] }

# ---- Geraet waehlen ------------------------------------------------------------
if {[catch {get_hardware_names} hwliste] || [llength $hwliste] == 0} {
    puts "FEHLER: kein USB-Blaster gefunden (jtagconfig pruefen)"
    exit 1
}
set hw [lindex $hwliste 0]
set dev [lindex [get_device_names -hardware_name $hw] 0]
puts "Hardware: $hw"
puts "Geraet:   $dev"
open_device -hardware_name $hw -device_name $dev
device_lock -timeout 10000

set fehler 0

# ---- A: ueber die Quartus-Befehle ----------------------------------------------
puts "\n--- A: device_virtual_* ---"
device_virtual_ir_shift -instance_index 0 -ir_value $VIR_ID -no_captured_ir_value
set id [device_virtual_dr_shift -instance_index 0 -length 32 -dr_value 00000000 -value_in_hex]
puts "ID:        0x$id"
if {([hex2int $id] >> 8) != 0x474638} { puts "  FEHLER: erwartet 0x474638xx"; incr fehler }

device_virtual_ir_shift -instance_index 0 -ir_value $VIR_SCRATCH -no_captured_ir_value
foreach muster {12345678 A5A5A5A5 00000001 80000000} {
    device_virtual_dr_shift -instance_index 0 -length 32 -dr_value $muster -value_in_hex -no_captured_dr_value
    set echo [device_virtual_dr_shift -instance_index 0 -length 32 -dr_value 00000000 -value_in_hex]
    set ok [expr {[hex2int $echo] == [hex2int $muster] ? "ok" : "FEHLER"}]
    if {$ok ne "ok"} { incr fehler }
    puts "Echo:      0x$muster -> 0x$echo  $ok"
}

# ---- B: roh, wie der ESP32 -----------------------------------------------------
puts "\n--- B: roh (USER1/USER0) ---"

# Hub selbst waehlen: USER1, DR mit 64 Nullen (Adresse 0, VIR 0)
device_ir_shift -ir_value $IR_USER1 -no_captured_ir_value
device_dr_shift -length 64 -dr_value 0000000000000000 -value_in_hex -no_captured_dr_value
device_ir_shift -ir_value $IR_USER0 -no_captured_ir_value

# 8 Halbbytes je Wort, untere zuerst
proc lies_wort {} {
    set w 0
    for {set i 0} {$i < 8} {incr i} {
        set n [device_dr_shift -length 4 -dr_value 0 -value_in_hex]
        set w [expr {$w | ([hex2int $n] << (4 * $i))}]
    }
    return $w
}

set hub [lies_wort]
set hub_n   [expr {$hub & 0xFF}]
set hub_mfg [expr {($hub >> 8) & 0x7FF}]
set hub_cnt [expr {($hub >> 19) & 0xFF}]
set hub_ver [expr {($hub >> 27) & 0x1F}]
puts [format "HUB_INFO:  0x%08X  Version %d, Knoten %d, Hersteller 0x%03X, VIR-Breite n %d" \
    $hub $hub_ver $hub_cnt $hub_mfg $hub_n]
if {$hub_mfg != 0x06E} { puts "  FEHLER: Hersteller nicht 0x06E - Bitfelder stimmen nicht"; incr fehler }

set adr_vj 0
for {set k 1} {$k <= $hub_cnt} {incr k} {
    set node [lies_wort]
    set n_inst [expr {$node & 0xFF}]
    set n_mfg  [expr {($node >> 8) & 0x7FF}]
    set n_id   [expr {($node >> 19) & 0xFF}]
    set n_ver  [expr {($node >> 27) & 0x1F}]
    puts [format "NODE_INFO: 0x%08X  Adresse %d: Version %d, Knoten-ID 0x%02X, Hersteller 0x%03X, Instanz %d" \
        $node $k $n_ver $n_id $n_mfg $n_inst]
    if {$n_id == 0x08 && $adr_vj == 0} { set adr_vj $k }
}

# Adressbreite m = ceil(log2(N+1))
set m 0
while {(1 << $m) < ($hub_cnt + 1)} { incr m }
puts "Adressbreite m = $m"

if {$adr_vj == 0} {
    puts "FEHLER: kein Virtual-JTAG-Knoten (ID 0x08) gefunden"
    incr fehler
} else {
    # Knoten adressieren: USER1, DR = {Adresse, VIR}, m + n Bit
    set breite [expr {$m + $hub_n}]
    set wert   [expr {($adr_vj << $hub_n) | $VIR_ID}]
    set hexlen [expr {($breite + 3) / 4}]
    device_ir_shift -ir_value $IR_USER1 -no_captured_ir_value
    device_dr_shift -length $breite -dr_value [format "%0${hexlen}X" $wert] -value_in_hex -no_captured_dr_value
    device_ir_shift -ir_value $IR_USER0 -no_captured_ir_value
    set id_roh [device_dr_shift -length 32 -dr_value 00000000 -value_in_hex]
    puts [format "Roh-ID:    0x%s  (USER1-DR %d Bit = 0x%X)" $id_roh $breite $wert]
    if {[hex2int $id_roh] != [hex2int $id]} { puts "  FEHLER: weicht von A ab"; incr fehler }
}

device_unlock
close_device

puts ""
if {$fehler == 0} { puts "ERGEBNIS: alles ok" } else { puts "ERGEBNIS: $fehler Fehler" }
exit [expr {$fehler == 0 ? 0 : 1}]
