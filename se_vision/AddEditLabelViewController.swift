//
//  AddEditLabelViewController.swift
//  Daykho
//
//  Created by Adarsh Hasija on 30/01/19.
//  Copyright © 2019 Adarsh Hasija. All rights reserved.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseDatabase

class AddEditLabelViewController : UIViewController {
    
    var ref: DatabaseReference!
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var addButton: UIButton!
    
    
    @IBAction func addTapped(_ sender: Any) {
        submitLabel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ref = Database.database().reference()
        textField.addTarget(self, action: #selector(enterPressed), for: .editingDidEndOnExit)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        textField.becomeFirstResponder()
    }
    
    @objc func enterPressed(){
        //do something with typed text if needed
        textField.resignFirstResponder()
        submitLabel()
    }
    
    private func submitLabel() {
        guard let user = Auth.auth().currentUser else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        guard let key = ref.child("labels").childByAutoId().key else {
            self.navigationController?.popViewController(animated: true)
            return
        }
        
        ref.child("labels").child(key).updateChildValues(["text": textField.text, "userId": user.uid])
        self.navigationController?.popViewController(animated: true)
        
    }
    
    
}
