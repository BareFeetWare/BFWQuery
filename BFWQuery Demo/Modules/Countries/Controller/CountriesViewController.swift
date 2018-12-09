//
//  CountriesViewController.swift
//  BFWQuery
//
//  Created by Tom Brodhurst-Hill on 26/03/2014.
//  Copyright (c) 2014 BareFeetWare. All rights reserved.
//

import UIKit
import BFWQuery

class CountriesViewController: UITableViewController, UISearchBarDelegate {
    
    // MARK: - IBOutlets
    
    @IBOutlet private var searchBar: UISearchBar!
    
    // MARK: - Accessors
    
    private let countries = BFWCountries()
    
    private var query: Database.Query! {
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
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return query.rowCount
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let queryRow = query![indexPath.row]
        cell.textLabel?.text = queryRow["name"]
        cell.detailTextLabel?.text = queryRow["code"]
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
