//
//  Extension.swift
//
//
//  Created by Jeet on 25/09/24.
//

import Foundation

extension Data {
    public var prettyPrintedJSONString: String? {
#if DEBUG
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = String(data: data, encoding: .utf8) else { return nil }
        return prettyPrintedString
#else
        return nil
#endif
    }
}
