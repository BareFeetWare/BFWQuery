BFWQuery

(c) 2010-2018 BareFeetWare
Tom Brodhurst-Hill
developer@barefeetware.com

Objectives:

1. Makes the power of SQLite available to Cocoa developers as simple as accessing arrays. Initialise a query, then get its rows.

2. Internally manages the array without storing all rows in RAM. BFWQuery creates the objects within a row lazily, when requested. So, whether your query result is 10 rows or 10,000 rows, it shouldn’t take noticeably more memory.

Usage:

1. Instantiate a database connection, eg:

let database = Database(path: "path/to/Countries.sqlite")

2. Create a query, eg:

let query = database.query(sql: "select * from Country order by name where name = ?",
                           arguments: [countryName])

3. Access rows of the query's result:

To get the number of rows in the result array: query.rowCount

To get row 4, value in column "name": query[4]["name"]


4. Using BFWQuery in a UITableViewController:

See the BFWQuery BFWQuery Demo target for more.

class CountriesViewController: UITableViewController {

    let query = database.query(sql: "select * from Country order by name")

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
}

Requirements:

1. In Xcode, add libsqlite3 to your project’s list of frameworks.

2. Add the BFWQuery.framework to your project.


License:

Use as you like, but keep the (c) BareFeetWare in the header and include “Includes the BFWQuery framework by BareFeetWare” in your app’s info panel or credits.

Many thanks to Dr Richard Hipp for SQLite.
