-- Lua Dissector for SMPTE ST2110-22 and VSF TR-08
-- Author: Arnaud Germain / Julien Van Loo (support@intopix.com)
-- Supported Wireshark Versions:
-- Version 3.4.4
--
-- to use in Wireshark:
-- 1) Ensure your Wireshark works with Lua plugins - "About Wireshark" should say it is compiled with Lua
-- 2) Install this dissector in the proper plugin directory - see "About Wireshark/Folders" to see Personal
--    and Global plugin directories.  After putting this dissector in the proper folder, "About Wireshark/Plugins"
--    should list "ST-2110_22.lua"
-- 3) Capture packets of ST 2110_22
-- 4) Use "Decode As" to define those UDP packets as RTP
-- 5) In Wireshark Preferences, under "Protocols", select ST2110_22  and set the actual capture payload type as dynamic payload type being used
-- 6) You will now see the ST 2110_22 Data dissection of the RTP payload
-- 7) Optionnally you can filter first packets using condition : st2110_22.First == True or add columns with st2110_22.First
--
-- Copyright (C) 2021 intoPIX s.a.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- Known Limitations:
-- * Doesn't check the box type before parsing
-- * No support of XLBox (not relevant for ST2110-22)
-- * Only most common color types are decoded
-- * No check of packet length constraints (as per VSF TR-08)

------------------------------------------------------------------------------------------------

-- Tables for range strings (uses legacy syntax)

local tbl_intl =      {[0]="Progressive","Reserved","First segment","Second segment"}

local tbl_frat_intl = {[0]="Progressive","Interlaced (0)","Interlaced ","Second segment"}

local tbl_sstruct = {
    [0]="4:2:2 (YCbCr)",
    [1]="4:4:4 (YCbCr)",
    [2]="4:4:4 (RGB)",
    [4]="4:2:2:4 (YCbCrAux)",
    [5]="4:4:4:4 (YCbCrAux)",
    [6]="4:4:4:4 (RGBAux)"
}

local tbl_plev_lev = {
    [0x00]="Unrestricted",
    [0x10]="2k-1",
    [0x20]="4k-1",
    [0x24]="4k-2",
    [0x28]="4k-3",
    [0x30]="8k-1",
    [0x34]="8k-2",
    [0x38]="8k-3",
    [0x40]="10k-1"
}

local tbl_plev_sublev = {
    [0x00]="Unrestricted",
    [0x80]="Full",
    [0x10]="Sublev12bpp",
    [0x0c]="Sublev9bpp",
    [0x08]="Sublev6bpp",
    [0x04]="Sublev3bpp"
}

local tbl_ppih = {
    [0x0000]="Unrestricted",
    [0x1500]="Light 422.10",
    [0x1a00]="Light 444.12",
    [0x2500]="Light-Subline 422.10",
    [0x3540]="Main 422.10",
    [0x3a40]="Main 444.12",
    [0x3e40]="Main 4444.12",
    [0x4a40]="High 444.12",
    [0x4e40]="High 4444.12"
}


