//
//  ListOfCoffeeMeetupsViewController.swift
//  CoffeeAlum
//
//  Created by Trevin Wisaksana on 12/26/16.
//  Copyright © 2016 Trevin Wisaksana. All rights reserved.
//

import UIKit
import Firebase

final class CoffeeMeetupsVC: UIViewController, SWRevealViewControllerDelegate, UIPopoverPresentationControllerDelegate, CoffeeMeetupsDelegate {
    
    fileprivate enum State {
        case `default`
        case loading
        case refreshData
        case retrieveCoffee
        case removeCoffee
        case rescheduleCoffee
        case invitationSelected(Invitation)
    }
    
    fileprivate var state: State = .default {
        didSet {
            didChange(state)
        }
    }

    // MARK: - IBOutlets
    @IBOutlet var mainView: CoffeeMeetupsVCMainView!
    @IBOutlet weak var collectionView: CoffeeMeetupsVCCollectionView!
    @IBOutlet weak var noInvitationLabel: UILabel!
    @IBOutlet weak var sidebarMenuButton: UIButton!
    
    // MARK: - Variables
    var headerTitleLabel: UILabel?
    private var titleHidden = true
    public var coffeeSelectedIndex: Int?
    public var collectionViewSection: Int?
    public var allCoffee = Set<Invitation>()
    private var refreshController = UIRefreshControl()
    
    // TODO: Getters and setters change it to fitler coffee
    fileprivate var pendingCoffee: [Invitation] {
        get {
            return Array(allCoffee).filter {
                !$0.coffee.accepted && !$0.coffee.rescheduled
            }
        }
        
        set {
            let invitationSelected = self.pendingCoffee[coffeeSelectedIndex!]
            allCoffee.remove(invitationSelected)
        }
    }
    
    fileprivate var upcomingCoffee: [Invitation] {
        get {
            return Array(allCoffee).filter {
                $0.coffee.accepted && !$0.coffee.rescheduled
            }
        }
        
        set {
            let invitationSelected = self.upcomingCoffee[coffeeSelectedIndex!]
            allCoffee.remove(invitationSelected)
        }
    }
    
    fileprivate var rescheduledCoffee: [Invitation] {
        get {
            return Array(allCoffee).filter {
                $0.coffee.rescheduled && !$0.coffee.accepted
            }
        }
        
        set {
            let invitationSelected = self.rescheduledCoffee[coffeeSelectedIndex!]
            allCoffee.remove(invitationSelected)
        }
    }

    
    private func didChange(_ state: State) {
        switch state {
        case .loading:
            retrieveCoffeeData()
            setupRefreshController()
            setupRevealViewController()
            sidebarMenuButton.setupSidebarButtonAction(to: self)
        case .refreshData:
            retrieveCoffeeData()
            collectionView.reloadData()
            refreshController.endRefreshing()
        case .removeCoffee:
            break
        case .rescheduleCoffee:
            break
        case .invitationSelected(let invitationSelected):
            setupPopover(with: invitationSelected)
        default:
            break
        }
    }
    
