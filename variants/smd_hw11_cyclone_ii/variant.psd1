@{
    Name        = 'smd_hw11_cyclone_ii'
    Title       = 'GottFA80 HW 1.1 SMD mit Cyclone II Board (EP2C5T144C8)'
    BoardId     = '1'            # eine Ziffer, steht auch in variant_pkg.vhd
    Line        = 'smd'          # files_smd.tcl, Top-Level top\SYS80_80.vhd
    TopEntity   = 'SYS80_80'
    RtlFamily   = 'cyclone_ii'      # welche files_<familie>.tcl (lib_cyclone_II / _IV / _10)
    Options     = @()
    BinFolder   = 'v110'
    ReleasePrefix   = 'GottFA80_v110_'   # GottFA80_v110_v<BoardId><SW_SUB_80>.pof
    ReleaseArtifact = 'pof'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Ausgeliefert als GottFA80_v110_v103.pof - damals mit lokalen Modulkopien im Ordner. Seit 12.11.2026 auf lib_common umgestellt: Verhalten gegenueber v103 geaendert, NICHT hardwaregetestet. Kein zweites Spiel-ROM fuer die spaeten 80B-Spiele (Speicher). Quartus 13.0sp1, VIRTUAL_PIN wirkt dort nicht - die Portliste ist ohnehin voll belegt. 80B-Bootanzeige wie PLuS v7_1 seit 12.11.2026.'
}
