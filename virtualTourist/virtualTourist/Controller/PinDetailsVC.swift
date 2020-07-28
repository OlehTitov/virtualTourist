//
//  PinDetailsVC.swift
//  virtualTourist
//
//  Created by Oleh Titov on 27.07.2020.
//  Copyright © 2020 Oleh Titov. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import MapKit

class PinDetailsVC: UIViewController, NSFetchedResultsControllerDelegate, UICollectionViewDelegate {
    
    //MARK: - PROPERTIES
    var altitude: CLLocationDistance!
    var annotation: MKAnnotation!
    var selectedPin: Pin!
    var dataSource: UICollectionViewDiffableDataSource<Int, SavedPhoto>! = nil
    var fetchedResultsController: NSFetchedResultsController<SavedPhoto>!
    var snapshot = NSDiffableDataSourceSnapshot<Int, SavedPhoto>()
    let mapViewMaxHeight: CGFloat = 180
    let mapViewMinHeight: CGFloat = 100
    
    //MARK: - OUTLETS
    @IBOutlet weak var photoCollection: UICollectionView!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var mapHeightConstraint: NSLayoutConstraint!

    //MARK: - VIEW DID LOAD
    override func viewDidLoad() {
        super.viewDidLoad()
        photoCollection.delegate = self
        setupFetchedResultsController()
        configureDataSource()
        configureLayout()
        //downloadImages()
        setupMap()
    }
    
    //MARK: - VIEW WILL APPEAR
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFetchedResultsController()
    }
    
    //MARK: - VIEW WILL DISAPPEAR
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultsController = nil
    }
    //MARK: - SETUP MAP
    private func setupMap() {
        mapHeightConstraint.constant = 180
        mapView.delegate = self
        mapView.addAnnotation(annotation)
        mapView.camera.altitude = 3000.00
        let region = MKCoordinateRegion(center: annotation.coordinate, span: mapView.region.span)
        mapView.setRegion(region, animated: true)
    }
    
    
    //MARK: - COLLECTION VIEW DIFFABLE DATA SOURCE
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, SavedPhoto>(collectionView: photoCollection) {
            (collectionView: UICollectionView, indexPath: IndexPath, photo: SavedPhoto) -> UICollectionViewCell? in
            
            // Create cell
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "photoCellIdentifier",
                for: indexPath) as? CollectionViewPhotoCell else { fatalError("Cannot create new cell") }
            
            // Populate the cell with image
            var image: UIImage!
            if let photoImage = photo.image {
                image = UIImage(data: photoImage)
            }
            //print(image.size as Any)
            cell.photoView.image = image
            
            return cell
        }
        setupSnapshot()
    }
    
    private func setupSnapshot() {
        snapshot = NSDiffableDataSourceSnapshot<Int, SavedPhoto>()
        snapshot.appendSections([0])
        snapshot.appendItems(fetchedResultsController.fetchedObjects ?? [])
        dataSource?.apply(self.snapshot)
    }
    
    //MARK: - SETUP FRC
    fileprivate func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<SavedPhoto> = SavedPhoto.fetchRequest()
        fetchRequest.sortDescriptors = []
        //Check if we have selectedPin
        
        let predicate = NSPredicate(format: "pin == %@", selectedPin)
        fetchRequest.predicate = predicate
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataController.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        do {
            try fetchedResultsController.performFetch()
            setupSnapshot()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    //MARK: - NETWORKING
    private func downloadImages() {
        FlickrClient.getListOfPhotosForLocation(lat: selectedPin.lat, lon: selectedPin.lon, radius: 7, page: 1) { (photos, error) in
            for photo in photos {
                guard let photoURL = URL(string: photo.imageURL ?? "") else {
                    return
                }
                //Check if there are URLs
                print(photoURL)
                DispatchQueue.global(qos: .userInteractive).async {
                    FlickrClient.downloadImage(path: photoURL, completion: handleImageDownload(data:error:))
                }
                
            }
        }
        
        func handleImageDownload(data: Data?, error: Error?) {
            guard let data = data else {
                return
            }
            //Check if we have the data
            print("Here goes the data from handleImageDownload: \(data)")
            // Save images to Core Data
            let image = SavedPhoto(context: DataController.shared.viewContext)
            image.pin = self.selectedPin
            image.image = data
            try? DataController.shared.viewContext.save()
            
            DispatchQueue.main.async {
                self.setupSnapshot()
                // Check if we have have data in Core Data
                //let photosInModel = self.fetchedResultsController.fetchedObjects
                //print("Amount of photos in Core Data: \(photosInModel?.count)")
            }
            
        }
    }
    
    //MARK: - FRC DELEGATE
    // Whenever the content changes it updates the snapshot
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        setupSnapshot()
    }
    
    //MARK: - COLLECTION VIEW LAYOUT
    func configureLayout() {
        photoCollection.collectionViewLayout = generateLayout()
        photoCollection.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    func generateLayout() -> UICollectionViewLayout {
        // First type. Full
        let fullPhotoItem = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(2/3)))
        
        fullPhotoItem.contentInsets = NSDirectionalEdgeInsets(
            top: 2,
            leading: 2,
            bottom: 2,
            trailing: 2)
        // Second type: Main with pair
        // 3
        let mainItem = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(2/3),
                heightDimension: .fractionalHeight(1.0)))
        
        mainItem.contentInsets = NSDirectionalEdgeInsets(
            top: 2,
            leading: 2,
            bottom: 2,
            trailing: 2)
        
        // 2
        let pairItem = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.5)))
        
        pairItem.contentInsets = NSDirectionalEdgeInsets(
            top: 2,
            leading: 2,
            bottom: 2,
            trailing: 2)
        
        let trailingGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1/3),
                heightDimension: .fractionalHeight(1.0)),
            subitem: pairItem,
            count: 2)
        
        // 1
        let mainWithPairGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(4/9)),
            subitems: [mainItem, trailingGroup])
        // Third type. Triplet
        let tripletItem = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1/3),
            heightDimension: .fractionalHeight(1.0)))

        tripletItem.contentInsets = NSDirectionalEdgeInsets(
          top: 2,
          leading: 2,
          bottom: 2,
          trailing: 2)

        let tripletGroup = NSCollectionLayoutGroup.horizontal(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(2/9)),
          subitems: [tripletItem, tripletItem, tripletItem])
        // Fourth type. Reversed main with pair
        let mainWithPairReversedGroup = NSCollectionLayoutGroup.horizontal(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(4/9)),
          subitems: [trailingGroup, mainItem])
        //2
        let nestedGroup = NSCollectionLayoutGroup.vertical(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(16/9)),
          subitems: [
            fullPhotoItem,
            mainWithPairGroup,
            tripletGroup,
            mainWithPairReversedGroup
          ]
        )

        let section = NSCollectionLayoutSection(group: nestedGroup)
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
}

extension PinDetailsVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = .red
            pinView!.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
}

//MARK: - SCROLL VIEW DELEGATE
extension PinDetailsVC: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y: CGFloat = scrollView.contentOffset.y
        let newMapViewHeight: CGFloat = mapHeightConstraint.constant - y
        
        if newMapViewHeight > mapViewMaxHeight {
            mapHeightConstraint.constant = mapViewMaxHeight
        } else if newMapViewHeight < mapViewMinHeight {
            mapHeightConstraint.constant = mapViewMinHeight
        } else {
            mapHeightConstraint.constant = newMapViewHeight
            scrollView.contentOffset.y = 0 // block scroll view
        }
    }
}