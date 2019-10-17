//
//  FeedWranglerAPICaller.swift
//  Account
//
//  Created by Jonathan Bennett on 2019-08-29.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import Foundation

import Foundation
import SyncDatabase
import RSWeb

final class FeedWranglerAPICaller: NSObject {
	
	private var transport: Transport!
	
	var credentials: Credentials?
	weak var accountMetadata: AccountMetadata?
	
	init(transport: Transport) {
		super.init()
		self.transport = transport
	}
	
	func validateCredentials(completion: @escaping (Result<Credentials?, Error>) -> Void) {
		let callURL = FeedWranglerConfig.clientURL.appendingPathComponent("users/authorize")
		let request = URLRequest(url: callURL, credentials: credentials)
		let username = self.credentials?.username ?? ""
		
		transport.send(request: request) { result in
			switch result {
			case .success(let (_, data)):
				guard let data = data else {
					completion(.success(nil))
					return
				}
				
				do {
					if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
						if let accessToken = json["access_token"] as? String {
							let authCredentials = Credentials(type: .feedWranglerToken, username: username, secret: accessToken)
							completion(.success(authCredentials))
							return
						}
					}
					
					completion(.success(nil))
				} catch let error {
					completion(.failure(error))
				}
			case .failure(let error):
				completion(.failure(error))
			}
			
		}
	}
	
	func retrieveSubscriptions(completion: @escaping (Result<[FeedWranglerSubscription], Error>) -> Void) {
		let url = FeedWranglerConfig.clientURL.appendingPathComponent("subscriptions/list")
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request, resultType: FeedWranglerSubscriptionsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feeds ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func renameSubscription(feedID: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("subscriptions/rename_feed"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		components.queryItems = [
			URLQueryItem(name: "feed_id", value: feedID),
			URLQueryItem(name: "feed_name", value: newName),
		]
		
		guard let url = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request, resultType: FeedWranglerSubscriptionsRequest.self) { result in
			switch result {
			case .success:
				completion(.success(()))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func removeSubscription(feedID: String, completion: @escaping (Result<Void, Error>) -> Void) {
		guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("subscriptions/remove_feed"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		components.queryItems = [
			URLQueryItem(name: "feed_id", value: feedID)
		]
		
		guard let url = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request, resultType: FeedWranglerGenericResult.self) { result in
			switch result {
			case .success:
				completion(.success(()))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	// MARK: FeedItems
	func retrieveFeedItems(page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("feed_items/list"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		// todo: handle initial sync better
		components.queryItems = [
			URLQueryItem(name: "read", value: "false"),
			URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
//			URLQueryItem(name: "created_since", value: feedID),
//			URLQueryItem(name: "updated_since", value: feedID),
		]
		
		guard let url = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}
		
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveUnreadFeedItems(page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("feed_items/list"), resolvingAgainstBaseURL: false) else {
			completion(.failure(TransportError.noURL))
			return
		}
		components.queryItems = [
			URLQueryItem(name: "read", value: "false"),
			URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
//			URLQueryItem(name: "created_since", value: feedID),
//			URLQueryItem(name: "updated_since", value: feedID),
		]
			
		guard let url = components.url else {
			completion(.failure(TransportError.noURL))
			return
		}
			
		let request = URLRequest(url: url, credentials: credentials)

		transport.send(request: request, resultType: FeedWranglerFeedItemsRequest.self) { result in
			switch result {
			case .success(let (_, results)):
				completion(.success(results?.feedItems ?? []))

			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveAllUnreadFeedItems(foundItems: [FeedWranglerFeedItem] = [], page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		retrieveUnreadFeedItems(page: page) { result in
			switch result {
			case .success(let newItems):
				if newItems.count > 0 {
					self.retrieveAllUnreadFeedItems(foundItems: foundItems + newItems, page: (page + 1), completion: completion)
				} else {
					completion(.success(foundItems + newItems))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func retrieveStarredFeedItems(page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
			guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("feed_items/list"), resolvingAgainstBaseURL: false) else {
				completion(.failure(TransportError.noURL))
				return
			}
			components.queryItems = [
				URLQueryItem(name: "starred", value: "true"),
				URLQueryItem(name: "offset", value: String(page * FeedWranglerConfig.pageSize)),
	//			URLQueryItem(name: "created_since", value: feedID),
	//			URLQueryItem(name: "updated_since", value: feedID),
			]
				
			guard let url = components.url else {
				completion(.failure(TransportError.noURL))
				return
			}
				
			let request = URLRequest(url: url, credentials: credentials)

			transport.send(request: request, resultType: FeedWranglerFeedItemsRequest.self) { result in
				switch result {
				case .success(let (_, results)):
					completion(.success(results?.feedItems ?? []))

				case .failure(let error):
					completion(.failure(error))
				}
			}
		}
	
	func retrieveAllStarredFeedItems(foundItems: [FeedWranglerFeedItem] = [], page: Int = 0, completion: @escaping (Result<[FeedWranglerFeedItem], Error>) -> Void) {
		retrieveStarredFeedItems(page: page) { result in
			switch result {
			case .success(let newItems):
				if newItems.count > 0 {
					self.retrieveAllStarredFeedItems(foundItems: foundItems + newItems, page: (page + 1), completion: completion)
				} else {
					completion(.success(foundItems + newItems))
				}
				
			case .failure(let error):
				completion(.failure(error))
			}
		}
	}
	
	func updateArticleStatus(_ articleID: String, _ statuses: [SyncStatus], completion: @escaping () -> Void) {
		guard var components = URLComponents(url: FeedWranglerConfig.clientURL.appendingPathComponent("feed_items/update"), resolvingAgainstBaseURL: false) else {
					completion()
					return
		}
		var queryItems = statuses.compactMap { status -> URLQueryItem? in
			switch status.key {
			case .read:
				return URLQueryItem(name: "read", value: status.flag.description)
				
			case .starred:
				return URLQueryItem(name: "starred", value: status.flag.description)
				
			case .userDeleted:
				return nil
			}
		}
		queryItems.append(URLQueryItem(name: "feed_item_id", value: articleID))
		components.queryItems = (components.queryItems ?? []) + queryItems
					
		guard let url = components.url else {
			completion()
			return
		}
					
		let request = URLRequest(url: url, credentials: credentials)
		
		transport.send(request: request, resultType: FeedWranglerGenericResult.self) { result in
			completion()
		}
	}

}
