//
//  BFWMasterViewController.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import UIKit

class BFWMasterViewController: UITableViewController, UISearchBarDelegate {
    
    // MARK: - IBOutlets
    
    @IBOutlet private var searchBar: UISearchBar!
    
    // MARK: - Accessors
    
    private let countries = BFWCountries()
    
    private var query: BFWQuery! {
        didSet {
            tableView.reloadData()
        }
    }
    
    private func updateQuery() {
        if let text = searchBar.text, !text.isEmpty {
            query = countries.queryForCountriesContaining(text)
        } else {
            query = countries.queryForAllCountries
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateQuery()
    }
    
    // MARK: - UITableViewController
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return query.resultArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let rowDictionary = query.resultArray.dictionary(atRow: indexPath.row)
        cell.textLabel?.text = rowDictionary.object(forKey: "Name") as? String
        cell.detailTextLabel?.text = rowDictionary.object(forKey: "Code") as? String
        return cell
    }
    
    // MARK: - UISearchBarDelegate
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        updateQuery()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = nil
        updateQuery()
    }
    
}
