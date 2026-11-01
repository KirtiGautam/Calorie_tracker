/// The sheets the Today screen can present, one at a time.
enum TodaySheet: Identifiable {
    /// Choose how much of a food to log.
    case logFood(FoodItem)

    /// Edit the goal and daily targets.
    case targets

    /// Create an account, sign in, or manage the account and sync.
    case account

    var id: String {
        switch self {
        case .logFood(let food): "logFood-\(food.id)"
        case .targets: "targets"
        case .account: "account"
        }
    }
}
