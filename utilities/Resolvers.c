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

#include "Resolvers.h"
#include <CoreServices/CoreServices.h>


bool ErrorName (IOReturn err, char* out_buf) {
    bool ok=true;
    switch (err) {
        case 0: sprintf(out_buf,"ok"); break; 	
        case kIOReturnError: sprintf(out_buf,"kIOReturnError - general error"); break; 	
        case kIOReturnNoMemory: sprintf(out_buf,"kIOReturnNoMemory - can't allocate memory");  break;
        case kIOReturnNoResources: sprintf(out_buf,"kIOReturnNoResources - resource shortage"); break;
        case kIOReturnIPCError: sprintf(out_buf,"kIOReturnIPCError - error during IPC"); break;
        case kIOReturnNoDevice: sprintf(out_buf,"kIOReturnNoDevice - no such device"); break;
        case kIOReturnNotPrivileged: sprintf(out_buf,"kIOReturnNotPrivileged - privilege violation"); break;
        case kIOReturnBadArgument: sprintf(out_buf,"kIOReturnBadArgument - invalid argument"); break;
        case kIOReturnLockedRead: sprintf(out_buf,"kIOReturnLockedRead - device read locked"); break;
        case kIOReturnLockedWrite: sprintf(out_buf,"kIOReturnLockedWrite - device write locked"); break;
        case kIOReturnExclusiveAccess: sprintf(out_buf,"kIOReturnExclusiveAccess - exclusive access and device already open"); break;
        case kIOReturnBadMessageID: sprintf(out_buf,"kIOReturnBadMessageID - sent/received messages had different msg_id"); break;
        case kIOReturnUnsupported: sprintf(out_buf,"kIOReturnUnsupported - unsupported function"); break;
        case kIOReturnVMError: sprintf(out_buf,"kIOReturnVMError - misc. VM failure"); break;
        case kIOReturnInternalError: sprintf(out_buf,"kIOReturnInternalError - internal error"); break;
        case kIOReturnIOError: sprintf(out_buf,"kIOReturnIOError - General I/O error"); break;
        case kIOReturnCannotLock: sprintf(out_buf,"kIOReturnCannotLock - can't acquire lock"); break;
        case kIOReturnNotOpen: sprintf(out_buf,"kIOReturnNotOpen - device not open"); break;
        case kIOReturnNotReadable: sprintf(out_buf,"kIOReturnNotReadable - read not supported"); break;
        case kIOReturnNotWritable: sprintf(out_buf,"kIOReturnNotWritable - write not supported"); break;
        case kIOReturnNotAligned: sprintf(out_buf,"kIOReturnNotAligned - alignment error"); break;
        case kIOReturnBadMedia: sprintf(out_buf,"kIOReturnBadMedia - Media Error"); break;
        case kIOReturnStillOpen: sprintf(out_buf,"kIOReturnStillOpen - device(s) still open"); break;
        case kIOReturnRLDError: sprintf(out_buf,"kIOReturnRLDError - rld failure"); break;
        case kIOReturnDMAError: sprintf(out_buf,"kIOReturnDMAError - DMA failure"); break;
        case kIOReturnBusy: sprintf(out_buf,"kIOReturnBusy - Device Busy"); break;
        case kIOReturnTimeout: sprintf(out_buf,"kIOReturnTimeout - I/O Timeout"); break;
        case kIOReturnOffline: sprintf(out_buf,"kIOReturnOffline - device offline"); break;
        case kIOReturnNotReady: sprintf(out_buf,"kIOReturnNotReady - not ready"); break;
        case kIOReturnNotAttached: sprintf(out_buf,"kIOReturnNotAttached - device not attached"); break;
        case kIOReturnNoChannels: sprintf(out_buf,"kIOReturnNoChannels - no DMA channels left"); break;
        case kIOReturnNoSpace: sprintf(out_buf,"kIOReturnNoSpace - no space for data"); break;
        case kIOReturnPortExists: sprintf(out_buf,"kIOReturnPortExists - port already exists"); break;
        case kIOReturnCannotWire: sprintf(out_buf,"kIOReturnCannotWire - can't wire down physical memory"); break;
        case kIOReturnNoInterrupt: sprintf(out_buf,"kIOReturnNoInterrupt - no interrupt attached"); break;
        case kIOReturnNoFrames: sprintf(out_buf,"kIOReturnNoFrames - no DMA frames enqueued"); break;
        case kIOReturnMessageTooLarge: sprintf(out_buf,"kIOReturnMessageTooLarge - oversized msg received on interrupt port"); break;
        case kIOReturnNotPermitted: sprintf(out_buf,"kIOReturnNotPermitted - not permitted"); break;
        case kIOReturnNoPower: sprintf(out_buf,"kIOReturnNoPower - no power to device"); break;
        case kIOReturnNoMedia: sprintf(out_buf,"kIOReturnNoMedia - media not present"); break;
        case kIOReturnUnformattedMedia: sprintf(out_buf,"kIOReturnUnformattedMedia - media not formatted"); break;
        case kIOReturnUnsupportedMode: sprintf(out_buf,"kIOReturnUnsupportedMode - no such mode"); break;
        case kIOReturnUnderrun: sprintf(out_buf,"kIOReturnUnderrun - data underrun"); break;
        case kIOReturnOverrun: sprintf(out_buf,"kIOReturnOverrun - data overrun"); break;
        case kIOReturnDeviceError: sprintf(out_buf,"kIOReturnDeviceError - the device is not working properly!"); break;
        case kIOReturnNoCompletion: sprintf(out_buf,"kIOReturnNoCompletion - a completion routine is required"); break;
        case kIOReturnAborted: sprintf(out_buf,"kIOReturnAborted - operation aborted"); break;
        case kIOReturnNoBandwidth: sprintf(out_buf,"kIOReturnNoBandwidth - bus bandwidth would be exceeded"); break;
        case kIOReturnNotResponding: sprintf(out_buf,"kIOReturnNotResponding - device not responding"); break;
        case kIOReturnIsoTooOld: sprintf(out_buf,"kIOReturnIsoTooOld - isochronous I/O request for distant past!"); break;
        case kIOReturnIsoTooNew: sprintf(out_buf,"kIOReturnIsoTooNew - isochronous I/O request for distant future"); break;
        case kIOReturnNotFound: sprintf(out_buf,"kIOReturnNotFound - data was not found"); break;
        case kIOReturnInvalid: sprintf(out_buf,"kIOReturnInvalid - should never be seen"); break;
        case kIOUSBUnknownPipeErr:sprintf(out_buf,"kIOUSBUnknownPipeErr - Pipe ref not recognised"); break;
        case kIOUSBTooManyPipesErr:sprintf(out_buf,"kIOUSBTooManyPipesErr - Too many pipes"); break;
        case kIOUSBNoAsyncPortErr:sprintf(out_buf,"kIOUSBNoAsyncPortErr - no async port"); break;
        case kIOUSBNotEnoughPipesErr:sprintf(out_buf,"kIOUSBNotEnoughPipesErr - not enough pipes in interface"); break;
        case kIOUSBNotEnoughPowerErr:sprintf(out_buf,"kIOUSBNotEnoughPowerErr - not enough power for selected configuration"); break;
        case kIOUSBEndpointNotFound:sprintf(out_buf,"kIOUSBEndpointNotFound - Not found"); break;
        case kIOUSBConfigNotFound:sprintf(out_buf,"kIOUSBConfigNotFound - Not found"); break;
        case kIOUSBTransactionTimeout:sprintf(out_buf,"kIOUSBTransactionTimeout - time out"); break;
        case kIOUSBTransactionReturned:sprintf(out_buf,"kIOUSBTransactionReturned - The transaction has been returned to the caller"); break;
        case kIOUSBPipeStalled:sprintf(out_buf,"kIOUSBPipeStalled - Pipe has stalled, error needs to be cleared"); break;
        case kIOUSBInterfaceNotFound:sprintf(out_buf,"kIOUSBInterfaceNotFound - Interface ref not recognised"); break;
        case kIOUSBLinkErr:sprintf(out_buf,"kIOUSBLinkErr - <no error description available>"); break;
        case kIOUSBNotSent2Err:sprintf(out_buf,"kIOUSBNotSent2Err - Transaction not sent"); break;
        case kIOUSBNotSent1Err:sprintf(out_buf,"kIOUSBNotSent1Err - Transaction not sent"); break;
        case kIOUSBBufferUnderrunErr:sprintf(out_buf,"kIOUSBBufferUnderrunErr - Buffer Underrun (Host hardware failure on data out, PCI busy?)"); break;
        case kIOUSBBufferOverrunErr:sprintf(out_buf,"kIOUSBBufferOverrunErr - Buffer Overrun (Host hardware failure on data out, PCI busy?)"); break;
        case kIOUSBReserved2Err:sprintf(out_buf,"kIOUSBReserved2Err - Reserved"); break;
        case kIOUSBReserved1Err:sprintf(out_buf,"kIOUSBReserved1Err - Reserved"); break;
        case kIOUSBWrongPIDErr:sprintf(out_buf,"kIOUSBWrongPIDErr - Pipe stall, Bad or wrong PID"); break;
        case kIOUSBPIDCheckErr:sprintf(out_buf,"kIOUSBPIDCheckErr - Pipe stall, PID CRC Err:or"); break;
        case kIOUSBDataToggleErr:sprintf(out_buf,"kIOUSBDataToggleErr - Pipe stall, Bad data toggle"); break;
        case kIOUSBBitstufErr:sprintf(out_buf,"kIOUSBBitstufErr - Pipe stall, bitstuffing"); break;
        case kIOUSBCRCErr:sprintf(out_buf,"kIOUSBCRCErr - Pipe stall, bad CRC"); break;
        
        default: sprintf(out_buf,"Unknown Error:%d Sub:%d System:%d",err_get_code(err),
                err_get_sub(err),err_get_system(err)); ok=false; break;
    }
    return ok;
}

void ShowError(IOReturn err, char* where) {
    char buf[256];
    if (where) {
        printf("%s: ", where);
    }
    if (err==0) {
        printf("ok");
    } else {
        printf("Error: %x ", err);
        ErrorName(err,buf);
        printf("%s", buf);
    }
    printf("\n");
}

void CheckError(IOReturn err, char* where) {
    if (err) {
        ShowError(err,where);
    }
}

bool ResolveVDSelector(short sel, char* str) {
    switch (sel) {
        case kComponentRegisterSelect:sprintf(str,"kComponentRegisterSelect"); break;
        case kComponentOpenSelect:sprintf(str,"kComponentOpenSelect"); break;
        case kComponentCloseSelect:sprintf(str,"kComponentCloseSelect"); break;
        case kComponentCanDoSelect:sprintf(str,"kComponentCanDoSelect"); break;
        case kComponentVersionSelect:sprintf(str,"kComponentVersionSelect"); break;
            
        default: sprintf(str,"unknown component function selector: %d",sel); return false; break;
    }
    return true;
}

void PrintVDSelector(short sel) {
    char name[300];
    ResolveVDSelector(sel,name);
    printf("%s\n",name);
}

