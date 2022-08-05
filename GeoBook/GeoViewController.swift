//
//  GeoViewController.swift
//  GeoBook
//
//  Created by Ranjan Akarsh on 05/08/22.
//

import UIKit
import CoreData
import CoreLocation
import MapKit

class GeoViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var subtitleLabel: UITextField!
    @IBOutlet weak var titleLabel: UITextField!

    var requestedLocationID: UUID? // nil means create new location
    
    var newLatitude: Double = 0.0
    var newLongitude: Double = 0.0
    
    let mapController: CLLocationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.mapView.delegate = self
        
        self.mapController.delegate = self
        self.mapController.desiredAccuracy = kCLLocationAccuracyBest
        self.mapController.requestWhenInUseAuthorization()
        
        if let requestedLocation = self.requestedLocationID { // requested to show already saved location
            self.saveButton.isHidden = true
            self.titleLabel.isUserInteractionEnabled = false
            self.subtitleLabel.isUserInteractionEnabled = false
            
            self.fetchRequestedLocationDetails(uuid: requestedLocation)
        } else { // create new
            let mapGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressedOnMap(gestureRecognizer:)))
            mapGesture.minimumPressDuration = 3
            self.mapView.addGestureRecognizer(mapGesture)

            self.mapController.startUpdatingLocation()
        }
    }

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if self.requestedLocationID != nil {
            let requestLocation = CLLocation(latitude: newLatitude, longitude: newLongitude)
            CLGeocoder().reverseGeocodeLocation(requestLocation, completionHandler: { (placemarks, error) in
                if let listOfPlacement = placemarks {
                    if listOfPlacement.count > 0 {
                        let newPlacemark = MKPlacemark(placemark: listOfPlacement[0])
                        let item = MKMapItem(placemark: newPlacemark)
                        item.name = self.titleLabel.text!
                        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                        item.openInMaps(launchOptions: launchOptions)
                    }
                }
                
            })
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let pinReuseID = "customAnnotation"
        var pinView = self.mapView.dequeueReusableAnnotationView(withIdentifier: pinReuseID) as? MKMarkerAnnotationView
        
        if pinView == nil {
            pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: pinReuseID)
            pinView?.canShowCallout = true
            pinView?.tintColor = UIColor.blue
            
            let button = UIButton(type: UIButton.ButtonType.detailDisclosure)
            pinView?.rightCalloutAccessoryView = button
        } else {
            pinView?.annotation = annotation
        }
        
        return pinView
    }
        
    @IBAction func saveButtonPressed(_ sender: UIButton) {
        if self.validateFields(validateAnnotation: true) {
            self.saveToDatabse()
            self.dismiss(animated: true)
            // notify
            self.navigationController?.popViewController(animated: true)
            NotificationCenter.default.post(name: Notification.Name("newLocation"), object: nil)
        }
    }
    
    @objc func longPressedOnMap(gestureRecognizer: UILongPressGestureRecognizer) {
        if self.validateFields(validateAnnotation: false) {
            let viewLocation = gestureRecognizer.location(in: self.mapView)
            let convertedLocation = self.mapView.convert(viewLocation, toCoordinateFrom: self.mapView)
            
            // add annotation
            self.createAnnotation(title: self.titleLabel.text!, subtitle: self.subtitleLabel.text!, latitude: convertedLocation.latitude, longitude: convertedLocation.longitude)
            
            self.newLatitude = convertedLocation.latitude
            self.newLongitude = convertedLocation.longitude
        }
    }
    
    private func fetchRequestedLocationDetails(uuid: UUID) {
        guard let delegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let wrappedContext = delegate.persistentContainer.viewContext
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Geo")
        fetchRequest.predicate = NSPredicate(format: "id = %@", uuid.uuidString)
        fetchRequest.returnsObjectsAsFaults = false
        
        do {
            let results = try wrappedContext.fetch(fetchRequest)
            for result in results as! [NSManagedObject] {
                if let id = result.value(forKey: "id") as? UUID {
                    if id == uuid {

                        if let title = result.value(forKey: "title") as? String {
                            self.titleLabel.text = title
                        }
                        
                        if let subtitle = result.value(forKey: "subtitle") as? String {
                            self.subtitleLabel.text = subtitle
                        }
                        
                        if let latitude = result.value(forKey: "latitude") as? Double, let longitude = result.value(forKey: "longitude") as? Double {
                            self.markOnMap(latitude: latitude, longitude: longitude)
                        }
                        
                        break
                    }
                }
            }
        } catch {
            print("error occurred while retrieveing \(uuid.uuidString) - \(error)")
        }
        
    }
    
    private func createAnnotation(title: String, subtitle: String, latitude: Double, longitude: Double) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        annotation.title = title
        annotation.subtitle = subtitle
        self.mapView.addAnnotation(annotation)
    }
    
    private func markOnMap(latitude: Double, longitude: Double) {
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: true)
        // create annotation
        self.createAnnotation(title: self.titleLabel.text!, subtitle: self.subtitleLabel.text!, latitude: location.latitude, longitude: location.longitude)
    }
    
    private func saveToDatabse() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let wrappedContext = appDelegate.persistentContainer.viewContext
        
        let entity = NSEntityDescription.insertNewObject(forEntityName: "Geo", into: wrappedContext)
        entity.setValue(UUID(), forKey: "id")
        entity.setValue(self.titleLabel.text!, forKey: "title")
        entity.setValue(self.subtitleLabel.text!, forKey: "subtitle")
        entity.setValue(newLatitude, forKey: "latitude")
        entity.setValue(newLongitude, forKey: "longitude")
        
        do {
            try wrappedContext.save()
        } catch {
            print("error occurred while saving - \(error)")
        }
    }
    
    private func validateFields(validateAnnotation: Bool) -> Bool {
        var message: String = ""
        if self.titleLabel.text!.isEmpty {
            message = "title cannot be empty!"
        } else if self.subtitleLabel.text!.isEmpty {
            message = "subtitle cannot be empty!"
        }
        
        if validateAnnotation {
            if self.newLatitude == 0.0 || self.newLongitude == 0.0 {
                message = "you have to annotate the map!"
            }
        }
        
        if !message.isEmpty {
            let alert = UIAlertController(title: "error!", message: message, preferredStyle: .alert)
            let done = UIAlertAction(title: "done", style: .cancel)
            alert.addAction(done)
            self.present(alert, animated: true)
            
            return false
        }
        
        return true
    }
}
