//
//  AuthSelectionController.swift
//  Daykho
//
//  Created by Adarsh Hasija on 28/01/19.
//  Copyright © 2019 Adarsh Hasija. All rights reserved.
//

import Foundation
import UIKit

class AuthSelectionController : UIViewController {
    
    
    @IBOutlet weak var signupButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    
    
    @IBAction func signupTapped(_ sender: Any) {
        performSegue(withIdentifier: "segueAuth", sender: nil)
    }
    
    
    @IBAction func loginTapped(_ sender: Any) {
        
    }
    
    override func viewDidLoad() {
        
    }
    
    override func didReceiveMemoryWarning() {
        
    }
}
