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
import FirebaseUI
import FirebaseDatabase

public class ShortcutsTableViewController: UITableViewController {
    
    // Properties
    var authUI : FUIAuth?
    var handle : AuthStateDidChangeListenerHandle?
    var ref: DatabaseReference!
    
    var shortcuts : [ShortcutListItem] = []
    var selectedIndex : Int = -1
    
    var defaultLabels : [String] = []
    var userLabels : [String] = []
    
    @IBOutlet weak var logoutButton: UIBarButtonItem!
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    @IBAction func logoutTapped(_ sender: Any) {
        for index in stride(from: self.shortcuts.count-1, through: 0, by: -1) {
            let shortcutItem = self.shortcuts[index]
            guard let firebaseUid =  shortcutItem.firebaseUid else {
                continue
            }
            self.shortcuts.remove(at: index)
        }
        self.tableView.reloadData()

        try! authUI?.signOut()
    }
    @IBAction func addTapped(_ sender: Any) {
        performSegue(withIdentifier: "segueAdd", sender: nil)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Daykho"
        defaultLabels.removeAll()
        userLabels.removeAll()
        
        authUI = FUIAuth.defaultAuthUI()
        // You need to adopt a FUIAuthDelegate protocol to receive callback
        authUI?.delegate = self
        
        ref = Database.database().reference()
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "What is around me?",
            messageOnOpen: "Hold you camera up and move it around you",
            activityType: "",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: false,
            textForYesNo: nil
            )
        )
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "What is the sign on this door?",
            messageOnOpen: "Point your camera at the sign. Sign should be in English",
            activityType: "com.starsearth.four.tellSignIntent",
            isUsingFirebase: true,
            isTextDetection: true,
            isLabelDetection: false,
            isYesNo: false,
            textForYesNo: nil
            )
        )
        
        appendLabel(shortcutListItem: ShortcutListItem(
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
        
        appendLabel(shortcutListItem: ShortcutListItem(
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
        
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "I am looking for a computer",
            messageOnOpen: "Point your camera in front of you",
            activityType: "",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "computer"
            )
        )
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "I am looking for a chair",
            messageOnOpen: "Point your camera in front of you",
            activityType: "",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "chair"
            )
        )
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "I am looking for a table",
            messageOnOpen: "Point your camera in front of you",
            activityType: "",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "tableware"
            )
        )
        
        appendLabel(shortcutListItem: ShortcutListItem(
            question: "I am looking for a television",
            messageOnOpen: "Point your camera in front of you",
            activityType: "",
            isUsingFirebase: true,
            isTextDetection: false,
            isLabelDetection: true,
            isYesNo: true,
            textForYesNo: "television"
            )
        )
        
        
        guard let currentUser = Auth.auth().currentUser else {
            logoutButton?.isEnabled = false
            logoutButton?.tintColor = UIColor.clear
            addButton?.isEnabled = false
            addButton?.tintColor = UIColor.clear
            let authViewController = authUI?.authViewController()
            present(authViewController!, animated: true, completion: nil)
            return
        }
        
        let labelsRef = ref.child("labels").queryOrdered(byChild: "userId").queryEqual(toValue : currentUser.uid)
        labelsRef.observe(.childAdded, with: { (snapshot) -> Void in
            let shortcutListItem = ShortcutListItem(dictionary: snapshot.value as! NSDictionary)
            shortcutListItem.setUid(uid: snapshot.key)
            if !self.defaultLabels.contains(shortcutListItem.textForYesNo) {
                self.shortcuts.append(shortcutListItem)
                self.userLabels.append(shortcutListItem.textForYesNo)
                self.tableView.insertRows(at: [IndexPath(row: self.shortcuts.count-1, section: 0)], with: UITableView.RowAnimation.automatic)
            }
            else {
                guard let firebaseUid = shortcutListItem.firebaseUid else {
                    return
                }
                
                //If it does not exist in our default labels, delete it
                let refForDelete = self.ref.child("labels").child(firebaseUid)
                refForDelete.removeValue()
            }
            
        })
        
        //This means user is valid
        logoutButton?.isEnabled = true
        logoutButton?.tintColor = nil
        addButton?.isEnabled = true
        addButton?.tintColor = nil
        
        
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener { (auth, user) in
            if user != nil {
                self.logoutButton?.isEnabled = true
                self.logoutButton?.tintColor = nil
                self.addButton?.isEnabled = true
                self.addButton?.tintColor = nil
            }
            else {
                self.logoutButton?.isEnabled = false
                self.logoutButton?.tintColor = UIColor.clear
                self.addButton?.isEnabled = false
                self.addButton?.tintColor = UIColor.clear
                
                //Show login controller again
                let authViewController = self.authUI?.authViewController()
                self.present(authViewController!, animated: true, completion: nil)
            }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        Auth.auth().removeStateDidChangeListener(handle!)
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
    
    public override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return self.shortcuts[indexPath.row].canUserDelete
    }
    
    public override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            guard let shortcutListItem : ShortcutListItem = self.shortcuts[indexPath.row] else {
                return
            }
            
            guard let firebaseUid = shortcutListItem.firebaseUid else {
                return
            }
            
            ref.child("labels").child(firebaseUid).removeValue()
            self.shortcuts.remove(at: indexPath.row)
            self.tableView.reloadData()
            
            guard let textForYesNo : String = shortcutListItem.textForYesNo else {
                return
            }
            
            let indexInUserLabels = userLabels.firstIndex(of: textForYesNo)
            if indexInUserLabels != nil {
                userLabels.remove(at: indexInUserLabels!)
            }
            
            
        }
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
        else if segue.destination is AddEditLabelViewController {
            var allItemsArray : [String] = []
            allItemsArray.append(contentsOf: defaultLabels)
            allItemsArray.append(contentsOf: userLabels)
            
            let vc = segue.destination as? AddEditLabelViewController
            vc?.labelsAlreadyPresent = allItemsArray
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
    
    private func appendLabel(shortcutListItem : ShortcutListItem) {
        shortcuts.append(shortcutListItem)
        defaultLabels.append(shortcutListItem.textForYesNo)
    }
    
}

