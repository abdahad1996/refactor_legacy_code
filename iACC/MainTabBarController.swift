//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
	
    private let friendsCache:FriendsCache
	 init(friendsCache:FriendsCache) {
         self.friendsCache = friendsCache
		super.init(nibName: nil, bundle: nil)
 		self.setupViewController()
       
	}
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
		let vc = ListViewController()
         
        let isPremium = User.shared?.isPremium == true
        let api = friendsApiAdapter(
            api: FriendsAPI.shared,
            cache: isPremium ? friendsCache : NullFriendsCache(),
            
            selectFriend: { [weak vc] friend in
                vc?.selectFriend(friend: friend)
            }).retry(retryCount: 2)
        let cache = friendsCacheAdapter(cache: (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache,  selectFriend: { [weak vc] friend in
            vc?.selectFriend(friend: friend)
        })
        
        vc.service = isPremium ? api.fallback(cache) : api
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addFriend))
        
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
         vc.service = sentTransferAdapter(
            api: TransfersAPI.shared,
            selectTransfer: { [weak vc] transfer in
                vc?.selectTransfer(transfer: transfer)
            }).retry(retryCount: 1)
        vc.title = "sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(sendMoney))
      
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
         vc.service = recievedTransferAdapter(
            api: TransfersAPI.shared,
            selectTransfer: { [weak vc] transfer in
                vc?.selectTransfer(transfer: transfer)
            }).retry(retryCount: 1)
        vc.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(requestMoney))
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
         vc.service = cardApiAdapter(
            api: CardAPI.shared,
            selectCard: { [weak vc] card in
                vc?.selectCard(card: card)
            })
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(addCard))
		return vc
	}
	
}



struct friendsApiAdapter:itemServiceStrategy{
    
    let api:FriendsAPI
    let cache:FriendsCache
    let selectFriend:(Friend)->(Void)
    
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
        api.loadFriends {  result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ item in
                        cache.save(item)
                  return item.map { item in
                        itemViewModel(friend: item, selection: {
                            selectFriend(item)
                        })
                    }
                     
                }))
               
            }
        }
    }
    
    
}

struct friendsCacheAdapter:itemServiceStrategy{
    
    let cache:FriendsCache
    let selectFriend:(Friend)->(Void)
    
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
        cache.loadFriends {  result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ item in
                  return item.map { item in
                        itemViewModel(friend: item, selection: {
                            selectFriend(item)
                        })
                    }
                     
                }))
               
            }
        }
    }
    
    
}

extension itemServiceStrategy{
    func fallback(_ fallback:itemServiceStrategy) -> itemServiceStrategy{
        return ItemsServiceWithFallbackComposite(primary: self, fallback: fallback)
    }
    
    func retry(retryCount:UInt) -> itemServiceStrategy{
        var service:itemServiceStrategy = self
        for _ in 0..<retryCount{
            service = service.fallback(self)
        }
        return service
    }
}
struct ItemsServiceWithFallbackComposite:itemServiceStrategy{
   
    
    let primary:itemServiceStrategy
    let fallback:itemServiceStrategy
    
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
        primary.loadItems { result in
            switch result {
            case .success(_):
                completion(result)
            case .failure(_):
                fallback.loadItems(completion: completion)
            }
        }
    }
    
}
class NullFriendsCache:FriendsCache{
    override func save(_ newFriends: [Friend]) {
        
    }
}

struct cardApiAdapter:itemServiceStrategy{
    
    let api:CardAPI
    let selectCard:(Card)->(Void)
    
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
        api.loadCards {  result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ item in
                  return item.map { item in
                        itemViewModel(card: item, selection: {
                            selectCard(item)
                        })
                    }
                     
                }))
               
            }
        }
    }
    
    
}


struct sentTransferAdapter:itemServiceStrategy{
    
    let api:TransfersAPI
    let selectTransfer:(Transfer)->(Void)
 
    func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
        api.loadTransfers {  result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map({ item in
                    return
                        item
                        .filter({$0.isSender})
                        .map { item in
                      itemViewModel(
                        transfer: item,
                        longDateStyle: true, selection: {
                        selectTransfer(item)
                        })
                    }
                     
                }))
               
            }
        }
    }
}
    
    struct recievedTransferAdapter:itemServiceStrategy{
        
        let api:TransfersAPI
        let selectTransfer:(Transfer)->(Void)
 
        func loadItems(completion: @escaping (Result<[itemViewModel], Error>) -> Void) {
            api.loadTransfers {  result in
                DispatchQueue.mainAsyncIfNeeded {
                    completion(result.map({ item in
                        return
                            item
                            .filter({!$0.isSender})
                            .map { item in
                          itemViewModel(transfer: item, longDateStyle: false, selection: {
                                selectTransfer(item)
                            })
                        }
                         
                    }))
                   
                }
            }
        }
    
    }


extension UIViewController{
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
