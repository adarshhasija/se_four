//
//  File.swift
//  Suno
//
//  Created by Adarsh Hasija on 22/09/18.
//  Copyright © 2018 Adam Behringer. All rights reserved.
//

import Foundation
import UIKit
import FirebaseAnalytics
import FirebaseAuth

public class ShortcutsTableViewController: UITableViewController {
    
    // Properties
    var shortcuts : [ShortcutListItem] = []
    var selectedIndex : Int = -1
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Daykho"
        
        shortcuts.append(ShortcutListItem(
            question: "What does this sign say?",
            messageOnOpen: "Point your camera at the sign. Sign should be in English",
            activityType: "com.starsearth.four.tellSignIntent",
            isUsingFirebase: true,
            isTextDetection: true,
            isLabelDetection: false,
            isYesNo: false,
            textForYesNo: nil
            )
        )
        
        shortcuts.append(ShortcutListItem(
            question: "Is there a car in front of me?",
            messageOnOpen: "Point your camera in front of you",
            activityType: "com.starsearth.four.isThereACarIntent",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "car"
            )
        )
        
        shortcuts.append(ShortcutListItem(
            question: "What is the number of this car?",
            messageOnOpen: "Point your camera at the license plate",
            activityType: "com.starsearth.four.tellLicensePlateIntent",
            isUsingFirebase: true,
            isTextDetection: true,
            isLabelDetection: false,
            isYesNo: false,
            textForYesNo: nil
            )
        )
        
        shortcuts.append(ShortcutListItem(
            question: "Is there a computer in front of me?",
            messageOnOpen: "Point your camera in front of you",
            activityType: "com.starsearth.four.isThereAComputerIntent",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "computer"
            )
        )
        
        shortcuts.append(ShortcutListItem(
            question: "Are there stairs in front of me?",
            messageOnOpen: "Point your camera in front of you",
            activityType: "com.starsearth.four.areThereStairsIntent",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "stairs"
            )
        )
        
   /*     shortcuts.append(ShortcutListItem(
            question: "What is this object?",
            messageOnOpen: "Point your camera in front of you",
            activityType: "com.starsearth.four.areThereStairsIntent",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: false,
            textForYesNo: nil
            )
        )   */
        
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        guard let currentUser = Auth.auth().currentUser else {
            performSegue(withIdentifier: "segueAuth", sender: nil)
            return
        }
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.shortcuts.count
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // create a new cell if needed or reuse an old one
        let cell:ShortcutsTableViewCell = self.tableView.dequeueReusableCell(withIdentifier: "shortcutCell") as! ShortcutsTableViewCell
        
        // set the text from the data model
        cell.questionLabel?.text = self.shortcuts[indexPath.row].question
        
        return cell
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        performSegue(withIdentifier: "segueShowDetailVision", sender: nil)
    }
    
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is VisionMLViewController {
            Analytics.logEvent("se4_shortcut_selected", parameters: [
                "os_version": UIDevice.current.systemVersion,
                "device_type": getDeviceType(),
                "interface": "table",
                "question": shortcuts[selectedIndex].question.prefix(100)
                ])
            let vc = segue.destination as? VisionMLViewController
            if shortcuts[selectedIndex].activityType != vc?.shortcutListItem.activityType {
                //If it is not the same as the copy already in the vc, add it
                vc?.shortcutListItem = shortcuts[selectedIndex]
            }
        }
    }
    
    func getDeviceType() -> String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .unspecified:
            return "unspecified"
        default:
            return "unknown"
        }
    }
}