    // MARK: - Mandatory Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        state = .loading
    }

    override func viewDidLayoutSubviews() {
        // Using the Pan Gesture Recognizer to reveal the "SWRevealViewController"
        self.view.addGestureRecognizer(revealViewController().panGestureRecognizer())
        // Adjusting the revealWidth so that it works fairly with all screen sizes
        revealViewController().rearViewRevealWidth = self.view.frame.width / 3.2
    }
    
    private func setupRefreshController() {
        refreshController.addTarget(
            self,
            action: #selector(refreshStream),
            for: .valueChanged
        )
        collectionView.addSubview(refreshController)
        collectionView.alwaysBounceVertical = true
    }
    
    @objc fileprivate func refreshStream() {
        state = .refreshData
    }
    
    private func retrieveCoffeeData() {
        // Allows the collection view to refresh
        allCoffee.removeAll()
        
        APIClient.getCoffeeInvitationReceived { [weak self] (invitationReceived) in
            self?.insertCoffee(with: invitationReceived)
        }
        
        APIClient.getCoffeeInvitationSent { [weak self] (invitationSent) in
            self?.insertCoffee(with: invitationSent)
        }
    }
    
    
    private func insertCoffee(with invitation: Invitation) {
        
        allCoffee.insert(invitation)
        collectionView.reloadData()
        
        if allCoffee.count > 0 {
            noInvitationLabel.isHidden = true
        } else {
            noInvitationLabel.isHidden = false
        }
        
    }
    
    // TODO: Delete the coffee meetup declined
    internal func deleteCoffeeMeetupSelected() {
        
        // Check which section the user has selected
        // Remove the coffee based the section selected
        if collectionViewSection == 0 {
            upcomingCoffee.remove(at: coffeeSelectedIndex!)
        } else if collectionViewSection == 1 {
            pendingCoffee.remove(at: coffeeSelectedIndex!)
        } else {
            rescheduledCoffee.remove(at: coffeeSelectedIndex!)
        }
        
        // Update the collectionView
        collectionView.performBatchUpdates({
            
            let indexPaths = [IndexPath(
                row: self.coffeeSelectedIndex!,
                section: self.collectionViewSection!
            )]
            
            self.collectionView.deleteItems(at: indexPaths)
            
        }) { (_) in
            self.state = .refreshData
        }
        
    }
    
}


// MARK: - UICollectionView extension
extension CoffeeMeetupsVC: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Upcoming coffee events
        if section == 0 {
            return upcomingCoffee.count
        } else if section == 1 {
            return pendingCoffee.count
        } else {
            return rescheduledCoffee.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        var reusableView: UICollectionReusableView!
        // Checks if the view for supplementary element is the right type
        if kind == UICollectionElementKindSectionHeader {
            // Assigning reusable view
            reusableView = collectionView.dequeueReusableSupplementaryView(
                ofKind: UICollectionElementKindSectionHeader,
                withReuseIdentifier: "Header",
                for: indexPath
            )
            
            // Accessing the labels
            let label = reusableView?.subviews[0] as! UILabel
            headerTitleLabel = label
            
            // Titles of the sections
            let sectionNames = [
                "Upcoming coffee meetups",
                "Pending coffee invitations",
                "Pending to be rescheduled"
            ]
            // Assigning the title of the label
            headerTitleLabel?.text = sectionNames[indexPath.section]
            
        }
        
        return reusableView
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        var invitationSelected: Invitation?
        
        let section = indexPath.section
        
        func setupInvitationSelected(with array: [Invitation]) {
            invitationSelected = array[indexPath.row]
            coffeeSelectedIndex = indexPath.row
            collectionViewSection = indexPath.section
        }
        
        // Invitation selected
        if section == 0 {
            setupInvitationSelected(with: upcomingCoffee)
        } else if section == 1 {
            setupInvitationSelected(with: pendingCoffee)
        } else {
            setupInvitationSelected(with: rescheduledCoffee)
        }
        
        if let invitationSelected = invitationSelected {
            state = .invitationSelected(invitationSelected)
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        /*
         if titleHidden == true {
         headerTitleLabel?.isHidden = false
         titleHidden = false
         }
         */
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "CoffeeMeetupCell",
            for: indexPath) as! CoffeeMeetupCollectionViewCell
        
        var thisData: Invitation
        let section = indexPath.section
        
        if section == 0 {
            thisData = upcomingCoffee[indexPath.row]
        } else if section == 1 {
            thisData = pendingCoffee[indexPath.row]
        } else {
            thisData = rescheduledCoffee[indexPath.row]
        }
        
        cell.configure(with: thisData)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = self.view.frame.size.width
        let height = self.view.frame.size.height
        
        return CGSize(
            width: width,
            height: height / 4
        )
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
}
