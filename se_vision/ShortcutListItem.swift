//
//  ShortcutListItem.swift
//  Daykho
//
//  Created by Adarsh Hasija on 01/01/19.
//  Copyright © 2019 Adarsh Hasija. All rights reserved.
//

import Foundation

class ShortcutListItem {
    var question: String
    var messageOnOpen: String  //Message that app tells a blind person when the camera screen is opened
    var activityType: String
    var isUsingFirebase: Bool
    var isTextDetection: Bool
    var isLabelDetection: Bool
    var isYesNo: Bool
    var textForYesNo: String  //If it is a yes/no question, text to check for. If text to check for is empty, we will say yes for any text
    var dictionary: [String: Any] {
        return ["question": question,
                "messageOnOpen": messageOnOpen,
                "activityType": activityType,
                "isUsingFirebase": isUsingFirebase,
                "isTextDetection": isTextDetection,
                "isLabelDetection": isLabelDetection,
                "isYesNo": isYesNo,
                "textForYesNo": textForYesNo
        ]
    }
    var nsDictionary: NSDictionary {
        return dictionary as NSDictionary
    }
    
    init(question: String, messageOnOpen: String, activityType: String, isUsingFirebase: Bool, isTextDetection: Bool, isLabelDetection: Bool, isYesNo: Bool, textForYesNo: String?) {
        self.question = question
        self.messageOnOpen = messageOnOpen
        self.activityType = activityType
        self.isUsingFirebase = isUsingFirebase
        self.isTextDetection = isTextDetection
        self.isLabelDetection = isLabelDetection
        self.isYesNo = isYesNo
        self.textForYesNo = textForYesNo ?? ""
    }
    
    init(dictionary: NSDictionary) {
        self.question = dictionary["question"] as? String ?? ""
        self.messageOnOpen = dictionary["messageOnOpen"] as? String ?? ""
        self.activityType = dictionary["activityType"] as? String ?? ""
        self.isUsingFirebase = dictionary["isUsingFirebase"] as? Bool ?? false
        self.isTextDetection = dictionary["isTextDetection"] as? Bool ?? false
        self.isLabelDetection = dictionary["isLabelDetection"] as? Bool ?? false
        self.isYesNo = dictionary["isYesNo"] as? Bool ?? false
        self.textForYesNo = dictionary["textForYesNo"] as? String ?? ""
    }
}
