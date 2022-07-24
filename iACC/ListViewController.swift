//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit


class ListViewController: UITableViewController {
	var items = [itemViewModel]()
	
	var retryCount = 0
	var maxRetryCount = 0
	var shouldRetry = false
	
	var longDateStyle = false
	
	var fromReceivedTransfersScreen = false
	var fromSentTransfersScreen = false
	var fromCardsScreen = false
	var fromFriendsScreen = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
		
		if fromFriendsScreen {
			shouldRetry = true
			maxRetryCount = 2
			
			title = "Friends"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addFriend))
			
		} else if fromCardsScreen {
			shouldRetry = false
			
			title = "Cards"
			
			navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCard))
			
		} else if fromSentTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = true

			navigationItem.title = "Sent"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendMoney))

		} else if fromReceivedTransfersScreen {
			shouldRetry = true
			maxRetryCount = 1
			longDateStyle = false
			
			navigationItem.title = "Received"
			navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: self, action: #selector(requestMoney))
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
		if fromFriendsScreen {
			FriendsAPI.shared.loadFriends { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
					self?.handleAPIResult(result)
				}
			}
		} else if fromCardsScreen {
			CardAPI.shared.loadCards { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
					self?.handleAPIResult(result)
				}
			}
		} else if fromSentTransfersScreen || fromReceivedTransfersScreen {
			TransfersAPI.shared.loadTransfers { [weak self] result in
				DispatchQueue.mainAsyncIfNeeded {
					self?.handleAPIResult(result)
				}
			}
		} else {
			fatalError("unknown context")
		}
	}
	
    
private func handleAPIResult<T>(_ result: Result<[T], Error>) {
		switch result {
		case let .success(items):
			if fromFriendsScreen && User.shared?.isPremium == true {
				(UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.save(items as! [Friend])
			}
			self.retryCount = 0
			
			var filteredItems = items as [Any]
			if let transfers = items as? [Transfer] {
				if fromSentTransfersScreen {
					filteredItems = transfers.filter(\.isSender)
				} else {
					filteredItems = transfers.filter { !$0.isSender }
				}
			}
			
            self.items = filteredItems.map({ item in
                if let friend = item as? Friend {
                    return itemViewModel(friend: friend, selection: { [weak self] in
                        self?.selectFriend(friend: friend)
                    })
                }
                else if let card = item as? Card {
                    return itemViewModel(card: card, selection: { [weak self] in
                        self?.selectCard(card: card)
                    })
                }
                else if let transfer = item as? Transfer {
                    return itemViewModel(transfer: transfer, longDateStyle: longDateStyle, selection: { [weak self] in
                        self?.selectTransfer(transfer: transfer)
                    })
                }
                else{
                    fatalError()
                }
            })
			self.refreshControl?.endRefreshing()
			self.tableView.reloadData()
			
		case let .failure(error):
			if shouldRetry && retryCount < maxRetryCount {
				retryCount += 1
				
				refresh()
				return
			}
			
			retryCount = 0
			
			if fromFriendsScreen && User.shared?.isPremium == true {
				(UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.loadFriends { [weak self] result in
					DispatchQueue.mainAsyncIfNeeded {
						switch result {
						case let .success(items):
                            self?.items = items.map({ item in
                                return itemViewModel(friend: item) { [weak self] in
                                    self?.selectFriend(friend: item)
                                }
                            })
							self?.tableView.reloadData()
							
						case let .failure(error):
                            self?.showError(error)
						}
						self?.refreshControl?.endRefreshing()
					}
				}
			} else {
                showError(error)
				self.refreshControl?.endRefreshing()
			}
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
	
    
    func selectFriend(friend:Friend){
        let vc = FriendDetailsViewController()
        vc.friend = friend
        show(vc, sender: self)
    }
    
    func selectCard(card:Card){
        let vc = CardDetailsViewController()
        vc.card = card
        show(vc, sender: self)
    }
    
    func selectTransfer(transfer:Transfer){
        let vc = TransferDetailsViewController()
        vc.transfer = transfer
        show(vc, sender: self)
    }
     func showError(_ error: (Error)) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        self.showDetailViewController(alert, sender: self)
     }

	@objc func addCard() {
        show(AddCardViewController(), sender: self)
 	}
	
	@objc func addFriend() {
        show(AddFriendViewController(), sender: self)

 	}
	
	@objc func sendMoney() {
        show(SendMoneyViewController(), sender: self)

 	}
	
	@objc func requestMoney() {
        show(RequestMoneyViewController(), sender: self)

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

