//
//  ViewController.swift
//  GeoBook
//
//  Created by Ranjan Akarsh on 05/08/22.
//

import UIKit
import CoreData

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    let cellIdentifier = "geo_cell"
    
    var arrayOfLocationNames = [String]()
    var arrayOfLocationIDs = [UUID]()
    
    var requestedLocationID: UUID? // empty means edit more, non empty means render saved location
    
    override func viewWillAppear(_ animated: Bool) {
        self.requestedLocationID = nil
        NotificationCenter.default.addObserver(self, selector: #selector(fetchFromDatabase), name: Notification.Name("newLocation"), object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellIdentifier)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.fetchFromDatabase()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellIdentifier, for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = self.arrayOfLocationNames[indexPath.row]
        cell.contentConfiguration = config
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.arrayOfLocationNames.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.requestedLocationID = self.arrayOfLocationIDs[indexPath.row]
        self.performSegue(withIdentifier: "toGeoBook", sender: nil)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
            let wrappedContext = delegate.persistentContainer.viewContext
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Geo")
            fetchRequest.predicate = NSPredicate(format: "id = %@", self.arrayOfLocationIDs[indexPath.row].uuidString)
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let results = try wrappedContext.fetch(fetchRequest)
                if results.count > 0 {
                    for result in results as! [NSManagedObject] {
                        if let id = result.value(forKey: "id") as? UUID {
                            if id == self.arrayOfLocationIDs[indexPath.row] {
                                wrappedContext.delete(result)
                                self.arrayOfLocationNames.remove(at: indexPath.row)
                                self.arrayOfLocationIDs.remove(at: indexPath.row)
                                
                                self.tableView.reloadData()
                                
                                // update the database
                                do {
                                    try wrappedContext.save()
                                } catch {
                                    print("error occurred while saving updated databse(deletion) - \(error)")
                                }
                                
                                break
                            }
                        }
                    }
                }
            } catch {
                print("error occurred while deletion - \(error)")
            }
        }
    }
    
    @IBAction func addButton(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "toGeoBook", sender: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toGeoBook" {
            let destination = segue.destination as! GeoViewController
            destination.requestedLocationID = self.requestedLocationID
        }
    }
    
    @objc func fetchFromDatabase() {
        // sanity check
        self.arrayOfLocationNames.removeAll(keepingCapacity: false)
        self.arrayOfLocationIDs.removeAll(keepingCapacity: false)
        
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let wrappedContex = delegate.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Geo")
        fetchRequest.returnsObjectsAsFaults = false
        do {
            let results = try wrappedContex.fetch(fetchRequest)
            for result in results as! [NSManagedObject] {
                if let locationName = result.value(forKey: "title") as? String {
                    self.arrayOfLocationNames.append(locationName)
                }
                
                if let locationID = result.value(forKey: "id") as? UUID {
                    self.arrayOfLocationIDs.append(locationID)
                }
            }
            
            self.tableView.reloadData()
        } catch {
            print("error occurred while retrieving from databse - \(error)")
        }
    }
}

