import Foundation

class ReaderSelectInterestsCoordinator {
    private struct Constants {
        static let userDefaultsKeyFormat = "Reader.SelectInterests.hasSeenBefore.%@"
    }

    private let interestsService: ReaderFollowedInterestsService
    private let store: KeyValueDatabase
    private let userId: NSNumber?

    /// Creates a new instance of the coordinator
    /// - Parameter service: An Optional `ReaderFollowedInterestsService` to use. If this is `nil` one will be created on the main context
    ///   - store: An optional backing store to keep track of if the user has seen the select interests view or not
    ///   - userId: The logged in user account, this makes sure the tracking is a per-user basis
    init(service: ReaderFollowedInterestsService? = nil,
         store: KeyValueDatabase = UserDefaults.standard,
         userId: NSNumber? = nil,
         context: NSManagedObjectContext = ContextManager.sharedInstance().mainContext) {

        self.interestsService = service ?? ReaderTopicService(managedObjectContext: context)
        self.store = store
        self.userId = userId ?? {
            let acctServ = AccountService(managedObjectContext: context)
            let account = acctServ.defaultWordPressComAccount()

            return account?.userID
        }()
    }

    // MARK: - Saving
    public func saveInterests(interests: [String], completion: @escaping (Bool) -> Void) {
        self.interestsService.followInterests(slugs: interests, success: { _ in
            completion(true)
        }) { error in
            completion(false)
        }
    }

    // MARK: - Display Logic

    /// Determines whether or not the select interests view should be displayed
    /// - Returns: true 
    public func shouldDisplay(completion: @escaping (Bool) -> Void) {
        interestsService.fetchFollowedInterestsLocally { [weak self] (followedInterests) in
            let shouldDisplay: Bool = self?.shouldDisplaySelectInterests(with: followedInterests) ?? false
            completion(shouldDisplay)
        }
    }

    private func shouldDisplaySelectInterests(with interests: [ReaderTagTopic]?) -> Bool {
        #if DEBUG
        return true
        #endif

        guard let interests = interests else {
            return false
        }

        return !hasSeenBefore() && interests.count <= 0
    }

    // MARK: - View Tracking

    /// Generates the user defaults key for the logged in user
    /// Returns nil if we can not get the default WP.com account
    private var userDefaultsKey: String? {
        get {
            return String(format: Constants.userDefaultsKeyFormat, userId ?? 0)
        }
    }

    /// Determines whether the select interests view has been seen before
    func hasSeenBefore() -> Bool {
        guard let key = userDefaultsKey else {
            return false
        }

        return store.bool(forKey: key)
    }

    /// Marks the view as seen for the user
    func markAsSeen() {
        guard let key = userDefaultsKey else {
            return
        }

        store.set(true, forKey: key)
    }

    //TODO: RI Remove this
    func _debugResetHasSeen() {
        guard let key = userDefaultsKey else {
            return
        }

        DDLogDebug("Resetting hasSeenBefore: \(key)")
        store.set(false, forKey: key)
    }
}
