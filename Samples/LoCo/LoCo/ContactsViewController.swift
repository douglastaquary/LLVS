//
//  ContactsViewController.swift
//  LoCo
//
//  Created by Drew McCormack on 17/01/2019.
//  Copyright © 2019 The Mental Faculty B.V. All rights reserved.
//

import UIKit

class ContactsViewController: UITableViewController {
    
    var contactBook: ContactBook!
    var contactViewController: ContactViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addContact(_:)))
        navigationItem.rightBarButtonItem = addButton
        
        if let split = splitViewController {
            let controllers = split.viewControllers
            let navController = controllers.last as! UINavigationController
            contactViewController = navController.topViewController as? ContactViewController
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    @objc func addContact(_ sender: Any) {
        let contact = Contact()
        try! contactBook.add(contact)
        let indexPath = IndexPath(row: contactBook.contacts.count-1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showContact" {
            if let indexPath = tableView.indexPathForSelectedRow {
                contactViewController.showContact(at: indexPath.row, in: contactBook)
                contactViewController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                contactViewController.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactBook.contacts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let contact = contactBook.contacts[indexPath.row]
        cell.textLabel!.text = "\(contact.value)"
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let contact = contactBook.contacts[indexPath.row].value
            try! contactBook.delete(contact)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }


}

