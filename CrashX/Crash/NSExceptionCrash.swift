//
//  NSExceptionCrash.swift
//  用于捕获OC的NSException导致的异常崩溃

import UIKit

func registerUncaughtExceptionHandler()
{
    NSSetUncaughtExceptionHandler(UncaughtExceptionHandler)
}

func UncaughtExceptionHandler(exception: NSException) {
    let arr = exception.callStackSymbols
    let reason = exception.reason
    let name = exception.name.rawValue
    var crash = String()
    crash += UIDevice.current.descriptions
    crash += "Stack:\n"
    crash = crash.appendingFormat("slideAdress:0x%0x\r\n", calculate())
    crash += "\r\n\r\n name:\(name) \r\n reason:\(String(describing: reason)) \r\n \(arr.joined(separator: "\r\n")) \r\n\r\n"

    CrashManager.saveCrash(appendPathStr: .nsExceptionCrashPath, exceptionInfo: crash)
}

