//
//  NokeDefines.swift
//  NokeMobileLibrary
//
//  Created by Spencer Apsley on 1/15/18.
//  Copyright © 2018 Noke. All rights reserved.
//

import UIKit

//Error codes for API, Go Library, and Noke Device
public enum NokeDeviceManagerError : Int {
    
    //Noke API Error
    case nokeAPIErrorInternalServer         = 1
    case nokeAPIErrorAPIKey                 = 2
    case nokeAPIErrorInput                  = 3
    case nokeAPIErrorRequestMethod          = 4
    case nokeAPIErrorInvalidEndpoint        = 5
    case nokeAPIErrorCompanyNotFound        = 6
    case nokeAPIErrorLockNotFound           = 7
    case nokeAPIErrorUnknown                = 99
    
    //GO Library Error
    case nokeGoUnlockError                  = 100
    case nokeGoUploadError                  = 101
    
    //Noke Device Errors (200 + error code)
    case nokeDeviceSuccessResult            = 260 //(200 + 60) SUCCESS_ResultType = 0x60
    case nokeDeviceErrorInvalidKey          = 261 //(200 + 61) INVALIDKEY_ResultType = 0x61
    case nokeDeviceErrorInvalidCmd          = 262 //(200 + 62) INVALIDCMD_ResultType = 0x62
    case nokeDeviceErrorInvalidPermission   = 263 //(200 + 63) INVALIDPERMISSION_ResultType = 0x63
    case nokeDeviceShutdownResult           = 264 //(200 + 64) SHUTDOWN_ResultType = 0x64
    case nokeDeviceErrorInvalidData         = 265 //(200 + 65) INVALIDDATA_ResultType = 0x65
    case nokeDeviceBatteryDataResult        = 266 //(200 + 66) BATTERYDATA_ResultType = 0x66
    case nokeDeviceErrorInvalidResult       = 267 //(200 + FF) INVALID_ResultType = 0xFF
    case nokeDeviceErrorUnknown             = 268
    
    //Noke Mobile Library Errors
    case nokeLibraryErrorInvalidOfflineKey  = 301
    case nokeLibraryErrorNoModeSet          = 302
    case nokeLibraryConnectionTimeout       = 317
}

public enum NokeLibraryMode : Int {
    case SANDBOX      = 0;
    case PRODUCTION   = 1;
    case DEVELOP      = 2;
    case OPEN         = 3;
    case CUSTOM       = 4;
}


//Defines used when interacting with the lock
public struct Constants {
    
    static let NOKE_DEVICE_IDENTIFIER_STRING = "NOKE"
    
    static let NOKE_HW_TYPE_1ST_GEN_PADLOCK         = "2P";
    static let NOKE_HW_TYPE_2ND_GEN_PADLOCK         = "3P";
    static let NOKE_HW_TYPE_ULOCK                   = "2U";
    static let NOKE_HW_TYPE_HD_LOCK                 = "I";
    static let NOKE_HW_TYPE_DOOR_CONTROLLER         = "2E";
    static let NOKE_HW_TYPE_PB12                    = "1C";
    
    //KEY LENGTHS
    static let AESKEYLEN =      16
    static let KEYLEN =         12
    static let CKLEN =          16
    
    //DESTINATIONS
    static let SERVER_Dest =    0x50
    static let APP_Dest =       0x51
    static let LOCK_Dest =      0x52
    
    //SERVER TYPES
    static let Key_ServerType = 0x74
    static let Unlock_ServerType = 0x75
    static let Log_ServerType = 0x76
    static let QC_ServerType = 0x77
    static let Radio_ServerType = 0x78
    static let Sleep_ServerType = 0x79
    static let LongPress_ServerType = 0x7A
    static let QcLockout_ServerType = 0x7B
    static let Reset_ServerType = 0x7C
    static let EnableLimitedKeys_ServerType = 0x7D
    
    //KEY TYPES
    static let BASE_KeyType = 0
    static let MCK_KeyType = 2
    static let LCK_KeyType = 4
    static let QCK_KeyType = 10
    //EOF KEY TYPES
    
    static let PACKETSIZE = 20
    static let STARTBYTE = 0x7E
    
    //RESPONSE TYPES
    static let SERVER_ResponseType = 0x50
    static let APP_ResponseType = 0x51
    static let INVALID_ResponseType = 0xff
    
    //LOCKAPPRESPONSE use by the app to confirm command succeeded
    //RESULT TYPES
    static let SUCCESS_ResultType = 0x60
    static let INVALIDKEY_ResultType = 0x61
    static let INVALIDCMD_ResultType = 0x62
    static let INVALIDPERMISSION_ResultType = 0x63
    static let SHUTDOWN_ResultType = 0x64
    static let INVALIDDATA_ResultType = 0x65
    static let BATTERYDATA_ResultType = 0x66
    static let FAILEDTOLOCK_ResultType = 0x68
    static let FAILEDTOUNLOCK_ResultType = 0x69
    static let FAILEDTOUNSHACKLE_ResultType = 0x6A
    static let INVALID_ResultType = 0xFF
    
    //COMMUNICATION PACKET TYPES
    //AppDataPacket Main structure for all commands from the app
    //CmdTypes
    static let SHUTDOWN_PK =            0xA0
    static let SETUP_PK =               0xA1
    static let UNLOCK_PK =              0xA2
    static let REMOVELIMITEDKEY_PK =    0xA3
    static let ENABLELIMITEDKEY_PK =    0xA4
    static let GETLOGS_PK =             0xA5
    static let SETQC_PK =               0xA6
    static let GETQC_PK =               0xA7
    static let SETQCLOCKOUT_PK =        0xA8
    static let RESET_PK =               0xA9
    static let GETBATTERY_PK =          0xAA
    static let FIRMWAREUPDATE_PK =      0xAB
    static let TEST_PK =                0xAC
    static let SETRADIOTX_PK =          0xAD
    static let SETTIMEOUT_PK =          0xAE
    static let SETLONGPRESSTIME_PK =    0xAF
    static let SETKEY_PK =              0xB0
    static let INVALID_PK =             0xFF
    static let CLEARQC_PK =             0xB1
    //EOF CmdTypes
    
    //Fob CmdTypes
    static let SETUPFOB_PK =       0xC0
    static let ADDLOCK_PK =        0xC1
    static let CLEARLOCKS_PK =     0xC2
    static let REMOVELOCK_PK =     0xC3
    
    static let ADDLOCKPART1_PK =   0xC4
    static let ADDLOCKPART2_PK =   0xC5
    
    //Response Types, Type slot in lock to app packet
    static let LOCKEDPACKET =       0xE0
    static let DATAPACKET =         0xD0
    static let SUCCESSPACKET =      0xD1
    static let ERRORPACKET =        0xD2
    
    //QuickClick Types
    static let QCFULL =             0xFF
    static let QCONETIME =          0x01
    static let QCDISABLED =         0x00
    
    //Offline Key Types
    public static let OFFLINE_KEY_LENGTH =  32
    public static let OFFLINE_COMMAND_LENGTH = 40
}

struct ApiURL {
    static let sandboxUploadURL         = "https://coreapi-sandbox.appspot.com/"
    static let productionUploadURL      = "https://coreapi-beta.appspot.com/"
    static let developUploadURL         = "https://lock-api-dev.appspot.com/"
    static let openString               = "OPEN"
}


