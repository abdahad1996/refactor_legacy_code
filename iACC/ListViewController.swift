//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit



protocol itemServiceStrategy {
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void)
}
 

class ListViewController: UITableViewController {
	var items = [itemViewModel]()
    var service:itemServiceStrategy?
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
        service?.loadItems(completion: handleAPIResult)
	}
	
    
private func handleAPIResult(_ result: Result<[itemViewModel], Error>) {
		switch result {
		case let .success(items):
            self.items = items
			self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
			
		case let .failure(error):
                showError(error)
				self.refreshControl?.endRefreshing()
			 
		}
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = items[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
        let viewModel = item
		cell.configure(viewModel)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let vm = items[indexPath.row]
        vm.selection()
	}
	
    
     
}

struct itemViewModel{
   
    let text : String
    let detailText:String
    var selection:()->(Void)
    
    init(card:Card, selection: @escaping () -> (Void)) {
       self.text = card.number
       self.detailText = card.holder
       self.selection = selection

   }
    
}

extension itemViewModel {
    init(friend:Friend,selection: @escaping () -> (Void)) {
       self.text = friend.name
       self.detailText = friend.phone
       self.selection = selection

   }
}

extension itemViewModel {
    init(transfer:Transfer,longDateStyle:Bool,selection: @escaping () -> (Void)) {
        let numberFormatter = Formatters.number
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = transfer.currencyCode
        self.selection = selection

        
        let amount = numberFormatter.string(from: transfer.amount as NSNumber)!
        text = "\(amount) • \(transfer.description)"
        
        let dateFormatter = Formatters.date
        if longDateStyle {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            detailText = "Sent to: \(transfer.recipient) on \(dateFormatter.string(from: transfer.date))"
        } else {
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            detailText = "Received from: \(transfer.sender) on \(dateFormatter.string(from: transfer.date))"
        }
    }
}

extension UITableViewCell {
	func configure(_ item: itemViewModel) {
        textLabel?.text = item.text
        detailTextLabel?.text = item.detailText
        
	}
}