do
    function range_string(str_table)
        -- Use different syntax for version 3. This function generates the right format
        -- for each wireshark version
        va,vb,vc = get_version():match("([^.]+).([^.]+).([^.]+)")
        res = {}
        for key,val in pairs(str_table) do
            if (va >= "3") then
                table.insert(res, {key,key,val})
            else
                res[key] = val
            end
        end
        return res
    end

    local st2110_22 = Proto("st2110_22", "SMPTE 2110-22 Jpeg-XS RTP")

    local prefs = st2110_22.prefs
    prefs.dyn_pt = Pref.uint("ST2110-22 payload type", 0, "The value > 95")

    local F = st2110_22.fields

    -- ST2110-22 RTP Payload

    F.T = ProtoField.bool("st2110_22.T","Transmission mode (T)",8,{"Sequential","Non-sequential"},0x80)
    F.K = ProtoField.bool("st2110_22.K","Packetization mode (K)",8,{"Slice packetization","Codestream packetization"},0x40)
    F.L = ProtoField.bool("st2110_22.L","Last packet (L)",8,{"True","False"},0x20)
    F.I = ProtoField.uint8("st2110_22.I","Interlaced (I)",base.RANGE_STRING,range_string(tbl_intl),0x18)

    F.FCNT  = ProtoField.uint32("st2110_22.FCnt", "Frame counter (F)", base.DEC,nil,  0x07C00000)
    F.SCNT  = ProtoField.uint32("st2110_22.SCnt", "Slice and Extended packet counter (SEP)", base.DEC,nil,0x003FF800)
    F.PCNT  = ProtoField.uint32("st2110_22.PCnt", "Packet counter (P)", base.DEC,nil, 0x000007FF)
    F.PCNT_EXT  = ProtoField.uint32("st2110_22.PCntExt", "Extended Packet counter (SEP & P when K=0)", base.DEC,nil, 0x003FFFFF)

    F.first = ProtoField.bool("st2110_22.First","First packet of frame (helper)")

    -- Box handling
    F.box_type = ProtoField.string("st2110_22.BOX_TYPE", "Box type (TBox)")
    F.box_len  = ProtoField.uint32("st2110_22.BOX_LEN", "Box length (LBox)",base.DEC)
    F.box_data = ProtoField.bytes("st2110_22.BOX_DATA", "Box data (DBox)")

    F.vsb = ProtoField.bytes("st2110_22.VSB", "Video support box")

    -- Video information box sub-fields
    F.vib_brat     = ProtoField.uint32("st2110_22.Brat", "Bit Rate (brat)",base.DEC)
    F.vib_frat     = ProtoField.uint32("st2110_22.Frat", "Frame Rate (frat)",base.HEX)
    F.vib_frat_hz  = ProtoField.float("st2110_22.FratHz", "Decoded frame Rate (fps)",base.UNIT_STRING, { " fps"})
    F.vib_frat_int = ProtoField.uint8("st2110_22.FratI","Interlaced (I)",base.RANGE_STRING,range_string(tbl_frat_intl),0xC0)

    F.vib_schar   = ProtoField.uint16("st2110_22.Schar", "Sample charactreristics (schar)",base.HEX)
    F.vib_svalid  = ProtoField.uint16("st2110_22.ScharValid", "Valid",base.DEC,nil,0x8000)
    F.vib_sbdepth = ProtoField.uint16("st2110_22.ScharBd","Bit depth",base.DEC,nil,0x00F0)

    F.vib_sstruct = ProtoField.uint16("st2110_22.ScharS","Sample struct",base.RANGE_STRING, range_string(tbl_sstruct) ,0x000F)
    F.vib_tcod    = ProtoField.uint32("st2110_22.Tcod", "Timecode (tcod)",base.HEX)
    F.vib_hours   = ProtoField.uint32("st2110_22.TcodHours", "Hours", base.UNIT_STRING, {"h"}, 0xFF000000)
    F.vib_minutes = ProtoField.uint32("st2110_22.TcodMin", "Minutes", base.UNIT_STRING, {"m"}, 0x00FF0000)
    F.vib_seconds = ProtoField.uint32("st2110_22.TcodSec", "Seconds", base.UNIT_STRING, {"s"}, 0x0000FF00)
    F.vib_frame   = ProtoField.uint32("st2110_22.TcodFrame", "Frame", base.DEC, nil, 0x000000FF)

    -- Profile and level box sub-fields
    F.plb_ppih     = ProtoField.uint16("st2110_22.Ppih", "Codestream profile",base.RANGE_STRING, range_string(tbl_ppih))

    F.plb_plev     = ProtoField.uint16("st2110_22.Plev", "Codestream level",base.HEX)
    F.plb_pllev    = ProtoField.uint16("st2110_22.PlevLev", "Level signaling",base.RANGE_STRING, range_string(tbl_plev_lev), 0xFF00)
    F.plb_plsublev = ProtoField.uint16("st2110_22.PlevSublev", "Sublevel signaling",base.RANGE_STRING, range_string(tbl_plev_sublev), 0x00FF)


    -- Buffer Model Description box sub-fields

    F.bmd_tbmd     = ProtoField.uint8("st2110_22.Tbmd", "Buffer Model Type (Tbmd)",base.DEC)
    F.bmd_rd       = ProtoField.uint8("st2110_22.Rd", "Reserved (Rd)",base.DEC)
    F.bmd_ncghz    = ProtoField.uint16("st2110_22.Ncghz", "Number of coef. groups for horizontal blanking period (Ncghz)",base.DEC)
    F.bmd_ncgvt    = ProtoField.uint16("st2110_22.Ncgvt", "Number of coef. groups for vertical blanking period (Ncgvt)",base.DEC)

    -- Mastering display metadata box sub-fields

    F.mdm_xc0     = ProtoField.uint16("st2110_22.MdXc0", "Xc0",base.DEC)
    F.mdm_yc0     = ProtoField.uint16("st2110_22.MdYc0", "Yc0",base.DEC)
    F.mdm_xc1     = ProtoField.uint16("st2110_22.MdXc1", "Xc1",base.DEC)
    F.mdm_yc1     = ProtoField.uint16("st2110_22.MdYc1", "Yc1",base.DEC)
    F.mdm_xc2     = ProtoField.uint16("st2110_22.MdXc2", "Xc2",base.DEC)
    F.mdm_yc2     = ProtoField.uint16("st2110_22.MdYc2", "Yc2",base.DEC)
    F.mdm_xwp     = ProtoField.uint16("st2110_22.MdXwp", "Xwp",base.DEC)
    F.mdm_ywp     = ProtoField.uint16("st2110_22.MdYwp", "Ywp",base.DEC)
    F.mdm_lmin    = ProtoField.uint32("st2110_22.Lmin", "Lmin",base.DEC)
    F.mdm_lmax    = ProtoField.uint32("st2110_22.Lmax", "Lmax",base.DEC)
    F.mdm_mcll    = ProtoField.uint16("st2110_22.Mcll", "Max Content Light Level (MCLL)",base.DEC)
    F.mdm_mfall   = ProtoField.uint16("st2110_22.Mfall", "Max Frame Average Light Level (MFALL)",base.DEC)

    -- Buffer Model Description box sub-fields

    F.jptp_slgs    = ProtoField.uint16("st2110_22.Slgs", "Contiguous slices (Slgs)",base.DEC)
    F.jptp_rsync   = ProtoField.uint8("st2110_22.Rsync", "RSync",base.DEC)
    F.jptp_tseq    = ProtoField.uint8("st2110_22.Tseq", "Tseq. Should be zero",base.DEC)
    F.jptp_mtu     = ProtoField.uint16("st2110_22.MTU", "MTU. Should be zero",base.DEC)

    -- Colour specification box

    F.csb = ProtoField.bytes("st2110_22.CSB", "Colour specification box")

    -- Colour specification box sub-fields
    F.csb_meth     = ProtoField.uint8("st2110_22.Meth", "Specification method (must be 5)",base.DEC)
    F.csb_prec     = ProtoField.int8("st2110_22.Prec", "Precedence (must be 0)",base.DEC)
    F.csb_appr     = ProtoField.uint8("st2110_22.Appr", "Colourspace approximation (must be 0)",base.DEC)
    F.csb_meth_cp  = ProtoField.uint16("st2110_22.ColPrim", "Colour primaries",base.DEC)
    F.csb_meth_tc  = ProtoField.uint16("st2110_22.TransChar", "Transfer Characteristics",base.DEC)
    F.csb_meth_mc  = ProtoField.uint16("st2110_22.MatCoef", "Matrix Coefficients",base.DEC)
    F.csb_meth_vfr = ProtoField.uint8("st2110_22.VFR", "Video Full Range",base.DEC,nil,0x80)
    F.csb_meth_cicp = ProtoField.uint8("st2110_22.Methdata_Cicp", "Reserved (should be 0)",base.DEC,nil,0x7F)
    F.csb_meth_str = ProtoField.string("st2110_22.ColourSpace", "ColourSpace type")

    -- Jpeg-XS Payload
    F.payloaddata = ProtoField.bytes("st2110_22.PayloadData", "Jpeg-XS Codestream Data")

    function st2110_22.dissector(tvb, pinfo, tree,offset)
        local subtree = tree:add(st2110_22, tvb(),"ST2110-22 Jpeg-XS RTP Payload")

        subtree:add(F.T,     tvb(0,1))
        subtree:add(F.K,     tvb(0,1))
        subtree:add(F.L,     tvb(0,1))
        subtree:add(F.I,     tvb(0,1))

        local K=tvb(0,1):bitfield(1,1)
        subtree:add(F.FCNT,  tvb(0,4))
        if (K == 1) then
            -- K=1 Slice Packetization Mode
            subtree:add(F.SCNT,  tvb(0,4))
            subtree:add(F.PCNT,  tvb(0,4))
        else
            -- K=0 Codestream Packetization Mode
            subtree:add(F.SCNT,  tvb(0,4))
            subtree:add(F.PCNT,  tvb(0,4))
            subtree:add(F.PCNT_EXT,  tvb(0,4))
        end

        local pcnt = tvb(0,4):bitfield(10,22) -- P counter + SEP counter
        local last = tvb(0,1):bitfield(2,1)

        local offset = 4;
        if (pcnt == 0) then
            subtree:add(F.first, tvb(0,4),true)

            if (last == 1) then
                subtree:append_text(":Mismatch L= 1")
            end
            -- Video support box
            local vsb_len = tvb(offset,4):uint()
            local vsb_type = tvb(offset+4,4):string()
            if (vsb_type ~= "jpvs") then
                subtree:append_text(": ERROR! Unexpected Video Support box type: "..vsb_type.." (Expected jpvs)")
                return
            end
            if (vsb_len < 42 or vsb_len > 42+14+14+36) then
                subtree:append_text(": ERROR! Unexpected Video Support Box length: "..vsb_len)
                return
            end

            local vsb_subtree = subtree:add(st2110_22, tvb(offset,vsb_len), "Video Support Box")
            vsb_subtree:add(F.box_len, tvb(offset,4))
            vsb_subtree:add(F.box_type, tvb(offset+4,4))
            vsb_subtree:add(F.box_data, tvb(offset+8,vsb_len-8))

            -- Video information box
            -- ---------------------

            local vsb_offset = offset+8
            local vib_len = tvb(vsb_offset,4):uint()
            local vib_type = tvb(vsb_offset+4,4):string()
            if (vib_len ~= 22) then
            	subtree:append_text(": ERROR! Unexpected Video Information Box length: "..vib_len.." (Expected 22)")
            	return
            end
            if (vib_type ~= "jpvi") then
                subtree:append_text(": ERROR! Unexpected box type: "..vib_type.." (Expected jpvi)")
                return
            end

            local vib_subtree = vsb_subtree:add(st2110_22, tvb(vsb_offset,vib_len), "Video Information Box")
            vib_subtree:add(F.box_len, tvb(vsb_offset,4))
            vib_subtree:add(F.box_type, tvb(vsb_offset+4,4))
            vib_subtree:add(F.box_data, tvb(vsb_offset+8,vib_len-8))

            -- Valid information box
            vib_subtree:add(F.vib_brat, tvb(vsb_offset+8,4))
            vib_subtree:add(F.vib_frat, tvb(vsb_offset+12,4))
            local fr_val = tvb(vsb_offset+12+2,2):uint()
            local fr_den = tvb(vsb_offset+12,1):bitfield(2,6)
            if (fr_den == 2) then
                fr_val = fr_val / 1.001
            end
            vib_subtree:add(F.vib_frat_hz, tvb(vsb_offset+12,4),fr_val)
            vib_subtree:add(F.vib_frat_int, tvb(vsb_offset+12,1))
            vib_subtree:add(F.vib_schar, tvb(vsb_offset+16,2))
            vib_subtree:add(F.vib_svalid, tvb(vsb_offset+16,2))
            local depth = bit.band(tvb(vsb_offset+17,1):uint() , 0xF0 ) + 16
            vib_subtree:add(F.vib_sbdepth,  tvb(vsb_offset+17,2), depth)
            vib_subtree:add(F.vib_sstruct, tvb(vsb_offset+16,2))
            vib_subtree:add(F.vib_tcod, tvb(vsb_offset+18,4))
            vib_subtree:add(F.vib_hours, tvb(vsb_offset+18,4))
            vib_subtree:add(F.vib_minutes, tvb(vsb_offset+18,4))
            vib_subtree:add(F.vib_seconds, tvb(vsb_offset+18,4))
            vib_subtree:add(F.vib_frame, tvb(vsb_offset+18,4))


            vsb_offset = vsb_offset + vib_len

            -- Profile and level box
            -- ---------------------

            local plb_type = tvb(vsb_offset+4,4):string()
            local plb_len = tvb(vsb_offset,4):uint()
            if (plb_len ~= 12) then
            	subtree:append_text(": ERROR! Unexpected Profile and level box length: "..plb_len.." (Expected 12)")
            	return
            end
            if (plb_type ~= "jxpl") then
                subtree:append_text(": ERROR! Unexpected box type: "..plb_type.." (Expected jxpl)")
                return
            end

            local plb_subtree = vsb_subtree:add(st2110_22, tvb(vsb_offset,plb_len), "Profile and level Box")
            plb_subtree:add(F.box_len, tvb(vsb_offset,4))
            plb_subtree:add(F.box_type, tvb(vsb_offset+4,4))
            plb_subtree:add(F.box_data, tvb(vsb_offset+8,plb_len-8))

            plb_subtree:add(F.plb_ppih, tvb(vsb_offset+8,2))
            plb_subtree:add(F.plb_plev, tvb(vsb_offset+8+2,2))
            plb_subtree:add(F.plb_pllev, tvb(vsb_offset+8+2,2))
            plb_subtree:add(F.plb_plsublev, tvb(vsb_offset+8+2,2))

            vsb_offset = vsb_offset + plb_len


            if (vsb_offset < offset + vsb_len) then
                local box_type = tvb(vsb_offset+4,4):string()
                local box_len = tvb(vsb_offset,4):uint()
                -- Buffer Model Description box
                -- ----------------------------
                if (box_type == "bmdm") then
                    local bmd_subtree = vsb_subtree:add(st2110_22, tvb(vsb_offset,box_len), "Buffer Model Description Box (optional)")
                    bmd_subtree:add(F.box_len, tvb(vsb_offset,4))
                    bmd_subtree:add(F.box_type, tvb(vsb_offset+4,4))
                    bmd_subtree:add(F.box_data, tvb(vsb_offset+8,box_len-8))
                    bmd_subtree:add(F.bmd_tbmd, tvb(vsb_offset+8,1))
                    bmd_subtree:add(F.bmd_rd,    tvb(vsb_offset+8+1,1))
                    bmd_subtree:add(F.bmd_ncghz, tvb(vsb_offset+8+2,2))
                    bmd_subtree:add(F.bmd_ncgvt, tvb(vsb_offset+8+4,2))

                    vsb_offset = vsb_offset + box_len
                end
            end
            if (vsb_offset < offset + vsb_len) then
                local box_type = tvb(vsb_offset+4,4):string()
                local box_len = tvb(vsb_offset,4):uint()
                -- Mastering Display Metadata  box
                -- ----------------------------
                if (box_type == "dmon") then
                    local mdm_subtree = vsb_subtree:add(st2110_22, tvb(vsb_offset,box_len), "Mastering Display Metadata Box (optional)")
                    mdm_subtree:add(F.box_len, tvb(vsb_offset,4))
                    mdm_subtree:add(F.box_type, tvb(vsb_offset+4,4))
                    mdm_subtree:add(F.box_data, tvb(vsb_offset+8,box_len-8))
                    mdm_subtree:add(F.mdm_xc0  ,tvb(vsb_offset+8,2))
                    mdm_subtree:add(F.mdm_yc0  ,tvb(vsb_offset+8+2,2))
                    mdm_subtree:add(F.mdm_xc1  ,tvb(vsb_offset+8+4,2))
                    mdm_subtree:add(F.mdm_yc1  ,tvb(vsb_offset+8+6,2))
                    mdm_subtree:add(F.mdm_xc2  ,tvb(vsb_offset+8+8,2))
                    mdm_subtree:add(F.mdm_yc2  ,tvb(vsb_offset+8+10,2))
                    mdm_subtree:add(F.mdm_xwp  ,tvb(vsb_offset+8+12,2))
                    mdm_subtree:add(F.mdm_ywp  ,tvb(vsb_offset+8+14,2))
                    mdm_subtree:add(F.mdm_lmin ,tvb(vsb_offset+8+16,4))
                    mdm_subtree:add(F.mdm_lmax ,tvb(vsb_offset+8+20,4))
                    mdm_subtree:add(F.mdm_mcll ,tvb(vsb_offset+8+24,2))
                    mdm_subtree:add(F.mdm_mfall,tvb(vsb_offset+8+26,2))
                    vsb_offset = vsb_offset + box_len
                end
            end
           if (vsb_offset < offset + vsb_len) then
               local box_type = tvb(vsb_offset+4,4):string()
               local box_len = tvb(vsb_offset,4):uint()
               -- Video Transport parameter box
               -- ----------------------------
               if (box_type == "jptp") then
                   local jptp_subtree = vsb_subtree:add(st2110_22, tvb(vsb_offset,box_len), "Video Transport Parameter Box (optional)")
                   jptp_subtree:add(F.box_len, tvb(vsb_offset,4))
                   jptp_subtree:add(F.box_type, tvb(vsb_offset+4,4))
                   jptp_subtree:add(F.box_data, tvb(vsb_offset+8,box_len-8))
                   jptp_subtree:add(F.jptp_slgs ,tvb(vsb_offset+8,2))
                   jptp_subtree:add(F.jptp_rsync,tvb(vsb_offset+8+2,1))
                   jptp_subtree:add(F.jptp_tseq ,tvb(vsb_offset+8+3,1))
                   jptp_subtree:add(F.jptp_mtu  ,tvb(vsb_offset+8+4,2))
                   vsb_offset = vsb_offset + box_len
               end
           end

            if (vsb_offset ~= offset + vsb_len) then
                subtree:append_text(": ERROR! Video support box length error")
                return
            end


            offset = offset + vsb_len

            -- Colour specification box
            local csb_len = tvb(offset,4):uint()
            if (csb_len ~= 18) then
            	subtree:append_text(": ERROR! Unexpected Colour support box length "..csb_len.." (Expected 18)")
            	return
            end
            local csb_subtree = subtree:add(st2110_22, tvb(offset,csb_len), "Colour Specification Box")
            csb_subtree:add(F.box_len, tvb(offset,4))
            csb_subtree:add(F.box_type, tvb(offset+4,4))
            csb_subtree:add(F.box_data, tvb(offset+8,csb_len-8))

            csb_subtree:add(F.csb_meth, tvb(offset+8,1))
            csb_subtree:add(F.csb_prec, tvb(offset+8+1,1))
            csb_subtree:add(F.csb_appr, tvb(offset+8+2,1))
            csb_subtree:add(F.csb_meth_cp, tvb(offset+8+3,2))
            local meth_cp = tvb(offset+8+3,2):uint()
            csb_subtree:add(F.csb_meth_tc, tvb(offset+8+5,2))
            local meth_tc = tvb(offset+8+5,2):uint()
            csb_subtree:add(F.csb_meth_mc, tvb(offset+8+7,2))
            local meth_mc = tvb(offset+8+7,2):uint()
            csb_subtree:add(F.csb_meth_vfr, tvb(offset+8+9,1))
            csb_subtree:add(F.csb_meth_cicp, tvb(offset+8+9,1))
            local meth_vfr = tvb(offset+8+9,1):uint()

            if (meth_cp == 1 and meth_tc == 13 and meth_mc == 0) then
            	csb_subtree:add(F.csb_meth_str, "IEC 61966-2-1 sRGB")
            elseif (meth_cp == 1 and meth_tc == 13 and meth_mc == 0) then
            	csb_subtree:add(F.csb_meth_str, "IEC 61966-2-1 sYCC")
            elseif (meth_cp == 1 and meth_tc == 1 and meth_mc == 1) then
            	csb_subtree:add(F.csb_meth_str, "Rec.ITU-R BT.709-6")
            elseif (meth_cp == 5 and meth_tc == 6 and meth_mc == 5) then
            	csb_subtree:add(F.csb_meth_str, "Rec.ITU-R BT.601-7 625")
            elseif (meth_cp == 6 and meth_tc == 6 and meth_mc == 6) then
            	csb_subtree:add(F.csb_meth_str, "Rec.ITU-R BT.601-7 525")
            elseif (meth_cp == 9 and (meth_tc == 14 or meth_tc == 15) and (meth_mc == 9 or meth_mc == 10)) then
            	csb_subtree:add(F.csb_meth_str, "Rec.ITU-R BT.2020-2")
            elseif (meth_cp == 9 and (meth_tc == 16 or meth_tc == 18) and meth_mc == 9 ) then
            	csb_subtree:add(F.csb_meth_str, "Rec.ITU-R BT.2100-0")
            end



            offset = offset + csb_len
        else
            subtree:add(F.first, tvb(0,4),false)
        end
        subtree:add(F.payloaddata, tvb(offset))
    end

    -- register dissector to dynamic payload type dissectorTable
    local dyn_payload_type_table = DissectorTable.get("rtp_dyn_payload_type")
    dyn_payload_type_table:add("st2110_22", st2110_22)

    -- register dissector to RTP payload type
    local payload_type_table = DissectorTable.get("rtp.pt")
    local old_dissector = nil
    local old_dyn_pt = 0
    function st2110_22.init()
        if (prefs.dyn_pt ~= old_dyn_pt) then
            if (old_dyn_pt > 0) then
                if (old_dissector == nil) then
                    payload_type_table:remove(old_dyn_pt, st2110_22)
                else
                    payload_type_table:add(old_dyn_pt, old_dissector)
                end
            end
            old_dyn_pt = prefs.dyn_pt
            old_dissector = payload_type_table:get_dissector(old_dyn_pt)
            if (prefs.dyn_pt > 0) then
                payload_type_table:add(prefs.dyn_pt, st2110_22)
            end
        end
    end
end
