/*
    macam - webcam app and QuickTime driver component
    Copyright (C) 2002 Matthias Krauss (macam@matthias-krauss.de)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 $Id$
*/

#define thng_RezTemplateVersion 1

#include <Carbon/Carbon.r>
#include <QuickTime/QuickTime.r>

/*

The vdig isn't registered automatically any more. It is done in the sgpn's register function. See "QT_architecture.txt" for details.
 
resource 'thng' (256) {
    'vdig',
    'wcam',
    'mk  ',
    componentHasMultiplePlatforms
    +cmpWantsRegisterMessage
    +componentDoAutoVersion
    +componentAutoVersionIncludeFlags,
    0,
    0,
    0,
    'STR ',
    256,
    'STR ',
    257,
    0,
    0,
    65537,
    componentHasMultiplePlatforms
    +cmpWantsRegisterMessage
    +componentDoAutoVersion
    +componentAutoVersionIncludeFlags,
    0,
    {
        componentHasMultiplePlatforms
        +cmpWantsRegisterMessage
        +componentDoAutoVersion
        +componentAutoVersionIncludeFlags,
        'dlle',
        256,
        platformPowerPCNativeEntryPoint,
    };
};

resource 'STR ' (256) {
    "Webcam"
};

resource 'STR ' (257) {
    "A video digitizer for USB some webcams"
};

resource 'dlle' (256) {
    "vdigMainEntry"
};
*/

resource 'thng' (258) {
    'sgpn',
    'vide',
    'MaCa',
    componentHasMultiplePlatforms
    +cmpWantsRegisterMessage
    +componentDoAutoVersion
    +componentAutoVersionIncludeFlags,
    0,
    0,
    0,
    'STR ',
    258,
    'STR ',
    259,
    0,
    0,
    65537,
    componentHasMultiplePlatforms
    +cmpWantsRegisterMessage
    +componentDoAutoVersion
    +componentAutoVersionIncludeFlags,
    0,
    {
        componentHasMultiplePlatforms
        +cmpWantsRegisterMessage
        +componentDoAutoVersion
        +componentAutoVersionIncludeFlags,
        'dlle',
        258,
        platformPowerPCNativeEntryPoint,
    };
};
    
resource 'STR ' (258) {
    "Webcam"
};

resource 'STR ' (259) {
    "Specific parameter settings for the USB webcam driver"
};

resource 'dlle' (258) {
    "sgpnMainEntry"
};

/* DITL for webcam panel. Can be localized in DriverLocalizable.strings */

resource 'DITL' (258) {
{
{0,0,20,200},		/* 1: Camera name */
    StaticText {
        enabled,
        "Not available"
    },
{25,0,45,60},		/* 2: HFlip checkbox */
    CheckBox {
        enabled,
        "Flip"
    },
{50,60,75,200},		/* 3: Gamma slider */
    Control {
        enabled,
        1000
    },
{25,60,45,200},		/* 4: Auto gain checkbox */
CheckBox {
    enabled,
    "Auto gain"
},
{75,60,100,200},	/* 5: Gain slider */
Control {
    enabled,
    1001
},
{100,60,125,200},	/* 6: Shutter/Exposure slider */
Control {
    enabled,
    1002
},
{190,0,215,200},	/* 7: Resolution popup menu */
Control {
    enabled,
    1003
},
{215,0,240,200},	/* 8: fps popup menu */
Control {
    enabled,
    1004
},
{125,60,150,200},	/* 9: compression slider */
Control {
    enabled,
    1005
},
{250,60,270,200},	/* 10: save prefs button */
Button {
    enabled,
    "Save as defaults"
},
{165,0,190,200},	/* 11: White Balance popup menu */
Control {
    enabled,
    1006
},
{50,0,75,60},		/* 12: Gamma label static text */
StaticText {
    enabled,
    "Gamma:"
},
{75,0,100,60},		/* 13: Gain label static text */
StaticText {
    enabled,
    "Gain:"
},
{100,0,125,60},		/* 14: Shutter label static text */
StaticText {
    enabled,
    "Shutter:"
},
{125,0,150,60},		/* 15: Compress label static text */
StaticText {
    enabled,
    "Compress:"
},
}};

resource 'CNTL' (1000) {
{0,0,20,200},
    500,
    visible,
    1000,
    0,
    kControlSliderProc,
    0,
    "Gamma"
};

resource 'CNTL' (1001) {
{0,0,20,200},
    500,
    visible,
    1000,
    0,
    kControlSliderProc,
    0,
    "Gain"
};

resource 'CNTL' (1002) {
{0,0,20,200},
    500,
    visible,
    1000,
    0,
    kControlSliderProc,
    0,
    "Shutter"
};

resource 'CNTL' (1003) {
{0,0,20,200},
    0,
    visible,
    60,
    1003,
    kControlPopupButtonProc+kControlPopupFixedWidthVariant,
    0,
    "Format:"
};

resource 'CNTL' (1004) {
{0,0,20,200},
    0,
    visible,
    60,
    1004,
    kControlPopupButtonProc+kControlPopupFixedWidthVariant,
    0,
    "Fps:"
};

resource 'CNTL' (1005) {
{0,0,40,200},
    0,
    visible,
    2,
    0,
    kControlSliderProc+kControlSliderHasTickMarks,
    0,
    "Compress"
};

resource 'CNTL' (1006) {
{0,0,20,200},
    0,
    visible,
    60,
    1006,
    kControlPopupButtonProc+kControlPopupFixedWidthVariant,
    0,
    "WB:"
};

resource 'MENU' (1003) {
    1003,
    textMenuProc,
    allEnabled,enabled,
    "Resolution",
{
    "SQSIF (128 x 96)",noIcon,noKey,noMark,plain,
    "QSIF (160 x 120)",noIcon,noKey,noMark,plain,
    "QCIF (176 x 144)",noIcon,noKey,noMark,plain,
    "SIF (320 x 240)",noIcon,noKey,noMark,plain,
    "CIF (352 x 288)",noIcon,noKey,noMark,plain,
    "VGA (640 x 480)",noIcon,noKey,noMark,plain,
}
};

resource 'MENU' (1004) {
    1004,
    textMenuProc,
    allEnabled,enabled,
    "Framerate",
{
    "5",noIcon,noKey,noMark,plain,
    "10",noIcon,noKey,noMark,plain,
    "15",noIcon,noKey,noMark,plain,
    "20",noIcon,noKey,noMark,plain,
    "25",noIcon,noKey,noMark,plain,
    "30",noIcon,noKey,noMark,plain,
}
};

resource 'MENU' (1006) {
    1006,
    textMenuProc,
    allEnabled,enabled,
    "White Balance",
{
    "Linear",noIcon,noKey,noMark,plain,
    "Indoor",noIcon,noKey,noMark,plain,
    "Outdoor",noIcon,noKey,noMark,plain,
    "Automatic",noIcon,noKey,noMark,plain,
}
};