extension ShortcutsTableViewController : FUIAuthDelegate {
    public func authUI(_ authUI: FUIAuth, didSignInWith authDataResult: AuthDataResult?, error: Error?) {
        guard let user = authDataResult?.user else {
            logoutButton?.isEnabled = false
            logoutButton?.tintColor = UIColor.clear
            addButton?.isEnabled = false
            addButton?.tintColor = UIColor.clear
            return
        }
        
        logoutButton?.isEnabled = true
        logoutButton?.tintColor = nil
        addButton?.isEnabled = true
        addButton?.tintColor = nil
        
        ref.child("users").child(user.uid).updateChildValues(["se_four": true])
        
        let labelsRef = ref.child("labels").queryOrdered(byChild: "userId").queryEqual(toValue : user.uid)
        labelsRef.observe(.childAdded, with: { (snapshot) -> Void in
            let shortcutListItem = ShortcutListItem(dictionary: snapshot.value as! NSDictionary)
            shortcutListItem.setUid(uid: snapshot.key)
            self.shortcuts.append(shortcutListItem)
            self.tableView.insertRows(at: [IndexPath(row: self.shortcuts.count-1, section: 0)], with: UITableView.RowAnimation.automatic)
        })
        // Listen for deleted comments in the Firebase database
        labelsRef.observe(.childRemoved, with: { (snapshot) -> Void in
          /*  let index = self.indexOfMessage(snapshot)
            self.comments.remove(at: index)
            self.tableView.deleteRows(at: [IndexPath(row: index, section: self.kSectionComments)], with: UITableViewRowAnimation.automatic) */
        })
    }
}
