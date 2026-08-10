//
//  FileManager+Directories.swift
//  Vendor
//
//  `URL.documentsDirectory` and its siblings are iOS 16+ only. These give the
//  same result back to iOS 15, which is Vendor's floor.
//

import Foundation

extension FileManager {
	var documentsDirectory: URL { urls(for: .documentDirectory, in: .userDomainMask)[0] }
	var applicationSupportDirectory: URL { urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
	var cachesDirectory: URL { urls(for: .cachesDirectory, in: .userDomainMask)[0] }
}
